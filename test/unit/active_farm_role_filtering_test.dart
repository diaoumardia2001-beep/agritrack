// test/unit/active_farm_role_filtering_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
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

void main() {
  group('Active Farm Filtering & Role Permissions Tests (Étape 4)', () {
    late Database testDb;
    late AnimalsRepository repository;
    late SyncQueueService syncQueueService;
    late ProviderContainer container;
    late FakeFarmService fakeFarmService;

    final farmDakar = Farm(
      id: 'farm_cloud_dakar',
      name: 'Ferme de Dakar',
      region: 'Dakar',
      isDemo: false,
      createdAt: DateTime(2026, 6, 1),
    );

    final farmThies = Farm(
      id: 'farm_cloud_thies',
      name: 'Ferme de Thiès',
      region: 'Thiès',
      isDemo: false,
      createdAt: DateTime(2026, 6, 2),
    );

    setUp(() async {
      final memoryFactory = newDatabaseFactoryMemory();
      testDb = await memoryFactory.openDatabase(
        'test_step4_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      await DatabaseMigrator.migrate(testDb);

      repository = AnimalsRepository(
        database: Future.value(testDb),
        autoSeed: false,
      );

      syncQueueService = SyncQueueService(database: Future.value(testDb));

      // 1. Peupler l'exploitation locale par défaut (Farm 1)
      await repository.addAnimal(
        Animal(
          id: 'anim_local_01',
          name: 'Vache Locale',
          type: AnimalType.bovin,
          ageMonths: 36,
          weightKg: 350.0,
          healthStatus: HealthStatus.sain,
          farmId: DatabaseMigrator.defaultFarmId,
          expenses: [
            Expense(
              id: 'exp_local_1',
              label: 'Herbe fraîche',
              amount: 5000,
              date: DateTime.now(),
              category: ExpenseCategory.alimentation,
              farmId: DatabaseMigrator.defaultFarmId,
              animalId: 'anim_local_01',
            ),
          ],
          createdAt: DateTime(2026, 1, 10),
        ),
      );

      // 2. Peupler l'exploitation distante Dakar (Farm 2)
      await repository.addAnimal(
        Animal(
          id: 'anim_dakar_01',
          name: 'Taureau Dakar',
          type: AnimalType.bovin,
          ageMonths: 24,
          weightKg: 400.0,
          healthStatus: HealthStatus.aSurveiller,
          farmId: 'farm_cloud_dakar',
          expenses: [
            Expense(
              id: 'exp_dakar_1',
              label: 'Vaccin Bovin',
              amount: 15000,
              date: DateTime.now(),
              category: ExpenseCategory.sante,
              farmId: 'farm_cloud_dakar',
              animalId: 'anim_dakar_01',
            ),
          ],
          createdAt: DateTime(2026, 6, 5),
        ),
      );

      await repository.addAnimal(
        Animal(
          id: 'anim_dakar_02',
          name: 'Brebis Dakar',
          type: AnimalType.ovin,
          ageMonths: 14,
          weightKg: 45.0,
          healthStatus: HealthStatus.sain,
          farmId: 'farm_cloud_dakar',
          expenses: const [],
          createdAt: DateTime(2026, 6, 10),
        ),
      );

      // 3. Farm 3 (Thiès) est vide (aucun animal inséré localement)

      fakeFarmService = FakeFarmService(
        userMemberships: {
          'user_worker_1': [
            UserFarmMembership(farm: farmDakar, role: UserRole.worker),
          ],
          'user_manager_1': [
            UserFarmMembership(farm: farmDakar, role: UserRole.manager),
          ],
          'user_owner_1': [
            UserFarmMembership(farm: farmDakar, role: UserRole.owner),
            UserFarmMembership(farm: farmThies, role: UserRole.owner),
          ],
        },
      );

      container = ProviderContainer(
        overrides: [
          animalsRepositoryProvider.overrideWithValue(repository),
          farmServiceProvider.overrideWithValue(fakeFarmService),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await testDb.close();
    });

    // ─── 1. Filtrage des animaux par exploitation active ─────────────────────
    test('1. animalsProvider returns ONLY animals belonging to the active farm',
        () async {
      // Par défaut, l'exploitation active est l'exploitation locale
      final initialAnimals = await container.read(animalsProvider.future);
      expect(initialAnimals.length, 1);
      expect(initialAnimals.first.id, 'anim_local_01');
      expect(initialAnimals.first.farmId, DatabaseMigrator.defaultFarmId);

      // Basculer sur la ferme de Dakar
      container
          .read(activeFarmProvider.notifier)
          .selectFarm(farmDakar, role: UserRole.owner);

      final dakarAnimals = await container.read(animalsProvider.future);
      expect(dakarAnimals.length, 2);
      expect(dakarAnimals.every((a) => a.farmId == 'farm_cloud_dakar'), isTrue);
      expect(dakarAnimals.map((a) => a.id),
          containsAll(['anim_dakar_01', 'anim_dakar_02']));
    });

    // ─── 2. Absence de mélange entre deux exploitations ───────────────────────
    test('2. No leak of animals between different farms', () async {
      // Sélectionner Dakar
      container
          .read(activeFarmProvider.notifier)
          .selectFarm(farmDakar, role: UserRole.owner);

      final dakarAnimals = await container.read(animalsProvider.future);
      expect(dakarAnimals.any((a) => a.id == 'anim_local_01'), isFalse);

      // animalByIdProvider pour un animal d'une autre ferme retourne null
      final crossAnimal = container.read(animalByIdProvider('anim_local_01'));
      expect(crossAnimal, isNull);

      final legitimateAnimal =
          container.read(animalByIdProvider('anim_dakar_01'));
      expect(legitimateAnimal, isNotNull);
      expect(legitimateAnimal!.name, 'Taureau Dakar');
    });

    // ─── 3. État vide d'une exploitation distante sans données locales ────────
    test('3. Remote farm with no local animals returns strictly empty list',
        () async {
      // Sélectionner la ferme de Thiès (qui n'a aucun animal localement)
      container
          .read(activeFarmProvider.notifier)
          .selectFarm(farmThies, role: UserRole.owner);

      final thiesAnimals = await container.read(animalsProvider.future);
      expect(thiesAnimals, isEmpty);

      final filtered = container.read(filteredAnimalsProvider).value!;
      expect(filtered, isEmpty);
    });

    // ─── 4. Cohérence des statistiques avec l'exploitation active ─────────────
    test('4. DashboardStats and speciesCounts match strictly the active farm',
        () async {
      // 1. Stats sur la ferme locale
      await container.read(animalsProvider.future);
      var stats = container.read(dashboardStatsProvider).value!;
      expect(stats.totalAnimals, 1);
      expect(stats.totalMonthlyExpenses, 5000);
      expect(stats.healthAlerts, 0);

      var species = container.read(speciesCountsProvider);
      expect(species[AnimalType.bovin], 1);
      expect(species[AnimalType.ovin], 0);

      // 2. Bascule sur Dakar (2 animaux, 1 bovin aSurveiller à 15000, 1 ovin sain à 0)
      container
          .read(activeFarmProvider.notifier)
          .selectFarm(farmDakar, role: UserRole.owner);

      // Attendre que Riverpod propage
      await container.read(animalsProvider.future);

      stats = container.read(dashboardStatsProvider).value!;
      expect(stats.totalAnimals, 2);
      expect(stats.totalMonthlyExpenses, 15000);
      expect(stats.healthAlerts, 1);

      species = container.read(speciesCountsProvider);
      expect(species[AnimalType.bovin], 1);
      expect(species[AnimalType.ovin], 1);

      // 3. Bascule sur Thiès (vide)
      container
          .read(activeFarmProvider.notifier)
          .selectFarm(farmThies, role: UserRole.owner);
      await container.read(animalsProvider.future);

      stats = container.read(dashboardStatsProvider).value!;
      expect(stats.totalAnimals, 0);
      expect(stats.totalMonthlyExpenses, 0);
      expect(stats.healthAlerts, 0);

      species = container.read(speciesCountsProvider);
      expect(species[null], 0);
    });

    // ─── 5. Permissions des rôles owner, manager et worker ───────────────────
    test('5. Role permissions align with SQL RLS specifications', () {
      // Owner
      expect(UserRole.owner.canAddAnimal, isTrue);
      expect(UserRole.owner.canUpdateAnimal, isTrue);
      expect(UserRole.owner.canDeleteAnimal, isTrue);
      expect(UserRole.owner.canAddExpense, isTrue);
      expect(UserRole.owner.canUpdateExpense, isTrue);
      expect(UserRole.owner.canDeleteExpense, isTrue);
      expect(UserRole.owner.canManageMembers, isTrue);
      expect(UserRole.owner.canEditFarm, isTrue);

      // Manager
      expect(UserRole.manager.canAddAnimal, isTrue);
      expect(UserRole.manager.canUpdateAnimal, isTrue);
      expect(UserRole.manager.canDeleteAnimal, isTrue);
      expect(UserRole.manager.canAddExpense, isTrue);
      expect(UserRole.manager.canUpdateExpense, isTrue);
      expect(UserRole.manager.canDeleteExpense, isTrue);
      expect(UserRole.manager.canManageMembers, isFalse);
      expect(UserRole.manager.canEditFarm, isFalse);

      // Worker
      expect(UserRole.worker.canAddAnimal, isTrue);
      expect(UserRole.worker.canUpdateAnimal, isTrue);
      expect(UserRole.worker.canAddExpense, isTrue);
      // Restrictions strictes :
      expect(UserRole.worker.canDeleteAnimal, isFalse);
      expect(UserRole.worker.canUpdateExpense, isFalse);
      expect(UserRole.worker.canDeleteExpense, isFalse);
      expect(UserRole.worker.canManageMembers, isFalse);
      expect(UserRole.worker.canEditFarm, isFalse);
    });

    // ─── 6. Refus des actions non autorisées au niveau du notifier ───────────
    test(
        '6. AnimalsNotifier enforces permissions and rejects worker deletions or cross-farm mutations',
        () async {
      // Configurer la ferme Dakar avec le rôle Worker
      container
          .read(activeFarmProvider.notifier)
          .selectFarm(farmDakar, role: UserRole.worker);

      final notifier = container.read(animalsNotifierProvider.notifier);

      // 6a. Worker tente de supprimer un animal -> Interdit
      expect(
        () => notifier.deleteAnimal('anim_dakar_01'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('les ouvriers ne peuvent pas supprimer d\'animaux'),
        )),
      );

      // 6b. Worker tente de modifier une dépense -> Interdit
      expect(
        () => notifier.updateExpense(
          animalId: 'anim_dakar_01',
          expense: Expense(
            id: 'exp_dakar_1',
            label: 'Nouveau libellé',
            amount: 20000,
            date: DateTime.now(),
            category: ExpenseCategory.sante,
          ),
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('les ouvriers ne peuvent pas modifier les dépenses'),
        )),
      );

      // 6c. Worker tente de supprimer une dépense -> Interdit
      expect(
        () => notifier.deleteExpense(
          animalId: 'anim_dakar_01',
          expenseId: 'exp_dakar_1',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('les ouvriers ne peuvent pas supprimer les dépenses'),
        )),
      );

      // 6d. Worker PEUT ajouter un animal et une dépense
      final newAnimal = await notifier.addAnimal(
        Animal(
          id: 'anim_worker_added_1',
          name: 'Veau Dakar',
          type: AnimalType.bovin,
          ageMonths: 4,
          weightKg: 60,
          healthStatus: HealthStatus.sain,
          expenses: const [],
          createdAt: DateTime.now(),
        ),
      );
      expect(newAnimal.farmId, 'farm_cloud_dakar');

      final newExpense = await notifier.addExpense(
        animalId: 'anim_worker_added_1',
        expense: Expense(
          id: 'exp_worker_1',
          label: 'Lait maternisé',
          amount: 8000,
          date: DateTime.now(),
          category: ExpenseCategory.alimentation,
        ),
      );
      expect(newExpense.farmId, 'farm_cloud_dakar');

      // 6e. Modification d'un animal appartenant à une AUTRE ferme -> Interdit
      expect(
        () => notifier.updateAnimal(
          Animal(
            id: 'anim_local_01',
            name: 'Piratage Ferme',
            type: AnimalType.bovin,
            ageMonths: 36,
            weightKg: 350.0,
            healthStatus: HealthStatus.sain,
            farmId: DatabaseMigrator.defaultFarmId,
            expenses: const [],
            createdAt: DateTime.now(),
          ),
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('cet animal n\'appartient pas à l\'exploitation active'),
        )),
      );

      // 6f. Basculer sur Owner : toutes les suppressions sont désormais autorisées
      container
          .read(activeFarmProvider.notifier)
          .selectFarm(farmDakar, role: UserRole.owner);

      final deletedExpense = await notifier.deleteExpense(
        animalId: 'anim_worker_added_1',
        expenseId: 'exp_worker_1',
      );
      expect(deletedExpense, isTrue);

      final deletedAnimal = await notifier.deleteAnimal('anim_worker_added_1');
      expect(deletedAnimal, isTrue);
    });

    // ─── 7. Rafraîchissement des providers après un changement d'exploitation ─
    test('7. Switching active farm automatically refreshes animalsProvider',
        () async {
      // 1. Initial : Local
      final a1 = await container.read(animalsProvider.future);
      expect(a1.length, 1);
      expect(a1.first.id, 'anim_local_01');

      // 2. Bascule vers Dakar
      container
          .read(activeFarmProvider.notifier)
          .selectFarm(farmDakar, role: UserRole.owner);

      final a2 = await container.read(animalsProvider.future);
      expect(a2.length, 2);
      expect(a2.any((a) => a.id == 'anim_dakar_01'), isTrue);

      // 3. Bascule vers Thiès
      container
          .read(activeFarmProvider.notifier)
          .selectFarm(farmThies, role: UserRole.owner);

      final a3 = await container.read(animalsProvider.future);
      expect(a3, isEmpty);

      // 4. Retour sur Local
      container.read(activeFarmProvider.notifier).switchToLocalFarm();

      final a4 = await container.read(animalsProvider.future);
      expect(a4.length, 1);
      expect(a4.first.id, 'anim_local_01');
    });

    // ─── 8. Déconnexion et absence de fuite des données du contexte précédent ─
    test('8. Logout resets context to local farm without leaking remote data',
        () async {
      // Connecter l'utilisateur sur Dakar
      container
          .read(activeFarmProvider.notifier)
          .selectFarm(farmDakar, role: UserRole.worker);

      expect(container.read(activeFarmProvider).isRemote, isTrue);
      expect(container.read(activeFarmProvider).isWorker, isTrue);

      // Déconnexion
      container.read(activeFarmProvider.notifier).switchToLocalFarm();

      final activeState = container.read(activeFarmProvider);
      expect(activeState.isLocal, isTrue);
      expect(activeState.activeFarm.id, DatabaseMigrator.defaultFarmId);
      expect(activeState.userRoleOnActiveFarm, UserRole.owner);
      expect(activeState.accessibleRemoteFarms, isEmpty);

      // Les animaux rechargés sont ceux de la ferme locale
      final currentAnimals = await container.read(animalsProvider.future);
      expect(currentAnimals.length, 1);
      expect(currentAnimals.first.id, 'anim_local_01');
    });

    // ─── 9. Préservation du fonctionnement hors-ligne ────────────────────────
    test(
        '9. Default local farm preserves full offline capabilities and owner role',
        () async {
      final activeState = container.read(activeFarmProvider);
      expect(activeState.isLocal, isTrue);
      expect(activeState.userRoleOnActiveFarm, UserRole.owner);
      expect(activeState.canAddAnimal, isTrue);
      expect(activeState.canUpdateAnimal, isTrue);
      expect(activeState.canDeleteAnimal, isTrue);
      expect(activeState.canAddExpense, isTrue);
      expect(activeState.canUpdateExpense, isTrue);
      expect(activeState.canDeleteExpense, isTrue);

      // Mutation locale complète
      final notifier = container.read(animalsNotifierProvider.notifier);
      final offlineAnimal = await notifier.addAnimal(
        Animal(
          id: 'offline_cow_1',
          name: 'Vache Hors-Ligne',
          type: AnimalType.bovin,
          ageMonths: 18,
          weightKg: 200,
          healthStatus: HealthStatus.sain,
          expenses: const [],
          createdAt: DateTime.now(),
        ),
      );
      expect(offlineAnimal.farmId, DatabaseMigrator.defaultFarmId);

      final offlineDeleted = await notifier.deleteAnimal('offline_cow_1');
      expect(offlineDeleted, isTrue);
    });

    // ─── 10. Absence de modification ou d'envoi automatique de sync_queue ────
    test(
        '10. Context changes and filtering do not purge or modify sync_queue store',
        () async {
      // 1. Ajouter une opération légitime dans sync_queue
      await syncQueueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'anim_dakar_01',
        action: SyncAction.update,
        farmId: 'farm_cloud_dakar',
        userId: 'user_owner_1',
        payload: {'weightKg': 420.0},
      );

      final initialQueueCount = await syncQueueService.count();
      expect(initialQueueCount, 1);

      // 2. Effectuer des changements de ferme et de rôles
      container
          .read(activeFarmProvider.notifier)
          .selectFarm(farmDakar, role: UserRole.worker);
      await container.read(animalsProvider.future);

      container
          .read(activeFarmProvider.notifier)
          .selectFarm(farmThies, role: UserRole.owner);
      await container.read(animalsProvider.future);

      container.read(activeFarmProvider.notifier).switchToLocalFarm();
      await container.read(animalsProvider.future);

      // 3. Vérifier que sync_queue est STRICTEMENT intact
      final finalQueueCount = await syncQueueService.count();
      expect(finalQueueCount, 1);

      final ops = await syncQueueService.getAllOperations();
      expect(ops.first.localId, 'anim_dakar_01');
      expect(ops.first.farmId, 'farm_cloud_dakar');
      expect(ops.first.userId, 'user_owner_1');
      expect(ops.first.status, SyncOperationStatus.pending);
    });
  });
}
