import 'dart:async';
import 'package:flutter/foundation.dart';
import 'database/app_database.dart';
import 'database/database_migrator.dart';
import '../models/animal.dart';
import '../models/expense.dart';
import '../models/farm.dart';
import '../models/sync_conflict.dart';

/// Résultat de l'application locale d'un lot de données distantes (Pull).
class PullBatchResult {
  final int animalsApplied;
  final int expensesApplied;
  final int animalsSkippedDueToConflict;
  final int expensesSkippedDueToConflict;
  final List<String> orphanExpenseRemoteIds;
  final List<String> conflictsLogged;
  final int orphansResolved;

  const PullBatchResult({
    this.animalsApplied = 0,
    this.expensesApplied = 0,
    this.animalsSkippedDueToConflict = 0,
    this.expensesSkippedDueToConflict = 0,
    this.orphanExpenseRemoteIds = const [],
    this.conflictsLogged = const [],
    this.orphansResolved = 0,
  });

  bool get hasChanges =>
      animalsApplied > 0 || expensesApplied > 0 || orphansResolved > 0;

  @override
  String toString() =>
      'PullBatchResult(animals: $animalsApplied, expenses: $expensesApplied, conflictAnimals: $animalsSkippedDueToConflict, conflictExpenses: $expensesSkippedDueToConflict, orphans: ${orphanExpenseRemoteIds.length}, orphansResolved: $orphansResolved)';
}

class AnimalsRepository {
  final Future<Database> Function()? _databaseProvider;
  final bool _autoSeed;

  final StoreRef<String, Map<String, dynamic>> _animalsStore =
      DatabaseMigrator.animalsStore;
  final StoreRef<String, Map<String, dynamic>> _metadataStore =
      DatabaseMigrator.metadataStore;
  final StoreRef<String, Map<String, dynamic>> _farmsStore =
      DatabaseMigrator.farmsStore;
  final StoreRef<String, Map<String, dynamic>> _orphanExpensesStore =
      DatabaseMigrator.orphanExpensesStore;
  final StoreRef<String, Map<String, dynamic>> _conflictsStore =
      DatabaseMigrator.conflictsStore;

  bool _initialized = false;
  Future<void>? _initFuture;
  static int _expenseCounter = 0;

  AnimalsRepository({
    Future<Database>? database,
    Future<Database> Function()? databaseProvider,
    bool autoSeed = true,
  })  : _databaseProvider =
            database != null ? (() => database) : databaseProvider,
        _autoSeed = autoSeed;

  Future<Database> _getDb() async {
    if (_databaseProvider != null) {
      return await _databaseProvider!();
    }
    return await AppDatabase.instance.database;
  }

  /// Initialise la base avec migration versionnée et seeding idempotent.
  Future<void> _ensureInitialized(Database db) async {
    if (_initialized) return;

    if (_initFuture != null) {
      await _initFuture;
      return;
    }

    final completer = Completer<void>();
    _initFuture = completer.future;

    try {
      // 1. Exécution systématique de la migration de schéma versionnée et transactionnelle
      await DatabaseMigrator.migrate(db);

      // 2. Seeding des données de démonstration initiales si activé
      if (_autoSeed) {
        await _runSeedIfNecessary(db);
      }

      _initialized = true;
      completer.complete();
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    } finally {
      _initFuture = null;
    }
  }

  Future<void> _runSeedIfNecessary(Database db) async {
    await db.transaction((txn) async {
      final seedingMeta = await _metadataStore.record('seeding').get(txn);
      if (seedingMeta != null && seedingMeta['seeded'] == true) {
        // Seeding déjà effectué antérieurement
        return;
      }

      final count = await _animalsStore.count(txn);
      if (count > 0) {
        // Des animaux sont déjà présents dans le store, on marque le seeding sans écraser
        await _metadataStore.record('seeding').put(txn, {
          'seeded': true,
          'seededAt': DateTime.now().toIso8601String(),
          'version': 1,
          'reason': 'existing_records_preserved',
        });
        return;
      }

      // Base vierge : insertion transactionnelle des 12 animaux initiaux
      for (final animal in demoAnimals) {
        await _animalsStore.record(animal.id).put(txn, animal.toMap());
      }

      await _metadataStore.record('seeding').put(txn, {
        'seeded': true,
        'seededAt': DateTime.now().toIso8601String(),
        'version': 1,
        'count': demoAnimals.length,
      });
    });
  }

  /// Réinitialise l'état des données du magasin en restaurant les 12 animaux initiaux.
  /// Utilisé en mode démo pour remettre à zéro le jeu de données éphémère.
  Future<void> resetDemoData() async {
    final db = await _getDb();
    await _ensureInitialized(db);
    await db.transaction((txn) async {
      await _animalsStore.delete(txn);
      await _metadataStore.record('seeding').delete(txn);

      for (final animal in demoAnimals) {
        // Copie profonde via toMap/fromMap pour isoler les références
        final cloned =
            Animal.fromMap(Map<String, dynamic>.from(animal.toMap()));
        await _animalsStore.record(cloned.id).put(txn, cloned.toMap());
      }

      await _metadataStore.record('seeding').put(txn, {
        'seeded': true,
        'seededAt': DateTime.now().toIso8601String(),
        'version': 1,
        'count': demoAnimals.length,
        'reset': true,
      });
    });
  }

  /// Récupère la liste des animaux persistés.
  /// Si [includeDeleted] est faux (par défaut), exclut les animaux supprimés logiquement.
  /// Si [farmId] est fourni, filtre les animaux de cette exploitation.
  /// Si [farmId] est omis, retourne tous les animaux actifs.
  Future<List<Animal>> fetchAnimals({
    String? farmId,
    bool includeDeleted = false,
  }) async {
    final db = await _getDb();
    await _ensureInitialized(db);

    final records = await _animalsStore.find(db);
    var animals =
        records.map((snapshot) => Animal.fromMap(snapshot.value)).toList();

    if (!includeDeleted) {
      animals = animals.where((a) => a.deletedAt == null).toList();
    }

    if (farmId == null) {
      return animals;
    }
    return animals.where((a) => a.farmId == farmId).toList();
  }

  /// Méthode d'accès explicite par exploitation.
  Future<List<Animal>> fetchAnimalsByFarm(
    String farmId, {
    bool includeDeleted = false,
  }) {
    return fetchAnimals(farmId: farmId, includeDeleted: includeDeleted);
  }

  /// Récupère les animaux ayant été supprimés logiquement (en attente de synchronisation).
  Future<List<Animal>> fetchDeletedAnimals({String? farmId}) async {
    final db = await _getDb();
    await _ensureInitialized(db);

    final records = await _animalsStore.find(db);
    var animals = records
        .map((snapshot) => Animal.fromMap(snapshot.value))
        .where((a) => a.deletedAt != null)
        .toList();

    if (farmId == null) {
      return animals;
    }
    return animals.where((a) => a.farmId == farmId).toList();
  }

  /// Ajoute un nouvel animal à la base.
  /// Si [targetFarmId] est spécifié, associe l'animal à cette exploitation.
  /// Lève un [StateError] si un animal portant le même identifiant existe déjà.
  Future<Animal> addAnimal(Animal animal, {String? targetFarmId}) async {
    final db = await _getDb();
    await _ensureInitialized(db);

    final animalToInsert =
        targetFarmId != null ? animal.copyWith(farmId: targetFarmId) : animal;

    final record = _animalsStore.record(animalToInsert.id);

    await db.transaction((txn) async {
      final existing = await record.get(txn);
      if (existing != null) {
        throw StateError(
            'Un animal avec l\'identifiant "${animalToInsert.id}" existe déjà.');
      }
      await record.put(txn, animalToInsert.toMap());
    });

    return animalToInsert;
  }

