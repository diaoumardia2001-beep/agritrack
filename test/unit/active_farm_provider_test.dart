// test/unit/active_farm_provider_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agritrack/data/animals_repository.dart';
import 'package:agritrack/data/database/app_database.dart';
import 'package:agritrack/data/database/database_migrator.dart';
import 'package:agritrack/models/farm.dart';
import 'package:agritrack/models/user_farm_membership.dart';
import 'package:agritrack/models/user_profile.dart';
import 'package:agritrack/providers/active_farm_provider.dart';
import 'package:agritrack/providers/animals_provider.dart';
import 'package:agritrack/providers/auth_provider.dart';
import 'auth_provider_test.dart';

/// Implémentation Fake en mémoire de IFarmService
class FakeFarmService implements IFarmService {
  List<UserFarmMembership> mockFarms;
  Exception? fetchError;
  Exception? createError;
  int createRemoteFarmCallCount = 0;

  FakeFarmService({
    this.mockFarms = const [],
    this.fetchError,
    this.createError,
  });

  @override
  Future<List<UserFarmMembership>> fetchUserFarms(String userId) async {
    if (fetchError != null) {
      throw fetchError!;
    }
    return mockFarms;
  }

  @override
  Future<Farm> createRemoteFarm({
    required String name,
    String? region,
    bool isDemo = false,
  }) async {
    createRemoteFarmCallCount++;
    if (createError != null) {
      throw createError!;
    }
    return Farm(
      id: 'farm_created_remote_uuid',
      name: name,
      region: region,
      ownerId: 'user_mock_id',
      isDemo: isDemo,
      createdAt: DateTime(2026, 3, 1),
    );
  }
}

