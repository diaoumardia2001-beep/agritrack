// lib/services/sync/sync_engine.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/animals_repository.dart';
import '../../data/database/database_migrator.dart';
import '../../models/animal.dart';
import '../../models/sync_conflict.dart';
import '../../models/sync_queue_operation.dart';
import '../../models/user_profile.dart';
import 'supabase_sync_client.dart';
import 'sync_cursor_service.dart';
import 'sync_queue_service.dart';

/// Résultat détaillé d'un cycle d'exécution du moteur de synchronisation.
class SyncResult {
  final int processedOperations;
  final int successCount;
  final int failureCount;
  final int blockedCount;
  final List<String> errors;
  final bool hasFatalError;
  final String? fatalErrorMessage;
  final int animalsPulled;
  final int expensesPulled;
  final int conflictsCount;
  final int orphansResolved;

  const SyncResult({
    this.processedOperations = 0,
    this.successCount = 0,
    this.failureCount = 0,
    this.blockedCount = 0,
    this.errors = const [],
    this.hasFatalError = false,
    this.fatalErrorMessage,
    this.animalsPulled = 0,
    this.expensesPulled = 0,
    this.conflictsCount = 0,
    this.orphansResolved = 0,
  });

  bool get isSuccess =>
      !hasFatalError && failureCount == 0 && blockedCount == 0;

  bool get hasConflicts => conflictsCount > 0;

  bool get hasChanges =>
      successCount > 0 ||
      animalsPulled > 0 ||
      expensesPulled > 0 ||
      orphansResolved > 0;

  factory SyncResult.empty() => const SyncResult();

  factory SyncResult.fatal(String message) => SyncResult(
        hasFatalError: true,
        fatalErrorMessage: message,
        errors: [message],
      );

  @override
  String toString() =>
      'SyncResult(processed: $processedOperations, success: $successCount, failures: $failureCount, blocked: $blockedCount, pulledAnimals: $animalsPulled, pulledExpenses: $expensesPulled, conflicts: $conflictsCount, orphansResolved: $orphansResolved, fatal: $hasFatalError)';
}

/// Moteur de synchronisation Sembast ↔ Supabase (Étape 5B & 5C).
///
/// Orchestre la transmission ordonnée et sécurisée des opérations en attente (Push)
/// et la récupération différentielle (Pull) depuis Supabase en respectant les règles métier et RLS :
/// - Ne synchronise jamais une exploitation locale.
/// - Exclut systématiquement toutes les données de démonstration.
/// - Vérifie l'adhésion et le rôle effectif de l'utilisateur sur l'exploitation distante.
/// - Ne considère jamais le rôle local `owner` comme une autorisation distante.
/// - Synchronise toujours les animaux avant leurs dépenses.
/// - Bloque l'envoi d'une dépense tant que son animal hôte ne possède pas de `remoteId` valide.
/// - Applique des suppressions exclusivement logiques (`deleted_at = now()`).
/// - Conserve les opérations en attente dans la file en cas d'erreur réseau pour reprise ultérieure.
/// - Préserve les modifications locales en attente contre tout écrasement lors d'un Pull.
class SyncEngine {
  final ISupabaseSyncClient _syncClient;
  final SyncQueueService _queueService;
  final AnimalsRepository _animalsRepository;
  final SyncCursorService _cursorService;

  SyncEngine({
    required ISupabaseSyncClient syncClient,
    required SyncQueueService queueService,
    required AnimalsRepository animalsRepository,
    SyncCursorService? cursorService,
  })  : _syncClient = syncClient,
        _queueService = queueService,
        _animalsRepository = animalsRepository,
        _cursorService = cursorService ?? SyncCursorService();

