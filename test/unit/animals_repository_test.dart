// test/unit/animals_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:agritrack/data/animals_repository.dart';
import 'package:agritrack/data/database/app_database.dart';
import 'package:agritrack/data/database/database_migrator.dart';
import 'package:agritrack/models/animal.dart';
import 'package:agritrack/models/expense.dart';

void main() {
  group('AnimalsRepository Tests', () {
    late Database testDb;
    late AnimalsRepository repository;

    setUp(() async {
      testDb = await AppDatabase.openInMemory(
        name: 'repo_test_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      repository = AnimalsRepository(database: Future.value(testDb));
    });

    tearDown(() async {
      await testDb.close();
    });

    // ─── Tests originaux fiabilisés ───────────────────────────────────────────
    test('fetchAnimals returns list of mock animals', () async {
      final animals = await repository.fetchAnimals();
      expect(animals, isNotEmpty);
      expect(animals.length, equals(12));
    });

    test('fetchAnimals includes all species types', () async {
      final animals = await repository.fetchAnimals();
      final types = animals.map((a) => a.type).toSet();

      expect(types.contains(AnimalType.bovin), isTrue);
      expect(types.contains(AnimalType.caprin), isTrue);
      expect(types.contains(AnimalType.ovin), isTrue);
      expect(types.contains(AnimalType.volaille), isTrue);
    });

    test('addAnimal adds a new animal and returns it', () async {
      final newAnimal = Animal(
        id: 'new_animal_123',
        name: 'Zeus',
        type: AnimalType.bovin,
        ageMonths: 14,
        weightKg: 280,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime(2026, 1, 1),
      );

      final added = await repository.addAnimal(newAnimal);
      expect(added.id, 'new_animal_123');
      expect(added.name, 'Zeus');

      final animals = await repository.fetchAnimals();
      expect(animals.any((a) => a.id == 'new_animal_123'), isTrue);
    });

    test('addExpense adds a new expense to an existing animal and returns it',
        () async {
      final animals = await repository.fetchAnimals();
      final target = animals.first;
      final initialCount = target.expenses.length;

      final expense = Expense(
        id: '',
        label: 'Vaccin Charbon',
        amount: 8500,
        date: DateTime(2026, 10, 19),
        category: ExpenseCategory.sante,
      );

      final added = await repository.addExpense(target.id, expense);
      expect(added.id, isNotEmpty);
      expect(added.label, 'Vaccin Charbon');
      expect(added.amount, 8500);
      expect(added.category, ExpenseCategory.sante);

      final updatedAnimal = await repository.getAnimalById(target.id);
      expect(updatedAnimal, isNotNull);
      expect(updatedAnimal!.expenses.length, initialCount + 1);
      expect(updatedAnimal.expenses.last.label, 'Vaccin Charbon');
    });

    test('addExpense throws ArgumentError when animal does not exist',
        () async {
      final expense = Expense(
        id: 'e_invalid',
        label: 'Test',
        amount: 1000,
        date: DateTime.now(),
        category: ExpenseCategory.autre,
      );

      expect(
        () => repository.addExpense('inexistant_id_999', expense),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('addExpense preserves existing expenses when adding a new one',
        () async {
      final animals = await repository.fetchAnimals();
      final target = animals.firstWhere((a) => a.expenses.isNotEmpty);
      final existingIds = target.expenses.map((e) => e.id).toList();

      final newExp = Expense(
        id: '',
        label: 'Nourriture complémentaire',
        amount: 3200,
        date: DateTime.now(),
        category: ExpenseCategory.alimentation,
      );

      await repository.addExpense(target.id, newExp);

      final updated = await repository.getAnimalById(target.id);
      for (final id in existingIds) {
        expect(updated!.expenses.any((e) => e.id == id), isTrue);
      }
    });

    test('addExpense isolates expenses between animals', () async {
      final animals = await repository.fetchAnimals();
      final animalA = animals[0];
      final animalB = animals[1];

      final countBBefore = animalB.expenses.length;

      final expenseForA = Expense(
        id: '',
        label: 'Soin exclusif A',
        amount: 15000,
        date: DateTime.now(),
        category: ExpenseCategory.sante,
      );

      await repository.addExpense(animalA.id, expenseForA);

      final updatedB = await repository.getAnimalById(animalB.id);
      expect(updatedB!.expenses.length, countBBefore);
      expect(
          updatedB.expenses.any((e) => e.label == 'Soin exclusif A'), isFalse);
    });

    test(
        'addExpense generates distinct IDs when multiple expenses are added rapidly',
        () async {
      final animals = await repository.fetchAnimals();
      final target = animals.last;

      final exp1 = await repository.addExpense(
        target.id,
        Expense(
          id: '',
          label: 'Frais rapide 1',
          amount: 500,
          date: DateTime.now(),
          category: ExpenseCategory.autre,
        ),
      );

      final exp2 = await repository.addExpense(
        target.id,
        Expense(
          id: '',
          label: 'Frais rapide 2',
          amount: 600,
          date: DateTime.now(),
          category: ExpenseCategory.autre,
        ),
      );

      expect(exp1.id, isNot(equals(exp2.id)));
    });

    // ─── Tests A : Persistance et réouverture ─────────────────────────────────
    test(
        'Animal and expenses are preserved after closing and reopening database',
        () async {
      final memoryFactory = newDatabaseFactoryMemory();
      const dbName = 'persistent_lifecycle.db';

      // 1. Première session : création d'un animal et d'une dépense
      final dbSession1 = await memoryFactory.openDatabase(dbName);
      final repo1 = AnimalsRepository(database: Future.value(dbSession1));

      final customAnimal = Animal(
        id: 'custom_001',
        name: 'Sahel',
        type: AnimalType.ovin,
        ageMonths: 15,
        weightKg: 60.0,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime(2026, 4, 1),
      );
      await repo1.addAnimal(customAnimal);
      await repo1.addExpense(
        'custom_001',
        Expense(
          id: 'exp_sahel_1',
          label: 'Traitement tiques',
          amount: 4000,
          date: DateTime(2026, 4, 15),
          category: ExpenseCategory.sante,
        ),
      );

      await dbSession1.close();

      // 2. Deuxième session : réouverture de la même base
      final dbSession2 = await memoryFactory.openDatabase(dbName);
      final repo2 = AnimalsRepository(database: Future.value(dbSession2));

      final fetched = await repo2.getAnimalById('custom_001');
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Sahel');
      expect(fetched.expenses.length, 1);
      expect(fetched.expenses.first.id, 'exp_sahel_1');
      expect(fetched.expenses.first.amount, 4000.0);

      await dbSession2.close();
    });

    // ─── Tests B : Seeding idempotent ─────────────────────────────────────────
    test('Empty database is seeded with 12 demo animals exactly once',
        () async {
      final animalsFirst = await repository.fetchAnimals();
      expect(animalsFirst.length, 12);

      // Deuxième appel ne duplique rien
      final animalsSecond = await repository.fetchAnimals();
      expect(animalsSecond.length, 12);
    });

    test(
        'User modifications and expenses are never overwritten by subsequent seeding checks',
        () async {
      final memoryFactory = newDatabaseFactoryMemory();
      const dbName = 'seeding_integrity.db';

      final db1 = await memoryFactory.openDatabase(dbName);
      final repo1 = AnimalsRepository(database: Future.value(db1));

      // Modifier une dépense sur a001
      await repo1.addExpense(
        'a001',
        Expense(
          id: 'exp_perso_1',
          label: 'Dépense éleveur personnalisée',
          amount: 25000,
          date: DateTime(2026, 10, 20),
          category: ExpenseCategory.autre,
        ),
      );

      await db1.close();

      // Réouverture
      final db2 = await memoryFactory.openDatabase(dbName);
      final repo2 = AnimalsRepository(database: Future.value(db2));

      final animalA001 = await repo2.getAnimalById('a001');
      expect(animalA001, isNotNull);
      expect(animalA001!.expenses.any((e) => e.id == 'exp_perso_1'), isTrue);
      // Vérifier que la liste complète fait 12 animaux (pas de duplication 24)
      final allAnimals = await repo2.fetchAnimals();
      expect(allAnimals.length, 12);

      await db2.close();
    });

    test('Deleted animals are not recreated upon subsequent app restarts',
        () async {
      final memoryFactory = newDatabaseFactoryMemory();
      const dbName = 'deleted_animal.db';

      final db1 = await memoryFactory.openDatabase(dbName);
      final repo1 = AnimalsRepository(database: Future.value(db1));

      // Initialisation par fetch
      await repo1.fetchAnimals();
      // Supprimer a001
      final deleted = await repo1.deleteAnimal('a001');
      expect(deleted, isTrue);

      final listAfterDelete = await repo1.fetchAnimals();
      expect(listAfterDelete.length, 11);
      expect(listAfterDelete.any((a) => a.id == 'a001'), isFalse);

      await db1.close();

      // Relancement de l'application
      final db2 = await memoryFactory.openDatabase(dbName);
      final repo2 = AnimalsRepository(database: Future.value(db2));

      final listOnRestart = await repo2.fetchAnimals();
      expect(listOnRestart.length, 11);
      expect(listOnRestart.any((a) => a.id == 'a001'), isFalse);

      await db2.close();
    });

    test(
        'Existing user data is preserved and not overwritten if base was already populated',
        () async {
      final memoryFactory = newDatabaseFactoryMemory();
      const dbName = 'pre_existing.db';

      final db1 = await memoryFactory.openDatabase(dbName);
      // Créer une base avec autoSeed: false et un animal utilisateur
      final repoPre =
          AnimalsRepository(database: Future.value(db1), autoSeed: false);
      await repoPre.addAnimal(
        Animal(
          id: 'user_first',
          name: 'Premier Animal Éleveur',
          type: AnimalType.caprin,
          ageMonths: 10,
          weightKg: 25.0,
          healthStatus: HealthStatus.sain,
          expenses: const [],
          createdAt: DateTime(2026, 1, 1),
        ),
      );

      // Maintenant on exécute un repo standard avec autoSeed: true
      final repoStandard =
          AnimalsRepository(database: Future.value(db1), autoSeed: true);
      final all = await repoStandard.fetchAnimals();

      // Comme des données utilisateur existaient déjà, le seeding n'écrase rien
      expect(all.length, 1);
      expect(all.first.id, 'user_first');

      await db1.close();
    });

    // ─── Tests C : Intégrité et collisions ─────────────────────────────────────
    test('addAnimal throws StateError when ID already exists', () async {
      final animal1 = Animal(
        id: 'dup_01',
        name: 'Original',
        type: AnimalType.bovin,
        ageMonths: 12,
        weightKg: 200,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime(2026, 1, 1),
      );

      final animalDuplicate = Animal(
        id: 'dup_01',
        name: 'Imposteur',
        type: AnimalType.caprin,
        ageMonths: 6,
        weightKg: 20,
        healthStatus: HealthStatus.malade,
        expenses: const [],
        createdAt: DateTime(2026, 2, 1),
      );

      await repository.addAnimal(animal1);

      expect(
        () => repository.addAnimal(animalDuplicate),
        throwsA(isA<StateError>()),
      );

      // Vérifier que les données n'ont pas été écrasées
      final fetched = await repository.getAnimalById('dup_01');
      expect(fetched!.name, 'Original');
    });

    // ─── Tests D : Concurrence ────────────────────────────────────────────────
    test('Concurrent operations execute safely without corruption', () async {
      final animals = await repository.fetchAnimals();
      final target = animals.first;

      // Déclencher 5 ajouts de dépenses simultanés
      final futures = List.generate(5, (i) {
        return repository.addExpense(
          target.id,
          Expense(
            id: 'concurrent_$i',
            label: 'Dépense concurrente $i',
            amount: (i + 1) * 1000.0,
            date: DateTime.now(),
            category: ExpenseCategory.alimentation,
          ),
        );
      });

      final results = await Future.wait(futures);
      expect(results.length, 5);

      final updated = await repository.getAnimalById(target.id);
      expect(updated!.expenses.length, target.expenses.length + 5);
      for (var i = 0; i < 5; i++) {
        expect(updated.expenses.any((e) => e.id == 'concurrent_$i'), isTrue);
      }
    });

    // ─── Tests E : Mise à jour (updateAnimal) ─────────────────────────────────
    test('updateAnimal modifies animal, preserves ID, createdAt, and expenses',
        () async {
      final animals = await repository.fetchAnimals();
      final initialTotal = animals.length;
      final target = animals.firstWhere((a) => a.expenses.isNotEmpty);

      final modified = target.copyWith(
        name: 'Nouveau Nom Modifié',
        weightKg: 499.5,
        healthStatus: HealthStatus.aSurveiller,
        ageMonths: target.ageMonths + 6,
      );

      final result = await repository.updateAnimal(modified);
      expect(result.id, target.id);
      expect(result.name, 'Nouveau Nom Modifié');

      final fetched = await repository.getAnimalById(target.id);
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Nouveau Nom Modifié');
      expect(fetched.weightKg, 499.5);
      expect(fetched.healthStatus, HealthStatus.aSurveiller);
      expect(fetched.ageMonths, target.ageMonths + 6);
      expect(fetched.createdAt, target.createdAt);
      expect(fetched.expenses.length, target.expenses.length);

      // Aucune duplication
      final allAnimals = await repository.fetchAnimals();
      expect(allAnimals.length, initialTotal);
    });

    test('updateAnimal throws ArgumentError when animal ID does not exist',
        () async {
      final nonExistent = Animal(
        id: 'inexistant_id_888',
        name: 'Fantôme',
        type: AnimalType.bovin,
        ageMonths: 12,
        weightKg: 100,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime.now(),
      );

      expect(
        () => repository.updateAnimal(nonExistent),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Logical Deletion (Soft Delete) & Active Animals Filtering Tests', () {
    late Database testDb;
    late AnimalsRepository repository;

    setUp(() async {
      testDb = await AppDatabase.openInMemory(
        name: 'soft_delete_test_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      repository = AnimalsRepository(database: Future.value(testDb));
    });

    tearDown(() async {
      await testDb.close();
    });

    test(
        'deleteAnimal marks deletedAt, sets pendingDelete, and preserves local ID and data in Sembast',
        () async {
      // 1. Ajouter un animal réel avec des dépenses
      final animal = Animal(
        id: 'soft_del_01',
        name: 'Moussa',
        type: AnimalType.bovin,
        ageMonths: 20,
        weightKg: 250.0,
        healthStatus: HealthStatus.sain,
        expenses: [
          Expense(
            id: 'exp_soft_1',
            label: 'Aliment concentré',
            amount: 7500,
            date: DateTime(2026, 10, 1),
            category: ExpenseCategory.alimentation,
          ),
        ],
        createdAt: DateTime(2026, 1, 1),
      );
      await repository.addAnimal(animal);

      // 2. Supprimer logiquement
      final beforeDelete = DateTime.now().subtract(const Duration(seconds: 1));
      final success = await repository.deleteAnimal('soft_del_01');
      final afterDelete = DateTime.now().add(const Duration(seconds: 1));
      expect(success, isTrue);

      // 3. Vérifier que deletedAt est renseigné et que local ID reste inchangé
      final deletedRaw =
          await DatabaseMigrator.animalsStore.record('soft_del_01').get(testDb);
      expect(deletedRaw, isNotNull,
          reason: "L'animal doit rester physiquement présent dans Sembast");

      final deletedAnimal = Animal.fromMap(deletedRaw!);
      expect(deletedAnimal.id, 'soft_del_01',
          reason: "L'identifiant local doit rester inchangé");
      expect(deletedAnimal.deletedAt, isNotNull);
      expect(deletedAnimal.deletedAt!.isAfter(beforeDelete), isTrue);
      expect(deletedAnimal.deletedAt!.isBefore(afterDelete), isTrue);

      // 4. Vérifier que le statut devient pendingDelete
      expect(deletedAnimal.syncStatus, SyncStatus.pendingDelete);

      // 5. Vérifier que les dépenses sont strictement préservées
      expect(deletedAnimal.expenses.length, 1);
      expect(deletedAnimal.expenses.first.id, 'exp_soft_1');
      expect(deletedAnimal.expenses.first.amount, 7500);
      expect(deletedAnimal.totalExpenses, 7500);

      // 6. Vérifier l'exclusion des listes normales
      final activeAnimals = await repository.fetchAnimals();
      expect(activeAnimals.any((a) => a.id == 'soft_del_01'), isFalse);
      expect(await repository.getAnimalById('soft_del_01'), isNull);

      // 7. Vérifier que fetchAnimals(includeDeleted: true) et fetchDeletedAnimals le retournent
      final allAnimals = await repository.fetchAnimals(includeDeleted: true);
      expect(allAnimals.any((a) => a.id == 'soft_del_01'), isTrue);

      final deletedList = await repository.fetchDeletedAnimals();
      expect(deletedList.any((a) => a.id == 'soft_del_01'), isTrue);
      expect(
          await repository.getAnimalById('soft_del_01', includeDeleted: true),
          isNotNull);
    });

    test(
        'Active animals continue to appear when another animal is logically deleted',
        () async {
      final active1 = await repository.addAnimal(Animal(
        id: 'active_1',
        name: 'Vache Blanche',
        type: AnimalType.bovin,
        ageMonths: 15,
        weightKg: 200,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime.now(),
      ));
      final toDelete = await repository.addAnimal(Animal(
        id: 'to_delete_2',
        name: 'Vache Noire',
        type: AnimalType.bovin,
        ageMonths: 18,
        weightKg: 220,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime.now(),
      ));

      await repository.deleteAnimal(toDelete.id);

      final activeList = await repository.fetchAnimals();
      expect(activeList.any((a) => a.id == active1.id), isTrue);
      expect(activeList.any((a) => a.id == toDelete.id), isFalse);
    });

    test(
        'Repeated deletion is idempotent and does not corrupt or overwrite initial deletedAt',
        () async {
      await repository.addAnimal(Animal(
        id: 'idem_del',
        name: 'Chèvre Idempotente',
        type: AnimalType.caprin,
        ageMonths: 10,
        weightKg: 20,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime.now(),
      ));

      // Première suppression
      final del1 = await repository.deleteAnimal('idem_del');
      expect(del1, isTrue);

      final firstDeleted =
          await repository.getAnimalById('idem_del', includeDeleted: true);
      final initialDeletedAt = firstDeleted!.deletedAt!;

      // Délai court pour s'assurer que DateTime.now() avancerait si réécrit
      await Future.delayed(const Duration(milliseconds: 50));

      // Deuxième suppression
      final del2 = await repository.deleteAnimal('idem_del');
      expect(del2, isTrue);

      final secondDeleted =
          await repository.getAnimalById('idem_del', includeDeleted: true);
      expect(secondDeleted!.deletedAt, equals(initialDeletedAt),
          reason:
              "Le timestamp deletedAt initial doit être strictement préservé sans écrasement");
      expect(secondDeleted.syncStatus, SyncStatus.pendingDelete);
    });

    test('deleteAnimal returns false when animal does not exist', () async {
      final result = await repository.deleteAnimal('non_existent_id_999');
      expect(result, isFalse);
    });

    test('Modifying or adding expense to a deleted animal is rejected',
        () async {
      final animal = await repository.addAnimal(Animal(
        id: 'del_safeguard',
        name: 'Mouton Protégé',
        type: AnimalType.ovin,
        ageMonths: 12,
        weightKg: 40,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime.now(),
      ));

      await repository.deleteAnimal('del_safeguard');

      // Tentative de mise à jour
      expect(
        () => repository.updateAnimal(animal.copyWith(name: 'Nouveau Nom')),
        throwsA(isA<StateError>()),
      );

      // Tentative d'ajout de dépense
      expect(
        () => repository.addExpense(
          'del_safeguard',
          Expense(
            id: 'exp_forbidden',
            label: 'Test',
            amount: 1000,
            date: DateTime.now(),
            category: ExpenseCategory.autre,
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('Active demo animals remain intact when one demo animal is deleted',
        () async {
      // 12 animaux de démo initialement
      final initialAnimals = await repository.fetchAnimals();
      expect(initialAnimals.length, 12);

      // Supprimer un animal de démo (a001)
      final deleted = await repository.deleteAnimal('a001');
      expect(deleted, isTrue);

      // 11 animaux de démo restent actifs
      final remainingActive = await repository.fetchAnimals();
      expect(remainingActive.length, 11);
      expect(remainingActive.any((a) => a.id == 'a001'), isFalse);
      expect(remainingActive.every((a) => a.deletedAt == null), isTrue);

      // Vérifier que a001 est toujours dans Sembast avec deletedAt
      final a001InDb =
          await repository.getAnimalById('a001', includeDeleted: true);
      expect(a001InDb, isNotNull);
      expect(a001InDb!.deletedAt, isNotNull);
      expect(a001InDb.syncStatus, SyncStatus.pendingDelete);
      expect(a001InDb.expenses.length, 3); // 3 dépenses de Bakary préservées
    });
  });
}
