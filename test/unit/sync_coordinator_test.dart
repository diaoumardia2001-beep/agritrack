// test/unit/sync_coordinator_test.dart
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:agritrack/data/animals_repository.dart';
import 'package:agritrack/data/database/database_migrator.dart';
import 'package:agritrack/models/animal.dart';
import 'package:agritrack/models/expense.dart';
import 'package:agritrack/models/farm.dart';
import 'package:agritrack/models/sync_queue_operation.dart';
import 'package:agritrack/models/user_farm_membership.dart';
import 'package:agritrack/models/user_profile.dart';
import 'package:agritrack/providers/active_farm_provider.dart';
import 'package:agritrack/providers/animals_provider.dart';
import 'package:agritrack/providers/auth_provider.dart';
import 'package:agritrack/providers/sync_provider.dart';
import 'package:agritrack/services/sync/connectivity_service.dart';
import 'package:agritrack/services/sync/supabase_sync_client.dart';
import 'package:agritrack/services/sync/sync_engine.dart';
import 'package:agritrack/services/sync/sync_queue_service.dart';

class FakeFarmService implements IFarmService {
  final Map<String, List<UserFarmMembership>> userMemberships;

  FakeFarmService({this.userMemberships = const {}});

  @override
  Future<List<UserFarmMembership>> fetchUserFarms(String userId) async {
    return userMemberships[userId] ?? const [];
  }

  @override
  Future<Farm> createRemoteFarm({
    required String name,
    String? region,
    bool isDemo = false,
  }) async {
    return Farm(
      id: 'farm_created_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      region: region,
      isDemo: isDemo,
      createdAt: DateTime.now(),
    );
  }
}

class FakeSupabaseSyncClient implements ISupabaseSyncClient {
  final List<Map<String, dynamic>> upsertedAnimals = [];
  final List<Map<String, dynamic>> softDeletedAnimals = [];
  final List<Map<String, dynamic>> upsertedExpenses = [];
  final List<Map<String, dynamic>> softDeletedExpenses = [];
  final Map<String, String> memberRoles = {};

  bool shouldThrowOnUpsertAnimal = false;
  bool shouldThrowOnUpsertExpense = false;
  bool shouldThrowOnSoftDelete = false;
  bool shouldThrowNetworkError = false;
  Completer<void>? delayCompleter;
  int syncCallCount = 0;

  void setMemberRole({
    required String farmId,
    required String userId,
    required String role,
  }) {
    memberRoles['$farmId:$userId'] = role;
  }

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
    syncCallCount++;
    if (delayCompleter != null) {
      await delayCompleter!.future;
    }
    if (shouldThrowNetworkError || shouldThrowOnUpsertAnimal) {
      throw Exception('Simulation: Erreur de connexion réseau (pushAnimalRpc)');
    }
    final effectiveRemoteId = remoteId ?? 'remote_anim_${upsertedAnimals.length + 1}';
    final payload = {
      'id': effectiveRemoteId,
      'farm_id': farmId,
      'local_id': localId,
      'name': name,
      'type': type,
      'age_months': ageMonths,
      'weight_kg': weightKg,
      'health_status': healthStatus,
      'image_url': imageUrl,
      'deleted_at': deletedAt?.toIso8601String(),
    };
    if (action == 'delete') {
      softDeletedAnimals.add({
        ...payload,
        'remoteId': effectiveRemoteId,
        'farmId': farmId,
      });
    } else {
      upsertedAnimals.add(payload);
    }
    return SyncPushResult.success(
      remoteId: effectiveRemoteId,
      versionId: (expectedVersion ?? 1) + (action == 'create' ? 0 : 1),
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
    if (shouldThrowNetworkError || shouldThrowOnUpsertExpense) {
      throw Exception('Simulation: Erreur réseau (pushExpenseRpc)');
    }
    final effectiveRemoteId =
        remoteId ?? 'remote_exp_${upsertedExpenses.length + 1}';
    final payload = {
      'id': effectiveRemoteId,
      'remoteId': effectiveRemoteId,
      'farm_id': farmId,
      'farmId': farmId,
      'local_id': localId,
      'animal_id': animalId,
      'label': label,
      'amount': amount,
      'date': date?.toIso8601String(),
      'category': category,
      'deleted_at': deletedAt?.toIso8601String(),
    };
    if (action == 'delete') {
      softDeletedExpenses.add(payload);
    } else {
      upsertedExpenses.add(payload);
    }
    return SyncPushResult.success(
      remoteId: effectiveRemoteId,
      versionId: (expectedVersion ?? 1) + (action == 'create' ? 0 : 1),
    );
  }

