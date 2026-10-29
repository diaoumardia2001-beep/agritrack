// test/unit/sync_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:agritrack/data/animals_repository.dart';
import 'package:agritrack/data/database/database_migrator.dart';
import 'package:agritrack/models/animal.dart';
import 'package:agritrack/models/expense.dart';
import 'package:agritrack/models/sync_queue_operation.dart';
import 'package:agritrack/services/sync/supabase_sync_client.dart';
import 'package:agritrack/services/sync/sync_engine.dart';
import 'package:agritrack/services/sync/sync_queue_service.dart';

/// Client simulé en mémoire pour tester le moteur de synchronisation
/// sans dépendance au réseau ni à une véritable instance Supabase.
class FakeSupabaseSyncClient implements ISupabaseSyncClient {
  final List<Map<String, dynamic>> upsertedAnimals = [];
  final List<Map<String, dynamic>> softDeletedAnimals = [];
  final List<Map<String, dynamic>> upsertedExpenses = [];
  final List<Map<String, dynamic>> softDeletedExpenses = [];
  final Map<String, String> memberRoles = {}; // key: "$farmId:$userId" -> role

  bool shouldThrowOnUpsertAnimal = false;
  bool shouldThrowOnUpsertExpense = false;
  bool shouldThrowOnSoftDelete = false;
  String? errorToThrow;

  int _uuidSequence = 1000;

  void setMemberRole({
    required String farmId,
    required String userId,
    required String role,
  }) {
    memberRoles['$farmId:$userId'] = role;
  }

  void clearRecordedCalls() {
    upsertedAnimals.clear();
    softDeletedAnimals.clear();
    upsertedExpenses.clear();
    softDeletedExpenses.clear();
  }

  @override
  Future<String> upsertAnimal(Map<String, dynamic> animalPayload) async {
    if (shouldThrowOnUpsertAnimal) {
      throw Exception(
          errorToThrow ?? 'Simulation d\'erreur réseau (upsertAnimal)');
    }
    upsertedAnimals.add(Map<String, dynamic>.from(animalPayload));
    final existingId = animalPayload['id'] as String?;
    if (existingId != null && existingId.isNotEmpty) {
      return existingId;
    }
    return 'uuid-animal-${_uuidSequence++}';
  }

  @override
  Future<void> softDeleteAnimal({
    required String remoteId,
    required String farmId,
    required DateTime deletedAt,
  }) async {
    if (shouldThrowOnSoftDelete) {
      throw Exception(
          errorToThrow ?? 'Simulation d\'erreur réseau (softDeleteAnimal)');
    }
    softDeletedAnimals.add({
      'remoteId': remoteId,
      'farmId': farmId,
      'deletedAt': deletedAt,
    });
  }

  @override
  Future<String> upsertExpense(Map<String, dynamic> expensePayload) async {
    if (shouldThrowOnUpsertExpense) {
      throw Exception(
          errorToThrow ?? 'Simulation d\'erreur réseau (upsertExpense)');
    }
    upsertedExpenses.add(Map<String, dynamic>.from(expensePayload));
    final existingId = expensePayload['id'] as String?;
    if (existingId != null && existingId.isNotEmpty) {
      return existingId;
    }
    return 'uuid-expense-${_uuidSequence++}';
  }

  @override
  Future<void> softDeleteExpense({
    required String remoteId,
    required String farmId,
    required DateTime deletedAt,
  }) async {
    if (shouldThrowOnSoftDelete) {
      throw Exception(
          errorToThrow ?? 'Simulation d\'erreur réseau (softDeleteExpense)');
    }
    softDeletedExpenses.add({
      'remoteId': remoteId,
      'farmId': farmId,
      'deletedAt': deletedAt,
    });
  }

  @override
  Future<String?> getMemberRole({
    required String farmId,
    required String userId,
  }) async {
    return memberRoles['$farmId:$userId'];
  }

  final List<Map<String, dynamic>> animalsToFetch = [];
  final List<Map<String, dynamic>> expensesToFetch = [];