  /// Exécute la synchronisation des opérations en attente pour une exploitation et un utilisateur donnés.
  Future<SyncResult> syncPendingOperations({
    required String farmId,
    required String userId,
    UserRole? fallbackRole,
  }) async {
    final cleanFarmId = farmId.trim();
    final cleanUserId = userId.trim();

    // 1. Garde-fou session utilisateur
    if (cleanUserId.isEmpty) {
      const msg = 'Session Supabase manquante ou non authentifiée.';
      debugPrint('[SyncEngine] $msg');
      return SyncResult.fatal(msg);
    }

    // 2. Garde-fou exploitation locale
    if (cleanFarmId.isEmpty ||
        cleanFarmId == DatabaseMigrator.defaultFarmId ||
        cleanFarmId.startsWith('local_')) {
      final msg =
          'Synchronisation refusée : l\'exploitation "$cleanFarmId" est locale et ne peut pas être synchronisée avec le cloud.';
      debugPrint('[SyncEngine] $msg');
      return SyncResult.fatal(msg);
    }

    // 3. Vérification de l'adhésion et du rôle effectif sur l'exploitation distante
    final remoteRoleStr = await _syncClient.getMemberRole(
      farmId: cleanFarmId,
      userId: cleanUserId,
    );

    if (remoteRoleStr == null) {
      final msg =
          'Accès refusé : l\'utilisateur $cleanUserId n\'est pas membre de l\'exploitation distante $cleanFarmId.';
      debugPrint('[SyncEngine] $msg');
      return SyncResult.fatal(msg);
    }

    final effectiveRole = UserRole.fromString(remoteRoleStr);
    debugPrint(
      '[SyncEngine] Démarrage synchronisation farm=$cleanFarmId, user=$cleanUserId, rôle distant=$effectiveRole',
    );

    // 4. Récupération des opérations en attente (FIFO)
    final pendingOps = await _queueService.getPendingOperations(
      farmId: cleanFarmId,
      userId: cleanUserId,
    );

    if (pendingOps.isEmpty) {
      debugPrint('[SyncEngine] Aucune opération en attente pour $cleanFarmId');
      return SyncResult.empty();
    }

    // 5. Partitionnement : les animaux d'abord, les dépenses ensuite
    final animalOps = pendingOps
        .where((op) => op.entityType == SyncEntityType.animal)
        .toList();
    final expenseOps = pendingOps
        .where((op) => op.entityType == SyncEntityType.expense)
        .toList();

    int successCount = 0;
    int failureCount = 0;
    int blockedCount = 0;
    int totalConflicts = 0;
    final List<String> errors = [];

    // ── Traitement des animaux ──────────────────────────────────────────────
    for (final op in animalOps) {
      // Exclusion des données de démo
      if (_queueService.isDemoOrNonSyncable(
        entityType: op.entityType,
        localId: op.localId,
        farmId: op.farmId,
        isDemo: op.payload?['isDemo'] == true,
      )) {
        await _queueService.completeOperation(op.id);
        continue;
      }

      await _queueService.markInProgress(op.id);

      try {
        final animal = await _animalsRepository.getAnimalById(
          op.localId,
          includeDeleted: true,
        );

        if (op.action == SyncAction.delete) {
          // Contrôle de permission : un worker ne peut pas supprimer un animal
          if (effectiveRole == UserRole.worker) {
            final err =
                'Permission refusée: un ouvrier ne peut pas supprimer un animal distant (${op.localId}).';
            await _queueService.recordFailure(op.id, err);
            errors.add(err);
            failureCount++;
            continue;
          }

          if (animal != null &&
              animal.remoteId != null &&
              animal.remoteId!.isNotEmpty) {
            final pushRes = await _syncClient.pushAnimalRpc(
              operationId: op.id,
              farmId: cleanFarmId,
              action: 'delete',
              expectedVersion: animal.versionId,
              remoteId: animal.remoteId,
              deletedAt: animal.deletedAt ?? DateTime.now(),
            );

            if (pushRes.isConflict) {
              final conflict = SyncConflict(
                id: 'conf_${op.id}',
                farmId: cleanFarmId,
                operationId: op.id,
                entityType: SyncEntityType.animal,
                localId: op.localId,
                remoteId: animal.remoteId,
                expectedVersion: pushRes.expectedVersion,
                serverVersion: pushRes.serverVersion,
                localPayload: op.payload ?? animal.toMap(),
                serverData: pushRes.serverData,
                createdAt: DateTime.now(),
              );
              await _animalsRepository.recordConflict(conflict);

              await _animalsRepository.updateAnimalSyncMetadata(
                animalId: op.localId,
                syncStatus: SyncStatus.error,
              );

              await _queueService.completeOperation(op.id);
              totalConflicts++;
              continue;
            }

            // Succès
            await _animalsRepository.updateAnimalSyncMetadata(
              animalId: op.localId,
              remoteId: pushRes.remoteId,
              versionId: pushRes.versionId,
              syncStatus: SyncStatus.synced,
            );
          } else {
            // Animal supprimé localement avant d'avoir un remoteId
            await _animalsRepository.updateAnimalSyncMetadata(
              animalId: op.localId,
              syncStatus: SyncStatus.synced,
            );
          }

          await _queueService.completeOperation(op.id);
          successCount++;
        } else {
          // create ou update
          if (animal == null) {
            final err =
                'Animal local introuvable pour synchronisation : ${op.localId}';
            await _queueService.recordFailure(op.id, err);
            errors.add(err);
            failureCount++;
            continue;
          }

          final actionStr =
              (op.action == SyncAction.create || animal.remoteId == null)
                  ? 'create'
                  : 'update';

          final pushRes = await _syncClient.pushAnimalRpc(
            operationId: op.id,
            farmId: cleanFarmId,
            action: actionStr,
            expectedVersion: actionStr == 'update' ? animal.versionId : null,
            localId: animal.id,
            remoteId: animal.remoteId,
            name: animal.name,
            type: animal.type.name,
            ageMonths: animal.ageMonths,
            weightKg: animal.weightKg,
            healthStatus: _mapHealthStatus(animal.healthStatus),
            imageUrl: animal.imageUrl,
            deletedAt: animal.deletedAt,
          );

          if (pushRes.isConflict) {
            final conflict = SyncConflict(
              id: 'conf_${op.id}',
              farmId: cleanFarmId,
              operationId: op.id,
              entityType: SyncEntityType.animal,
              localId: op.localId,
              remoteId: animal.remoteId,
              expectedVersion: pushRes.expectedVersion,
              serverVersion: pushRes.serverVersion,
              localPayload: op.payload ?? animal.toMap(),
              serverData: pushRes.serverData,
              createdAt: DateTime.now(),
            );
            await _animalsRepository.recordConflict(conflict);

            await _animalsRepository.updateAnimalSyncMetadata(
              animalId: animal.id,
              syncStatus: SyncStatus.error,
            );

            await _queueService.completeOperation(op.id);
            totalConflicts++;
            continue;
          }

          // Succès
          await _animalsRepository.updateAnimalSyncMetadata(
            animalId: animal.id,
            remoteId: pushRes.remoteId,
            versionId: pushRes.versionId,
            syncStatus: SyncStatus.synced,
          );

          await _queueService.completeOperation(op.id);
          successCount++;
        }
      } catch (e) {
        final err = 'Erreur réseau/sync animal ${op.localId}: $e';
        debugPrint('[SyncEngine] $err');
        await _queueService.recordFailure(op.id, err);
        errors.add(err);
        failureCount++;
      }
    }

    // ── Traitement des dépenses ─────────────────────────────────────────────
    for (final op in expenseOps) {
      if (_queueService.isDemoOrNonSyncable(
        entityType: op.entityType,
        localId: op.localId,
        farmId: op.farmId,
        isDemo: op.payload?['isDemo'] == true,
      )) {
        await _queueService.completeOperation(op.id);
        continue;
      }

      // Identification de l'animal parent
      String? parentAnimalId = op.payload?['animalId'] as String?;
      Animal? parentAnimal;

      if (parentAnimalId != null && parentAnimalId.isNotEmpty) {
        parentAnimal = await _animalsRepository.getAnimalById(
          parentAnimalId,
          includeDeleted: true,
        );
      } else {
        // Recherche inverse dans les animaux de l'exploitation
        final allAnimals = await _animalsRepository.fetchAnimals(
          farmId: cleanFarmId,
          includeDeleted: true,
        );
        for (final a in allAnimals) {
          if (a.expenses.any((e) => e.id == op.localId)) {
            parentAnimal = a;
            parentAnimalId = a.id;
            break;
          }
        }
      }

      // Blocage impératif : l'animal parent doit exister ET posséder un remoteId distant valide
      if (parentAnimal == null ||
          parentAnimal.remoteId == null ||
          parentAnimal.remoteId!.trim().isEmpty) {
        final blockMsg =
            'Blocage: la dépense ${op.localId} ne peut pas être envoyée car son animal parent ($parentAnimalId) ne possède pas encore de remoteId distant.';
        debugPrint('[SyncEngine] $blockMsg');
        await _queueService.recordFailure(op.id, blockMsg);
        errors.add(blockMsg);
        blockedCount++;
        continue;
      }

      // Contrôle de permission : un worker ne peut ni modifier ni supprimer une dépense
      if (effectiveRole == UserRole.worker &&
          (op.action == SyncAction.update || op.action == SyncAction.delete)) {
        final err =
            'Permission refusée: un ouvrier ne peut pas modifier ou supprimer une dépense distante (${op.localId}).';
        await _queueService.recordFailure(op.id, err);
        errors.add(err);
        failureCount++;
        continue;
      }

      await _queueService.markInProgress(op.id);

      try {
        final expenseIndex =
            parentAnimal.expenses.indexWhere((e) => e.id == op.localId);
        final expense =
            expenseIndex != -1 ? parentAnimal.expenses[expenseIndex] : null;

        if (op.action == SyncAction.delete) {
          final effectiveRemoteId = (expense != null &&
                  expense.remoteId != null &&
                  expense.remoteId!.isNotEmpty)
              ? expense.remoteId
              : (op.payload?['remoteId'] as String?);

          if (effectiveRemoteId != null && effectiveRemoteId.isNotEmpty) {
            final pushRes = await _syncClient.pushExpenseRpc(
              operationId: op.id,
              farmId: cleanFarmId,
              action: 'delete',
              expectedVersion: expense?.versionId ?? 1,
              remoteId: effectiveRemoteId,
              animalId: parentAnimal.remoteId,
              deletedAt: expense?.deletedAt ?? DateTime.now(),
            );

            if (pushRes.isConflict) {
              final conflict = SyncConflict(
                id: 'conf_${op.id}',
                farmId: cleanFarmId,
                operationId: op.id,
                entityType: SyncEntityType.expense,
                localId: op.localId,
                remoteId: effectiveRemoteId,
                expectedVersion: pushRes.expectedVersion,
                serverVersion: pushRes.serverVersion,
                localPayload: op.payload ?? (expense != null ? expense.toMap() : {}),
                serverData: pushRes.serverData,
                createdAt: DateTime.now(),
              );
              await _animalsRepository.recordConflict(conflict);

              if (expense != null) {
                await _animalsRepository.updateExpenseSyncMetadata(
                  animalId: parentAnimal.id,
                  expenseId: op.localId,
                  syncStatus: SyncStatus.error,
                );
              }

              await _queueService.completeOperation(op.id);
              totalConflicts++;
              continue;
            }

            if (expense != null) {
              await _animalsRepository.updateExpenseSyncMetadata(
                animalId: parentAnimal.id,
                expenseId: op.localId,
                versionId: pushRes.versionId,
                syncStatus: SyncStatus.synced,
              );
            }
          } else {
            if (expense != null) {
              await _animalsRepository.updateExpenseSyncMetadata(
                animalId: parentAnimal.id,
                expenseId: op.localId,
                syncStatus: SyncStatus.synced,
              );
            }
          }
          await _queueService.completeOperation(op.id);
          successCount++;
        } else {
          // create ou update
          if (expense == null) {
            final err =
                'Dépense locale introuvable pour synchronisation : ${op.localId}';
            await _queueService.recordFailure(op.id, err);
            errors.add(err);
            failureCount++;
            continue;
          }

          final actionStr =
              (op.action == SyncAction.create || expense.remoteId == null)
                  ? 'create'
                  : 'update';

          final pushRes = await _syncClient.pushExpenseRpc(
            operationId: op.id,
            farmId: cleanFarmId,
            action: actionStr,
            expectedVersion: actionStr == 'update' ? expense.versionId : null,
            localId: expense.id,
            remoteId: expense.remoteId,
            animalId: parentAnimal.remoteId,
            label: expense.label,
            amount: expense.amount,
            date: expense.date,
            category: expense.category.name,
            deletedAt: expense.deletedAt,
          );

          if (pushRes.isConflict) {
            final conflict = SyncConflict(
              id: 'conf_${op.id}',
              farmId: cleanFarmId,
              operationId: op.id,
              entityType: SyncEntityType.expense,
              localId: op.localId,
              remoteId: expense.remoteId,
              expectedVersion: pushRes.expectedVersion,
              serverVersion: pushRes.serverVersion,
              localPayload: op.payload ?? expense.toMap(),
              serverData: pushRes.serverData,
              createdAt: DateTime.now(),
            );
            await _animalsRepository.recordConflict(conflict);

            await _animalsRepository.updateExpenseSyncMetadata(
              animalId: parentAnimal.id,
              expenseId: expense.id,
              syncStatus: SyncStatus.error,
            );

            await _queueService.completeOperation(op.id);
            totalConflicts++;
            continue;
          }

          // Succès
          await _animalsRepository.updateExpenseSyncMetadata(
            animalId: parentAnimal.id,
            expenseId: expense.id,
            remoteId: pushRes.remoteId,
            versionId: pushRes.versionId,
            syncStatus: SyncStatus.synced,
          );

          await _queueService.completeOperation(op.id);
          successCount++;
        }
      } catch (e) {
        final err = 'Erreur réseau/sync dépense ${op.localId}: $e';
        debugPrint('[SyncEngine] $err');
        await _queueService.recordFailure(op.id, err);
        errors.add(err);
        failureCount++;
      }
    }

    return SyncResult(
      processedOperations: animalOps.length + expenseOps.length,
      successCount: successCount,
      failureCount: failureCount,
      blockedCount: blockedCount,
      conflictsCount: totalConflicts,
      errors: errors,
    );
  }