void main() {
  group('ActiveFarmProvider Unit Tests', () {
    late FakeAuthService fakeAuth;
    late FakeFarmService fakeFarmService;
    late AnimalsRepository testRepo;
    late Database memoryDb;
    late ProviderContainer container;

    setUp(() async {
      // Base Sembast en mémoire isolée pour chaque test (zéro I/O disque)
      memoryDb = await AppDatabase.openInMemory();
      testRepo = AnimalsRepository(
        database: Future.value(memoryDb),
        autoSeed: true,
      );
      // S'assurer que le seeding initial Sembast est terminé avant d'exécuter les tests
      await testRepo.fetchFarms();

      fakeAuth = FakeAuthService();
      fakeFarmService = FakeFarmService();

      container = ProviderContainer(
        overrides: [
          animalsRepositoryProvider.overrideWithValue(testRepo),
          authServiceProvider.overrideWithValue(fakeAuth),
          farmServiceProvider.overrideWithValue(fakeFarmService),
        ],
      );
    });

    tearDown(() async {
      await Future<void>.delayed(Duration.zero);
      container.dispose();
      fakeAuth.dispose();
      await memoryDb.close();
      await AppDatabase.resetForTesting();
    });

    test(
        '1. Initial state defaults to local Sembast farm without network calls',
        () async {
      final state = container.read(activeFarmProvider);

      expect(state.activeFarm.id, equals(DatabaseMigrator.defaultFarmId));
      expect(state.isLocal, isTrue);
      expect(state.isRemote, isFalse);
      expect(state.userRoleOnActiveFarm, equals(UserRole.owner));
      expect(state.accessibleRemoteFarms, isEmpty);
      expect(state.errorMessage, isNull);
    });

    test(
        '2. Loads remote farms and assigns specific role per farm on user login',
        () async {
      final farmDiop = Farm(
        id: 'farm_diop_uuid',
        name: 'Ferme Diop Touba',
        region: 'Diourbel',
        ownerId: 'user_owner_uuid',
        createdAt: DateTime(2026, 1, 1),
      );

      final farmThies = Farm(
        id: 'farm_thies_uuid',
        name: 'Ferme Ndiaye Thiès',
        region: 'Thiès',
        ownerId: 'another_owner_uuid',
        createdAt: DateTime(2026, 1, 2),
      );

      fakeFarmService.mockFarms = [
        UserFarmMembership(farm: farmDiop, role: UserRole.owner),
        UserFarmMembership(farm: farmThies, role: UserRole.worker),
      ];

      final authNotifier = container.read(authProvider.notifier);
      await authNotifier.signIn(
        email: 'eleveur@agritrack.sn',
        password: 'Password123!',
      );

      // Laisser le temps à la réaction authProvider d'appeler loadRemoteFarms
      await container
          .read(activeFarmProvider.notifier)
          .loadRemoteFarms('user_owner_uuid');

      final state = container.read(activeFarmProvider);
      expect(state.accessibleRemoteFarms.length, equals(2));
      expect(state.hasRemoteFarms, isTrue);

      // Première ferme sélectionnée : Diop Touba (avec rôle owner)
      expect(state.activeFarm.id, equals('farm_diop_uuid'));
      expect(state.isRemote, isTrue);
      expect(state.userRoleOnActiveFarm, equals(UserRole.owner));
      expect(state.isOwner, isTrue);
      expect(state.canManage, isTrue);

      // Bascule vers la seconde ferme (où l'utilisateur est worker)
      container.read(activeFarmProvider.notifier).selectFarm(farmThies);
      final stateWorker = container.read(activeFarmProvider);
      expect(stateWorker.activeFarm.id, equals('farm_thies_uuid'));
      expect(stateWorker.userRoleOnActiveFarm, equals(UserRole.worker));
      expect(stateWorker.isWorker, isTrue);
      expect(stateWorker.isOwner, isFalse);
      expect(stateWorker.canManage, isFalse);
    });

    test(
        '3. Handles authenticated user with zero accessible remote farms cleanly',
        () async {
      fakeFarmService.mockFarms = const [];

      final farmNotifier = container.read(activeFarmProvider.notifier);
      await farmNotifier.loadRemoteFarms('new_user_without_farms');

      final state = container.read(activeFarmProvider);
      expect(state.accessibleRemoteFarms, isEmpty);
      expect(state.hasRemoteFarms, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('4. Handles remote farm loading network error without crashing',
        () async {
      fakeFarmService.fetchError =
          Exception('Network error: connection refused');

      final farmNotifier = container.read(activeFarmProvider.notifier);
      await farmNotifier.loadRemoteFarms('user_offline_id');

      final state = container.read(activeFarmProvider);
      expect(state.errorMessage,
          contains('Impossible de charger les exploitations distantes'));
      expect(state.isLoading, isFalse);
      // Conserve la ferme active locale
      expect(state.isLocal, isTrue);
    });

    test('5. Creates remote farm via RPC and sets user as owner atomically',
        () async {
      final farmNotifier = container.read(activeFarmProvider.notifier);
      final created = await farmNotifier.createRemoteFarm(
        name: 'Ferme Fatick Moderne',
        region: 'Fatick',
        isDemo: false,
      );

      expect(created, isNotNull);
      expect(created!.name, equals('Ferme Fatick Moderne'));
      expect(fakeFarmService.createRemoteFarmCallCount, equals(1));

      final state = container.read(activeFarmProvider);
      expect(state.activeFarm.name, equals('Ferme Fatick Moderne'));
      expect(state.userRoleOnActiveFarm, equals(UserRole.owner));
      expect(state.isOwner, isTrue);
      expect(state.accessibleRemoteFarms.any((m) => m.farm.id == created.id),
          isTrue);
    });

    test('6. Handles creation failure gracefully', () async {
      fakeFarmService.createError = Exception('Violation contrainte SQL');

      final farmNotifier = container.read(activeFarmProvider.notifier);
      final created = await farmNotifier.createRemoteFarm(
        name: 'Ferme Erreur',
      );

      expect(created, isNull);
      final state = container.read(activeFarmProvider);
      expect(state.errorMessage,
          contains('Échec de la création de l\'exploitation'));
      expect(state.isLoading, isFalse);
    });

    test(
        '7. Logout switches back to local farm WITHOUT deleting local Sembast data',
        () async {
      // 1. Vérifier que les 12 animaux locaux existent au départ
      final initialAnimals = await testRepo.fetchAnimals();
      expect(initialAnimals.length, equals(12));

      // 2. Connexion et passage en mode distant
      fakeFarmService.mockFarms = [
        UserFarmMembership(
          farm: Farm(
            id: 'remote_farm_temp',
            name: 'Ferme Distante',
            ownerId: 'test_uid',
            createdAt: DateTime.now(),
          ),
          role: UserRole.owner,
        ),
      ];
      final authNotifier = container.read(authProvider.notifier);
      await authNotifier.signIn(email: 'test@agritrack.sn', password: 'Pass');
      await container
          .read(activeFarmProvider.notifier)
          .loadRemoteFarms('test_uid');

      expect(container.read(activeFarmProvider).isRemote, isTrue);

      // 3. Déconnexion
      await authNotifier.signOut();

      // 4. L'état revient sur la ferme locale
      final stateAfterSignOut = container.read(activeFarmProvider);
      expect(stateAfterSignOut.isLocal, isTrue);
      expect(stateAfterSignOut.activeFarm.id,
          equals(DatabaseMigrator.defaultFarmId));
      expect(stateAfterSignOut.accessibleRemoteFarms, isEmpty);

      // 5. GARANTIE CRITIQUE : Les données locales Sembast sont strictement intactes !
      final localAnimalsAfter = await testRepo.fetchAnimals();
      expect(localAnimalsAfter.length, equals(12));
      expect(localAnimalsAfter.first.id, equals('a001'));
      expect(localAnimalsAfter.first.name, equals('Bakary'));
    });
  });
}
