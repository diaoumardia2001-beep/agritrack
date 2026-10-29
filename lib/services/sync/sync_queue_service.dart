// lib/services/sync/sync_queue_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/animals_repository.dart';
import '../../data/database/app_database.dart';
import '../../data/database/database_migrator.dart';
import '../../models/animal.dart';
import '../../models/sync_queue_operation.dart';

/// Service responsable de la gestion et de la persistance de la file d'attente
/// des opérations de synchronisation locale (`sync_queue`).
class SyncQueueService {
  final Future<Database> Function()? _databaseProvider;
  final StoreRef<String, Map<String, dynamic>> _store =
      DatabaseMigrator.syncQueueStore;

  SyncQueueService({
    Future<Database>? database,
    Future<Database> Function()? databaseProvider,
  }) : _databaseProvider =
            database != null ? (() => database) : databaseProvider;

  Future<Database> _getDb() async {
    if (_databaseProvider != null) {
      return await _databaseProvider!();
    }
    return await AppDatabase.instance.database;
  }

  /// Vérifie si une entité est une donnée de démonstration ou une exploitation locale non synchronisable.
  /// En cas de doute, la fonction refuse l'ajout et journalise la raison.
  bool isDemoOrNonSyncable({
    required SyncEntityType entityType,
    required String localId,
    required String farmId,
    bool isDemo = false,
  }) {
    if (isDemo) {
      debugPrint(
          '[SyncQueue] Opération refusée pour $localId : marquée explicitement isDemo');
      return true;
    }

    if (farmId == DatabaseMigrator.defaultFarmId ||
        farmId.startsWith('local_')) {
      debugPrint(
          '[SyncQueue] Opération refusée pour $localId : exploitation locale "$farmId" exclue de la synchronisation cloud');
      return true;
    }

    if (entityType == SyncEntityType.animal &&
        DatabaseMigrator.knownDemoAnimalIds.contains(localId)) {
      debugPrint(
          '[SyncQueue] Opération refusée pour $localId : animal de démonstration officiel');
      return true;
    }

    if (entityType == SyncEntityType.expense &&
        DatabaseMigrator.knownDemoExpenseIds.contains(localId)) {
      debugPrint(
          '[SyncQueue] Opération refusée pour $localId : dépense de démonstration officielle');
      return true;
    }

    return false;
  }