  /// Conversion conforme des enums de statut sanitaire vers les contraintes SQL CHECK.
  String _mapHealthStatus(HealthStatus status) {
    switch (status) {
      case HealthStatus.sain:
        return 'sain';
      case HealthStatus.aSurveiller:
        return 'a_surveiller';
      case HealthStatus.malade:
        return 'malade';
    }
  }

  /// Exécute la synchronisation descendante (Pull) depuis Supabase vers Sembast.
  ///
  /// Récupère de manière paginée et différentielle les animaux puis les dépenses
  /// modifiés depuis les derniers curseurs enregistrés.
  ///
  /// Règles strictes :
  /// 1. Garde-fous : session valide, exploitation distante autorisée.
  /// 2. Vérification rôle membre distant.
  /// 3. Ingestion ordonnée (animaux avant dépenses) via [_animalsRepository.applyRemotePullBatch].
  /// 4. Préservation intégrale des entités locales en attente (aucun écrasement, conflits tracés).
  /// 5. Avancement du curseur uniquement après traitement réussi du lot.
  Future<SyncResult> pullRemoteChanges({
    required String farmId,
    required String userId,
    int pageSize = 100,
  }) async {
    final cleanFarmId = farmId.trim();
    final cleanUserId = userId.trim();

    // 1. Garde-fou session utilisateur
    if (cleanUserId.isEmpty) {
      const msg = 'Session Supabase manquante ou non authentifiée pour le Pull.';
      debugPrint('[SyncEngine] $msg');
      return SyncResult.fatal(msg);
    }

    // 2. Garde-fou exploitation locale
    if (cleanFarmId.isEmpty ||
        cleanFarmId == DatabaseMigrator.defaultFarmId ||
        cleanFarmId.startsWith('local_')) {
      final msg =
          'Pull refusé : l\'exploitation "$cleanFarmId" est locale et ne peut pas être synchronisée avec le cloud.';
      debugPrint('[SyncEngine] $msg');
      return SyncResult.fatal(msg);
    }

    // 3. Vérification du rôle distant (RLS security check)
    final remoteRoleStr = await _syncClient.getMemberRole(
      farmId: cleanFarmId,
      userId: cleanUserId,
    );
    if (remoteRoleStr == null) {
      final msg =
          'Accès refusé pour le Pull : l\'utilisateur $cleanUserId n\'est pas membre de l\'exploitation distante $cleanFarmId.';
      debugPrint('[SyncEngine] $msg');
      return SyncResult.fatal(msg);
    }

    debugPrint(
      '[SyncEngine] Démarrage du Pull pour farm=$cleanFarmId (user=$cleanUserId)',
    );

    int totalAnimalsPulled = 0;
    int totalExpensesPulled = 0;
    int totalConflicts = 0;
    int totalOrphansResolved = 0;
    final List<String> errors = [];

    // 4. Récupération des curseurs actuels
    SyncCursor? animalCursor = await _cursorService.getCursor(
      farmId: cleanFarmId,
      entityType: SyncEntityType.animal,
    );
    SyncCursor? expenseCursor = await _cursorService.getCursor(
      farmId: cleanFarmId,
      entityType: SyncEntityType.expense,
    );

    // ── Phase 1 : PULL ANIMAUX (paginé) ─────────────────────────────────────
    bool hasMoreAnimals = true;
    while (hasMoreAnimals) {
      List<Map<String, dynamic>> animalRows;
      try {
        animalRows = await _syncClient.fetchAnimals(
          farmId: cleanFarmId,
          since: animalCursor?.updatedAt,
          lastId: animalCursor?.lastId,
          limit: pageSize,
        );
      } catch (e) {
        final err = 'Erreur réseau lors de la récupération des animaux : $e';
        debugPrint('[SyncEngine] $err');
        errors.add(err);
        break; // Ne pas avancer le curseur en cas d'erreur
      }

      if (animalRows.isEmpty) {
        hasMoreAnimals = false;
        break;
      }

      // Application atomique locale dans AnimalsRepository
      try {
        final batchResult = await _animalsRepository.applyRemotePullBatch(
          farmId: cleanFarmId,
          remoteAnimals: animalRows,
          remoteExpenses: const [],
        );
        totalAnimalsPulled += batchResult.animalsApplied;
        totalConflicts += batchResult.animalsSkippedDueToConflict;
        totalOrphansResolved += batchResult.orphansResolved;

        // Avancer le curseur uniquement après application réussie
        final lastRow = animalRows.last;
        final lastUpdated =
            DateTime.tryParse(lastRow['updated_at'] as String? ?? '');
        final lastId = lastRow['id'] as String?;

        if (lastUpdated != null) {
          animalCursor = SyncCursor(updatedAt: lastUpdated, lastId: lastId);
          await _cursorService.saveCursor(
            farmId: cleanFarmId,
            entityType: SyncEntityType.animal,
            cursor: animalCursor,
          );
        }
      } catch (e) {
        final err = 'Erreur lors de l\'application locale des animaux : $e';
        debugPrint('[SyncEngine] $err');
        errors.add(err);
        break; // Échec d'application locale sans avancement du curseur
      }

      if (animalRows.length < pageSize) {
        hasMoreAnimals = false;
      }
    }

    // ── Résolution des dépenses en quarantaine après import des animaux ──────
    try {
      final extraResolved = await _animalsRepository.resolveQuarantinedExpenses(
        farmId: cleanFarmId,
      );
      totalOrphansResolved += extraResolved;
      if (extraResolved > 0) {
        debugPrint(
          '[SyncEngine] $extraResolved dépenses orphelines rattachées après le pull des animaux.',
        );
      }
    } catch (e) {
      debugPrint(
        '[SyncEngine] Avertissement lors de la résolution des dépenses orphelines: $e',
      );
    }

    // ── Phase 2 : PULL DÉPENSES (paginé) ────────────────────────────────────
    bool hasMoreExpenses = true;
    while (hasMoreExpenses) {
      List<Map<String, dynamic>> expenseRows;
      try {
        expenseRows = await _syncClient.fetchExpenses(
          farmId: cleanFarmId,
          since: expenseCursor?.updatedAt,
          lastId: expenseCursor?.lastId,
          limit: pageSize,
        );
      } catch (e) {
        final err = 'Erreur réseau lors de la récupération des dépenses : $e';
        debugPrint('[SyncEngine] $err');
        errors.add(err);
        break;
      }

      if (expenseRows.isEmpty) {
        hasMoreExpenses = false;
        break;
      }

      try {
        final batchResult = await _animalsRepository.applyRemotePullBatch(
          farmId: cleanFarmId,
          remoteAnimals: const [],
          remoteExpenses: expenseRows,
        );
        totalExpensesPulled += batchResult.expensesApplied;
        totalConflicts += batchResult.expensesSkippedDueToConflict;
        totalOrphansResolved += batchResult.orphansResolved;

        final lastRow = expenseRows.last;
        final lastUpdated =
            DateTime.tryParse(lastRow['updated_at'] as String? ?? '');
        final lastId = lastRow['id'] as String?;

        if (lastUpdated != null) {
          expenseCursor = SyncCursor(updatedAt: lastUpdated, lastId: lastId);
          await _cursorService.saveCursor(
            farmId: cleanFarmId,
            entityType: SyncEntityType.expense,
            cursor: expenseCursor,
          );
        }
      } catch (e) {
        final err = 'Erreur lors de l\'application locale des dépenses : $e';
        debugPrint('[SyncEngine] $err');
        errors.add(err);
        break;
      }

      if (expenseRows.length < pageSize) {
        hasMoreExpenses = false;
      }
    }

    // Tentative finale de résolution d'orphelins
    try {
      final finalResolved = await _animalsRepository.resolveQuarantinedExpenses(
        farmId: cleanFarmId,
      );
      totalOrphansResolved += finalResolved;
    } catch (_) {}

    debugPrint(
      '[SyncEngine] Fin du Pull pour $cleanFarmId : $totalAnimalsPulled animaux, $totalExpensesPulled dépenses, $totalOrphansResolved orphelines rattachées, $totalConflicts conflits',
    );

    return SyncResult(
      animalsPulled: totalAnimalsPulled,
      expensesPulled: totalExpensesPulled,
      conflictsCount: totalConflicts,
      orphansResolved: totalOrphansResolved,
      errors: errors,
      failureCount: errors.length,
    );
  }
}