  @override
  Future<String> upsertAnimal(Map<String, dynamic> animalPayload) async {
    syncCallCount++;
    if (delayCompleter != null) {
      await delayCompleter!.future;
    }
    if (shouldThrowNetworkError || shouldThrowOnUpsertAnimal) {
      throw Exception('Simulation: Erreur de connexion réseau (upsertAnimal)');
    }
    upsertedAnimals.add(Map<String, dynamic>.from(animalPayload));
    return animalPayload['id'] ?? 'remote_anim_${upsertedAnimals.length}';
  }

  @override
  Future<void> softDeleteAnimal({
    required String remoteId,
    required String farmId,
    required DateTime deletedAt,
  }) async {
    if (shouldThrowNetworkError || shouldThrowOnSoftDelete) {
      throw Exception('Simulation: Erreur réseau (softDeleteAnimal)');
    }
    softDeletedAnimals.add({
      'remoteId': remoteId,
      'farmId': farmId,
      'deletedAt': deletedAt,
    });
  }

  @override
  Future<String> upsertExpense(Map<String, dynamic> expensePayload) async {
    if (shouldThrowNetworkError || shouldThrowOnUpsertExpense) {
      throw Exception('Simulation: Erreur réseau (upsertExpense)');
    }
    upsertedExpenses.add(Map<String, dynamic>.from(expensePayload));
    return expensePayload['id'] ?? 'remote_exp_${upsertedExpenses.length}';
  }