  /// Ajoute une opération dans la file d'attente de manière idempotente et sécurisée.
  ///
  /// Applique les règles de fusion/coalescing :
  /// 1. Si une création est déjà en attente :
  ///    - une mise à jour réactualise la création sans créer de doublon.
  ///    - une suppression annule la création locale (néantisation hors ligne) et supprime l'opération.
  /// 2. Si une mise à jour est en attente :
  ///    - une nouvelle mise à jour fusionne le payload et réinitialise le statut à pending.
  ///    - une suppression remplace la mise à jour par une suppression.
  /// 3. Si une suppression est déjà en attente :
  ///    - une seconde suppression est ignorée (idempotente).
  ///
  /// Retourne l'opération enregistrée, ou `null` si l'opération a été refusée (ex: démo) ou neutralisée.
  Future<SyncQueueOperation?> enqueue({
    required SyncEntityType entityType,
    required String localId,
    required SyncAction action,
    required String farmId,
    String? userId,
    bool isDemo = false,
    Map<String, dynamic>? payload,
  }) async {
    final cleanLocalId = localId.trim();
    final cleanFarmId = farmId.trim();

    if (cleanLocalId.isEmpty || cleanFarmId.isEmpty) {
      debugPrint(
          '[SyncQueue] Opération refusée : localId ou farmId vide (localId: "$localId", farmId: "$farmId")');
      return null;
    }

    if (isDemoOrNonSyncable(
      entityType: entityType,
      localId: cleanLocalId,
      farmId: cleanFarmId,
      isDemo: isDemo,
    )) {
      return null;
    }

    final db = await _getDb();
    await DatabaseMigrator.migrate(db);

    return await db.transaction((txn) async {
      // Rechercher les opérations existantes pour cette entité sur cette exploitation
      final records = await _store.find(txn);
      final existingOps = records
          .map((s) => SyncQueueOperation.fromMap(s.value))
          .where((op) =>
              op.entityType == entityType &&
              op.localId == cleanLocalId &&
              op.farmId == cleanFarmId &&
              op.status != SyncOperationStatus.inProgress)
          .toList();

      if (existingOps.isNotEmpty) {
        final existing = existingOps.first;

        // Règle 1 : Entité créée localement et non encore synchronisée
        if (existing.action == SyncAction.create) {
          if (action == SyncAction.update) {
            // Mise à jour d'une création en attente : mise à jour du payload, reste en 'create'
            final updatedPayload = {
              if (existing.payload != null) ...existing.payload!,
              if (payload != null) ...payload,
            };
            final updatedOp = existing.copyWith(
              payload: updatedPayload,
              createdAt: DateTime.now(),
              status: SyncOperationStatus.pending,
              clearErrorMessage: true,
            );
            await _store.record(existing.id).put(txn, updatedOp.toMap());
            return updatedOp;
          } else if (action == SyncAction.delete) {
            // Création suivie d'une suppression hors ligne : neutralisation complète
            await _store.record(existing.id).delete(txn);
            // Si c'est un animal, annuler également les dépenses en attente rattachées à cet animal
            if (entityType == SyncEntityType.animal) {
              for (final r in records) {
                final op = SyncQueueOperation.fromMap(r.value);
                if (op.entityType == SyncEntityType.expense &&
                    op.payload?['animalId'] == cleanLocalId) {
                  await _store.record(op.id).delete(txn);
                }
              }
            }
            debugPrint(
                '[SyncQueue] Entité locale $cleanLocalId créée puis supprimée hors ligne : neutralisée.');
            return null;
          } else if (action == SyncAction.create) {
            // Doublon create : idempotent
            return existing;
          }
        }

        // Règle 2 : Entité mise à jour
        if (existing.action == SyncAction.update) {
          if (action == SyncAction.update) {
            final updatedPayload = {
              if (existing.payload != null) ...existing.payload!,
              if (payload != null) ...payload,
            };
            final updatedOp = existing.copyWith(
              payload: updatedPayload,
              createdAt: DateTime.now(),
              status: SyncOperationStatus.pending,
              clearErrorMessage: true,
            );
            await _store.record(existing.id).put(txn, updatedOp.toMap());
            return updatedOp;
          } else if (action == SyncAction.delete) {
            // La suppression l'emporte sur une simple mise à jour de propriétés
            final deleteOp = existing.copyWith(
              action: SyncAction.delete,
              payload: payload,
              createdAt: DateTime.now(),
              status: SyncOperationStatus.pending,
              clearErrorMessage: true,
            );
            await _store.record(existing.id).put(txn, deleteOp.toMap());
            return deleteOp;
          }
        }

        // Règle 3 : Suppression déjà en attente
        if (existing.action == SyncAction.delete) {
          if (action == SyncAction.delete) {
            return existing; // Idempotent
          }
        }
      }

      // Règle 4 : Nouvelle opération
      final opId =
          'sq_${DateTime.now().microsecondsSinceEpoch}_${cleanLocalId}_${action.name}';
      final newOp = SyncQueueOperation(
        id: opId,
        entityType: entityType,
        localId: cleanLocalId,
        action: action,
        farmId: cleanFarmId,
        userId: userId?.trim(),
        createdAt: DateTime.now(),
        status: SyncOperationStatus.pending,
        payload: payload,
      );

      await _store.record(opId).put(txn, newOp.toMap());
      return newOp;
    });
  }

  /// Récupère les opérations en attente (statut pending ou error), triées par ordre chronologique (FIFO).
  Future<List<SyncQueueOperation>> getPendingOperations({
    String? farmId,
    String? userId,
  }) async {
    final db = await _getDb();
    await DatabaseMigrator.migrate(db);

    final records = await _store.find(db);
    var ops = records
        .map((s) => SyncQueueOperation.fromMap(s.value))
        .where((op) =>
            op.status == SyncOperationStatus.pending ||
            op.status == SyncOperationStatus.error)
        .toList();

    if (farmId != null && farmId.isNotEmpty) {
      ops = ops.where((op) => op.farmId == farmId).toList();
    }

    if (userId != null && userId.isNotEmpty) {
      ops = ops.where((op) => op.userId == userId).toList();
    }

    ops.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return ops;
  }