  /// Met à jour un animal existant dans la base de façon atomique.
  /// Préserve l'ID, la date de création et les dépenses existantes pour garantir l'intégrité financière.
  /// Lève un [ArgumentError] si aucun animal portant cet ID n'est trouvé.
  /// Lève un [StateError] si l'animal a été supprimé logiquement.
  Future<Animal> updateAnimal(Animal animal) async {
    final db = await _getDb();
    await _ensureInitialized(db);

    final record = _animalsStore.record(animal.id);

    Animal? updated;
    await db.transaction((txn) async {
      final existingMap = await record.get(txn);
      if (existingMap == null) {
        throw ArgumentError(
            'Aucun animal trouvé avec l\'identifiant "${animal.id}".');
      }

      final existingAnimal = Animal.fromMap(existingMap);
      if (existingAnimal.deletedAt != null) {
        throw StateError(
            'Impossible de modifier un animal supprimé ("${animal.id}").');
      }

      updated = animal.copyWith(
        id: existingAnimal.id,
        createdAt: existingAnimal.createdAt,
        expenses: existingAnimal.expenses,
      );

      await record.put(txn, updated!.toMap());
    });

    return updated!;
  }

  /// Ajoute une dépense à un animal identifié par son ID de façon atomique.
  /// Associe automatiquement la dépense à l'animalId et au farmId de l'animal hôte.
  /// Lève un [ArgumentError] si l'animal n'existe pas.
  /// Lève un [StateError] si l'animal a été supprimé logiquement.
  Future<Expense> addExpense(String animalId, Expense expense) async {
    final db = await _getDb();
    await _ensureInitialized(db);

    final record = _animalsStore.record(animalId);
    Expense? createdExpense;

    await db.transaction((txn) async {
      final rawMap = await record.get(txn);
      if (rawMap == null) {
        throw ArgumentError(
            'Aucun animal trouvé avec l\'identifiant "$animalId"');
      }

      final targetAnimal = Animal.fromMap(rawMap);
      if (targetAnimal.deletedAt != null) {
        throw StateError(
            'Impossible d\'ajouter une dépense à un animal supprimé ("$animalId").');
      }

      final String uniqueId = expense.id.isNotEmpty
          ? expense.id
          : 'exp_${DateTime.now().microsecondsSinceEpoch}_${_expenseCounter++}';

      createdExpense = Expense(
        id: uniqueId,
        remoteId: expense.remoteId,
        syncStatus: expense.syncStatus,
        animalId: expense.animalId ?? targetAnimal.id,
        farmId: expense.farmId ?? targetAnimal.farmId,
        createdBy: expense.createdBy,
        updatedAt: expense.updatedAt,
        deletedAt: expense.deletedAt,
        label: expense.label,
        amount: expense.amount,
        date: expense.date,
        category: expense.category,
      );

      final updatedAnimal = targetAnimal.copyWith(
        expenses: [...targetAnimal.expenses, createdExpense!],
      );

      await record.put(txn, updatedAnimal.toMap());
    });

    return createdExpense!;
  }

  /// Met à jour une dépense existante d'un animal.
  /// Lève un [ArgumentError] si l'animal ou la dépense n'existe pas.
  /// Lève un [StateError] si l'animal est supprimé logiquement.
  Future<Expense> updateExpense(String animalId, Expense expense) async {
    final db = await _getDb();
    await _ensureInitialized(db);

    final record = _animalsStore.record(animalId);
    Expense? updatedExpense;

    await db.transaction((txn) async {
      final rawMap = await record.get(txn);
      if (rawMap == null) {
        throw ArgumentError(
            'Aucun animal trouvé avec l\'identifiant "$animalId"');
      }

      final targetAnimal = Animal.fromMap(rawMap);
      if (targetAnimal.deletedAt != null) {
        throw StateError(
            'Impossible de modifier une dépense d\'un animal supprimé ("$animalId").');
      }

      final index = targetAnimal.expenses.indexWhere((e) => e.id == expense.id);
      if (index == -1) {
        throw ArgumentError(
            'Aucune dépense avec l\'identifiant "${expense.id}" trouvée pour l\'animal "$animalId".');
      }

      final existingExpense = targetAnimal.expenses[index];
      updatedExpense = expense.copyWith(
        id: existingExpense.id,
        animalId: existingExpense.animalId ?? animalId,
        farmId: existingExpense.farmId ?? targetAnimal.farmId,
        createdBy: existingExpense.createdBy,
        updatedAt: DateTime.now(),
      );

      final newExpenses = List<Expense>.from(targetAnimal.expenses);
      newExpenses[index] = updatedExpense!;

      final updatedAnimal = targetAnimal.copyWith(expenses: newExpenses);
      await record.put(txn, updatedAnimal.toMap());
    });

    return updatedExpense!;
  }

  /// Supprime une dépense d'un animal.
  /// Lève un [ArgumentError] si l'animal n'existe pas.
  /// Lève un [StateError] si l'animal est supprimé logiquement.
  Future<bool> deleteExpense(String animalId, String expenseId) async {
    final db = await _getDb();
    await _ensureInitialized(db);

    final record = _animalsStore.record(animalId);

    return await db.transaction((txn) async {
      final rawMap = await record.get(txn);
      if (rawMap == null) {
        return false;
      }

      final targetAnimal = Animal.fromMap(rawMap);
      if (targetAnimal.deletedAt != null) {
        throw StateError(
            'Impossible de supprimer une dépense d\'un animal supprimé ("$animalId").');
      }

      final expenseIndex =
          targetAnimal.expenses.indexWhere((e) => e.id == expenseId);
      if (expenseIndex == -1) {
        return false;
      }

      final existingExpense = targetAnimal.expenses[expenseIndex];
      final isRemoteFarm = !targetAnimal.farmId.startsWith('local_') &&
          targetAnimal.farmId != DatabaseMigrator.defaultFarmId;

      final List<Expense> newExpenses;
      if (isRemoteFarm && existingExpense.remoteId != null) {
        // Suppression logique locale : conserve deletedAt et pendingDelete pour cohérence distante et réconciliation
        newExpenses = List<Expense>.from(targetAnimal.expenses);
        newExpenses[expenseIndex] = existingExpense.copyWith(
          deletedAt: DateTime.now(),
          updatedAt: DateTime.now(),
          syncStatus: SyncStatus.pendingDelete,
        );
      } else {
        // Dépense locale ou création hors ligne non encore envoyée : suppression directe
        newExpenses =
            targetAnimal.expenses.where((e) => e.id != expenseId).toList();
      }

      final updatedAnimal = targetAnimal.copyWith(expenses: newExpenses);
      await record.put(txn, updatedAnimal.toMap());
      return true;
    });
  }

  /// Récupère un animal par son ID (ou null s'il n'existe pas ou est supprimé et [includeDeleted] = false).
  Future<Animal?> getAnimalById(
    String animalId, {
    bool includeDeleted = false,
  }) async {
    final db = await _getDb();
    await _ensureInitialized(db);

    final rawMap = await _animalsStore.record(animalId).get(db);
    if (rawMap == null) return null;
    final animal = Animal.fromMap(rawMap);
    if (!includeDeleted && animal.deletedAt != null) {
      return null;
    }
    return animal;
  }

