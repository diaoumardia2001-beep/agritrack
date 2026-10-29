// test/unit/animals_notifier_sync_queue_test.dart
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

class FaultySyncQueueService extends SyncQueueService {
  FaultySyncQueueService({required super.database});

  @override
  Future<SyncQueueOperation?> enqueue({
    required SyncEntityType entityType,
    required String localId,
    required SyncAction action,
    required String farmId,
    String? userId,
    bool isDemo = false,
    Map<String, dynamic>? payload,
  }) async {
    throw Exception('Simulated SyncQueue storage failure');
  }
}

void main() {
  group('AnimalsNotifier <-> SyncQueueService Integration Tests', () {
    late Database testDb;
    late AnimalsRepository repository;
    late SyncQueueService syncQueueService;
    late ProviderContainer container;

    const testUserId = 'usr_owner_abc123';
    final testUser = User(
      id: testUserId,
      appMetadata: const {},
      userMetadata: const {'full_name': 'Amadou Diallo'},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: 'amadou@agritrack.ci',
    );

    final remoteFarm = Farm(
      id: 'farm_remote_abidjan',
      name: 'Ranch d\'Abidjan',
      region: 'Abidjan',
      isDemo: false,
      createdAt: DateTime(2026, 5, 1),
    );


    setUp(() async {
      final memoryFactory = newDatabaseFactoryMemory();
      testDb = await memoryFactory.openDatabase(
        'test_sync_wiring_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      await DatabaseMigrator.migrate(testDb);

      repository = AnimalsRepository(
        database: Future.value(testDb),
        autoSeed: false,
      );

      syncQueueService = SyncQueueService(database: Future.value(testDb));

      container = ProviderContainer(
        overrides: [
          animalsRepositoryProvider.overrideWithValue(repository),
          syncQueueServiceProvider.overrideWithValue(syncQueueService),
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
                  email: 'amadou@agritrack.ci',
                  fullName: 'Amadou Diallo',
                  createdAt: DateTime(2026, 1, 1),
                ),
              );
          }),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await testDb.close();
    });

    // ─── 1. Création d'un animal admissible ──────────────────────────────────
    test('1. addAnimal on remote farm enqueues SyncAction.create in sync_queue',
        () async {
      // Activer la ferme distante en tant qu'owner
      container
          .read(activeFarmProvider.notifier)
          .selectFarm(remoteFarm, role: UserRole.owner);

      final newAnimal = Animal(
        id: 'anim_remote_001',
        name: 'Bovin Abidjan 1',
        type: AnimalType.bovin,
        ageMonths: 24,
        weightKg: 380.0,
        healthStatus: HealthStatus.sain,
        farmId: remoteFarm.id,
        expenses: const [],
        createdAt: DateTime.now(),
      );

      final created = await container
          .read(animalsNotifierProvider.notifier)
          .addAnimal(newAnimal);

      // Vérification Sembast locale
      expect(created.id, 'anim_remote_001');
      expect(created.syncStatus, SyncStatus.pendingCreate);
      final storedInSembast = await repository.getAnimalById('anim_remote_001');
      expect(storedInSembast, isNotNull);
      expect(storedInSembast!.syncStatus, SyncStatus.pendingCreate);

      // Vérification file de synchronisation
      final pendingOps = await syncQueueService.getPendingOperations(
        farmId: remoteFarm.id,
      );
      expect(pendingOps.length, 1);
      final op = pendingOps.first;
      expect(op.entityType, SyncEntityType.animal);
      expect(op.localId, 'anim_remote_001');
      expect(op.action, SyncAction.create);
      expect(op.farmId, remoteFarm.id);
      expect(op.userId, testUserId);
      expect(op.status, SyncOperationStatus.pending);
    });

    // ─── 2. Modification d'un animal admissible ──────────────────────────────
    test('2. updateAnimal on remote farm enqueues SyncAction.update', () async {
      container
          .read(activeFarmProvider.notifier)
          .selectFarm(remoteFarm, role: UserRole.owner);

      // Insérer d'abord un animal déjà existant et synchronisé
      await repository.addAnimal(
        Animal(
          id: 'anim_synced_002',
          remoteId: 'rem_anim_002',
          name: 'Vache Synced',
          type: AnimalType.bovin,
          ageMonths: 30,
          weightKg: 420.0,
          healthStatus: HealthStatus.sain,
          farmId: remoteFarm.id,
          syncStatus: SyncStatus.synced,
          expenses: const [],
          createdAt: DateTime.now(),
        ),
        targetFarmId: remoteFarm.id,
      );

      // Modification via AnimalsNotifier
      final animalToUpdate = Animal(
        id: 'anim_synced_002',
        remoteId: 'rem_anim_002',
        name: 'Vache Renommée',
        type: AnimalType.bovin,
        ageMonths: 30,
        weightKg: 435.0,
        healthStatus: HealthStatus.sain,
        farmId: remoteFarm.id,
        expenses: const [],
        createdAt: DateTime.now(),
      );

      final updated = await container
          .read(animalsNotifierProvider.notifier)
          .updateAnimal(animalToUpdate);

      expect(updated.name, 'Vache Renommée');
      expect(updated.weightKg, 435.0);
      expect(updated.syncStatus, SyncStatus.pendingUpdate);

      final pendingOps = await syncQueueService.getPendingOperations(
        farmId: remoteFarm.id,
      );
      expect(pendingOps.length, 1);
      final op = pendingOps.first;
      expect(op.entityType, SyncEntityType.animal);
      expect(op.localId, 'anim_synced_002');
      expect(op.action, SyncAction.update);
    });

    // ─── 3. Suppression logique d'un animal admissible ──────────────────────
    test('3. deleteAnimal on remote farm enqueues SyncAction.delete', () async {
      container
          .read(activeFarmProvider.notifier)
          .selectFarm(remoteFarm, role: UserRole.owner);

      await repository.addAnimal(
        Animal(
          id: 'anim_synced_003',
          remoteId: 'rem_anim_003',
          name: 'Mouton Synced',
          type: AnimalType.ovin,
          ageMonths: 18,
          weightKg: 50.0,
          healthStatus: HealthStatus.sain,
          farmId: remoteFarm.id,
          syncStatus: SyncStatus.synced,
          expenses: const [],
          createdAt: DateTime.now(),
        ),
        targetFarmId: remoteFarm.id,
      );

      final deleted = await container
          .read(animalsNotifierProvider.notifier)
          .deleteAnimal('anim_synced_003');

      expect(deleted, isTrue);

      // Vérification Sembast : supprimé logiquement, non détruit physiquement
      final sembastAnimal = await repository.getAnimalById(
        'anim_synced_003',
        includeDeleted: true,
      );
      expect(sembastAnimal, isNotNull);
      expect(sembastAnimal!.deletedAt, isNotNull);
      expect(sembastAnimal.syncStatus, SyncStatus.pendingDelete);

      // Vérification file
      final pendingOps = await syncQueueService.getPendingOperations(
        farmId: remoteFarm.id,
      );
      expect(pendingOps.length, 1);
      final op = pendingOps.first;
      expect(op.entityType, SyncEntityType.animal);
      expect(op.localId, 'anim_synced_003');
      expect(op.action, SyncAction.delete);
    });

    // ─── 4. Ajout d'une dépense admissible ──────────────────────────────────
    test('4. addExpense on remote farm enqueues expense SyncAction.create with animalId payload',
        () async {
      container
          .read(activeFarmProvider.notifier)
          .selectFarm(remoteFarm, role: UserRole.owner);

      await repository.addAnimal(
        Animal(
          id: 'anim_host_01',
          name: 'Hôte Dépense',
          type: AnimalType.caprin,
          ageMonths: 12,
          weightKg: 25.0,
          healthStatus: HealthStatus.sain,
          farmId: remoteFarm.id,
          expenses: const [],
          createdAt: DateTime.now(),
        ),
        targetFarmId: remoteFarm.id,
      );

      final createdExpense = await container
          .read(animalsNotifierProvider.notifier)
          .addExpense(
            animalId: 'anim_host_01',
            expense: Expense(
              id: 'exp_remote_001',
              label: 'Vermifuge Caprin',
              amount: 4500,
              date: DateTime.now(),
              category: ExpenseCategory.sante,
            ),
          );

      expect(createdExpense.id, 'exp_remote_001');
      expect(createdExpense.syncStatus, SyncStatus.pendingCreate);

      final pendingOps = await syncQueueService.getPendingOperations(
        farmId: remoteFarm.id,
      );
      expect(pendingOps.length, 1);
      final op = pendingOps.first;
      expect(op.entityType, SyncEntityType.expense);
      expect(op.localId, 'exp_remote_001');
      expect(op.action, SyncAction.create);
      expect(op.payload?['animalId'], 'anim_host_01');
    });

    // ─── 5. Mise à jour d'une dépense admissible ────────────────────────────
    test('5. updateExpense on remote farm enqueues SyncAction.update', () async {
      container
          .read(activeFarmProvider.notifier)
          .selectFarm(remoteFarm, role: UserRole.owner);

      await repository.addAnimal(
        Animal(
          id: 'anim_host_02',
          name: 'Hôte Dépense 2',
          type: AnimalType.caprin,
          ageMonths: 14,
          weightKg: 28.0,
          healthStatus: HealthStatus.sain,
          farmId: remoteFarm.id,
          expenses: [
            Expense(
              id: 'exp_to_edit',
              remoteId: 'rem_exp_002',
              label: 'Aliment initial',
              amount: 5000,
              date: DateTime.now(),
              category: ExpenseCategory.alimentation,
              syncStatus: SyncStatus.synced,
              farmId: remoteFarm.id,
              animalId: 'anim_host_02',
            ),
          ],
          createdAt: DateTime.now(),
        ),
        targetFarmId: remoteFarm.id,
      );

      final updatedExpense = await container
          .read(animalsNotifierProvider.notifier)
          .updateExpense(
            animalId: 'anim_host_02',
            expense: Expense(
              id: 'exp_to_edit',
              remoteId: 'rem_exp_002',
              label: 'Aliment enrichi',
              amount: 6500,
              date: DateTime.now(),
              category: ExpenseCategory.alimentation,
              syncStatus: SyncStatus.synced,
            ),
          );

      expect(updatedExpense.label, 'Aliment enrichi');
      expect(updatedExpense.amount, 6500);
      expect(updatedExpense.syncStatus, SyncStatus.pendingUpdate);

      final pendingOps = await syncQueueService.getPendingOperations(
        farmId: remoteFarm.id,
      );
      expect(pendingOps.length, 1);
      final op = pendingOps.first;
      expect(op.entityType, SyncEntityType.expense);
      expect(op.localId, 'exp_to_edit');
      expect(op.action, SyncAction.update);
      expect(op.payload?['animalId'], 'anim_host_02');
    });

    // ─── 6. Suppression d'une dépense admissible ────────────────────────────
    test('6. deleteExpense on remote farm enqueues SyncAction.delete with remoteId in payload',
        () async {
      container
          .read(activeFarmProvider.notifier)
          .selectFarm(remoteFarm, role: UserRole.owner);

      await repository.addAnimal(
        Animal(
          id: 'anim_host_03',
          name: 'Hôte Dépense 3',
          type: AnimalType.ovin,
          ageMonths: 20,
          weightKg: 52.0,
          healthStatus: HealthStatus.sain,
          farmId: remoteFarm.id,
          expenses: [
            Expense(
              id: 'exp_to_del',
              remoteId: 'rem_exp_003',
              label: 'Frais vétérinaire',
              amount: 12000,
              date: DateTime.now(),
              category: ExpenseCategory.sante,
              syncStatus: SyncStatus.synced,
              farmId: remoteFarm.id,
              animalId: 'anim_host_03',
            ),
          ],
          createdAt: DateTime.now(),
        ),
        targetFarmId: remoteFarm.id,
      );

      final deleted = await container
          .read(animalsNotifierProvider.notifier)
          .deleteExpense(animalId: 'anim_host_03', expenseId: 'exp_to_del');

      expect(deleted, isTrue);

      final pendingOps = await syncQueueService.getPendingOperations(
        farmId: remoteFarm.id,
      );
      expect(pendingOps.length, 1);
      final op = pendingOps.first;
      expect(op.entityType, SyncEntityType.expense);
      expect(op.localId, 'exp_to_del');
      expect(op.action, SyncAction.delete);
      expect(op.payload?['animalId'], 'anim_host_03');
      expect(op.payload?['remoteId'], 'rem_exp_003');
    });

    // ─── 7. Données de démonstration formellement exclues ───────────────────
    test('7. Demo animals and demo expenses are NEVER enqueued', () async {
      container
          .read(activeFarmProvider.notifier)
          .selectFarm(remoteFarm, role: UserRole.owner);

      // Animal avec isDemo = true
      final demoAnimal = Animal(
        id: 'anim_demo_flagged',
        name: 'Animal Démo Flag',
        type: AnimalType.bovin,
        ageMonths: 12,
        weightKg: 200.0,
        healthStatus: HealthStatus.sain,
        farmId: remoteFarm.id,
        isDemo: true,
        expenses: const [],
        createdAt: DateTime.now(),
      );

      await container
          .read(animalsNotifierProvider.notifier)
          .addAnimal(demoAnimal);

      // Animal avec un ID officiel de démo (a001)
      final officialDemoAnimal = Animal(
        id: 'a001',
        name: 'Bella Démo',
        type: AnimalType.bovin,
        ageMonths: 36,
        weightKg: 450.0,
        healthStatus: HealthStatus.sain,
        farmId: remoteFarm.id,
        expenses: const [],
        createdAt: DateTime.now(),
      );

      // Tenter une modification
      await repository.addAnimal(officialDemoAnimal, targetFarmId: remoteFarm.id);
      await container
          .read(animalsNotifierProvider.notifier)
          .updateAnimal(officialDemoAnimal.copyWith(name: 'Bella Modifiée'));

      // Tenter une suppression
      await container
          .read(animalsNotifierProvider.notifier)
          .deleteAnimal('a001');

      // Aucune opération ne doit avoir été mise en file
      final ops = await syncQueueService.getPendingOperations(
        farmId: remoteFarm.id,
      );
      expect(ops, isEmpty);
    });

    // ─── 8. Exploitations locales formellement exclues ────────────────────────
    test('8. Local farms (local_*) NEVER enqueue sync operations', () async {
      final localContainer = ProviderContainer(
        overrides: [
          animalsRepositoryProvider.overrideWithValue(repository),
          syncQueueServiceProvider.overrideWithValue(syncQueueService),
        ],
      );
      addTearDown(localContainer.dispose);

      final localAnimal = Animal(
        id: 'anim_strictly_local_1',
        name: 'Vache Purement Locale',
        type: AnimalType.bovin,
        ageMonths: 24,
        weightKg: 300.0,
        healthStatus: HealthStatus.sain,
        farmId: DatabaseMigrator.defaultFarmId,
        expenses: const [],
        createdAt: DateTime.now(),
      );

      await localContainer
          .read(animalsNotifierProvider.notifier)
          .addAnimal(localAnimal);

      await localContainer
          .read(animalsNotifierProvider.notifier)
          .addExpense(
            animalId: 'anim_strictly_local_1',
            expense: Expense(
              id: 'exp_local_only',
              label: 'Herbe locale',
              amount: 2000,
              date: DateTime.now(),
              category: ExpenseCategory.alimentation,
            ),
          );

      await localContainer
          .read(animalsNotifierProvider.notifier)
          .deleteAnimal('anim_strictly_local_1');

      // Aucune opération dans toute la table sync_queue
      final allOps = await syncQueueService.getPendingOperations();
      expect(allOps, isEmpty);
    });

    // ─── 9. Résilience : échec d'enfilement ne perd pas la modification locale ─
    test('9. SyncQueue failure does NOT delete or revert local Sembast modifications',
        () async {
      final faultyQueue = FaultySyncQueueService(
        database: Future.value(testDb),
      );

      final resilientContainer = ProviderContainer(
        overrides: [
          animalsRepositoryProvider.overrideWithValue(repository),
          syncQueueServiceProvider.overrideWithValue(faultyQueue),
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
              );
          }),
        ],
      );
      addTearDown(resilientContainer.dispose);

      resilientContainer
          .read(activeFarmProvider.notifier)
          .selectFarm(remoteFarm, role: UserRole.owner);

      final newAnimal = Animal(
        id: 'anim_resilience_test',
        name: 'Bovin Résilient',
        type: AnimalType.bovin,
        ageMonths: 20,
        weightKg: 340.0,
        healthStatus: HealthStatus.sain,
        farmId: remoteFarm.id,
        expenses: const [],
        createdAt: DateTime.now(),
      );

      // Ne doit pas lever d'exception non gérée vers l'UI
      final created = await resilientContainer
          .read(animalsNotifierProvider.notifier)
          .addAnimal(newAnimal);

      expect(created.id, 'anim_resilience_test');

      // Les données sont bel et bien conservées dans Sembast !
      final persisted =
          await repository.getAnimalById('anim_resilience_test');
      expect(persisted, isNotNull);
      expect(persisted!.name, 'Bovin Résilient');
    });

    // ─── 10. Respect des permissions et de l'isolation multi-fermes ─────────
    test('10. Workers cannot perform unauthorized mutations; cross-farm actions forbidden',
        () async {
      final workerFarm = Farm(
        id: 'farm_worker_test',
        name: 'Ferme Worker',
        isDemo: false,
        createdAt: DateTime(2026, 6, 1),
      );

      final workerContainer = ProviderContainer(
        overrides: [
          animalsRepositoryProvider.overrideWithValue(repository),
          syncQueueServiceProvider.overrideWithValue(syncQueueService),
          farmServiceProvider.overrideWithValue(
            FakeFarmService(
              userMemberships: {
                'worker_user_id': [
                  UserFarmMembership(farm: workerFarm, role: UserRole.worker),
                ],
              },
            ),
          ),
          authProvider.overrideWith((ref) {
            return AuthNotifier(
              ref.read(authServiceProvider),
            )..state = AppAuthState.authenticated(
                user: User(
                  id: 'worker_user_id',
                  appMetadata: const {},
                  userMetadata: const {},
                  aud: 'authenticated',
                  createdAt: DateTime.now().toIso8601String(),
                  email: 'worker@agritrack.ci',
                ),
                profile: UserProfile(
                  id: 'worker_user_id',
                  email: 'worker@agritrack.ci',
                  fullName: 'Ouvrier Test',
                  createdAt: DateTime(2026, 1, 1),
                ),
              );
          }),
        ],
      );
      addTearDown(workerContainer.dispose);

      await workerContainer
          .read(activeFarmProvider.notifier)
          .loadRemoteFarms('worker_user_id');

      // 10.1 Worker ne peut pas supprimer d'animal
      await repository.addAnimal(
        Animal(
          id: 'anim_worker_check',
          name: 'Animal Test Worker',
          type: AnimalType.bovin,
          ageMonths: 18,
          weightKg: 300.0,
          healthStatus: HealthStatus.sain,
          farmId: workerFarm.id,
          expenses: const [],
          createdAt: DateTime.now(),
        ),
        targetFarmId: workerFarm.id,
      );

      expect(
        () => workerContainer
            .read(animalsNotifierProvider.notifier)
            .deleteAnimal('anim_worker_check'),
        throwsA(isA<StateError>()),
      );

      // 10.2 Worker ne peut pas modifier ni supprimer de dépenses
      expect(
        () => workerContainer
            .read(animalsNotifierProvider.notifier)
            .deleteExpense(
              animalId: 'anim_worker_check',
              expenseId: 'exp_inexistant',
            ),
        throwsA(isA<StateError>()),
      );

      // 10.3 Action sur un animal d'une autre exploitation rejetée
      final otherFarmAnimal = Animal(
        id: 'anim_other_farm',
        name: 'Animal Autre Ferme',
        type: AnimalType.ovin,
        ageMonths: 10,
        weightKg: 35.0,
        healthStatus: HealthStatus.sain,
        farmId: 'farm_other_xyz',
        expenses: const [],
        createdAt: DateTime.now(),
      );
      await repository.addAnimal(
        otherFarmAnimal,
        targetFarmId: 'farm_other_xyz',
      );

      expect(
        () => workerContainer
            .read(animalsNotifierProvider.notifier)
            .updateAnimal(otherFarmAnimal),
        throwsA(isA<StateError>()),
      );
    });

    // ─── 11. Coalescing et neutralisation hors ligne ─────────────────────────
    test('11. Offline create followed by delete neutralizes sync queue operation',
        () async {
      container
          .read(activeFarmProvider.notifier)
          .selectFarm(remoteFarm, role: UserRole.owner);

      final transientAnimal = Animal(
        id: 'anim_transient_001',
        name: 'Animal Éphémère',
        type: AnimalType.volaille,
        ageMonths: 4,
        weightKg: 2.2,
        healthStatus: HealthStatus.sain,
        farmId: remoteFarm.id,
        expenses: const [],
        createdAt: DateTime.now(),
      );

      // 1. Création hors ligne
      await container
          .read(animalsNotifierProvider.notifier)
          .addAnimal(transientAnimal);

      // 2. Dépense ajoutée hors ligne
      await container
          .read(animalsNotifierProvider.notifier)
          .addExpense(
            animalId: 'anim_transient_001',
            expense: Expense(
              id: 'exp_transient_001',
              label: 'Grain',
              amount: 1500,
              date: DateTime.now(),
              category: ExpenseCategory.alimentation,
            ),
          );

      var ops = await syncQueueService.getPendingOperations(
        farmId: remoteFarm.id,
      );
      expect(ops.length, 2);

      // 3. Suppression hors ligne de l'animal avant toute synchronisation
      await container
          .read(animalsNotifierProvider.notifier)
          .deleteAnimal('anim_transient_001');

      // Le coalescing dans SyncQueueService neutralise la création locale et ses dépenses !
      ops = await syncQueueService.getPendingOperations(
        farmId: remoteFarm.id,
      );
      expect(ops, isEmpty);
    });
  });
}