  /// Récupère toutes les opérations d'une exploitation donnée.
  Future<List<SyncQueueOperation>> getOperationsByFarm(String farmId) async {
    final db = await _getDb();
    await DatabaseMigrator.migrate(db);

    final records = await _store.find(db);
    final ops = records
        .map((s) => SyncQueueOperation.fromMap(s.value))
        .where((op) => op.farmId == farmId)
        .toList();
    ops.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return ops;
  }

  /// Récupère toutes les opérations associées à un utilisateur donné.
  Future<List<SyncQueueOperation>> getOperationsByUser(String userId) async {
    final db = await _getDb();
    await DatabaseMigrator.migrate(db);

    final records = await _store.find(db);
    final ops = records
        .map((s) => SyncQueueOperation.fromMap(s.value))
        .where((op) => op.userId == userId)
        .toList();
    ops.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return ops;
  }

  /// Récupère l'intégralité des opérations de la file.
  Future<List<SyncQueueOperation>> getAllOperations() async {
    final db = await _getDb();
    await DatabaseMigrator.migrate(db);

    final records = await _store.find(db);
    final ops =
        records.map((s) => SyncQueueOperation.fromMap(s.value)).toList();
    ops.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return ops;
  }

  /// Récupère une opération par son identifiant unique.
  Future<SyncQueueOperation?> getOperationById(String operationId) async {
    final db = await _getDb();
    await DatabaseMigrator.migrate(db);

    final raw = await _store.record(operationId).get(db);
    if (raw == null) return null;
    return SyncQueueOperation.fromMap(raw);
  }

  /// Marque une opération comme en cours de traitement réseau.
  Future<void> markInProgress(String operationId) async {
    final db = await _getDb();
    await DatabaseMigrator.migrate(db);

    await db.transaction((txn) async {
      final raw = await _store.record(operationId).get(txn);
      if (raw == null) return;
      final op = SyncQueueOperation.fromMap(raw);
      final updated = op.copyWith(
        status: SyncOperationStatus.inProgress,
        lastAttemptAt: DateTime.now(),
      );
      await _store.record(operationId).put(txn, updated.toMap());
    });
  }

  /// Enregistre un échec temporaire ou définitif et incrémente le compteur de tentatives.
  /// L'opération est conservée dans la file avec le statut [SyncOperationStatus.error].
  Future<void> recordFailure(String operationId, String errorMessage) async {
    final db = await _getDb();
    await DatabaseMigrator.migrate(db);

    await db.transaction((txn) async {
      final raw = await _store.record(operationId).get(txn);
      if (raw == null) return;
      final op = SyncQueueOperation.fromMap(raw);
      final updated = op.copyWith(
        status: SyncOperationStatus.error,
        retryCount: op.retryCount + 1,
        lastAttemptAt: DateTime.now(),
        lastErrorMessage: errorMessage,
      );
      await _store.record(operationId).put(txn, updated.toMap());
    });
  }

  /// Marque une opération comme terminée avec succès et la retire définitivement de la file.
  Future<bool> completeOperation(String operationId) async {
    final db = await _getDb();
    await DatabaseMigrator.migrate(db);

    final key = await _store.record(operationId).delete(db);
    return key != null;
  }

  /// Annule une opération en attente lorsque cette annulation est explicitement demandée.
  Future<bool> cancelOperation(String operationId) async {
    final db = await _getDb();
    await DatabaseMigrator.migrate(db);

    final key = await _store.record(operationId).delete(db);
    return key != null;
  }

  /// Compte le nombre total d'opérations dans la file (avec filtres optionnels).
  Future<int> count({String? farmId, String? userId}) async {
    final db = await _getDb();
    await DatabaseMigrator.migrate(db);

    final records = await _store.find(db);
    var ops = records.map((s) => SyncQueueOperation.fromMap(s.value));

    if (farmId != null && farmId.isNotEmpty) {
      ops = ops.where((op) => op.farmId == farmId);
    }
    if (userId != null && userId.isNotEmpty) {
      ops = ops.where((op) => op.userId == userId);
    }

    return ops.length;
  }