  SyncPushResult? nextAnimalPushResult;
  SyncPushResult? nextExpensePushResult;

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
    if (shouldThrowOnUpsertAnimal ||
        (action == 'delete' && shouldThrowOnSoftDelete)) {
      throw Exception(
          errorToThrow ?? 'Simulation d\'erreur réseau (pushAnimalRpc)');
    }
    if (nextAnimalPushResult != null) {
      final res = nextAnimalPushResult!;
      nextAnimalPushResult = null;
      return res;
    }
    if (action == 'delete') {
      softDeletedAnimals.add({
        'remoteId': remoteId,
        'farmId': farmId,
        'deletedAt': deletedAt,
      });
      return SyncPushResult.success(
        remoteId: remoteId ?? 'uuid-animal-${_uuidSequence++}',
        versionId: (expectedVersion ?? 1) + 1,
      );
    }
    final payload = <String, dynamic>{
      'operation_id': operationId,
      'farm_id': farmId,
      'action': action,
      'expected_version': expectedVersion,
      'local_id': localId,
      'id': remoteId,
      'name': name,
      'type': type,
      'age_months': ageMonths,
      'weight_kg': weightKg,
      'health_status': healthStatus,
      'image_url': imageUrl,
      'deleted_at': deletedAt?.toIso8601String(),
    };
    upsertedAnimals.add(payload);
    final finalRemoteId = remoteId?.isNotEmpty == true
        ? remoteId!
        : 'uuid-animal-${_uuidSequence++}';
    return SyncPushResult.success(
      remoteId: finalRemoteId,
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
    if (shouldThrowOnUpsertExpense ||
        (action == 'delete' && shouldThrowOnSoftDelete)) {
      throw Exception(
          errorToThrow ?? 'Simulation d\'erreur réseau (pushExpenseRpc)');
    }
    if (nextExpensePushResult != null) {
      final res = nextExpensePushResult!;
      nextExpensePushResult = null;
      return res;
    }
    if (action == 'delete') {
      softDeletedExpenses.add({
        'remoteId': remoteId,
        'farmId': farmId,
        'deletedAt': deletedAt,
      });
      return SyncPushResult.success(
        remoteId: remoteId ?? 'uuid-expense-${_uuidSequence++}',
        versionId: (expectedVersion ?? 1) + 1,
      );
    }
    final payload = <String, dynamic>{
      'operation_id': operationId,
      'farm_id': farmId,
      'action': action,
      'expected_version': expectedVersion,
      'local_id': localId,
      'id': remoteId,
      'animal_id': animalId,
      'label': label,
      'amount': amount,
      'date': date?.toIso8601String(),
      'category': category,
      'deleted_at': deletedAt?.toIso8601String(),
    };
    upsertedExpenses.add(payload);
    final finalRemoteId = remoteId?.isNotEmpty == true
        ? remoteId!
        : 'uuid-expense-${_uuidSequence++}';
    return SyncPushResult.success(
      remoteId: finalRemoteId,
      versionId: (expectedVersion ?? 1) + 1,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAnimals({
    required String farmId,
    DateTime? since,
    String? lastId,
    int limit = 100,
  }) async {
    return animalsToFetch.where((a) => a['farm_id'] == farmId).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchExpenses({
    required String farmId,
    DateTime? since,
    String? lastId,
    int limit = 100,
  }) async {
    return expensesToFetch.where((e) => e['farm_id'] == farmId).toList();
  }
}

void main() {
  group('SyncEngine Unit & Simulation Tests (Étape 5B)', () {
    late Database testDb;
    late SyncQueueService queueService;
    late AnimalsRepository animalsRepo;
    late FakeSupabaseSyncClient fakeClient;
    late SyncEngine syncEngine;

    const testFarmId = 'remote-farm-uuid-1';
    const testUserId = 'auth-user-uuid-1';

    setUp(() async {
      final memoryFactory = newDatabaseFactoryMemory();
      final dbName =
          'test_sync_engine_${DateTime.now().microsecondsSinceEpoch}.db';
      testDb = await memoryFactory.openDatabase(dbName);
      await DatabaseMigrator.migrate(testDb);

      queueService = SyncQueueService(database: Future.value(testDb));
      animalsRepo = AnimalsRepository(
        database: Future.value(testDb),
        autoSeed: false,
      );
      fakeClient = FakeSupabaseSyncClient();

      // Par défaut, l'utilisateur de test est 'manager' sur l'exploitation distante de test
      fakeClient.setMemberRole(
        farmId: testFarmId,
        userId: testUserId,
        role: 'manager',
      );

      syncEngine = SyncEngine(
        syncClient: fakeClient,
        queueService: queueService,
        animalsRepository: animalsRepo,
      );
    });

    tearDown(() async {
      await testDb.close();
    });

    // ─── 1. Création d'un animal et conservation de son remoteId ─────────────
    test('1. Sync animal creation and persist its remoteId in Sembast',
        () async {
      final localAnimal = Animal(
        id: 'animal_local_1',
        farmId: testFarmId,
        name: 'Sahel',
        type: AnimalType.bovin,
        ageMonths: 24,
        weightKg: 280.0,
        healthStatus: HealthStatus.aSurveiller,
        syncStatus: SyncStatus.pendingCreate,
        expenses: const [],
        createdAt: DateTime(2026, 10, 1),
      );
      await animalsRepo.addAnimal(localAnimal);

      await queueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: localAnimal.id,
        action: SyncAction.create,
        farmId: testFarmId,
        userId: testUserId,
      );

      final result = await syncEngine.syncPendingOperations(
        farmId: testFarmId,
        userId: testUserId,
      );

      expect(result.isSuccess, isTrue);
      expect(result.successCount, 1);
      expect(result.failureCount, 0);
      expect(result.blockedCount, 0);

      // Vérifie l'appel réseau
      expect(fakeClient.upsertedAnimals.length, 1);
      final payload = fakeClient.upsertedAnimals.first;
      expect(payload['local_id'], 'animal_local_1');
      expect(payload['farm_id'], testFarmId);
      expect(payload['name'], 'Sahel');
      expect(payload['health_status'], 'a_surveiller'); // Conversion snake_case

      // Vérifie la mise à jour locale
      final updatedAnimal = await animalsRepo.getAnimalById('animal_local_1');
      expect(updatedAnimal, isNotNull);
      expect(updatedAnimal!.remoteId, startsWith('uuid-animal-'));
      expect(updatedAnimal.syncStatus, SyncStatus.synced);

      // Vérifie que la file est vide
      final remainingOps = await queueService.getPendingOperations(
        farmId: testFarmId,
        userId: testUserId,
      );
      expect(remainingOps.isEmpty, isTrue);
    });

    // ─── 2. Création d'une dépense liée au bon animal distant ────────────────
    test('2. Sync expense creation linked to correct parent animal remote UUID',
        () async {
      const parentRemoteId = 'uuid-animal-parent-42';
      final localAnimal = Animal(
        id: 'animal_local_2',
        farmId: testFarmId,
        remoteId: parentRemoteId,
        syncStatus: SyncStatus.synced,
        name: 'Bella',
        type: AnimalType.ovin,
        ageMonths: 12,
        weightKg: 45.0,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime(2026, 10, 1),
      );
      await animalsRepo.addAnimal(localAnimal);

      final createdExpense = await animalsRepo.addExpense(
        localAnimal.id,
        Expense(
          id: 'exp_local_1',
          farmId: testFarmId,
          animalId: localAnimal.id,
          label: 'Aliment concentré',
          amount: 5000,
          date: DateTime(2026, 10, 2),
          category: ExpenseCategory.alimentation,
          syncStatus: SyncStatus.pendingCreate,
        ),
      );

      await queueService.enqueue(
        entityType: SyncEntityType.expense,
        localId: createdExpense.id,
        action: SyncAction.create,
        farmId: testFarmId,
        userId: testUserId,
        payload: {'animalId': localAnimal.id},
      );

      final result = await syncEngine.syncPendingOperations(
        farmId: testFarmId,
        userId: testUserId,
      );

      expect(result.isSuccess, isTrue);
      expect(result.successCount, 1);
      expect(fakeClient.upsertedExpenses.length, 1);

      final expensePayload = fakeClient.upsertedExpenses.first;
      expect(expensePayload['local_id'], 'exp_local_1');
      expect(expensePayload['animal_id'],
          parentRemoteId); // Clé étrangère distante !
      expect(expensePayload['farm_id'], testFarmId);
      expect(expensePayload['amount'], 5000);

      // Vérification locale
      final updatedAnimal = await animalsRepo.getAnimalById('animal_local_2');
      final updatedExpense = updatedAnimal!.expenses.first;
      expect(updatedExpense.remoteId, startsWith('uuid-expense-'));
      expect(updatedExpense.syncStatus, SyncStatus.synced);
    });

    // ─── 3. Blocage d'une dépense sans remoteId parent ───────────────────────
    test('3. Block expense sync when parent animal lacks a remoteId', () async {
      // Animal local sans remoteId
      final localAnimal = Animal(
        id: 'animal_local_3',
        farmId: testFarmId,
        remoteId: null, // Pas encore synchronisé !
        syncStatus: SyncStatus.pendingCreate,
        name: 'Moussa',
        type: AnimalType.caprin,
        ageMonths: 8,
        weightKg: 20.0,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime(2026, 10, 1),
      );
      await animalsRepo.addAnimal(localAnimal);

      final expense = await animalsRepo.addExpense(
        localAnimal.id,
        Expense(
          id: 'exp_blocked_1',
          farmId: testFarmId,
          animalId: localAnimal.id,
          label: 'Vaccin',
          amount: 3000,
          date: DateTime(2026, 10, 3),
          category: ExpenseCategory.sante,
        ),
      );

      await queueService.enqueue(
        entityType: SyncEntityType.expense,
        localId: expense.id,
        action: SyncAction.create,
        farmId: testFarmId,
        userId: testUserId,
        payload: {'animalId': localAnimal.id},
      );

      final result = await syncEngine.syncPendingOperations(
        farmId: testFarmId,
        userId: testUserId,
      );

      expect(result.isSuccess, isFalse);
      expect(result.blockedCount, 1);
      expect(fakeClient.upsertedExpenses.isEmpty,
          isTrue); // STRICTEMENT AUCUN ENVOI RÉSEAU !

      // L'opération reste conservée dans la file
      final pending = await queueService.getPendingOperations(
        farmId: testFarmId,
        userId: testUserId,
      );
      expect(pending.length, 1);
      expect(pending.first.localId, 'exp_blocked_1');
      expect(pending.first.lastErrorMessage,
          contains('ne possède pas encore de remoteId'));
    });

    // ─── 4. Suppressions logiques (Soft Delete) ──────────────────────────────
    test('4. Logical deletions send soft delete and preserve records',
        () async {
      final localAnimal = Animal(
        id: 'animal_to_delete',
        farmId: testFarmId,
        remoteId: 'uuid-animal-del-99',
        syncStatus: SyncStatus.synced,
        name: 'Vieux Bovin',
        type: AnimalType.bovin,
        ageMonths: 60,
        weightKg: 400.0,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime(2026, 1, 1),
      );
      await animalsRepo.addAnimal(localAnimal);
      await animalsRepo.deleteAnimal(localAnimal.id); // Soft delete local

      await queueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: localAnimal.id,
        action: SyncAction.delete,
        farmId: testFarmId,
        userId: testUserId,
      );

      final result = await syncEngine.syncPendingOperations(
        farmId: testFarmId,
        userId: testUserId,
      );

      expect(result.isSuccess, isTrue);
      expect(fakeClient.softDeletedAnimals.length, 1);
      expect(fakeClient.softDeletedAnimals.first['remoteId'],
          'uuid-animal-del-99');

      // L'enregistrement existe toujours localement (avec deletedAt et synced)
      final deletedLocally = await animalsRepo.getAnimalById(
        'animal_to_delete',
        includeDeleted: true,
      );
      expect(deletedLocally, isNotNull);
      expect(deletedLocally!.deletedAt, isNotNull);
      expect(deletedLocally.syncStatus, SyncStatus.synced);
    });

    // ─── 5. Tentatives non autorisées d'un utilisateur worker ────────────────
    test('5. Worker role cannot delete animal or update/delete expense',
        () async {
      // Définir le rôle distant en worker
      fakeClient.setMemberRole(
        farmId: testFarmId,
        userId: 'worker_user_id',
        role: 'worker',
      );

      final localAnimal = Animal(
        id: 'animal_worker_test',
        farmId: testFarmId,
        remoteId: 'uuid-animal-worker-1',
        syncStatus: SyncStatus.synced,
        name: 'Animal Worker',
        type: AnimalType.bovin,
        ageMonths: 18,
        weightKg: 200.0,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime(2026, 5, 1),
      );
      await animalsRepo.addAnimal(localAnimal);

      // Le worker tente une suppression d'animal
      await queueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: localAnimal.id,
        action: SyncAction.delete,
        farmId: testFarmId,
        userId: 'worker_user_id',
      );

      final result = await syncEngine.syncPendingOperations(
        farmId: testFarmId,
        userId: 'worker_user_id',
      );

      expect(result.isSuccess, isFalse);
      expect(result.failureCount, 1);
      expect(fakeClient.softDeletedAnimals.isEmpty, isTrue); // Action bloquée !
      expect(result.errors.first,
          contains('Permission refusée: un ouvrier ne peut pas supprimer'));
    });

    // ─── 6. Reprise après une erreur réseau ──────────────────────────────────
    test('6. Network error preserves operation and recovers on retry',
        () async {
      final localAnimal = Animal(
        id: 'animal_retry_test',
        farmId: testFarmId,
        name: 'Retry Animal',
        type: AnimalType.volaille,
        ageMonths: 5,
        weightKg: 2.5,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime(2026, 9, 1),
      );
      await animalsRepo.addAnimal(localAnimal);

      await queueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: localAnimal.id,
        action: SyncAction.create,
        farmId: testFarmId,
        userId: testUserId,
      );

      // Simuler une coupure réseau
      fakeClient.shouldThrowOnUpsertAnimal = true;
      fakeClient.errorToThrow = 'Connexion réseau perdue (SocketException)';

      final failedResult = await syncEngine.syncPendingOperations(
        farmId: testFarmId,
        userId: testUserId,
      );

      expect(failedResult.isSuccess, isFalse);
      expect(failedResult.failureCount, 1);

      // L'opération est conservée en erreur dans la file avec incrément de retryCount
      final pendingAfterError = await queueService.getPendingOperations(
        farmId: testFarmId,
        userId: testUserId,
      );
      expect(pendingAfterError.length, 1);
      expect(pendingAfterError.first.retryCount, 1);
      expect(pendingAfterError.first.status, SyncOperationStatus.error);

      // Rétablissement du réseau et nouvelle tentative
      fakeClient.shouldThrowOnUpsertAnimal = false;

      final successResult = await syncEngine.syncPendingOperations(
        farmId: testFarmId,
        userId: testUserId,
      );

      expect(successResult.isSuccess, isTrue);
      expect(successResult.successCount, 1);

      // L'opération a été retirée de la file avec succès
      final pendingAfterSuccess = await queueService.getPendingOperations(
        farmId: testFarmId,
        userId: testUserId,
      );
      expect(pendingAfterSuccess.isEmpty, isTrue);
    });

    // ─── 7. Nouvelles tentatives sans doublons (idempotence) ─────────────────
    test(
        '7. Repeated sync attempts use onConflict and do not create duplicates',
        () async {
      final localAnimal = Animal(
        id: 'animal_idempotent_1',
        farmId: testFarmId,
        name: 'Idempotent Animal',
        type: AnimalType.bovin,
        ageMonths: 30,
        weightKg: 350.0,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime(2026, 8, 1),
      );
      await animalsRepo.addAnimal(localAnimal);

      await queueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: localAnimal.id,
        action: SyncAction.create,
        farmId: testFarmId,
        userId: testUserId,
      );

      // Première synchronisation
      await syncEngine.syncPendingOperations(
        farmId: testFarmId,
        userId: testUserId,
      );

      final animalAfterSync =
          await animalsRepo.getAnimalById('animal_idempotent_1');
      final firstRemoteId = animalAfterSync!.remoteId;
      expect(firstRemoteId, isNotNull);

      // Ajout d'une mise à jour locale
      await queueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: localAnimal.id,
        action: SyncAction.update,
        farmId: testFarmId,
        userId: testUserId,
      );

      // Deuxième synchronisation
      await syncEngine.syncPendingOperations(
        farmId: testFarmId,
        userId: testUserId,
      );

      // La charge utile de la mise à jour transmet bien l'id distant existant
      expect(fakeClient.upsertedAnimals.length, 2);
      expect(fakeClient.upsertedAnimals[1]['id'], firstRemoteId);
      expect(fakeClient.upsertedAnimals[1]['local_id'], 'animal_idempotent_1');
    });

    // ─── 8. Changement d'utilisateur pendant opérations en attente ───────────
    test(
        '8. Changing user isolates operations and rejects unauthorized execution',
        () async {
      await queueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'animal_user_a',
        action: SyncAction.create,
        farmId: testFarmId,
        userId: 'user_A',
      );

      // Tentative de synchronisation par user_B qui n'a pas d'adhésion
      final resultUnauth = await syncEngine.syncPendingOperations(
        farmId: testFarmId,
        userId: 'user_B_no_membership',
      );

      expect(resultUnauth.hasFatalError, isTrue);
      expect(resultUnauth.fatalErrorMessage, contains('Accès refusé'));

      // Les opérations de user_A sont préservées intactes
      final pendingOps =
          await queueService.getPendingOperations(farmId: testFarmId);
      expect(pendingOps.length, 1);
      expect(pendingOps.first.userId, 'user_A');
    });

    // ─── 9. Exclusion des données de démonstration ───────────────────────────
    test('9. Demo data are strictly excluded from network sync', () async {
      // Tentative d'enqueue ou de synchronisation d'un animal démo officiel 'a001'
      final op = await queueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'a001',
        action: SyncAction.create,
        farmId: testFarmId,
        userId: testUserId,
      );

      // SyncQueueService refuse immédiatement l'enqueue
      expect(op, isNull);

      final result = await syncEngine.syncPendingOperations(
        farmId: testFarmId,
        userId: testUserId,
      );

      expect(result.processedOperations, 0);
      expect(fakeClient.upsertedAnimals.isEmpty, isTrue);
    });

    // ─── 10. Absence d'import automatique ────────────────────────────────────
    test(
        '10. Existing local animals are NOT automatically imported without queue ops',
        () async {
      // Ajout de 5 animaux locaux dans Sembast sans opération dans la queue
      for (int i = 1; i <= 5; i++) {
        await animalsRepo.addAnimal(Animal(
          id: 'unimported_animal_$i',
          farmId: testFarmId,
          name: 'Animal $i',
          type: AnimalType.bovin,
          ageMonths: 10,
          weightKg: 150.0,
          healthStatus: HealthStatus.sain,
          expenses: const [],
          createdAt: DateTime(2026, 1, 1),
        ));
      }

      final result = await syncEngine.syncPendingOperations(
        farmId: testFarmId,
        userId: testUserId,
      );

      expect(result.processedOperations, 0);
      expect(fakeClient.upsertedAnimals.isEmpty,
          isTrue); // Zéro import automatique !
    });

    // ─── 11. Séparation stricte des données entre fermes ─────────────────────
    test(
        '11. Strict tenant isolation: syncing farm-A does not touch farm-B operations',
        () async {
      const farmA = 'farm-uuid-alpha';
      const farmB = 'farm-uuid-beta';

      fakeClient.setMemberRole(
          farmId: farmA, userId: testUserId, role: 'manager');
      fakeClient.setMemberRole(
          farmId: farmB, userId: testUserId, role: 'manager');

      await animalsRepo.addAnimal(Animal(
        id: 'animal_farm_a',
        farmId: farmA,
        name: 'Animal Farm A',
        type: AnimalType.bovin,
        ageMonths: 20,
        weightKg: 300.0,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime(2026, 2, 1),
      ));

      await animalsRepo.addAnimal(Animal(
        id: 'animal_farm_b',
        farmId: farmB,
        name: 'Animal Farm B',
        type: AnimalType.caprin,
        ageMonths: 15,
        weightKg: 40.0,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime(2026, 3, 1),
      ));

      await queueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'animal_farm_a',
        action: SyncAction.create,
        farmId: farmA,
        userId: testUserId,
      );

      await queueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'animal_farm_b',
        action: SyncAction.create,
        farmId: farmB,
        userId: testUserId,
      );

      // Synchronisation de Farm A uniquement
      final resultA = await syncEngine.syncPendingOperations(
        farmId: farmA,
        userId: testUserId,
      );

      expect(resultA.successCount, 1);
      expect(fakeClient.upsertedAnimals.length, 1);
      expect(fakeClient.upsertedAnimals.first['farm_id'], farmA);

      // L'opération de Farm B reste intacte dans la file
      final pendingFarmB = await queueService.getPendingOperations(
        farmId: farmB,
        userId: testUserId,
      );
      expect(pendingFarmB.length, 1);
      expect(pendingFarmB.first.localId, 'animal_farm_b');
    });

    // ─── 12. Ordre strict : les animaux sont synchronisés avant leurs dépenses
    test('12. Animals are always synced before expenses in the same cycle',
        () async {
      // On enregistre l'ordre des appels
      fakeClient.upsertedAnimals.clear();
      fakeClient.upsertedExpenses.clear();

      final localAnimal = Animal(
        id: 'animal_order_test',
        farmId: testFarmId,
        name: 'Animal Order',
        type: AnimalType.bovin,
        ageMonths: 24,
        weightKg: 310.0,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime(2026, 10, 1),
      );
      await animalsRepo.addAnimal(localAnimal);

      final exp = await animalsRepo.addExpense(
        localAnimal.id,
        Expense(
          id: 'exp_order_test',
          farmId: testFarmId,
          animalId: localAnimal.id,
          label: 'Foin',
          amount: 4000,
          date: DateTime(2026, 10, 2),
          category: ExpenseCategory.alimentation,
        ),
      );

      // Même si l'opération dépense est enqueued AVANT l'animal :
      // On insère l'opération dépense d'abord
      await queueService.enqueue(
        entityType: SyncEntityType.expense,
        localId: exp.id,
        action: SyncAction.create,
        farmId: testFarmId,
        userId: testUserId,
        payload: {'animalId': localAnimal.id},
      );

      // Puis l'opération animal
      await queueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: localAnimal.id,
        action: SyncAction.create,
        farmId: testFarmId,
        userId: testUserId,
      );

      final result = await syncEngine.syncPendingOperations(
        farmId: testFarmId,
        userId: testUserId,
      );

      expect(result.isSuccess, isTrue);
      expect(result.successCount, 2);

      // L'animal a été envoyé et a reçu un remoteId
      expect(fakeClient.upsertedAnimals.length, 1);
      expect(fakeClient.upsertedExpenses.length, 1);

      // La dépense a bien reçu l'identifiant distant de son animal généré durant ce même cycle !
      final animalRemoteId = fakeClient.upsertedAnimals.first['id'] ??
          (await animalsRepo.getAnimalById('animal_order_test'))!.remoteId;
      expect(fakeClient.upsertedExpenses.first['animal_id'], animalRemoteId);
    });

    // ─── 13. Détection et enregistrement d'un conflit optimiste sur un animal ─
    test(
        '13. Animal optimistic concurrency conflict records in conflicts store and dequeues operation',
        () async {
      final localAnimal = Animal(
        id: 'animal_conflict_1',
        farmId: testFarmId,
        remoteId: 'remote-uuid-conflict-1',
        versionId: 1,
        syncStatus: SyncStatus.pendingUpdate,
        name: 'Taureau Alpha Local',
        type: AnimalType.bovin,
        ageMonths: 36,
        weightKg: 500.0,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime(2026, 1, 1),
      );
      await animalsRepo.addAnimal(localAnimal);

      await queueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: localAnimal.id,
        action: SyncAction.update,
        farmId: testFarmId,
        userId: testUserId,
      );

      // Simuler que le serveur renvoie un conflit (version_id = 3 sur le serveur, expected = 1)
      fakeClient.nextAnimalPushResult = const SyncPushResult.conflict(
        remoteId: 'remote-uuid-conflict-1',
        serverVersion: 3,
        expectedVersion: 1,
        serverData: {
          'id': 'remote-uuid-conflict-1',
          'farm_id': testFarmId,
          'name': 'Taureau Alpha Serveur',
          'version_id': 3,
        },
      );

      final result = await syncEngine.syncPendingOperations(
        farmId: testFarmId,
        userId: testUserId,
      );

      expect(result.hasConflicts, isTrue);
      expect(result.conflictsCount, 1);
      expect(result.successCount, 0);

      // L'opération a été retirée de la file pour ne pas bloquer les cycles ultérieurs
      final remainingOps = await queueService.getPendingOperations(
        farmId: testFarmId,
        userId: testUserId,
      );
      expect(remainingOps.isEmpty, isTrue);

      // L'animal local a son statut mis à jour à 'error'
      final reloadedAnimal =
          await animalsRepo.getAnimalById('animal_conflict_1');
      expect(reloadedAnimal, isNotNull);
      expect(reloadedAnimal!.syncStatus, SyncStatus.error);
      expect(reloadedAnimal.name, 'Taureau Alpha Local'); // Donnée locale non écrasée !

      // Le conflit est dûment persisté dans le store Sembast 'conflicts'
      final conflicts = await animalsRepo.getConflicts(farmId: testFarmId);
      expect(conflicts.length, 1);
      final c = conflicts.first;
      expect(c.entityType, SyncEntityType.animal);
      expect(c.localId, 'animal_conflict_1');
      expect(c.expectedVersion, 1);
      expect(c.serverVersion, 3);
      expect(c.serverData?['name'], 'Taureau Alpha Serveur');
      expect(c.resolved, isFalse);
    });

    // ─── 14. Conflit sur une dépense sans bloquer les opérations suivantes ───
    test(
        '14. Expense conflict records in store and does not block other operations',
        () async {
      final hostAnimal = Animal(
        id: 'animal_host_14',
        farmId: testFarmId,
        remoteId: 'remote-uuid-host-14',
        versionId: 2,
        syncStatus: SyncStatus.synced,
        name: 'Vache Hôte',
        type: AnimalType.bovin,
        ageMonths: 24,
        weightKg: 320.0,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime(2026, 1, 1),
      );
      await animalsRepo.addAnimal(hostAnimal);

      // Dépense 1 : aura un conflit
      final expConflict = await animalsRepo.addExpense(
        hostAnimal.id,
        Expense(
          id: 'exp_conflicted',
          farmId: testFarmId,
          animalId: hostAnimal.id,
          remoteId: 'remote-exp-conflicted-id',
          versionId: 1,
          label: 'Soin Local',
          amount: 15000,
          date: DateTime(2026, 10, 1),
          category: ExpenseCategory.sante,
          syncStatus: SyncStatus.pendingUpdate,
        ),
      );

      // Dépense 2 : sera créée avec succès
      final expSuccess = await animalsRepo.addExpense(
        hostAnimal.id,
        Expense(
          id: 'exp_success',
          farmId: testFarmId,
          animalId: hostAnimal.id,
          label: 'Nourriture',
          amount: 25000,
          date: DateTime(2026, 10, 2),
          category: ExpenseCategory.alimentation,
          syncStatus: SyncStatus.pendingCreate,
        ),
      );

      await queueService.enqueue(
        entityType: SyncEntityType.expense,
        localId: expConflict.id,
        action: SyncAction.update,
        farmId: testFarmId,
        userId: testUserId,
        payload: {'animalId': hostAnimal.id},
      );

      await queueService.enqueue(
        entityType: SyncEntityType.expense,
        localId: expSuccess.id,
        action: SyncAction.create,
        farmId: testFarmId,
        userId: testUserId,
        payload: {'animalId': hostAnimal.id},
      );

      // Simuler le conflit pour la première dépense
      fakeClient.nextExpensePushResult = const SyncPushResult.conflict(
        remoteId: 'remote-exp-conflicted-id',
        serverVersion: 2,
        expectedVersion: 1,
        serverData: {
          'id': 'remote-exp-conflicted-id',
          'amount': 18000,
          'version_id': 2,
        },
      );

      final result = await syncEngine.syncPendingOperations(
        farmId: testFarmId,
        userId: testUserId,
      );

      // 1 succès (exp_success) et 1 conflit (exp_conflicted)
      expect(result.conflictsCount, 1);
      expect(result.successCount, 1);

      // La file d'attente est désormais vide car l'une a réussi et l'autre a été retirée pour conflit
      final remainingOps = await queueService.getPendingOperations(
        farmId: testFarmId,
        userId: testUserId,
      );
      expect(remainingOps.isEmpty, isTrue);

      // La dépense en succès est marquée 'synced'
      final reloadedHost = await animalsRepo.getAnimalById(hostAnimal.id);
      final okExp =
          reloadedHost!.expenses.firstWhere((e) => e.id == 'exp_success');
      expect(okExp.syncStatus, SyncStatus.synced);

      // La dépense en conflit est marquée 'error'
      final badExp =
          reloadedHost.expenses.firstWhere((e) => e.id == 'exp_conflicted');
      expect(badExp.syncStatus, SyncStatus.error);

      // Conflit enregistré
      final recordedConflicts =
          await animalsRepo.getConflicts(farmId: testFarmId);
      expect(recordedConflicts.length, 1);
      expect(recordedConflicts.first.entityType, SyncEntityType.expense);
      expect(recordedConflicts.first.localId, 'exp_conflicted');
      expect(recordedConflicts.first.serverVersion, 2);
    });

    // ─── 15. Erreur réseau transitoire ≠ conflit (opération préservée) ────────
    test(
        '15. Network error does not record a conflict and preserves operation for retry',
        () async {
      final localAnimal = Animal(
        id: 'animal_net_err',
        farmId: testFarmId,
        remoteId: 'remote-uuid-net-1',
        versionId: 1,
        syncStatus: SyncStatus.pendingUpdate,
        name: 'Bovin Réseau',
        type: AnimalType.bovin,
        ageMonths: 18,
        weightKg: 200.0,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime(2026, 1, 1),
      );
      await animalsRepo.addAnimal(localAnimal);

      await queueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: localAnimal.id,
        action: SyncAction.update,
        farmId: testFarmId,
        userId: testUserId,
      );

      fakeClient.shouldThrowOnUpsertAnimal = true;
      fakeClient.errorToThrow = 'Erreur HTTP 503 Service Unavailable';

      final result = await syncEngine.syncPendingOperations(
        farmId: testFarmId,
        userId: testUserId,
      );

      expect(result.isSuccess, isFalse);
      expect(result.conflictsCount, 0); // Strictement aucun conflit !
      expect(result.failureCount, 1);

      // L'opération reste dans la file pour le prochain rejeu
      final remainingOps = await queueService.getPendingOperations(
        farmId: testFarmId,
        userId: testUserId,
      );
      expect(remainingOps.length, 1);
      expect(remainingOps.first.retryCount, 1);

      // Aucun enregistrement dans le store 'conflicts'
      final conflicts = await animalsRepo.getConflicts(farmId: testFarmId);
      expect(conflicts.isEmpty, isTrue);
    });
  });
}