  @override
  Future<void> softDeleteExpense({
    required String remoteId,
    required String farmId,
    required DateTime deletedAt,
  }) async {
    if (shouldThrowNetworkError || shouldThrowOnSoftDelete) {
      throw Exception('Simulation: Erreur réseau (softDeleteExpense)');
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

  @override
  Future<List<Map<String, dynamic>>> fetchAnimals({
    required String farmId,
    DateTime? since,
    String? lastId,
    int limit = 100,
  }) async {
    if (shouldThrowNetworkError) {
      throw Exception('Simulation: Erreur réseau (fetchAnimals)');
    }
    return animalsToFetch.where((a) => a['farm_id'] == farmId).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchExpenses({
    required String farmId,
    DateTime? since,
    String? lastId,
    int limit = 100,
  }) async {
    if (shouldThrowNetworkError) {
      throw Exception('Simulation: Erreur réseau (fetchExpenses)');
    }
    return expensesToFetch.where((e) => e['farm_id'] == farmId).toList();
  }
}

void main() {
  group('SyncCoordinator (Automatic Trigger & Outbox Recovery Tests)', () {
    late Database testDb;
    late AnimalsRepository repository;
    late SyncQueueService syncQueueService;
    late FakeSupabaseSyncClient syncClient;
    late SyncEngine syncEngine;
    late FakeConnectivityService connectivityService;
    late ProviderContainer container;

    const testUserId = 'usr_auto_sync_1';
    final testUser = User(
      id: testUserId,
      appMetadata: const {},
      userMetadata: const {'full_name': 'Kouassi Yves'},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: 'kouassi@agritrack.ci',
    );

    final remoteFarm = Farm(
      id: 'farm_cloud_bouake',
      name: 'Ferme de Bouaké',
      region: 'Bouaké',
      isDemo: false,
      createdAt: DateTime(2026, 6, 1),
    );

    setUp(() async {
      final memoryFactory = newDatabaseFactoryMemory();
      testDb = await memoryFactory.openDatabase(
        'test_sync_coordinator_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      await DatabaseMigrator.migrate(testDb);

      repository = AnimalsRepository(
        database: Future.value(testDb),
        autoSeed: false,
      );

      syncQueueService = SyncQueueService(database: Future.value(testDb));
      syncClient = FakeSupabaseSyncClient();
      syncClient.setMemberRole(
        farmId: remoteFarm.id,
        userId: testUserId,
        role: 'owner',
      );

      syncEngine = SyncEngine(
        syncClient: syncClient,
        queueService: syncQueueService,
        animalsRepository: repository,
      );

      connectivityService = FakeConnectivityService(initialOnline: false);

      container = ProviderContainer(
        overrides: [
          animalsRepositoryProvider.overrideWithValue(repository),
          syncQueueServiceProvider.overrideWithValue(syncQueueService),
          supabaseSyncClientProvider.overrideWithValue(syncClient),
          syncEngineProvider.overrideWithValue(syncEngine),
          connectivityServiceProvider.overrideWithValue(connectivityService),
          farmServiceProvider.overrideWithValue(
            FakeFarmService(
              userMemberships: {
                testUserId: [
                  UserFarmMembership(farm: remoteFarm, role: UserRole.owner),
                ],
              },
            ),
          ),
          authProvider.overrideWith((ref) {
            return AuthNotifier(
              ref.read(authServiceProvider),
            )..state = AppAuthState.authenticated(
                user: testUser,
                profile: UserProfile(
                  id: testUserId,
                  email: 'kouassi@agritrack.ci',
                  fullName: 'Kouassi Yves',
                  createdAt: DateTime(2026, 1, 1),
                ),
              );
          }),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      connectivityService.dispose();
      await testDb.close();
    });

    // ─── 1. Détection du retour réseau ───────────────────────────────────────
    test('1. Connectivity restoration triggers sync for active remote farm',
        () async {
      final coordinator = container.read(syncCoordinatorProvider.notifier);

      container
          .read(activeFarmProvider.notifier)
          .selectFarm(remoteFarm, role: UserRole.owner);

      // Enfiler une opération locale en attente
      await syncQueueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'anim_bouake_01',
        action: SyncAction.create,
        farmId: remoteFarm.id,
        userId: testUserId,
      );

      await repository.addAnimal(
        Animal(
          id: 'anim_bouake_01',
          name: 'Vache Bouaké 1',
          type: AnimalType.bovin,
          ageMonths: 20,
          weightKg: 350.0,
          healthStatus: HealthStatus.sain,
          farmId: remoteFarm.id,
          syncStatus: SyncStatus.pendingCreate,
          expenses: const [],
          createdAt: DateTime.now(),
        ),
        targetFarmId: remoteFarm.id,
      );

      expect(syncClient.upsertedAnimals, isEmpty);

      // Simuler le passage du statut réseau de hors-ligne à en ligne
      connectivityService.emit(true);

      // Attendre la résolution de l'événement stream et la complétion de la synchronisation
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (coordinator.currentSyncFuture != null) {
        await coordinator.currentSyncFuture;
      }

      expect(syncClient.upsertedAnimals.length, 1);
      expect(syncClient.upsertedAnimals.first['local_id'], 'anim_bouake_01');

      final pendingAfter =
          await syncQueueService.getPendingOperations(farmId: remoteFarm.id);
      expect(pendingAfter, isEmpty);
    });

    // ─── 2. Retour de l'application au premier plan (AppLifecycleState.resumed)
    test('2. App returning to foreground triggers sync for active remote farm',
        () async {
      final coordinator = container.read(syncCoordinatorProvider.notifier);

      container
          .read(activeFarmProvider.notifier)
          .selectFarm(remoteFarm, role: UserRole.owner);

      await syncQueueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'anim_bouake_02',
        action: SyncAction.create,
        farmId: remoteFarm.id,
        userId: testUserId,
      );

      await repository.addAnimal(
        Animal(
          id: 'anim_bouake_02',
          name: 'Vache Bouaké 2',
          type: AnimalType.bovin,
          ageMonths: 22,
          weightKg: 370.0,
          healthStatus: HealthStatus.sain,
          farmId: remoteFarm.id,
          syncStatus: SyncStatus.pendingCreate,
          expenses: const [],
          createdAt: DateTime.now(),
        ),
        targetFarmId: remoteFarm.id,
      );

      expect(syncClient.upsertedAnimals, isEmpty);

      // Simuler le retour au premier plan
      coordinator.didChangeAppLifecycleState(AppLifecycleState.resumed);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (coordinator.currentSyncFuture != null) {
        await coordinator.currentSyncFuture;
      }

      expect(syncClient.upsertedAnimals.length, 1);
      expect(syncClient.upsertedAnimals.first['local_id'], 'anim_bouake_02');
    });

    // ─── 3. Verrou anti-concurrence : pas de synchronisations simultanées ────
    test('3. Concurrent sync calls on the same farm are blocked by mutex',
        () async {
      final coordinator = container.read(syncCoordinatorProvider.notifier);

      container
          .read(activeFarmProvider.notifier)
          .selectFarm(remoteFarm, role: UserRole.owner);

      await syncQueueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'anim_bouake_03',
        action: SyncAction.create,
        farmId: remoteFarm.id,
        userId: testUserId,
      );

      await repository.addAnimal(
        Animal(
          id: 'anim_bouake_03',
          name: 'Vache Bouaké 3',
          type: AnimalType.bovin,
          ageMonths: 25,
          weightKg: 390.0,
          healthStatus: HealthStatus.sain,
          farmId: remoteFarm.id,
          syncStatus: SyncStatus.pendingCreate,
          expenses: const [],
          createdAt: DateTime.now(),
        ),
        targetFarmId: remoteFarm.id,
      );

      // Simuler une synchronisation lente pour tester la concurrence
      final delay = Completer<void>();
      syncClient.delayCompleter = delay;

      // Lancer la 1ère synchronisation
      final firstFuture = coordinator.syncActiveFarm(triggerReason: 'call_1');

      // Attendre un tick que le verrou soit activé
      await Future<void>.delayed(Duration.zero);
      expect(coordinator.isSyncingFarm(remoteFarm.id), isTrue);

      // Lancer une 2nde synchronisation concurrente pendant que la 1ère est bloquée
      final secondResult = await coordinator.syncActiveFarm(triggerReason: 'call_2');

      // Le 2ème appel doit avoir été immédiatement rejeté/ignoré sans exécuter le moteur
      expect(secondResult.processedOperations, 0);

      // Libérer la 1ère synchronisation
      delay.complete();
      final firstResult = await firstFuture;

      expect(firstResult.successCount, 1);
      expect(coordinator.isSyncingFarm(remoteFarm.id), isFalse);
      expect(syncClient.syncCallCount, 1,
          reason: 'Le moteur ne doit avoir été invoqué qu\'une seule fois.');
    });

    // ─── 4. Échec réseau et reprise ultérieure ──────────────────────────────
    test('4. Network failure keeps operations in sync_queue and retries successfully',
        () async {
      final coordinator = container.read(syncCoordinatorProvider.notifier);

      container
          .read(activeFarmProvider.notifier)
          .selectFarm(remoteFarm, role: UserRole.owner);

      await syncQueueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'anim_bouake_04',
        action: SyncAction.create,
        farmId: remoteFarm.id,
        userId: testUserId,
      );

      await repository.addAnimal(
        Animal(
          id: 'anim_bouake_04',
          name: 'Taureau Bouaké',
          type: AnimalType.bovin,
          ageMonths: 30,
          weightKg: 500.0,
          healthStatus: HealthStatus.sain,
          farmId: remoteFarm.id,
          syncStatus: SyncStatus.pendingCreate,
          expenses: const [],
          createdAt: DateTime.now(),
        ),
        targetFarmId: remoteFarm.id,
      );

      // 1. Simuler une erreur réseau
      syncClient.shouldThrowNetworkError = true;
      final failResult = await coordinator.syncActiveFarm(triggerReason: 'test_fail');
      expect(failResult.failureCount, 1);

      // L'opération DOIT rester dans sync_queue avec statut error
      var pending =
          await syncQueueService.getPendingOperations(farmId: remoteFarm.id);
      expect(pending.length, 1);
      expect(pending.first.status, SyncOperationStatus.error);

      // 2. Rétablissement du réseau et nouvelle tentative
      syncClient.shouldThrowNetworkError = false;
      final successResult =
          await coordinator.syncActiveFarm(triggerReason: 'test_retry');
      expect(successResult.successCount, 1);

      // L'opération est maintenant vidée de la file
      pending =
          await syncQueueService.getPendingOperations(farmId: remoteFarm.id);
      expect(pending, isEmpty);
    });

    // ─── 5. Expiration de session ───────────────────────────────────────────
    test('5. Expired or missing session safely aborts sync and preserves operations',
        () async {
      final unauthContainer = ProviderContainer(
        overrides: [
          animalsRepositoryProvider.overrideWithValue(repository),
          syncQueueServiceProvider.overrideWithValue(syncQueueService),
          supabaseSyncClientProvider.overrideWithValue(syncClient),
          syncEngineProvider.overrideWithValue(syncEngine),
          connectivityServiceProvider.overrideWithValue(connectivityService),
          // Utilisateur non connecté
          authProvider.overrideWith((ref) {
            return AuthNotifier(
              ref.read(authServiceProvider),
            )..state = const AppAuthState.unauthenticated();
          }),
        ],
      );
      addTearDown(unauthContainer.dispose);

      final coordinator = unauthContainer.read(syncCoordinatorProvider.notifier);

      // Mettre une opération dans la file
      await syncQueueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'anim_saved_op',
        action: SyncAction.create,
        farmId: remoteFarm.id,
        userId: testUserId,
      );

      final result = await coordinator.syncActiveFarm(triggerReason: 'unauth_test');
      expect(result.hasFatalError, isTrue);
      expect(result.fatalErrorMessage, contains('Session utilisateur'));

      // Les opérations dans sync_queue ne doivent ABSOLUMENT PAS être supprimées
      final pending =
          await syncQueueService.getPendingOperations(farmId: remoteFarm.id);
      expect(pending.length, 1);
      expect(pending.first.localId, 'anim_saved_op');
    });

    // ─── 6. Exclusion des démos et fermes locales ───────────────────────────
    test('6. Demo entities and local farms are strictly excluded from auto sync',
        () async {
      final coordinator = container.read(syncCoordinatorProvider.notifier);

      // Exploitation locale par défaut
      container.read(activeFarmProvider.notifier).switchToLocalFarm();

      final localResult =
          await coordinator.syncActiveFarm(triggerReason: 'local_test');
      expect(localResult.hasFatalError, isTrue);
      expect(localResult.fatalErrorMessage, contains('locale et non synchronisable'));
      expect(syncClient.upsertedAnimals, isEmpty);
    });

    // ─── 7. Récupération des opérations non mises en file (Outbox Recovery) ───
    test('7. Outbox reconciliation automatically recovers and enqueues unqueued local modifications',
        () async {
      final coordinator = container.read(syncCoordinatorProvider.notifier);

      container
          .read(activeFarmProvider.notifier)
          .selectFarm(remoteFarm, role: UserRole.owner);

      // Simuler une mutation locale enregistrée dans Sembast (ex: suite à un crash avant enqueue)
      // L'animal a syncStatus == pendingCreate, mais sync_queue est VIDE.
      await repository.addAnimal(
        Animal(
          id: 'anim_unqueued_01',
          name: 'Vache Réconciliée',
          type: AnimalType.bovin,
          ageMonths: 18,
          weightKg: 310.0,
          healthStatus: HealthStatus.sain,
          farmId: remoteFarm.id,
          syncStatus: SyncStatus.pendingCreate,
          expenses: [
            Expense(
              id: 'exp_unqueued_01',
              label: 'Vaccin Charbon',
              amount: 5000,
              date: DateTime.now(),
              category: ExpenseCategory.sante,
              farmId: remoteFarm.id,
              animalId: 'anim_unqueued_01',
              syncStatus: SyncStatus.pendingCreate,
            ),
          ],
          createdAt: DateTime.now(),
        ),
        targetFarmId: remoteFarm.id,
      );

      // Vérifier que la file est initialement vide
      var pending =
          await syncQueueService.getPendingOperations(farmId: remoteFarm.id);
      expect(pending, isEmpty);

      // Déclencher la synchronisation (qui appelle la réconciliation au préalable)
      final result =
          await coordinator.syncActiveFarm(triggerReason: 'recovery_test');

      // La réconciliation a retrouvé l'animal et sa dépense et les a synchronisés avec succès !
      expect(result.successCount, 2);
      expect(syncClient.upsertedAnimals.any((a) => a['local_id'] == 'anim_unqueued_01'), isTrue);
      expect(syncClient.upsertedExpenses.any((e) => e['local_id'] == 'exp_unqueued_01'), isTrue);

      pending =
          await syncQueueService.getPendingOperations(farmId: remoteFarm.id);
      expect(pending, isEmpty);
    });

    // ─── 8. Prévention des doublons ─────────────────────────────────────────
    test('8. Repeated reconciliation calls never duplicate pending operations',
        () async {
      await repository.addAnimal(
        Animal(
          id: 'anim_idempotent_test',
          name: 'Brebis Idempotente',
          type: AnimalType.ovin,
          ageMonths: 12,
          weightKg: 40.0,
          healthStatus: HealthStatus.sain,
          farmId: remoteFarm.id,
          syncStatus: SyncStatus.pendingCreate,
          expenses: const [],
          createdAt: DateTime.now(),
        ),
        targetFarmId: remoteFarm.id,
      );

      // 1ère réconciliation
      final count1 = await syncQueueService.reconcile(
        repository: repository,
        farmId: remoteFarm.id,
        userId: testUserId,
      );
      expect(count1, 1);

      // 2ème réconciliation immédiate : ne doit rien dupliquer
      final count2 = await syncQueueService.reconcile(
        repository: repository,
        farmId: remoteFarm.id,
        userId: testUserId,
      );
      expect(count2, 0);

      final ops =
          await syncQueueService.getPendingOperations(farmId: remoteFarm.id);
      expect(ops.length, 1);
      expect(ops.first.localId, 'anim_idempotent_test');
    });

    // ─── 9. Cohérence locale vs distante sur suppression de dépense ──────────
    test('9. Deleting a remote synced expense soft-deletes locally and remotely',
        () async {
      final coordinator = container.read(syncCoordinatorProvider.notifier);

      container
          .read(activeFarmProvider.notifier)
          .selectFarm(remoteFarm, role: UserRole.owner);

      // 1. Animal hôte avec dépense déjà synchronisée
      final hostAnimal = Animal(
        id: 'anim_host_synced',
        remoteId: 'rem_host_synced_100',
        name: 'Hôte Dépense Synced',
        type: AnimalType.bovin,
        ageMonths: 36,
        weightKg: 420.0,
        healthStatus: HealthStatus.sain,
        farmId: remoteFarm.id,
        syncStatus: SyncStatus.synced,
        expenses: [
          Expense(
            id: 'exp_synced_to_delete',
            remoteId: 'rem_exp_to_del_999',
            label: 'Aliment concentré',
            amount: 8000,
            date: DateTime.now(),
            category: ExpenseCategory.alimentation,
            farmId: remoteFarm.id,
            animalId: 'anim_host_synced',
            syncStatus: SyncStatus.synced,
          ),
        ],
        createdAt: DateTime.now(),
      );
      await repository.addAnimal(hostAnimal, targetFarmId: remoteFarm.id);

      // 2. Supprimer la dépense via AnimalsNotifier
      final deleted = await container
          .read(animalsNotifierProvider.notifier)
          .deleteExpense(
            animalId: 'anim_host_synced',
            expenseId: 'exp_synced_to_delete',
          );
      expect(deleted, isTrue);

      // 3. Vérifier la cohérence locale : activeExpenses ne contient plus la dépense
      final animalLocal =
          await repository.getAnimalById('anim_host_synced');
      expect(animalLocal!.activeExpenses.isEmpty, isTrue);
      expect(animalLocal.totalExpenses, 0.0);

      // 4. Déclencher la synchronisation
      final syncResult =
          await coordinator.syncActiveFarm(triggerReason: 'delete_expense_test');
      expect(syncResult.successCount, 1);

      // 5. Vérifier que Supabase a reçu le softDeleteExpense avec le bon remoteId
      expect(syncClient.softDeletedExpenses.length, 1);
      expect(syncClient.softDeletedExpenses.first['remoteId'], 'rem_exp_to_del_999');
      expect(syncClient.softDeletedExpenses.first['farmId'], remoteFarm.id);
    });
  });
}
