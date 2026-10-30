// test/unit/demo_mode_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:agritrack/core/demo_mode_config.dart';
import 'package:agritrack/core/supabase_config.dart';
import 'package:agritrack/data/animals_repository.dart';
import 'package:agritrack/data/database/database_migrator.dart';
import 'package:agritrack/data/database/demo_database_manager.dart';
import 'package:agritrack/models/animal.dart';
import 'package:agritrack/models/expense.dart';
import 'package:agritrack/providers/active_farm_provider.dart';
import 'package:agritrack/providers/animals_provider.dart';
import 'package:agritrack/providers/sync_provider.dart';
import 'package:agritrack/services/sync/supabase_sync_client.dart';

void main() {
  group('1. DemoModeConfig & URL Detection Tests', () {
    tearDown(() {
      DemoModeConfig.setOverrideForTesting(null);
    });

    test('Defaults to false when URL parameter is absent', () {
      final uri = Uri.parse('https://agritrack-olive.vercel.app');
      expect(DemoModeConfig.isDemoMode(uri), isFalse);
    });

    test('Detects demo=true (case-insensitive)', () {
      expect(
        DemoModeConfig.isDemoMode(
            Uri.parse('https://agritrack-olive.vercel.app/?demo=true')),
        isTrue,
      );
      expect(
        DemoModeConfig.isDemoMode(
            Uri.parse('https://agritrack-olive.vercel.app/?demo=TRUE')),
        isTrue,
      );
      expect(
        DemoModeConfig.isDemoMode(
            Uri.parse('https://agritrack-olive.vercel.app/?demo=1')),
        isTrue,
      );
    });

    test('Ignores demo=false, demo=0 or arbitrary values', () {
      expect(
        DemoModeConfig.isDemoMode(
            Uri.parse('https://agritrack-olive.vercel.app/?demo=false')),
        isFalse,
      );
      expect(
        DemoModeConfig.isDemoMode(
            Uri.parse('https://agritrack-olive.vercel.app/?demo=0')),
        isFalse,
      );
      expect(
        DemoModeConfig.isDemoMode(
            Uri.parse('https://agritrack-olive.vercel.app/?other=value')),
        isFalse,
      );
    });

    test('DemoModeNotifier allows toggling and setting state', () {
      final notifier = DemoModeNotifier(initialValue: false);
      expect(notifier.state, isFalse);

      notifier.enableDemoMode();
      expect(notifier.state, isTrue);

      notifier.disableDemoMode();
      expect(notifier.state, isFalse);

      notifier.toggleDemoMode();
      expect(notifier.state, isTrue);
    });
  });

  group('2. Storage Isolation & In-Memory Database Tests', () {
    late Database persistentMockDb;
    late Database inMemoryDemoDb;

    setUp(() async {
      final memoryFactory = newDatabaseFactoryMemory();
      persistentMockDb = await memoryFactory.openDatabase('persistent_sim.db');
      inMemoryDemoDb = await memoryFactory.openDatabase('demo_isolated.db');

      await DatabaseMigrator.migrate(persistentMockDb);
      await DatabaseMigrator.migrate(inMemoryDemoDb);
    });

    tearDown(() async {
      await persistentMockDb.close();
      await inMemoryDemoDb.close();
      await DemoDatabaseManager.closeAndReset();
      DemoModeConfig.setOverrideForTesting(null);
    });

    test('In-memory demo database initializes cleanly with 12 demo animals',
        () async {
      final demoRepo = AnimalsRepository(
        database: Future.value(inMemoryDemoDb),
        autoSeed: true,
      );

      final animals = await demoRepo.fetchAnimals();
      expect(animals.length, equals(12));
      expect(animals.map((a) => a.id), containsAll(['a001', 'a006', 'a012']));
      expect(animals.every((a) => a.isDemo), isTrue);

      // Verify the persistent simulation database is empty (unseeded)
      final persistentRecords =
          await DatabaseMigrator.animalsStore.find(persistentMockDb);
      expect(persistentRecords, isEmpty);
    });

    test(
        'Mutations in demo mode do NOT leak into persistent storage (Add, Update, Delete)',
        () async {
      final demoRepo = AnimalsRepository(
        database: Future.value(inMemoryDemoDb),
        autoSeed: true,
      );

      // 1. Add animal
      final newAnimal = Animal(
        id: 'test_demo_999',
        name: 'Mouton Visiteur',
        type: AnimalType.ovin,
        ageMonths: 14,
        weightKg: 45.0,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime.now(),
        isDemo: true,
      );

      final added = await demoRepo.addAnimal(newAnimal);
      expect(added.id, equals('test_demo_999'));

      final demoListAfterAdd = await demoRepo.fetchAnimals();
      expect(demoListAfterAdd.length, equals(13));

      // 2. Add expense
      final newExpense = Expense(
        id: 'exp_demo_888',
        animalId: 'test_demo_999',
        label: 'Aliment test',
        amount: 5000,
        date: DateTime.now(),
        category: ExpenseCategory.alimentation,
      );
      await demoRepo.addExpense('test_demo_999', newExpense);

      final fetched = await demoRepo.getAnimalById('test_demo_999');
      expect(fetched!.expenses.length, equals(1));
      expect(fetched.expenses.first.label, equals('Aliment test'));

      // 3. Update animal
      final updatedAnimal = fetched.copyWith(
        weightKg: 48.5,
        healthStatus: HealthStatus.aSurveiller,
      );
      await demoRepo.updateAnimal(updatedAnimal);

      final afterUpdate = await demoRepo.getAnimalById('test_demo_999');
      expect(afterUpdate!.weightKg, equals(48.5));
      expect(afterUpdate.healthStatus, equals(HealthStatus.aSurveiller));

      // 4. Delete animal
      await demoRepo.deleteAnimal('test_demo_999');
      final demoListAfterDelete = await demoRepo.fetchAnimals();
      expect(demoListAfterDelete.length, equals(12));

      // 5. CRITICAL CHECK: Verify persistentMockDb contains ZERO records
      final persistentCount =
          await DatabaseMigrator.animalsStore.count(persistentMockDb);
      expect(persistentCount, equals(0));
    });

    test('resetDemoData restores exactly the 12 initial animals and 25 expenses',
        () async {
      final demoRepo = AnimalsRepository(
        database: Future.value(inMemoryDemoDb),
        autoSeed: true,
      );

      // Mutate: delete 2 animals and add 1
      await demoRepo.deleteAnimal('a001');
      await demoRepo.deleteAnimal('a002');
      await demoRepo.addAnimal(Animal(
        id: 'custom_temp_animal',
        name: 'Chèvre Visiteur',
        type: AnimalType.caprin,
        ageMonths: 10,
        weightKg: 25.0,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime.now(),
      ));

      final mutatedList = await demoRepo.fetchAnimals();
      expect(mutatedList.length, equals(11));
      expect(mutatedList.any((a) => a.id == 'a001'), isFalse);

      // Execute Reset
      await demoRepo.resetDemoData();

      // Check pristine restoration
      final restoredList = await demoRepo.fetchAnimals();
      expect(restoredList.length, equals(12));
      expect(restoredList.any((a) => a.id == 'a001'), isTrue);
      expect(restoredList.any((a) => a.id == 'a002'), isTrue);
      expect(restoredList.any((a) => a.id == 'custom_temp_animal'), isFalse);

      // Check all 25 expenses are restored
      final totalExpensesCount =
          restoredList.fold<int>(0, (sum, a) => sum + a.expenses.length);
      expect(totalExpensesCount, equals(25));
    });
  });

  group('3. Supabase Write Blocking & Isolation Tests', () {
    tearDown(() {
      DemoModeConfig.setOverrideForTesting(null);
    });

    test('SupabaseConfig.safeClient returns null when demo mode is active', () {
      DemoModeConfig.setOverrideForTesting(true);
      expect(SupabaseConfig.safeClient, isNull);
    });

    test('SupabaseConfig.client throws StateError when demo mode is active', () {
      DemoModeConfig.setOverrideForTesting(true);
      expect(() => SupabaseConfig.client, throwsStateError);
    });

    test('DisabledSupabaseSyncClient throws StateError on any push operation',
        () async {
      const client = DisabledSupabaseSyncClient();

      expect(
        () => client.pushAnimalRpc(
          operationId: 'op_1',
          farmId: 'farm_1',
          action: 'create',
        ),
        throwsA(isA<StateError>().having((e) => e.message, 'message',
            contains('Mode démo actif'))),
      );

      expect(
        () => client.pushExpenseRpc(
          operationId: 'op_e1',
          farmId: 'farm_1',
          action: 'create',
        ),
        throwsA(isA<StateError>().having((e) => e.message, 'message',
            contains('Mode démo actif'))),
      );

      expect(
        () => client.softDeleteAnimal(
          remoteId: 'rem_1',
          farmId: 'farm_1',
          deletedAt: DateTime.now(),
        ),
        throwsA(isA<StateError>()),
      );

      expect(
        () => client.softDeleteExpense(
          remoteId: 'rem_e1',
          farmId: 'farm_1',
          deletedAt: DateTime.now(),
        ),
        throwsA(isA<StateError>()),
      );

      // Fetch calls return empty list safely without network calls
      expect(await client.fetchAnimals(farmId: 'test_farm'), isEmpty);
      expect(await client.fetchExpenses(farmId: 'test_farm'), isEmpty);
    });

    test('DisabledFarmService rejects remote farm creation', () async {
      const farmService = DisabledFarmService();

      expect(
        () => farmService.createRemoteFarm(name: 'Ferme Démo'),
        throwsA(isA<StateError>().having((e) => e.message, 'message',
            contains('Mode démo actif'))),
      );
      expect(await farmService.fetchUserFarms('user_123'), isEmpty);
    });

    test('Riverpod container configures isolated providers in demo mode',
        () async {
      DemoModeConfig.setOverrideForTesting(true);

      final container = ProviderContainer(
        overrides: [
          isDemoModeProvider.overrideWith((ref) => DemoModeNotifier(initialValue: true)),
        ],
      );

      addTearDown(() {
        container.dispose();
        DemoDatabaseManager.closeAndReset();
      });

      // Verify sync client is disabled
      final syncClient = container.read(supabaseSyncClientProvider);
      expect(syncClient, isA<DisabledSupabaseSyncClient>());

      // Verify farm service is disabled
      final farmService = container.read(farmServiceProvider);
      expect(farmService, isA<DisabledFarmService>());

      // Verify animals repository operates on memory db
      final repo = container.read(animalsRepositoryProvider);
      final animals = await repo.fetchAnimals();
      expect(animals.length, equals(12));
    });
  });
}