  /// Supprime logiquement un animal par son ID.
  ///
  /// Renseigne [deletedAt] avec l'horodatage actuel, positionne [syncStatus] à
  /// [SyncStatus.pendingDelete] pour préparer la future synchronisation cloud,
  /// et préserve l'enregistrement et ses dépenses dans Sembast.
  ///
  /// Cette opération est idempotente : si l'animal est déjà marqué supprimé,
  /// son horodatage [deletedAt] d'origine est préservé.
  /// Retourne `true` si l'animal a été trouvé et marqué supprimé, `false` si l'animal n'existe pas.
  Future<bool> deleteAnimal(String animalId) async {
    final db = await _getDb();
    await _ensureInitialized(db);

    final record = _animalsStore.record(animalId);

    return await db.transaction((txn) async {
      final rawMap = await record.get(txn);
      if (rawMap == null) {
        return false;
      }

      final existingAnimal = Animal.fromMap(rawMap);
      if (existingAnimal.deletedAt != null) {
        // Déjà supprimé logiquement : opération idempotente, préserver l'horodatage initial
        return true;
      }

      final now = DateTime.now();
      final updatedAnimal = existingAnimal.copyWith(
        deletedAt: now,
        updatedAt: now,
        syncStatus: SyncStatus.pendingDelete,
      );

      await record.put(txn, updatedAnimal.toMap());
      return true;
    });
  }

  /// Met à jour les métadonnées de synchronisation d'un animal (remoteId, syncStatus).
  /// S'applique aussi bien à un animal actif qu'à un animal supprimé logiquement.
  /// Lève un [ArgumentError] si l'animal n'existe pas.
  /// Met à jour les métadonnées de synchronisation d'un animal (remoteId, syncStatus, versionId).
  /// S'applique aussi bien à un animal actif qu'à un animal supprimé logiquement.
  /// Lève un [ArgumentError] si l'animal n'existe pas.
  Future<Animal> updateAnimalSyncMetadata({
    required String animalId,
    String? remoteId,
    required SyncStatus syncStatus,
    int? versionId,
  }) async {
    final db = await _getDb();
    await _ensureInitialized(db);

    final record = _animalsStore.record(animalId);
    Animal? updated;

    await db.transaction((txn) async {
      final rawMap = await record.get(txn);
      if (rawMap == null) {
        throw ArgumentError(
            'Aucun animal trouvé avec l\'identifiant "$animalId".');
      }

      final existing = Animal.fromMap(rawMap);
      updated = existing.copyWith(
        remoteId: remoteId ?? existing.remoteId,
        syncStatus: syncStatus,
        versionId: versionId ?? existing.versionId,
        updatedAt: DateTime.now(),
      );

      await record.put(txn, updated!.toMap());
    });

    return updated!;
  }

  /// Met à jour les métadonnées de synchronisation d'une dépense (remoteId, syncStatus, versionId).
  /// S'applique aussi bien à un animal actif qu'à un animal supprimé logiquement.
  /// Lève un [ArgumentError] si l'animal ou la dépense n'existe pas.
  Future<Expense> updateExpenseSyncMetadata({
    required String animalId,
    required String expenseId,
    String? remoteId,
    required SyncStatus syncStatus,
    int? versionId,
  }) async {
    final db = await _getDb();
    await _ensureInitialized(db);

    final record = _animalsStore.record(animalId);
    Expense? updatedExpense;

    await db.transaction((txn) async {
      final rawMap = await record.get(txn);
      if (rawMap == null) {
        throw ArgumentError(
            'Aucun animal trouvé avec l\'identifiant "$animalId".');
      }

      final existingAnimal = Animal.fromMap(rawMap);
      final index =
          existingAnimal.expenses.indexWhere((e) => e.id == expenseId);
      if (index == -1) {
        throw ArgumentError(
            'Aucune dépense trouvée avec l\'identifiant "$expenseId" pour l\'animal "$animalId".');
      }

      final existingExpense = existingAnimal.expenses[index];
      updatedExpense = existingExpense.copyWith(
        remoteId: remoteId ?? existingExpense.remoteId,
        syncStatus: syncStatus,
        versionId: versionId ?? existingExpense.versionId,
        updatedAt: DateTime.now(),
      );

      final newExpenses = List<Expense>.from(existingAnimal.expenses);
      newExpenses[index] = updatedExpense!;

      final updatedAnimal = existingAnimal.copyWith(expenses: newExpenses);
      await record.put(txn, updatedAnimal.toMap());
    });

    return updatedExpense!;
  }

  /// Enregistre durablement un conflit de synchronisation dans Sembast.
  Future<void> recordConflict(SyncConflict conflict) async {
    final db = await _getDb();
    await _ensureInitialized(db);

    await _conflictsStore.record(conflict.id).put(db, conflict.toMap());
    debugPrint(
      '[AnimalsRepository] Conflit persisté : ${conflict.id} (entité: ${conflict.entityType.name} local: ${conflict.localId} remote: ${conflict.remoteId})',
    );
  }

