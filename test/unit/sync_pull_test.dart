// test/unit/sync_pull_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:agritrack/data/animals_repository.dart';
import 'package:agritrack/data/database/database_migrator.dart';
import 'package:agritrack/models/animal.dart';
import 'package:agritrack/models/expense.dart';
import 'package:agritrack/models/sync_queue_operation.dart';
import 'package:agritrack/services/sync/supabase_sync_client.dart';
import 'package:agritrack/services/sync/sync_cursor_service.dart';
import 'package:agritrack/services/sync/sync_engine.dart';
import 'package:agritrack/services/sync/sync_queue_service.dart';

class MockSupabaseSyncClient implements ISupabaseSyncClient {
  final List<Map<String, dynamic>> animalsStore = [];
  final List<Map<String, dynamic>> expensesStore = [];
  final Map<String, String> memberRoles = {};

  bool shouldThrowOnFetchAnimals = false;
  bool shouldThrowOnFetchExpenses = false;
  int? throwOnFetchAnimalsCall;
  int fetchAnimalsCallCount = 0;
  int fetchExpensesCallCount = 0;

  void setMemberRole({
    required String farmId,
    required String userId,
    required String role,
  }) {
    memberRoles['$farmId:$userId'] = role;
  }

  @override
  Future<String?> getMemberRole({
    required String farmId,
    required String userId,
  }) async {
    return memberRoles['$farmId:$userId'];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAnimals({
    required String farmId,
    DateTime? since,
    String? lastId,
    int limit = 100,
  }) async {
    fetchAnimalsCallCount++;
    if (shouldThrowOnFetchAnimals ||
        (throwOnFetchAnimalsCall != null &&
            fetchAnimalsCallCount == throwOnFetchAnimalsCall)) {
      throw Exception('Simulation: Erreur réseau intermittente (fetchAnimals)');
    }

    var list = animalsStore
        .where((a) => a['farm_id'] == farmId)
        .toList();

    if (since != null) {
      final sinceIso = since.toIso8601String();
      list = list.where((a) {
        final upd = a['updated_at'] as String;
        if (upd.compareTo(sinceIso) > 0) return true;
        if (upd == sinceIso && lastId != null) {
          final id = a['id'] as String;
          return id.compareTo(lastId) > 0;
        }
        return false;
      }).toList();
    }

    list.sort((a, b) {
      final cmp = (a['updated_at'] as String).compareTo(b['updated_at'] as String);
      if (cmp != 0) return cmp;
      return (a['id'] as String).compareTo(b['id'] as String);
    });

    return list.take(limit).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchExpenses({
    required String farmId,
    DateTime? since,
    String? lastId,
    int limit = 100,
  }) async {
    fetchExpensesCallCount++;
    if (shouldThrowOnFetchExpenses) {
      throw Exception('Simulation: Erreur réseau (fetchExpenses)');
    }

    var list = expensesStore
        .where((e) => e['farm_id'] == farmId)
        .toList();

    if (since != null) {
      final sinceIso = since.toIso8601String();
      list = list.where((e) {
        final upd = e['updated_at'] as String;
        if (upd.compareTo(sinceIso) > 0) return true;
        if (upd == sinceIso && lastId != null) {
          final id = e['id'] as String;
          return id.compareTo(lastId) > 0;
        }
        return false;
      }).toList();
    }

    list.sort((a, b) {
      final cmp = (a['updated_at'] as String).compareTo(b['updated_at'] as String);
      if (cmp != 0) return cmp;
      return (a['id'] as String).compareTo(b['id'] as String);
    });

    return list.take(limit).toList();
  }

  @override
  Future<String> upsertAnimal(Map<String, dynamic> animalPayload) async {
    return animalPayload['id'] ?? 'remote_anim_mock';
  }

  @override
  Future<void> softDeleteAnimal({
    required String remoteId,
    required String farmId,
    required DateTime deletedAt,
  }) async {}

  @override
  Future<String> upsertExpense(Map<String, dynamic> expensePayload) async {
    return expensePayload['id'] ?? 'remote_exp_mock';
  }

  @override
  Future<void> softDeleteExpense({
    required String remoteId,
    required String farmId,
    required DateTime deletedAt,
  }) async {}

  @override
  Future<SyncPushResult> pushAnimalRpc({
    required String operationId,
    required String farmId,
    required String action,
    int? expectedVersion,
    String? localId,
    String? remoteId,
    String? name,
    String? type,
    int? ageMonths,
    double? weightKg,
    String? healthStatus,
    String? imageUrl,
    DateTime? deletedAt,
  }) async {
    return SyncPushResult.success(
      remoteId: remoteId ?? 'remote_anim_mock',
      versionId: (expectedVersion ?? 1) + 1,
    );
  }

  @override
  Future<SyncPushResult> pushExpenseRpc({
    required String operationId,
    required String farmId,
    required String action,
    int? expectedVersion,
    String? localId,
    String? remoteId,
    String? animalId,
    String? label,
    double? amount,
    DateTime? date,
    String? category,
    DateTime? deletedAt,
  }) async {
    return SyncPushResult.success(
      remoteId: remoteId ?? 'remote_exp_mock',
      versionId: (expectedVersion ?? 1) + 1,
    );
  }
}

void main() {
  group('Downstream Synchronization (Pull) Unit Tests (Étape 5C)', () {
    late Database testDb;
    late AnimalsRepository repository;
    late SyncQueueService queueService;
    late SyncCursorService cursorService;
    late MockSupabaseSyncClient mockClient;
    late SyncEngine syncEngine;

    const testFarmId = 'farm_cloud_pull_test';
    const testUserId = 'usr_cloud_pull_tester';

    setUp(() async {
      testDb = await databaseFactoryMemory.openDatabase('pull_test_${DateTime.now().microsecondsSinceEpoch}.db');
      await DatabaseMigrator.migrate(testDb);

      repository = AnimalsRepository(
        database: Future.value(testDb),
        autoSeed: false,
      );
      queueService = SyncQueueService(database: Future.value(testDb));
      cursorService = SyncCursorService(database: Future.value(testDb));
      mockClient = MockSupabaseSyncClient();

      mockClient.setMemberRole(
        farmId: testFarmId,
        userId: testUserId,
        role: 'owner',
      );

      syncEngine = SyncEngine(
        syncClient: mockClient,
        queueService: queueService,
        animalsRepository: repository,
        cursorService: cursorService,
      );
    });

    tearDown(() async {
      await testDb.close();
    });

    // 1. Premier Pull sur une base locale vide
    test('1. Premier Pull sur une base locale vide importe les données et initialise les curseurs', () async {
      mockClient.animalsStore.addAll([
        {
          'id': 'remote_a_1',
          'farm_id': testFarmId,
          'local_id': 'local_a_1',
          'name': 'Bovin Alpha',
          'type': 'bovin',
          'age_months': 24,
          'weight_kg': 450.0,
          'health_status': 'sain',
          'is_demo': false,
          'created_at': '2026-10-20T10:00:00.000Z',
          'updated_at': '2026-10-20T10:00:00.000Z',
        },
      ]);
      mockClient.expensesStore.addAll([
        {
          'id': 'remote_e_1',
          'animal_id': 'remote_a_1',
          'farm_id': testFarmId,
          'local_id': 'local_e_1',
          'label': 'Vaccin Alpha',
          'amount': 15000.0,
          'date': '2026-10-21T08:00:00.000Z',
          'category': 'sante',
          'updated_at': '2026-10-21T08:00:00.000Z',
        },
      ]);

      final result = await syncEngine.pullRemoteChanges(
        farmId: testFarmId,
        userId: testUserId,
      );

      expect(result.animalsPulled, 1);
      expect(result.expensesPulled, 1);
      expect(result.conflictsCount, 0);

      final localAnimals = await repository.fetchAnimals(farmId: testFarmId);
      expect(localAnimals.length, 1);
      final animal = localAnimals.first;
      expect(animal.name, 'Bovin Alpha');
      expect(animal.remoteId, 'remote_a_1');
      expect(animal.syncStatus, SyncStatus.synced);
      expect(animal.expenses.length, 1);
      expect(animal.expenses.first.label, 'Vaccin Alpha');
      expect(animal.expenses.first.remoteId, 'remote_e_1');

      final aCursor = await cursorService.getCursor(farmId: testFarmId, entityType: SyncEntityType.animal);
      final eCursor = await cursorService.getCursor(farmId: testFarmId, entityType: SyncEntityType.expense);
      expect(aCursor?.updatedAt, DateTime.parse('2026-10-20T10:00:00.000Z'));
      expect(eCursor?.updatedAt, DateTime.parse('2026-10-21T08:00:00.000Z'));
    });

    // 2. Pull différentiel après modification distante
    test('2. Pull différentiel ne récupère que les entités modifiées après le curseur existant', () async {
      await cursorService.saveCursor(
        farmId: testFarmId,
        entityType: SyncEntityType.animal,
        cursor: SyncCursor(updatedAt: DateTime.parse('2026-10-20T12:00:00.000Z'), lastId: 'remote_a_1'),
      );

      mockClient.animalsStore.addAll([
        {
          'id': 'remote_a_old',
          'farm_id': testFarmId,
          'name': 'Ancien Animal',
          'type': 'bovin',
          'updated_at': '2026-10-20T10:00:00.000Z',
        },
        {
          'id': 'remote_a_new',
          'farm_id': testFarmId,
          'name': 'Nouvel Animal',
          'type': 'ovin',
          'updated_at': '2026-10-21T15:00:00.000Z',
        },
      ]);

      final result = await syncEngine.pullRemoteChanges(
        farmId: testFarmId,
        userId: testUserId,
      );

      expect(result.animalsPulled, 1);
      final animals = await repository.fetchAnimals(farmId: testFarmId);
      expect(animals.length, 1);
      expect(animals.first.name, 'Nouvel Animal');

      final updatedCursor = await cursorService.getCursor(farmId: testFarmId, entityType: SyncEntityType.animal);
      expect(updatedCursor?.updatedAt, DateTime.parse('2026-10-21T15:00:00.000Z'));
    });

    // 3. Import d'animaux et de dépenses
    test('3. Importe correctement les enums et attributs sanitaires/catégories', () async {
      mockClient.animalsStore.add({
        'id': 'remote_a_caprin',
        'farm_id': testFarmId,
        'name': 'Chèvre Blanche',
        'type': 'caprin',
        'age_months': 14,
        'weight_kg': 35.5,
        'health_status': 'a_surveiller',
        'updated_at': '2026-10-22T09:00:00.000Z',
      });
      mockClient.expensesStore.add({
        'id': 'remote_e_feed',
        'animal_id': 'remote_a_caprin',
        'farm_id': testFarmId,
        'label': 'Foin spécial',
        'amount': 8500.0,
        'category': 'alimentation',
        'date': '2026-10-22T10:00:00.000Z',
        'updated_at': '2026-10-22T10:00:00.000Z',
      });

      await syncEngine.pullRemoteChanges(farmId: testFarmId, userId: testUserId);

      final animal = (await repository.fetchAnimals(farmId: testFarmId)).first;
      expect(animal.type, AnimalType.caprin);
      expect(animal.healthStatus, HealthStatus.aSurveiller);
      expect(animal.expenses.first.category, ExpenseCategory.alimentation);
    });

    // 4. Propagation des suppressions logiques
    test('4. Propagation des suppressions logiques (soft delete) masque les entités', () async {
      await repository.addAnimal(
        Animal(
          id: 'local_a_to_delete',
          name: 'Animal Actif',
          type: AnimalType.bovin,
          ageMonths: 12,
          weightKg: 200.0,
          healthStatus: HealthStatus.sain,
          farmId: testFarmId,
          remoteId: 'remote_a_soft_del',
          syncStatus: SyncStatus.synced,
          expenses: const [],
          createdAt: DateTime(2026),
        ),
      );

      mockClient.animalsStore.add({
        'id': 'remote_a_soft_del',
        'farm_id': testFarmId,
        'name': 'Animal Actif',
        'type': 'bovin',
        'deleted_at': '2026-10-25T14:30:00.000Z',
        'updated_at': '2026-10-25T14:30:00.000Z',
      });

      await syncEngine.pullRemoteChanges(farmId: testFarmId, userId: testUserId);

      final activeAnimals = await repository.fetchAnimals(farmId: testFarmId, includeDeleted: false);
      expect(activeAnimals, isEmpty);

      final allAnimals = await repository.fetchAnimals(farmId: testFarmId, includeDeleted: true);
      expect(allAnimals.length, 1);
      expect(allAnimals.first.deletedAt, DateTime.parse('2026-10-25T14:30:00.000Z'));
      expect(allAnimals.first.syncStatus, SyncStatus.synced);
    });

    // 5. Absence de doublons lors de plusieurs Pulls successifs
    test('5. Absence totale de doublons lors de plusieurs Pulls successifs (idempotence)', () async {
      mockClient.animalsStore.add({
        'id': 'remote_a_dup',
        'farm_id': testFarmId,
        'local_id': 'local_a_dup',
        'name': 'Bovin Unique',
        'type': 'bovin',
        'updated_at': '2026-10-23T11:00:00.000Z',
      });

      // 3 Pulls successifs
      await syncEngine.pullRemoteChanges(farmId: testFarmId, userId: testUserId);
      await syncEngine.pullRemoteChanges(farmId: testFarmId, userId: testUserId);
      await syncEngine.pullRemoteChanges(farmId: testFarmId, userId: testUserId);

      final animals = await repository.fetchAnimals(farmId: testFarmId);
      expect(animals.length, 1);
      expect(animals.first.id, 'local_a_dup');
      expect(animals.first.remoteId, 'remote_a_dup');
    });

    // 6. Reprise après interruption réseau
    test('6. Reprise après interruption réseau sans perte de données', () async {
      mockClient.animalsStore.add({
        'id': 'remote_a_retry',
        'farm_id': testFarmId,
        'name': 'Animal Résilient',
        'type': 'bovin',
        'updated_at': '2026-10-24T12:00:00.000Z',
      });

      mockClient.shouldThrowOnFetchAnimals = true;
      final failResult = await syncEngine.pullRemoteChanges(farmId: testFarmId, userId: testUserId);
      expect(failResult.failureCount, 1);

      var cursor = await cursorService.getCursor(farmId: testFarmId, entityType: SyncEntityType.animal);
      expect(cursor, isNull);

      // Rétablissement du réseau
      mockClient.shouldThrowOnFetchAnimals = false;
      final successResult = await syncEngine.pullRemoteChanges(farmId: testFarmId, userId: testUserId);
      expect(successResult.animalsPulled, 1);

      cursor = await cursorService.getCursor(farmId: testFarmId, entityType: SyncEntityType.animal);
      expect(cursor?.updatedAt, DateTime.parse('2026-10-24T12:00:00.000Z'));
    });

    // 7. Échec d'application locale sans avancement du curseur
    test('7. Échec d\'application locale n\'avance pas le curseur', () async {
      // Données provoquant un rejet (ex: farmId mismatch simulé)
      final batchResult = await repository.applyRemotePullBatch(
        farmId: testFarmId,
        remoteAnimals: [
          {
            'id': 'bad_animal',
            'farm_id': 'other_farm_mismatch',
            'updated_at': '2026-10-24T12:00:00.000Z',
          }
        ],
        remoteExpenses: const [],
      );

      expect(batchResult.animalsApplied, 0);
      final cursor = await cursorService.getCursor(farmId: testFarmId, entityType: SyncEntityType.animal);
      expect(cursor, isNull);
    });

    // 8. Plusieurs enregistrements partageant le même updated_at
    test('8. Plusieurs enregistrements partageant le même updated_at sont tous importés sans omission', () async {
      const sameTimestamp = '2026-10-24T10:00:00.000Z';
      mockClient.animalsStore.addAll([
        {
          'id': 'uuid_1',
          'farm_id': testFarmId,
          'name': 'Animal 1',
          'type': 'bovin',
          'updated_at': sameTimestamp,
        },
        {
          'id': 'uuid_2',
          'farm_id': testFarmId,
          'name': 'Animal 2',
          'type': 'ovin',
          'updated_at': sameTimestamp,
        },
        {
          'id': 'uuid_3',
          'farm_id': testFarmId,
          'name': 'Animal 3',
          'type': 'caprin',
          'updated_at': sameTimestamp,
        },
      ]);

      // Pagination par pages de 2
      final result = await syncEngine.pullRemoteChanges(
        farmId: testFarmId,
        userId: testUserId,
        pageSize: 2,
      );

      expect(result.animalsPulled, 3);
      final animals = await repository.fetchAnimals(farmId: testFarmId);
      expect(animals.length, 3);
    });

    // 9. Protection d'un animal local pendingUpdate
    test('9. Protection d\'un animal local pendingUpdate (aucun écrasement et conflit tracé)', () async {
      final localAnimal = await repository.addAnimal(
        Animal(
          id: 'local_pending_anim',
          name: 'Nom Local Modifié',
          type: AnimalType.bovin,
          ageMonths: 20,
          weightKg: 400.0,
          healthStatus: HealthStatus.sain,
          farmId: testFarmId,
          remoteId: 'remote_conflict_anim',
          syncStatus: SyncStatus.pendingUpdate,
          expenses: const [],
          createdAt: DateTime(2026),
        ),
      );

      mockClient.animalsStore.add({
        'id': 'remote_conflict_anim',
        'farm_id': testFarmId,
        'name': 'Nom Serveur Différent',
        'type': 'bovin',
        'updated_at': '2026-10-25T11:00:00.000Z',
      });

      final result = await syncEngine.pullRemoteChanges(farmId: testFarmId, userId: testUserId);

      expect(result.animalsPulled, 0);
      expect(result.conflictsCount, 1);

      final currentAnimal = await repository.getAnimalById(localAnimal.id);
      expect(currentAnimal!.name, 'Nom Local Modifié');
      expect(currentAnimal.syncStatus, SyncStatus.pendingUpdate);
    });

    // 10. Protection d'un animal local pendingDelete
    test('10. Protection d\'un animal local pendingDelete contre réapparition par le serveur', () async {
      final animal = await repository.addAnimal(
        Animal(
          id: 'local_del_anim',
          name: 'Animal Supprimé Local',
          type: AnimalType.bovin,
          ageMonths: 15,
          weightKg: 250.0,
          healthStatus: HealthStatus.sain,
          farmId: testFarmId,
          remoteId: 'remote_del_conflict',
          syncStatus: SyncStatus.synced,
          expenses: const [],
          createdAt: DateTime(2026),
        ),
      );

      await repository.deleteAnimal(animal.id);
      final deleted = await repository.getAnimalById(animal.id, includeDeleted: true);
      expect(deleted!.syncStatus, SyncStatus.pendingDelete);

      mockClient.animalsStore.add({
        'id': 'remote_del_conflict',
        'farm_id': testFarmId,
        'name': 'Animal Réactivé Serveur',
        'type': 'bovin',
        'updated_at': '2026-10-25T16:00:00.000Z',
      });

      final result = await syncEngine.pullRemoteChanges(farmId: testFarmId, userId: testUserId);
      expect(result.conflictsCount, 1);

      final stillDeleted = await repository.getAnimalById(animal.id, includeDeleted: true);
      expect(stillDeleted!.deletedAt, isNotNull);
      expect(stillDeleted.syncStatus, SyncStatus.pendingDelete);
    });

    // 11. Protection d'une dépense locale en attente
    test('11. Protection d\'une dépense locale pendingUpdate contre écrasement', () async {
      final animal = await repository.addAnimal(
        Animal(
          id: 'local_anim_exp',
          name: 'Animal Hôte',
          type: AnimalType.bovin,
          ageMonths: 18,
          weightKg: 300.0,
          healthStatus: HealthStatus.sain,
          farmId: testFarmId,
          remoteId: 'remote_anim_exp_id',
          syncStatus: SyncStatus.synced,
          expenses: [
            Expense(
              id: 'local_exp_conflict',
              remoteId: 'remote_exp_conflict_id',
              label: 'Libellé Local Modifié',
              amount: 25000.0,
              date: DateTime(2026, 10, 20),
              category: ExpenseCategory.sante,
              syncStatus: SyncStatus.pendingUpdate,
            ),
          ],
          createdAt: DateTime(2026),
        ),
      );

      mockClient.expensesStore.add({
        'id': 'remote_exp_conflict_id',
        'animal_id': 'remote_anim_exp_id',
        'farm_id': testFarmId,
        'label': 'Libellé Distant Serveur',
        'amount': 10000.0,
        'updated_at': '2026-10-25T17:00:00.000Z',
      });

      final result = await syncEngine.pullRemoteChanges(farmId: testFarmId, userId: testUserId);
      expect(result.conflictsCount, 1);

      final current = await repository.getAnimalById(animal.id);
      expect(current!.expenses.first.label, 'Libellé Local Modifié');
      expect(current.expenses.first.amount, 25000.0);
      expect(current.expenses.first.syncStatus, SyncStatus.pendingUpdate);
    });

    // 12. Isolation stricte entre deux exploitations
    test('12. Isolation stricte multi-fermes : les données de farm_B ne polluent pas farm_A', () async {
      mockClient.animalsStore.add({
        'id': 'remote_a_other_farm',
        'farm_id': 'other_unrelated_farm',
        'name': 'Animal Ferme B',
        'type': 'bovin',
        'updated_at': '2026-10-25T18:00:00.000Z',
      });

      final result = await syncEngine.pullRemoteChanges(farmId: testFarmId, userId: testUserId);
      expect(result.animalsPulled, 0);

      final animals = await repository.fetchAnimals(farmId: testFarmId);
      expect(animals, isEmpty);
    });

    // 13. Absence de boucle Pull -> Outbox -> Push
    test('13. Absence de boucle : un Pull ne génère aucune entrée dans sync_queue', () async {
      mockClient.animalsStore.add({
        'id': 'remote_no_loop',
        'farm_id': testFarmId,
        'name': 'Animal Sans Boucle',
        'type': 'ovin',
        'updated_at': '2026-10-25T19:00:00.000Z',
      });

      await syncEngine.pullRemoteChanges(farmId: testFarmId, userId: testUserId);

      // 1. La file doit être vide
      final pendingOps = await queueService.getPendingOperations(farmId: testFarmId);
      expect(pendingOps, isEmpty);

      // 2. La réconciliation Outbox ne doit rien récupérer
      final recovered = await queueService.reconcile(
        repository: repository,
        farmId: testFarmId,
        userId: testUserId,
      );
      expect(recovered, 0);
    });

    // 14. Conservation des dépenses locales existantes lors de la mise à jour d'un animal
    test('14. Conservation des dépenses existantes lors de la mise à jour des attributs d\'un animal', () async {
      final existingAnimal = await repository.addAnimal(
        Animal(
          id: 'local_keep_exp',
          name: 'Nom Avant',
          type: AnimalType.bovin,
          ageMonths: 20,
          weightKg: 350.0,
          healthStatus: HealthStatus.sain,
          farmId: testFarmId,
          remoteId: 'remote_keep_exp_id',
          syncStatus: SyncStatus.synced,
          expenses: [
            Expense(
              id: 'exp_preserved',
              label: 'Dépense Précieuse',
              amount: 50000.0,
              date: DateTime(2026, 10, 1),
              category: ExpenseCategory.alimentation,
              syncStatus: SyncStatus.synced,
            ),
          ],
          createdAt: DateTime(2026),
        ),
      );

      mockClient.animalsStore.add({
        'id': 'remote_keep_exp_id',
        'farm_id': testFarmId,
        'name': 'Nom Après Mise à Jour',
        'weight_kg': 390.0,
        'type': 'bovin',
        'updated_at': '2026-10-25T20:00:00.000Z',
      });

      await syncEngine.pullRemoteChanges(farmId: testFarmId, userId: testUserId);

      final updatedAnimal = await repository.getAnimalById(existingAnimal.id);
      expect(updatedAnimal!.name, 'Nom Après Mise à Jour');
      expect(updatedAnimal.weightKg, 390.0);
      expect(updatedAnimal.expenses.length, 1);
      expect(updatedAnimal.expenses.first.label, 'Dépense Précieuse');
      expect(updatedAnimal.expenses.first.amount, 50000.0);
    });

    // 15. Gestion des dépenses orphelines : mise en quarantaine persistante
    test('15. Gestion des dépenses orphelines : mise en quarantaine durable sans bloquer ni corrompre', () async {
      mockClient.expensesStore.add({
        'id': 'remote_orphan_exp',
        'animal_id': 'non_existent_remote_animal',
        'farm_id': testFarmId,
        'label': 'Dépense Orpheline',
        'amount': 12000.0,
        'updated_at': '2026-10-25T21:00:00.000Z',
      });

      final result = await syncEngine.pullRemoteChanges(farmId: testFarmId, userId: testUserId);
      expect(result.expensesPulled, 0);

      final allAnimals = await repository.fetchAnimals(farmId: testFarmId);
      for (final a in allAnimals) {
        expect(a.expenses.any((e) => e.remoteId == 'remote_orphan_exp'), isFalse);
      }

      // Vérification que la dépense orpheline est durablement stockée dans orphan_expenses
      final quarantined = await repository.getQuarantinedExpenses(farmId: testFarmId);
      expect(quarantined.length, 1);
      expect(quarantined.first['id'], 'remote_orphan_exp');
      expect(quarantined.first['animal_id'], 'non_existent_remote_animal');
      expect(quarantined.first['farm_id'], testFarmId);
      expect(quarantined.first['attempt_count'], 1);
    });

    // 16. Respect des limites de pagination
    test('16. Pagination séquentielle : traite plusieurs pages successivement', () async {
      for (int i = 1; i <= 5; i++) {
        mockClient.animalsStore.add({
          'id': 'paged_animal_$i',
          'farm_id': testFarmId,
          'name': 'Animal Paginé $i',
          'type': 'bovin',
          'updated_at': '2026-10-25T10:0$i:00.000Z',
        });
      }

      final result = await syncEngine.pullRemoteChanges(
        farmId: testFarmId,
        userId: testUserId,
        pageSize: 2,
      );

      expect(result.animalsPulled, 5);
      expect(mockClient.fetchAnimalsCallCount, 3); // 2 + 2 + 1
      final animals = await repository.fetchAnimals(farmId: testFarmId);
      expect(animals.length, 5);
    });

    // 17. Absence de synchronisation des données de démonstration
    test('17. Rejet systématique des données marquées is_demo: true', () async {
      mockClient.animalsStore.add({
        'id': 'demo_animal_cloud',
        'farm_id': testFarmId,
        'name': 'Animal Démo Rejeté',
        'type': 'volaille',
        'is_demo': true,
        'updated_at': '2026-10-25T22:00:00.000Z',
      });

      final result = await syncEngine.pullRemoteChanges(farmId: testFarmId, userId: testUserId);
      expect(result.animalsPulled, 0);

      final animals = await repository.fetchAnimals(farmId: testFarmId);
      expect(animals, isEmpty);
    });

    // 18. Pagination composite native : horodatages identiques traversant une frontière de page
    test('18. Pagination composite : horodatages identiques traversant les frontières sans doublon ni omission', () async {
      const sameTimestamp = '2026-10-25T15:00:00.000Z';
      for (int i = 1; i <= 7; i++) {
        mockClient.animalsStore.add({
          'id': 'anim_same_time_$i',
          'farm_id': testFarmId,
          'name': 'Animal Même Date $i',
          'type': 'ovin',
          'updated_at': sameTimestamp,
        });
      }

      // Pagination avec pageSize = 3 : page 1 (3), page 2 (3), page 3 (1) -> 3 appels
      final result = await syncEngine.pullRemoteChanges(
        farmId: testFarmId,
        userId: testUserId,
        pageSize: 3,
      );

      expect(result.animalsPulled, 7);
      expect(mockClient.fetchAnimalsCallCount, 3);

      final localAnimals = await repository.fetchAnimals(farmId: testFarmId);
      expect(localAnimals.length, 7);
      final ids = localAnimals.map((a) => a.remoteId).toSet();
      expect(ids.length, 7, reason: 'Tous les 7 animaux doivent être présents sans doublon');

      // Vérifier le curseur final composite
      final cursor = await cursorService.getCursor(
        farmId: testFarmId,
        entityType: SyncEntityType.animal,
      );
      expect(cursor?.updatedAt, DateTime.parse(sameTimestamp));
      expect(cursor?.lastId, 'anim_same_time_7');
    });

    // 19. Pagination : reprise après interruption réseau
    test('19. Pagination : reprise après interruption réseau sans perte de progression ni doublons', () async {
      for (int i = 1; i <= 6; i++) {
        mockClient.animalsStore.add({
          'id': 'resumable_anim_$i',
          'farm_id': testFarmId,
          'name': 'Animal Reprise $i',
          'type': 'caprin',
          'updated_at': '2026-10-25T16:0$i:00.000Z',
        });
      }

      // Première passe : interruption réseau au 2e lot
      mockClient.fetchAnimalsCallCount = 0;
      mockClient.throwOnFetchAnimalsCall = 2;

      final failResult = await syncEngine.pullRemoteChanges(
        farmId: testFarmId,
        userId: testUserId,
        pageSize: 2,
      );

      // Le lot 1 (2 animaux) a été appliqué avec succès avant l'échec du lot 2
      expect(failResult.animalsPulled, 2);
      expect(failResult.failureCount, 1);

      // Le curseur a avancé au dernier élément du premier lot
      final midCursor = await cursorService.getCursor(
        farmId: testFarmId,
        entityType: SyncEntityType.animal,
      );
      expect(midCursor?.lastId, 'resumable_anim_2');

      // Deuxième passe : reprise normale sans erreur
      mockClient.throwOnFetchAnimalsCall = null;
      final resumeResult = await syncEngine.pullRemoteChanges(
        farmId: testFarmId,
        userId: testUserId,
        pageSize: 2,
      );

      // Les 4 animaux restants sont récupérés
      expect(resumeResult.animalsPulled, 4);
      expect(resumeResult.failureCount, 0);

      final allAnimals = await repository.fetchAnimals(farmId: testFarmId);
      expect(allAnimals.length, 6);
      final uniqueIds = allAnimals.map((a) => a.remoteId).toSet();
      expect(uniqueIds.length, 6, reason: 'Exactement 6 animaux distincts après reprise');
    });

    // 20. Quarantaine : persistance après fermeture et réouverture de la base, puis résolution automatique
    test('20. Quarantaine persistante : survit à la fermeture/réouverture et se rattache dès que le parent arrive', () async {
      final dbName = 'persistent_quarantine_${DateTime.now().microsecondsSinceEpoch}.db';
      final db1 = await databaseFactoryMemory.openDatabase(dbName);
      await DatabaseMigrator.migrate(db1);

      final repo1 = AnimalsRepository(database: Future.value(db1), autoSeed: false);
      final queue1 = SyncQueueService(database: Future.value(db1));
      final cursor1 = SyncCursorService(database: Future.value(db1));
      final engine1 = SyncEngine(
        syncClient: mockClient,
        queueService: queue1,
        animalsRepository: repo1,
        cursorService: cursor1,
      );

      // 1. Dépense orpheline arrive sans son animal parent
      mockClient.expensesStore.add({
        'id': 'orphan_exp_persistent',
        'animal_id': 'parent_anim_late',
        'farm_id': testFarmId,
        'label': 'Soin Vétérinaire Anticipé',
        'amount': 35000.0,
        'category': 'soins_medicaux',
        'updated_at': '2026-10-25T17:00:00.000Z',
      });

      final pull1 = await engine1.pullRemoteChanges(farmId: testFarmId, userId: testUserId);
      expect(pull1.expensesPulled, 0);

      // Vérifier que la dépense est bien en quarantaine
      var qList = await repo1.getQuarantinedExpenses(farmId: testFarmId);
      expect(qList.length, 1);
      expect(qList.first['id'], 'orphan_exp_persistent');

      // 2. Fermeture de la base de données (simulation arrêt application)
      await db1.close();

      // 3. Réouverture de la même base de données (simulation redémarrage application)
      final db2 = await databaseFactoryMemory.openDatabase(dbName);
      final repo2 = AnimalsRepository(database: Future.value(db2), autoSeed: false);
      final queue2 = SyncQueueService(database: Future.value(db2));
      final cursor2 = SyncCursorService(database: Future.value(db2));
      final engine2 = SyncEngine(
        syncClient: mockClient,
        queueService: queue2,
        animalsRepository: repo2,
        cursorService: cursor2,
      );

      // La dépense orpheline est TOUJOURS présente dans le magasin de quarantaine
      qList = await repo2.getQuarantinedExpenses(farmId: testFarmId);
      expect(qList.length, 1);
      expect(qList.first['id'], 'orphan_exp_persistent');

      // 4. L'animal parent arrive dans le lot distant suivant
      mockClient.animalsStore.add({
        'id': 'parent_anim_late',
        'farm_id': testFarmId,
        'name': 'Génisse Retrouvée',
        'type': 'bovin',
        'updated_at': '2026-10-25T18:00:00.000Z',
      });

      final pull2 = await engine2.pullRemoteChanges(farmId: testFarmId, userId: testUserId);
      expect(pull2.animalsPulled, 1);
      expect(pull2.orphansResolved, 1);

      // 5. La quarantaine est maintenant vide
      final qAfter = await repo2.getQuarantinedExpenses(farmId: testFarmId);
      expect(qAfter, isEmpty, reason: 'La dépense doit être retirée de la quarantaine après rattachement');

      // 6. La dépense est correctement rattachée à l'animal parent
      final animals = await repo2.fetchAnimals(farmId: testFarmId);
      final parent = animals.firstWhere((a) => a.remoteId == 'parent_anim_late');
      expect(parent.expenses.length, 1);
      final attachedExp = parent.expenses.first;
      expect(attachedExp.remoteId, 'orphan_exp_persistent');
      expect(attachedExp.label, 'Soin Vétérinaire Anticipé');
      expect(attachedExp.amount, 35000.0);
      expect(attachedExp.syncStatus, SyncStatus.synced);

      // 7. Aucune opération générée dans l'Outbox (empêche boucle Pull -> Outbox -> Push)
      final pendingOps = await queue2.getPendingOperations(farmId: testFarmId);
      expect(pendingOps, isEmpty);

      await db2.close();
    });

    // 21. Quarantaine : déduplication et compteur de tentatives
    test('21. Quarantaine : pas de doublons lors de plusieurs tentatives, incrémente attempt_count', () async {
      mockClient.expensesStore.add({
        'id': 'orphan_dedup_test',
        'animal_id': 'missing_anim',
        'farm_id': testFarmId,
        'label': 'Dépense Récurrente Orpheline',
        'amount': 5000.0,
        'updated_at': '2026-10-25T19:00:00.000Z',
      });

      // Pull 1
      await syncEngine.pullRemoteChanges(farmId: testFarmId, userId: testUserId);
      var q = await repository.getQuarantinedExpenses(farmId: testFarmId);
      expect(q.length, 1);
      expect(q.first['attempt_count'], 1);

      // Deuxième appel direct applyRemotePullBatch avec la même dépense
      await repository.applyRemotePullBatch(
        farmId: testFarmId,
        remoteAnimals: const [],
        remoteExpenses: [
          {
            'id': 'orphan_dedup_test',
            'animal_id': 'missing_anim',
            'farm_id': testFarmId,
            'label': 'Dépense Récurrente Orpheline v2',
            'amount': 5000.0,
            'updated_at': '2026-10-25T19:10:00.000Z',
          }
        ],
      );

      q = await repository.getQuarantinedExpenses(farmId: testFarmId);
      expect(q.length, 1, reason: 'La quarantaine ne doit pas créer de doublons');
      expect(q.first['attempt_count'], 2);
      expect((q.first['payload'] as Map)['label'], 'Dépense Récurrente Orpheline v2');
    });

    // 22. Quarantaine : isolation stricte entre exploitations
    test('22. Quarantaine : isolation stricte entre deux exploitations', () async {
      const otherFarmId = 'farm_other_isolation_test';
      mockClient.setMemberRole(farmId: otherFarmId, userId: testUserId, role: 'owner');

      // Dépense orpheline pour testFarmId ciblant 'shared_anim_id'
      mockClient.expensesStore.add({
        'id': 'orphan_farm1',
        'animal_id': 'shared_anim_id',
        'farm_id': testFarmId,
        'label': 'Alimentation Exploitation 1',
        'amount': 8000.0,
        'updated_at': '2026-10-25T20:00:00.000Z',
      });

      await syncEngine.pullRemoteChanges(farmId: testFarmId, userId: testUserId);

      // Un animal avec le même remoteId 'shared_anim_id' arrive, mais pour otherFarmId
      mockClient.animalsStore.add({
        'id': 'shared_anim_id',
        'farm_id': otherFarmId,
        'name': 'Bovin Exploitation 2',
        'type': 'bovin',
        'updated_at': '2026-10-25T20:05:00.000Z',
      });

      final pullOther = await syncEngine.pullRemoteChanges(
        farmId: otherFarmId,
        userId: testUserId,
      );
      expect(pullOther.animalsPulled, 1);
      expect(pullOther.orphansResolved, 0);

      // Vérifier que l'animal de otherFarmId n'a PAS reçu la dépense orpheline de testFarmId
      final otherAnimals = await repository.fetchAnimals(farmId: otherFarmId);
      final animal2 = otherAnimals.firstWhere((a) => a.remoteId == 'shared_anim_id');
      expect(animal2.expenses, isEmpty);

      // La dépense orpheline est toujours en quarantaine pour testFarmId
      final q1 = await repository.getQuarantinedExpenses(farmId: testFarmId);
      expect(q1.length, 1);
      expect(q1.first['id'], 'orphan_farm1');
    });

    // 23. Quarantaine : conservation du statut de suppression logique (soft delete)
    test('23. Quarantaine : préserve deleted_at lors du rattachement ultérieur', () async {
      mockClient.expensesStore.add({
        'id': 'orphan_soft_deleted',
        'animal_id': 'target_anim_soft_del',
        'farm_id': testFarmId,
        'label': 'Dépense Supprimée Orpheline',
        'amount': 4500.0,
        'deleted_at': '2026-10-25T20:30:00.000Z',
        'updated_at': '2026-10-25T20:30:00.000Z',
      });

      await syncEngine.pullRemoteChanges(farmId: testFarmId, userId: testUserId);

      // L'animal parent arrive ensuite
      mockClient.animalsStore.add({
        'id': 'target_anim_soft_del',
        'farm_id': testFarmId,
        'name': 'Animal Parent Soft Del',
        'type': 'ovin',
        'updated_at': '2026-10-25T20:35:00.000Z',
      });

      final pull = await syncEngine.pullRemoteChanges(farmId: testFarmId, userId: testUserId);
      expect(pull.orphansResolved, 1);

      final animals = await repository.fetchAnimals(farmId: testFarmId, includeDeleted: true);
      final parent = animals.firstWhere((a) => a.remoteId == 'target_anim_soft_del');
      expect(parent.expenses.length, 1);
      final exp = parent.expenses.first;
      expect(exp.deletedAt, isNotNull);
      expect(exp.deletedAt != null, isTrue);
      expect(exp.deletedAt, DateTime.parse('2026-10-25T20:30:00.000Z'));
    });

    // 24. Avancement de curseur : ne saute aucune dépense orpheline
    test('24. Curseur : avance normalement mais l\'orphelin reste rattachable indéfiniment', () async {
      // Dépense 1 : orpheline (updated_at = 10:00)
      mockClient.expensesStore.add({
        'id': 'orphan_first',
        'animal_id': 'anim_later',
        'farm_id': testFarmId,
        'label': 'Dépense 1',
        'amount': 1000.0,
        'updated_at': '2026-10-25T10:00:00.000Z',
      });

      // Animal 2 déjà présent localement
      final existingAnimal = Animal(
        id: 'local_a2',
        remoteId: 'remote_a2',
        farmId: testFarmId,
        name: 'Animal Présent',
        type: AnimalType.bovin,
        ageMonths: 12,
        weightKg: 250.0,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime.now(),
      );
      await repository.addAnimal(existingAnimal);

      // Dépense 2 : normale sur animal existant (updated_at = 11:00)
      mockClient.expensesStore.add({
        'id': 'expense_second',
        'animal_id': 'remote_a2',
        'farm_id': testFarmId,
        'label': 'Dépense 2',
        'amount': 2000.0,
        'updated_at': '2026-10-25T11:00:00.000Z',
      });

      final pull1 = await syncEngine.pullRemoteChanges(farmId: testFarmId, userId: testUserId);
      expect(pull1.expensesPulled, 1); // Dépense 2 appliquée

      // Le curseur a avancé jusqu'à la dépense 2 (11:00)
      final cursor = await cursorService.getCursor(
        farmId: testFarmId,
        entityType: SyncEntityType.expense,
      );
      expect(cursor?.lastId, 'expense_second');

      // L'orpheline 1 n'est pas perdue bien que le curseur soit passé après elle
      final q = await repository.getQuarantinedExpenses(farmId: testFarmId);
      expect(q.length, 1);
      expect(q.first['id'], 'orphan_first');

      // Même si Supabase n'envoie plus la dépense 1 au prochain Pull (car since >= 11:00),
      // l'import de 'anim_later' résout la dépense 1 depuis la quarantaine locale
      mockClient.animalsStore.add({
        'id': 'anim_later',
        'farm_id': testFarmId,
        'name': 'Animal Arrivé Plus Tard',
        'type': 'caprin',
        'updated_at': '2026-10-25T12:00:00.000Z',
      });

      final pull2 = await syncEngine.pullRemoteChanges(farmId: testFarmId, userId: testUserId);
      expect(pull2.orphansResolved, 1);

      final qAfter = await repository.getQuarantinedExpenses(farmId: testFarmId);
      expect(qAfter, isEmpty);

      final allAnimals = await repository.fetchAnimals(farmId: testFarmId);
      final attachedParent = allAnimals.firstWhere((a) => a.remoteId == 'anim_later');
      expect(attachedParent.expenses.first.remoteId, 'orphan_first');
    });
  });
}