  /// Analyse Sembast et réconcilie la file d'attente pour une exploitation distante.
  /// Si des modifications locales (animaux ou dépenses avec syncStatus.isPending)
  /// n'ont pas d'opération correspondante dans [sync_queue] (suite à un crash,
  /// coupure ou échec d'enfilement initial), elles sont remises en file de façon idempotente.
  Future<int> reconcile({
    required AnimalsRepository repository,
    required String farmId,
    String? userId,
  }) async {
    final cleanFarmId = farmId.trim();
    if (cleanFarmId.isEmpty ||
        cleanFarmId == DatabaseMigrator.defaultFarmId ||
        cleanFarmId.startsWith('local_')) {
      return 0;
    }

    final pendingOps = await getPendingOperations(farmId: cleanFarmId);
    final pendingAnimalIds = pendingOps
        .where((op) => op.entityType == SyncEntityType.animal)
        .map((op) => op.localId)
        .toSet();
    final pendingExpenseIds = pendingOps
        .where((op) => op.entityType == SyncEntityType.expense)
        .map((op) => op.localId)
        .toSet();

    final allAnimals = await repository.fetchAnimals(
      farmId: cleanFarmId,
      includeDeleted: true,
    );

    int recoveredCount = 0;

    for (final animal in allAnimals) {
      if (isDemoOrNonSyncable(
        entityType: SyncEntityType.animal,
        localId: animal.id,
        farmId: cleanFarmId,
        isDemo: animal.isDemo,
      )) {
        continue;
      }

      // 1. Réconciliation de l'animal
      if (animal.syncStatus.isPending && !pendingAnimalIds.contains(animal.id)) {
        final action = animal.deletedAt != null ||
                animal.syncStatus == SyncStatus.pendingDelete
            ? SyncAction.delete
            : (animal.remoteId == null ||
                    animal.syncStatus == SyncStatus.pendingCreate
                ? SyncAction.create
                : SyncAction.update);

        final enqueued = await enqueue(
          entityType: SyncEntityType.animal,
          localId: animal.id,
          action: action,
          farmId: cleanFarmId,
          userId: userId,
          isDemo: animal.isDemo,
        );

        if (enqueued != null) {
          pendingAnimalIds.add(animal.id);
          recoveredCount++;
        }
      }

      // 2. Réconciliation des dépenses de l'animal
      for (final expense in animal.expenses) {
        if (isDemoOrNonSyncable(
          entityType: SyncEntityType.expense,
          localId: expense.id,
          farmId: cleanFarmId,
          isDemo: animal.isDemo,
        )) {
          continue;
        }

        if (expense.syncStatus.isPending &&
            !pendingExpenseIds.contains(expense.id)) {
          final action = expense.deletedAt != null ||
                  expense.syncStatus == SyncStatus.pendingDelete
              ? SyncAction.delete
              : (expense.remoteId == null ||
                      expense.syncStatus == SyncStatus.pendingCreate
                  ? SyncAction.create
                  : SyncAction.update);

          final enqueued = await enqueue(
            entityType: SyncEntityType.expense,
            localId: expense.id,
            action: action,
            farmId: cleanFarmId,
            userId: userId,
            isDemo: animal.isDemo,
            payload: {
              'animalId': animal.id,
              if (expense.remoteId != null) 'remoteId': expense.remoteId,
            },
          );

          if (enqueued != null) {
            pendingExpenseIds.add(expense.id);
            recoveredCount++;
          }
        }
      }
    }

    if (recoveredCount > 0) {
      debugPrint(
        '[SyncQueue] Réconciliation terminée pour $cleanFarmId : $recoveredCount opération(s) récupérée(s) dans la file.',
      );
    }
    return recoveredCount;
  }

  /// Nettoie toutes les opérations de la file (pour les tests).
  Future<void> clearAllForTesting() async {
    final db = await _getDb();
    await _store.delete(db);
  }
}