  /// Récupère la liste des conflits enregistrés pour une exploitation.
  Future<List<SyncConflict>> getConflicts({
    required String farmId,
    bool unresolvedOnly = false,
  }) async {
    final db = await _getDb();
    await _ensureInitialized(db);

    final records = await _conflictsStore.find(db);
    var conflicts = records
        .map((r) => SyncConflict.fromMap(r.value))
        .where((c) => c.farmId == farmId);

    if (unresolvedOnly) {
      conflicts = conflicts.where((c) => !c.resolved);
    }

    final list = conflicts.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Récupère un conflit spécifique par son identifiant unique.
  Future<SyncConflict?> getConflictById(String conflictId) async {
    final db = await _getDb();
    await _ensureInitialized(db);

    final raw = await _conflictsStore.record(conflictId).get(db);
    if (raw == null) return null;
    return SyncConflict.fromMap(raw);
  }

  // ─── Ingestion locale de synchronisation descendante (Pull) ─────────────────

  /// Applique un lot de données distantes (animaux et dépenses) de manière atomique et sécurisée.
  ///
  /// Règles strictes :
  /// 1. Exécution dans une transaction Sembast.
  /// 2. Rapprochement par `remoteId`, puis par `local_id`.
  /// 3. Préservation intégrale des dépenses existantes lors de la mise à jour d'un animal.
  /// 4. Traitement ordonné : animaux d'abord, puis dépenses.
  /// 5. Rattachement des dépenses via l'identifiant distant (`animal_id`) de leur animal parent.
  /// 6. Mise de côté des dépenses orphelines dont l'animal parent est introuvable.
  /// 7. Application des suppressions logiques (`deletedAt`).
  /// 8. Affectation du statut [SyncStatus.synced] aux données appliquées sans déclencher d'Outbox.
  /// 9. Protection absolue : si l'entité locale est en attente (`isPending`), elle n'est pas écrasée
  ///    et le conflit est journalisé.
  /// 10. Aucun doublon lors de la répétition d'un appel (idempotent).
  Future<PullBatchResult> applyRemotePullBatch({
    required String farmId,
    required List<Map<String, dynamic>> remoteAnimals,
    required List<Map<String, dynamic>> remoteExpenses,
  }) async {
    final cleanFarmId = farmId.trim();
    if (cleanFarmId.isEmpty ||
        cleanFarmId == DatabaseMigrator.defaultFarmId ||
        cleanFarmId.startsWith('local_')) {
      throw ArgumentError(
        'Impossible d\'appliquer un lot distant sur une exploitation locale ("$cleanFarmId").',
      );
    }

    final db = await _getDb();
    await _ensureInitialized(db);

    int animalsApplied = 0;
    int expensesApplied = 0;
    int animalsSkippedConflict = 0;
    int expensesSkippedConflict = 0;
    int orphansResolved = 0;
    final List<String> orphanExpenses = [];
    final List<String> conflictsLogged = [];

    await db.transaction((txn) async {
      // 1. Charger tous les animaux actuels en mémoire pour résolution rapide et atomique
      final records = await _animalsStore.find(txn);
      final Map<String, Animal> animalsMap = {};
      for (final s in records) {
        animalsMap[s.key] = Animal.fromMap(s.value);
      }

      Animal? findAnimal({String? remoteId, String? localId}) {
        if (remoteId != null && remoteId.isNotEmpty) {
          for (final a in animalsMap.values) {
            if (a.remoteId == remoteId) return a;
          }
        }
        if (localId != null && localId.isNotEmpty) {
          if (animalsMap.containsKey(localId)) {
            return animalsMap[localId];
          }
        }
        return null;
      }

      // ── Traitement des animaux ────────────────────────────────────────────
      for (final raw in remoteAnimals) {
        final remoteId = raw['id'] as String?;
        final rawFarmId = raw['farm_id'] as String?;
        final localIdCandidate = raw['local_id'] as String?;

        if (remoteId == null || remoteId.isEmpty) continue;
        if (rawFarmId != null && rawFarmId != cleanFarmId) {
          debugPrint(
            '[AnimalsRepository] Rejet animal distant $remoteId: farm_id incompatible ("$rawFarmId" != "$cleanFarmId")',
          );
          continue;
        }
        if (raw['is_demo'] == true) continue;

        final existing = findAnimal(
          remoteId: remoteId,
          localId: localIdCandidate,
        );

        if (existing != null) {
          // Si l'animal local a une opération en attente, le préserver (conflit)
          if (existing.syncStatus.isPending) {
            final logMsg =
                'Conflit sur animal ${existing.id} (remote: $remoteId): modification locale en attente (${existing.syncStatus.label}). Donnée locale préservée.';
            debugPrint('[AnimalsRepository] $logMsg');
            conflictsLogged.add(logMsg);
            animalsSkippedConflict++;
            continue;
          }

          // Mise à jour de l'existant en préservant ses dépenses locales existantes
          final updatedAnimal = existing.copyWith(
            remoteId: remoteId,
            name: (raw['name'] as String?)?.trim() ?? existing.name,
            type: raw['type'] != null
                ? _parseAnimalType(raw['type'] as String)
                : existing.type,
            ageMonths: (raw['age_months'] as num?)?.toInt() ?? existing.ageMonths,
            weightKg: (raw['weight_kg'] as num?)?.toDouble() ?? existing.weightKg,
            healthStatus: raw['health_status'] != null
                ? _parseHealthStatus(raw['health_status'] as String)
                : existing.healthStatus,
            imageUrl: raw.containsKey('image_url')
                ? raw['image_url'] as String?
                : existing.imageUrl,
            updatedAt: raw['updated_at'] != null
                ? DateTime.tryParse(raw['updated_at'] as String)
                : existing.updatedAt,
            deletedAt: raw['deleted_at'] != null
                ? DateTime.tryParse(raw['deleted_at'] as String)
                : existing.deletedAt,
            versionId: (raw['version_id'] as num?)?.toInt() ?? existing.versionId,
            syncStatus: SyncStatus.synced,
          );

          animalsMap[updatedAnimal.id] = updatedAnimal;
          await _animalsStore
              .record(updatedAnimal.id)
              .put(txn, updatedAnimal.toMap());
          animalsApplied++;
        } else {
          // Nouvel animal importé
          final newId = (localIdCandidate != null &&
                  localIdCandidate.isNotEmpty &&
                  !animalsMap.containsKey(localIdCandidate))
              ? localIdCandidate
              : 'anim_${remoteId.replaceAll('-', '')}';

          final newAnimal = Animal(
            id: newId,
            farmId: cleanFarmId,
            remoteId: remoteId,
            syncStatus: SyncStatus.synced,
            isDemo: false,
            createdBy: raw['created_by'] as String?,
            updatedAt: raw['updated_at'] != null
                ? DateTime.tryParse(raw['updated_at'] as String)
                : null,
            deletedAt: raw['deleted_at'] != null
                ? DateTime.tryParse(raw['deleted_at'] as String)
                : null,
            versionId: (raw['version_id'] as num?)?.toInt() ?? 1,
            name: (raw['name'] as String?)?.trim() ?? 'Animal sans nom',
            type: _parseAnimalType(raw['type'] as String?),
            ageMonths: (raw['age_months'] as num?)?.toInt() ?? 0,
            weightKg: (raw['weight_kg'] as num?)?.toDouble() ?? 1.0,
            healthStatus: _parseHealthStatus(raw['health_status'] as String?),
            imageUrl: raw['image_url'] as String?,
            expenses: const [],
            createdAt: raw['created_at'] != null
                ? (DateTime.tryParse(raw['created_at'] as String) ?? DateTime.now())
                : DateTime.now(),
          );

          animalsMap[newAnimal.id] = newAnimal;
          await _animalsStore
              .record(newAnimal.id)
              .put(txn, newAnimal.toMap());
          animalsApplied++;
        }
      }

      // ── Résolution immédiate des dépenses orphelines en quarantaine ──────────
      final quarantinedRecords = await _orphanExpensesStore.find(
        txn,
        finder: Finder(filter: Filter.equals('farm_id', cleanFarmId)),
      );

      for (final qRecord in quarantinedRecords) {
        final qData = qRecord.value;
        final targetRemoteAnimalId = qData['animal_id'] as String?;
        final rawPayload = qData['payload'] as Map<String, dynamic>?;

        if (targetRemoteAnimalId == null || rawPayload == null) continue;

        // Rapprochement du parent désormais présent pour la même exploitation
        Animal? parent;
        for (final a in animalsMap.values) {
          if (a.remoteId == targetRemoteAnimalId && a.farmId == cleanFarmId) {
            parent = a;
            break;
          }
        }

        if (parent != null) {
          final remoteExpenseId = (rawPayload['id'] as String?) ?? qRecord.key;
          final localExpenseIdCandidate = rawPayload['local_id'] as String?;

          final existingExpenseIndex = parent.expenses.indexWhere(
            (e) =>
                e.remoteId == remoteExpenseId ||
                (localExpenseIdCandidate != null &&
                    localExpenseIdCandidate.isNotEmpty &&
                    e.id == localExpenseIdCandidate),
          );

          if (existingExpenseIndex != -1) {
            final existingExpense = parent.expenses[existingExpenseIndex];

            if (existingExpense.syncStatus.isPending) {
              final logMsg =
                  'Conflit sur dépense en quarantaine ${existingExpense.id} (remote: $remoteExpenseId): modification locale en attente (${existingExpense.syncStatus.label}). Donnée locale préservée.';
              debugPrint('[AnimalsRepository] $logMsg');
              conflictsLogged.add(logMsg);
              expensesSkippedConflict++;
              // Supprimer de la quarantaine car déjà présente localement
              await _orphanExpensesStore.record(qRecord.key).delete(txn);
              continue;
            }

            final updatedExpense = existingExpense.copyWith(
              remoteId: remoteExpenseId,
              label: (rawPayload['label'] as String?)?.trim() ??
                  existingExpense.label,
              amount: (rawPayload['amount'] as num?)?.toDouble() ??
                  existingExpense.amount,
              date: rawPayload['date'] != null
                  ? (DateTime.tryParse(rawPayload['date'] as String) ??
                      existingExpense.date)
                  : existingExpense.date,
              category: rawPayload['category'] != null
                  ? _parseExpenseCategory(rawPayload['category'] as String)
                  : existingExpense.category,
              updatedAt: rawPayload['updated_at'] != null
                  ? DateTime.tryParse(rawPayload['updated_at'] as String)
                  : existingExpense.updatedAt,
              deletedAt: rawPayload['deleted_at'] != null
                  ? DateTime.tryParse(rawPayload['deleted_at'] as String)
                  : existingExpense.deletedAt,
              syncStatus: SyncStatus.synced,
            );

            final newExpenses = List<Expense>.from(parent.expenses);
            newExpenses[existingExpenseIndex] = updatedExpense;
            final updatedParent = parent.copyWith(expenses: newExpenses);

            animalsMap[updatedParent.id] = updatedParent;
            await _animalsStore
                .record(updatedParent.id)
                .put(txn, updatedParent.toMap());
            expensesApplied++;
          } else {
            final newExpenseId = (localExpenseIdCandidate != null &&
                    localExpenseIdCandidate.isNotEmpty &&
                    !parent.expenses.any((e) => e.id == localExpenseIdCandidate))
                ? localExpenseIdCandidate
                : 'exp_${remoteExpenseId.replaceAll('-', '')}';

            final newExpense = Expense(
              id: newExpenseId,
              remoteId: remoteExpenseId,
              syncStatus: SyncStatus.synced,
              animalId: parent.id,
              farmId: cleanFarmId,
              createdBy: rawPayload['created_by'] as String?,
              updatedAt: rawPayload['updated_at'] != null
                  ? DateTime.tryParse(rawPayload['updated_at'] as String)
                  : null,
              deletedAt: rawPayload['deleted_at'] != null
                  ? DateTime.tryParse(rawPayload['deleted_at'] as String)
                  : null,
              label: (rawPayload['label'] as String?)?.trim() ?? 'Dépense',
              amount: (rawPayload['amount'] as num?)?.toDouble() ?? 0.0,
              date: rawPayload['date'] != null
                  ? (DateTime.tryParse(rawPayload['date'] as String) ??
                      DateTime.now())
                  : DateTime.now(),
              category: _parseExpenseCategory(rawPayload['category'] as String?),
            );

            final newExpenses = [...parent.expenses, newExpense];
            final updatedParent = parent.copyWith(expenses: newExpenses);

            animalsMap[updatedParent.id] = updatedParent;
            await _animalsStore
                .record(updatedParent.id)
                .put(txn, updatedParent.toMap());
            expensesApplied++;
          }

          // Supprimer de la quarantaine UNIQUEMENT après écriture locale réussie dans la même transaction
          await _orphanExpensesStore.record(qRecord.key).delete(txn);
          orphansResolved++;
        }
      }

      // ── Traitement des dépenses ───────────────────────────────────────────
      for (final raw in remoteExpenses) {
        final remoteExpenseId = raw['id'] as String?;
        final remoteAnimalId = raw['animal_id'] as String?;
        final rawFarmId = raw['farm_id'] as String?;
        final localExpenseIdCandidate = raw['local_id'] as String?;

        if (remoteExpenseId == null || remoteExpenseId.isEmpty) continue;
        if (remoteAnimalId == null || remoteAnimalId.isEmpty) continue;
        if (rawFarmId != null && rawFarmId != cleanFarmId) {
          debugPrint(
            '[AnimalsRepository] Rejet dépense distante $remoteExpenseId: farm_id incompatible ("$rawFarmId" != "$cleanFarmId")',
          );
          continue;
        }

        // Rapprochement de l'animal hôte par son remoteId
        Animal? parentAnimal;
        for (final a in animalsMap.values) {
          if (a.remoteId == remoteAnimalId && a.farmId == cleanFarmId) {
            parentAnimal = a;
            break;
          }
        }

        if (parentAnimal == null) {
          debugPrint(
            '[AnimalsRepository] Dépense distante $remoteExpenseId orpheline : animal parent $remoteAnimalId introuvable localement. Mise en quarantaine durable.',
          );
          orphanExpenses.add(remoteExpenseId);

          // Vérifier si la dépense n'est pas déjà présente localement
          bool alreadyPresentLocally = false;
          for (final a in animalsMap.values) {
            if (a.expenses.any((e) =>
                e.remoteId == remoteExpenseId ||
                (localExpenseIdCandidate != null &&
                    localExpenseIdCandidate.isNotEmpty &&
                    e.id == localExpenseIdCandidate))) {
              alreadyPresentLocally = true;
              break;
            }
          }

          if (!alreadyPresentLocally) {
            final existingQuarantine =
                await _orphanExpensesStore.record(remoteExpenseId).get(txn);
            final attemptCount = existingQuarantine != null
                ? ((existingQuarantine['attempt_count'] as int? ?? 1) + 1)
                : 1;

            await _orphanExpensesStore.record(remoteExpenseId).put(txn, {
              'id': remoteExpenseId,
              'remote_id': remoteExpenseId,
              'animal_id': remoteAnimalId,
              'farm_id': cleanFarmId,
              'payload': Map<String, dynamic>.from(raw),
              'updated_at': raw['updated_at'] as String?,
              'quarantined_at': existingQuarantine != null
                  ? (existingQuarantine['quarantined_at'] as String? ??
                      DateTime.now().toIso8601String())
                  : DateTime.now().toIso8601String(),
              'attempt_count': attemptCount,
            });
          }
          continue;
        }

        // Recherche d'une dépense locale existante correspondante
        final existingExpenseIndex = parentAnimal.expenses.indexWhere(
          (e) =>
              e.remoteId == remoteExpenseId ||
              (localExpenseIdCandidate != null &&
                  localExpenseIdCandidate.isNotEmpty &&
                  e.id == localExpenseIdCandidate),
        );

        if (existingExpenseIndex != -1) {
          final existingExpense = parentAnimal.expenses[existingExpenseIndex];

          if (existingExpense.syncStatus.isPending) {
            final logMsg =
                'Conflit sur dépense ${existingExpense.id} (remote: $remoteExpenseId): modification locale en attente (${existingExpense.syncStatus.label}). Donnée locale préservée.';
            debugPrint('[AnimalsRepository] $logMsg');
            conflictsLogged.add(logMsg);
            expensesSkippedConflict++;
            // Supprimer de la quarantaine si elle s'y trouvait
            await _orphanExpensesStore.record(remoteExpenseId).delete(txn);
            continue;
          }

          final updatedExpense = existingExpense.copyWith(
            remoteId: remoteExpenseId,
            label: (raw['label'] as String?)?.trim() ?? existingExpense.label,
            amount: (raw['amount'] as num?)?.toDouble() ?? existingExpense.amount,
            date: raw['date'] != null
                ? (DateTime.tryParse(raw['date'] as String) ?? existingExpense.date)
                : existingExpense.date,
            category: raw['category'] != null
                ? _parseExpenseCategory(raw['category'] as String)
                : existingExpense.category,
            updatedAt: raw['updated_at'] != null
                ? DateTime.tryParse(raw['updated_at'] as String)
                : existingExpense.updatedAt,
            deletedAt: raw['deleted_at'] != null
                ? DateTime.tryParse(raw['deleted_at'] as String)
                : existingExpense.deletedAt,
            versionId: (raw['version_id'] as num?)?.toInt() ?? existingExpense.versionId,
            syncStatus: SyncStatus.synced,
          );

          final newExpenses = List<Expense>.from(parentAnimal.expenses);
          newExpenses[existingExpenseIndex] = updatedExpense;
          final updatedParent = parentAnimal.copyWith(expenses: newExpenses);

          animalsMap[updatedParent.id] = updatedParent;
          await _animalsStore
              .record(updatedParent.id)
              .put(txn, updatedParent.toMap());
          expensesApplied++;
          await _orphanExpensesStore.record(remoteExpenseId).delete(txn);
        } else {
          // Nouvelle dépense importée
          final newExpenseId = (localExpenseIdCandidate != null &&
                  localExpenseIdCandidate.isNotEmpty &&
                  !parentAnimal.expenses.any((e) => e.id == localExpenseIdCandidate))
              ? localExpenseIdCandidate
              : 'exp_${remoteExpenseId.replaceAll('-', '')}';

          final newExpense = Expense(
            id: newExpenseId,
            remoteId: remoteExpenseId,
            syncStatus: SyncStatus.synced,
            animalId: parentAnimal.id,
            farmId: cleanFarmId,
            createdBy: raw['created_by'] as String?,
            updatedAt: raw['updated_at'] != null
                ? DateTime.tryParse(raw['updated_at'] as String)
                : null,
            deletedAt: raw['deleted_at'] != null
                ? DateTime.tryParse(raw['deleted_at'] as String)
                : null,
            versionId: (raw['version_id'] as num?)?.toInt() ?? 1,
            label: (raw['label'] as String?)?.trim() ?? 'Dépense',
            amount: (raw['amount'] as num?)?.toDouble() ?? 0.0,
            date: raw['date'] != null
                ? (DateTime.tryParse(raw['date'] as String) ?? DateTime.now())
                : DateTime.now(),
            category: _parseExpenseCategory(raw['category'] as String?),
          );

          final newExpenses = [...parentAnimal.expenses, newExpense];
          final updatedParent = parentAnimal.copyWith(expenses: newExpenses);

          animalsMap[updatedParent.id] = updatedParent;
          await _animalsStore
              .record(updatedParent.id)
              .put(txn, updatedParent.toMap());
          expensesApplied++;
          await _orphanExpensesStore.record(remoteExpenseId).delete(txn);
        }
      }
    });

    return PullBatchResult(
      animalsApplied: animalsApplied,
      expensesApplied: expensesApplied,
      animalsSkippedDueToConflict: animalsSkippedConflict,
      expensesSkippedDueToConflict: expensesSkippedConflict,
      orphanExpenseRemoteIds: orphanExpenses,
      conflictsLogged: conflictsLogged,
      orphansResolved: orphansResolved,
    );
  }

  /// Tente de rattacher toutes les dépenses en quarantaine dont l'animal parent est
  /// désormais présent localement pour l'exploitation [farmId].
  ///
  /// Opération strictement atomique par Sembast [txn].
  /// L'entrée de quarantaine est supprimée uniquement après que le parent animal
  /// a été mis à jour avec succès dans [_animalsStore].
  /// Les dépenses rattachées ont [SyncStatus.synced] afin d'éviter toute boucle Outbox.
  Future<int> resolveQuarantinedExpenses({required String farmId}) async {
    final cleanFarmId = farmId.trim();
    if (cleanFarmId.isEmpty ||
        cleanFarmId == DatabaseMigrator.defaultFarmId ||
        cleanFarmId.startsWith('local_')) {
      return 0;
    }

    final db = await _getDb();
    await _ensureInitialized(db);

    int resolvedCount = 0;

    await db.transaction((txn) async {
      final quarantinedRecords = await _orphanExpensesStore.find(
        txn,
        finder: Finder(filter: Filter.equals('farm_id', cleanFarmId)),
      );

      if (quarantinedRecords.isEmpty) return;

      final records = await _animalsStore.find(txn);
      final Map<String, Animal> animalsMap = {};
      for (final s in records) {
        final a = Animal.fromMap(s.value);
        if (a.farmId == cleanFarmId) {
          animalsMap[a.id] = a;
        }
      }

      for (final qRecord in quarantinedRecords) {
        final qData = qRecord.value;
        final targetRemoteAnimalId = qData['animal_id'] as String?;
        final rawPayload = qData['payload'] as Map<String, dynamic>?;

        if (targetRemoteAnimalId == null || rawPayload == null) continue;

        Animal? parent;
        for (final a in animalsMap.values) {
          if (a.remoteId == targetRemoteAnimalId && a.farmId == cleanFarmId) {
            parent = a;
            break;
          }
        }

        if (parent != null) {
          final remoteExpenseId = (rawPayload['id'] as String?) ?? qRecord.key;
          final localExpenseIdCandidate = rawPayload['local_id'] as String?;

          final existingExpenseIndex = parent.expenses.indexWhere(
            (e) =>
                e.remoteId == remoteExpenseId ||
                (localExpenseIdCandidate != null &&
                    localExpenseIdCandidate.isNotEmpty &&
                    e.id == localExpenseIdCandidate),
          );

          if (existingExpenseIndex != -1) {
            final existingExpense = parent.expenses[existingExpenseIndex];

            if (!existingExpense.syncStatus.isPending) {
              final updatedExpense = existingExpense.copyWith(
                remoteId: remoteExpenseId,
                label: (rawPayload['label'] as String?)?.trim() ??
                    existingExpense.label,
                amount: (rawPayload['amount'] as num?)?.toDouble() ??
                    existingExpense.amount,
                date: rawPayload['date'] != null
                    ? (DateTime.tryParse(rawPayload['date'] as String) ??
                        existingExpense.date)
                    : existingExpense.date,
                category: rawPayload['category'] != null
                    ? _parseExpenseCategory(rawPayload['category'] as String)
                    : existingExpense.category,
                updatedAt: rawPayload['updated_at'] != null
                    ? DateTime.tryParse(rawPayload['updated_at'] as String)
                    : existingExpense.updatedAt,
                deletedAt: rawPayload['deleted_at'] != null
                    ? DateTime.tryParse(rawPayload['deleted_at'] as String)
                    : existingExpense.deletedAt,
                syncStatus: SyncStatus.synced,
              );

              final newExpenses = List<Expense>.from(parent.expenses);
              newExpenses[existingExpenseIndex] = updatedExpense;
              final updatedParent = parent.copyWith(expenses: newExpenses);

              animalsMap[updatedParent.id] = updatedParent;
              await _animalsStore
                  .record(updatedParent.id)
                  .put(txn, updatedParent.toMap());
            }
          } else {
            final newExpenseId = (localExpenseIdCandidate != null &&
                    localExpenseIdCandidate.isNotEmpty &&
                    !parent.expenses.any((e) => e.id == localExpenseIdCandidate))
                ? localExpenseIdCandidate
                : 'exp_${remoteExpenseId.replaceAll('-', '')}';

            final newExpense = Expense(
              id: newExpenseId,
              remoteId: remoteExpenseId,
              syncStatus: SyncStatus.synced,
              animalId: parent.id,
              farmId: cleanFarmId,
              createdBy: rawPayload['created_by'] as String?,
              updatedAt: rawPayload['updated_at'] != null
                  ? DateTime.tryParse(rawPayload['updated_at'] as String)
                  : null,
              deletedAt: rawPayload['deleted_at'] != null
                  ? DateTime.tryParse(rawPayload['deleted_at'] as String)
                  : null,
              label: (rawPayload['label'] as String?)?.trim() ?? 'Dépense',
              amount: (rawPayload['amount'] as num?)?.toDouble() ?? 0.0,
              date: rawPayload['date'] != null
                  ? (DateTime.tryParse(rawPayload['date'] as String) ??
                      DateTime.now())
                  : DateTime.now(),
              category: _parseExpenseCategory(rawPayload['category'] as String?),
            );

            final newExpenses = [...parent.expenses, newExpense];
            final updatedParent = parent.copyWith(expenses: newExpenses);

            animalsMap[updatedParent.id] = updatedParent;
            await _animalsStore
                .record(updatedParent.id)
                .put(txn, updatedParent.toMap());
          }

          // Suppression du magasin de quarantaine uniquement après confirmation d'écriture
          await _orphanExpensesStore.record(qRecord.key).delete(txn);
          resolvedCount++;
        }
      }
    });

    return resolvedCount;
  }

  /// Récupère la liste des dépenses actuellement en quarantaine pour l'exploitation [farmId].
  Future<List<Map<String, dynamic>>> getQuarantinedExpenses({
    required String farmId,
  }) async {
    final cleanFarmId = farmId.trim();
    final db = await _getDb();
    await _ensureInitialized(db);
    final records = await _orphanExpensesStore.find(
      db,
      finder: Finder(filter: Filter.equals('farm_id', cleanFarmId)),
    );
    return records.map((r) => Map<String, dynamic>.from(r.value)).toList();
  }

  HealthStatus _parseHealthStatus(String? val) {
    switch (val) {
      case 'sain':
        return HealthStatus.sain;
      case 'a_surveiller':
        return HealthStatus.aSurveiller;
      case 'malade':
        return HealthStatus.malade;
      default:
        return HealthStatus.sain;
    }
  }

  AnimalType _parseAnimalType(String? val) {
    switch (val) {
      case 'bovin':
        return AnimalType.bovin;
      case 'caprin':
        return AnimalType.caprin;
      case 'ovin':
        return AnimalType.ovin;
      case 'volaille':
        return AnimalType.volaille;
      default:
        return AnimalType.bovin;
    }
  }

  ExpenseCategory _parseExpenseCategory(String? val) {
    switch (val) {
      case 'alimentation':
        return ExpenseCategory.alimentation;
      case 'sante':
        return ExpenseCategory.sante;
      case 'autre':
        return ExpenseCategory.autre;
      default:
        return ExpenseCategory.autre;
    }
  }

  // ─── Opérations multi-fermes (Farms) ───────────────────────────────────────

  /// Crée une nouvelle exploitation agricole dans la base locale.
  /// Lève un [StateError] si une exploitation avec cet identifiant existe déjà.
  Future<Farm> createFarm(Farm farm) async {
    final db = await _getDb();
    await _ensureInitialized(db);

    final record = _farmsStore.record(farm.id);

    await db.transaction((txn) async {
      final existing = await record.get(txn);
      if (existing != null) {
        throw StateError(
            'Une exploitation avec l\'identifiant "${farm.id}" existe déjà.');
      }
      await record.put(txn, farm.toMap());
    });

    return farm;
  }

  /// Récupère une exploitation par son identifiant (ou null si inexistante).
  Future<Farm?> getFarmById(String farmId) async {
    final db = await _getDb();
    await _ensureInitialized(db);

    final rawMap = await _farmsStore.record(farmId).get(db);
    if (rawMap == null) return null;
    return Farm.fromMap(rawMap);
  }

  /// Récupère la liste de toutes les exploitations existantes.
  Future<List<Farm>> fetchFarms() async {
    final db = await _getDb();
    await _ensureInitialized(db);

    final records = await _farmsStore.find(db);
    return records.map((s) => Farm.fromMap(s.value)).toList();
  }

  /// Met à jour une exploitation existante.
  /// Préserve l'ID et la date de création.
  /// Lève un [ArgumentError] si l'exploitation n'existe pas.
  Future<Farm> updateFarm(Farm farm) async {
    final db = await _getDb();
    await _ensureInitialized(db);

    final record = _farmsStore.record(farm.id);
    Farm? updated;

    await db.transaction((txn) async {
      final existingMap = await record.get(txn);
      if (existingMap == null) {
        throw ArgumentError(
            'Aucune exploitation trouvée avec l\'identifiant "${farm.id}".');
      }

      final existingFarm = Farm.fromMap(existingMap);
      updated = farm.copyWith(
        id: existingFarm.id,
        createdAt: existingFarm.createdAt,
        updatedAt: farm.updatedAt ?? DateTime.now(),
      );

      await record.put(txn, updated!.toMap());
    });

    return updated!;
  }

  /// Vérifie si une exploitation existe dans la base.
  Future<bool> farmExists(String farmId) async {
    final db = await _getDb();
    await _ensureInitialized(db);

    final raw = await _farmsStore.record(farmId).get(db);
    return raw != null;
  }

  // ─── 12 Animaux de démonstration pour le premier démarrage ───────────────────
  static final List<Animal> demoAnimals = [
    Animal(
      id: 'a001',
      farmId: DatabaseMigrator.defaultFarmId,
      isDemo: true,
      name: 'Bakary',
      type: AnimalType.bovin,
      imageUrl: 'assets/images/bovin.jpg',
      ageMonths: 36,
      weightKg: 320.0,
      healthStatus: HealthStatus.sain,
      expenses: [
        Expense(
          id: 'e001',
          animalId: 'a001',
          farmId: DatabaseMigrator.defaultFarmId,
          label: 'Sac de foin 50kg',
          amount: 8500,
          date: DateTime(2026, 10, 1),
          category: ExpenseCategory.alimentation,
        ),
        Expense(
          id: 'e002',
          animalId: 'a001',
          farmId: DatabaseMigrator.defaultFarmId,
          label: 'Vaccination FMD',
          amount: 15000,
          date: DateTime(2026, 9, 15),
          category: ExpenseCategory.sante,
        ),
        Expense(
          id: 'e003',
          animalId: 'a001',
          farmId: DatabaseMigrator.defaultFarmId,
          label: 'Complément minéral',
          amount: 6200,
          date: DateTime(2026, 9, 5),
          category: ExpenseCategory.alimentation,
        ),
      ],
      createdAt: DateTime(2026, 1, 15),
    ),
    Animal(
      id: 'a002',
      farmId: DatabaseMigrator.defaultFarmId,
      isDemo: true,
      name: 'Fanta',
      type: AnimalType.bovin,
      imageUrl: 'assets/images/bovin.jpg',
      ageMonths: 24,
      weightKg: 265.0,
      healthStatus: HealthStatus.aSurveiller,
      expenses: [
        Expense(
          id: 'e004',
          animalId: 'a002',
          farmId: DatabaseMigrator.defaultFarmId,
          label: 'Consultation vétérinaire',
          amount: 12000,
          date: DateTime(2026, 10, 1),
          category: ExpenseCategory.sante,
        ),
        Expense(
          id: 'e005',
          animalId: 'a002',
          farmId: DatabaseMigrator.defaultFarmId,
          label: 'Antibiotiques',
          amount: 9500,
          date: DateTime(2026, 10, 1),
          category: ExpenseCategory.sante,
        ),
        Expense(
          id: 'e006',
          animalId: 'a002',
          farmId: DatabaseMigrator.defaultFarmId,
          label: 'Aliment concentré',
          amount: 7800,
          date: DateTime(2026, 9, 20),
          category: ExpenseCategory.alimentation,
        ),
      ],
      createdAt: DateTime(2026, 3, 22),
    ),
    Animal(
      id: 'a003',
      farmId: DatabaseMigrator.defaultFarmId,
      isDemo: true,
      name: 'Koné',
      type: AnimalType.bovin,
      imageUrl: 'assets/images/bovin.jpg',
      ageMonths: 48,
      weightKg: 410.0,
      healthStatus: HealthStatus.sain,
      expenses: [
        Expense(
          id: 'e007',
          animalId: 'a003',
          farmId: DatabaseMigrator.defaultFarmId,
          label: 'Foin et paille',
          amount: 10500,
          date: DateTime(2026, 10, 1),
          category: ExpenseCategory.alimentation,
        ),
        Expense(
          id: 'e008',
          animalId: 'a003',
          farmId: DatabaseMigrator.defaultFarmId,
          label: 'Vermifuge',
          amount: 4500,
          date: DateTime(2026, 9, 10),
          category: ExpenseCategory.sante,
        ),
      ],
      createdAt: DateTime(2025, 8, 10),
    ),
    Animal(
      id: 'a004',
      farmId: DatabaseMigrator.defaultFarmId,
      isDemo: true,
      name: 'Mamadou',
      type: AnimalType.caprin,
      imageUrl: 'assets/images/caprin.jpg',
      ageMonths: 18,
      weightKg: 32.0,
      healthStatus: HealthStatus.sain,
      expenses: [
        Expense(
          id: 'e009',
          animalId: 'a004',
          farmId: DatabaseMigrator.defaultFarmId,
          label: 'Mélange grain/son',
          amount: 2200,
          date: DateTime(2026, 10, 1),
          category: ExpenseCategory.alimentation,
        ),
        Expense(
          id: 'e010',
          animalId: 'a004',
          farmId: DatabaseMigrator.defaultFarmId,
          label: 'Vaccin PPR',
          amount: 3500,
          date: DateTime(2026, 8, 20),
          category: ExpenseCategory.sante,
        ),
      ],
      createdAt: DateTime(2026, 5, 3),
    ),
    Animal(
      id: 'a005',
      farmId: DatabaseMigrator.defaultFarmId,
      isDemo: true,
      name: 'Awa',
      type: AnimalType.caprin,
      imageUrl: 'assets/images/caprin.jpg',
      ageMonths: 12,
      weightKg: 18.0,
      healthStatus: HealthStatus.malade,
      expenses: [
        Expense(
          id: 'e011',
          animalId: 'a005',
          farmId: DatabaseMigrator.defaultFarmId,
          label: 'Traitement diarrhée',
          amount: 7500,
          date: DateTime(2026, 10, 1),
          category: ExpenseCategory.sante,
        ),
        Expense(
          id: 'e012',
          animalId: 'a005',
          farmId: DatabaseMigrator.defaultFarmId,
          label: 'Sérum réhydratant',
          amount: 4200,
          date: DateTime(2026, 9, 28),
          category: ExpenseCategory.sante,
        ),
        Expense(
          id: 'e013',
          animalId: 'a005',
          farmId: DatabaseMigrator.defaultFarmId,
          label: 'Fourrage vert',
          amount: 1500,
          date: DateTime(2026, 9, 25),
          category: ExpenseCategory.alimentation,
        ),
      ],
      createdAt: DateTime(2026, 7, 18),
    ),
    Animal(
      id: 'a006',
      farmId: DatabaseMigrator.defaultFarmId,
      isDemo: true,
      name: 'Souleymane',
      type: AnimalType.caprin,
      imageUrl: 'assets/images/caprin.jpg',
      ageMonths: 30,
      weightKg: 45.0,
      healthStatus: HealthStatus.sain,
      expenses: [
        Expense(
          id: 'e014',
          animalId: 'a006',
          farmId: DatabaseMigrator.defaultFarmId,
          label: 'Bloc minéral lécheur',
          amount: 2800,
          date: DateTime(2026, 10, 1),
          category: ExpenseCategory.alimentation,
        ),
      ],
      createdAt: DateTime(2025, 12, 1),
    ),
    Animal(
      id: 'a007',
      farmId: DatabaseMigrator.defaultFarmId,
      isDemo: true,
      name: 'Rokia',
      type: AnimalType.ovin,
      imageUrl: 'assets/images/ovin.jpg',
      ageMonths: 22,
      weightKg: 55.0,
      healthStatus: HealthStatus.sain,
      expenses: [
        Expense(
          id: 'e015',
          animalId: 'a007',
          farmId: DatabaseMigrator.defaultFarmId,
          label: 'Son de maïs 25kg',
          amount: 3800,
          date: DateTime(2026, 10, 1),
          category: ExpenseCategory.alimentation,
        ),
        Expense(
          id: 'e016',
          animalId: 'a007',
          farmId: DatabaseMigrator.defaultFarmId,
          label: 'Tonte et soin sabots',
          amount: 5000,
          date: DateTime(2026, 9, 12),
          category: ExpenseCategory.autre,
        ),
      ],
      createdAt: DateTime(2026, 2, 28),
    ),
    Animal(
      id: 'a008',
      farmId: DatabaseMigrator.defaultFarmId,
      isDemo: true,
      name: 'Ibrahim',
      type: AnimalType.ovin,
      imageUrl: 'assets/images/ovin.jpg',
      ageMonths: 14,
      weightKg: 38.0,
      healthStatus: HealthStatus.aSurveiller,
      expenses: [
        Expense(
          id: 'e017',
          animalId: 'a008',
          farmId: DatabaseMigrator.defaultFarmId,
          label: 'Bilan sanguin',
          amount: 18000,
          date: DateTime(2026, 10, 1),
          category: ExpenseCategory.sante,
        ),
        Expense(
          id: 'e018',
          animalId: 'a008',
          farmId: DatabaseMigrator.defaultFarmId,
          label: 'Pâture supplémentaire',
          amount: 4200,
          date: DateTime(2026, 9, 18),
          category: ExpenseCategory.alimentation,
        ),
      ],
      createdAt: DateTime(2026, 6, 10),
    ),
    Animal(
      id: 'a009',
      farmId: DatabaseMigrator.defaultFarmId,
      isDemo: true,
      name: 'Adjoua',
      type: AnimalType.ovin,
      imageUrl: 'assets/images/ovin.jpg',
      ageMonths: 60,
      weightKg: 78.0,
      healthStatus: HealthStatus.sain,
      expenses: [
        Expense(
          id: 'e019',
          animalId: 'a009',
          farmId: DatabaseMigrator.defaultFarmId,
          label: 'Foin de légumineuse',
          amount: 5600,
          date: DateTime(2026, 10, 1),
          category: ExpenseCategory.alimentation,
        ),
      ],
      createdAt: DateTime(2024, 11, 5),
    ),
    Animal(
      id: 'a010',
      farmId: DatabaseMigrator.defaultFarmId,
      isDemo: true,
      name: 'Cocorico',
      type: AnimalType.volaille,
      imageUrl: 'assets/images/volaille.jpg',
      ageMonths: 6,
      weightKg: 2.8,
      healthStatus: HealthStatus.sain,
      expenses: [
        Expense(
          id: 'e020',
          animalId: 'a010',
          farmId: DatabaseMigrator.defaultFarmId,
          label: 'Aliment pondeuse 10kg',
          amount: 5200,
          date: DateTime(2026, 10, 1),
          category: ExpenseCategory.alimentation,
        ),
        Expense(
          id: 'e021',
          animalId: 'a010',
          farmId: DatabaseMigrator.defaultFarmId,
          label: 'Vaccination Newcastle',
          amount: 2500,
          date: DateTime(2026, 9, 8),
          category: ExpenseCategory.sante,
        ),
      ],
      createdAt: DateTime(2026, 8, 5),
    ),
    Animal(
      id: 'a011',
      farmId: DatabaseMigrator.defaultFarmId,
      isDemo: true,
      name: 'Perlita',
      type: AnimalType.volaille,
      imageUrl: 'assets/images/volaille.jpg',
      ageMonths: 4,
      weightKg: 1.9,
      healthStatus: HealthStatus.malade,
      expenses: [
        Expense(
          id: 'e022',
          animalId: 'a011',
          farmId: DatabaseMigrator.defaultFarmId,
          label: 'Traitement coccidiose',
          amount: 3800,
          date: DateTime(2026, 10, 1),
          category: ExpenseCategory.sante,
        ),
        Expense(
          id: 'e023',
          animalId: 'a011',
          farmId: DatabaseMigrator.defaultFarmId,
          label: 'Probiotique avicole',
          amount: 2100,
          date: DateTime(2026, 9, 30),
          category: ExpenseCategory.sante,
        ),
      ],
      createdAt: DateTime(2026, 9, 1),
    ),
    Animal(
      id: 'a012',
      farmId: DatabaseMigrator.defaultFarmId,
      isDemo: true,
      name: 'Djata',
      type: AnimalType.bovin,
      imageUrl: 'assets/images/bovin.jpg',
      ageMonths: 8,
      weightKg: 115.0,
      healthStatus: HealthStatus.sain,
      expenses: [
        Expense(
          id: 'e024',
          animalId: 'a012',
          farmId: DatabaseMigrator.defaultFarmId,
          label: 'Lait maternel substitut',
          amount: 12000,
          date: DateTime(2026, 10, 1),
          category: ExpenseCategory.alimentation,
        ),
        Expense(
          id: 'e025',
          animalId: 'a012',
          farmId: DatabaseMigrator.defaultFarmId,
          label: 'Boucle auriculaire + enregistrement',
          amount: 3500,
          date: DateTime(2026, 9, 2),
          category: ExpenseCategory.autre,
        ),
      ],
      createdAt: DateTime(2026, 9, 15),
    ),
  ];
}