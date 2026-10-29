// test/unit/database_migration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:agritrack/data/animals_repository.dart';
import 'package:agritrack/data/database/app_database.dart';
import 'package:agritrack/data/database/database_migrator.dart';
import 'package:agritrack/models/animal.dart';
import 'package:agritrack/models/expense.dart';
import 'package:agritrack/models/farm.dart';

void main() {
  group('DatabaseMigrator & Multi-Farm Migration Tests', () {
    late Database testDb;

    setUp(() async {
      testDb = await AppDatabase.openInMemory(
        name: 'migrator_test_${DateTime.now().microsecondsSinceEpoch}.db',
      );
    });

    tearDown(() async {
      await testDb.close();
    });

    // ─── 1. Création de la ferme locale par défaut ───────────────────────────
    test('Migration creates default local farm when database is at version 1',
        () async {
      final initialVersion = await DatabaseMigrator.getSchemaVersion(testDb);
      expect(initialVersion, 1);

      final result = await DatabaseMigrator.migrate(testDb);
      expect(result.performedMigration, isTrue);
      expect(result.versionBefore, 1);
      expect(result.versionAfter, 5);
      expect(result.defaultFarmCreated, isTrue);

      final farmRaw = await DatabaseMigrator.farmsStore
          .record(DatabaseMigrator.defaultFarmId)
          .get(testDb);
      expect(farmRaw, isNotNull);

      final farm = Farm.fromMap(farmRaw!);
      expect(farm.id, DatabaseMigrator.defaultFarmId);
      expect(farm.name, DatabaseMigrator.defaultFarmName);
      expect(farm.isDemo, isFalse);
      expect(farm.createdAt, isA<DateTime>());
    });

    // ─── 2. Migration d'animaux anciens sans farmId ──────────────────────────
    test('Migration adds farmId to legacy animals missing farmId', () async {
      final legacyAnimal = {
        'id': 'legacy_bovin_01',
        'name': 'Bébé Bovin',
        'type': 'bovin',
        'ageMonths': 14,
        'weightKg': 240.0,
        'healthStatus': 'sain',
        'createdAt': '2026-01-10T08:00:00.000',
        'expenses': <Map<String, dynamic>>[],
      };

      await DatabaseMigrator.animalsStore
          .record('legacy_bovin_01')
          .put(testDb, legacyAnimal);

      final result = await DatabaseMigrator.migrate(testDb);
      expect(result.performedMigration, isTrue);
      expect(result.animalsMigrated, 1);

      final migratedRaw = await DatabaseMigrator.animalsStore
          .record('legacy_bovin_01')
          .get(testDb);
      expect(migratedRaw, isNotNull);
      expect(migratedRaw!['farmId'], DatabaseMigrator.defaultFarmId);
    });

    // ─── 3. Préservation des identifiants et des dépenses ─────────────────────
    test('Migration preserves all animal IDs, fields, and embedded expenses',
        () async {
      final legacyAnimalWithExpenses = {
        'id': 'user_sheep_42',
        'name': 'Bélier Spécial',
        'type': 'ovin',
        'ageMonths': 20,
        'weightKg': 65.5,
        'healthStatus': 'aSurveiller',
        'imageUrl': 'assets/images/ovin.jpg',
        'createdAt': '2026-03-15T12:00:00.000',
        'expenses': [
          {
            'id': 'exp_precise_01',
            'label': 'Sérum anti-venin',
            'amount': 28500.5,
            'date': '2026-04-01T10:30:00.000',
            'category': 'sante',
          },
          {
            'id': 'exp_precise_02',
            'label': 'Poudre vitaminée',
            'amount': 7200.0,
            'date': '2026-04-10T14:00:00.000',
            'category': 'alimentation',
          },
        ],
      };

      await DatabaseMigrator.animalsStore
          .record('user_sheep_42')
          .put(testDb, legacyAnimalWithExpenses);

      await DatabaseMigrator.migrate(testDb);

      final migratedRaw = await DatabaseMigrator.animalsStore
          .record('user_sheep_42')
          .get(testDb);
      expect(migratedRaw, isNotNull);

      final animal = Animal.fromMap(migratedRaw!);
      expect(animal.id, 'user_sheep_42');
      expect(animal.name, 'Bélier Spécial');
      expect(animal.type, AnimalType.ovin);
      expect(animal.ageMonths, 20);
      expect(animal.weightKg, 65.5);
      expect(animal.healthStatus, HealthStatus.aSurveiller);
      expect(animal.imageUrl, 'assets/images/ovin.jpg');
      expect(animal.createdAt, DateTime(2026, 3, 15, 12, 0));
      expect(animal.farmId, DatabaseMigrator.defaultFarmId);
      expect(animal.isDemo, isFalse);

      // Vérification rigoureuse des dépenses imbriquées
      expect(animal.expenses.length, 2);
      expect(animal.expenses[0].id, 'exp_precise_01');
      expect(animal.expenses[0].label, 'Sérum anti-venin');
      expect(animal.expenses[0].amount, 28500.5);
      expect(animal.expenses[0].category, ExpenseCategory.sante);

      expect(animal.expenses[1].id, 'exp_precise_02');
      expect(animal.expenses[1].label, 'Poudre vitaminée');
      expect(animal.expenses[1].amount, 7200.0);
      expect(animal.expenses[1].category, ExpenseCategory.alimentation);
      expect(animal.totalExpenses, 35700.5);
    });

    // ─── 4. Absence de duplication après plusieurs démarrages ─────────────────
    test('Migration is strictly idempotent across multiple runs', () async {
      final initialAnimal = {
        'id': 'animal_unique_1',
        'name': 'Unique',
        'type': 'caprin',
        'ageMonths': 10,
        'weightKg': 25.0,
        'healthStatus': 'sain',
        'createdAt': '2026-01-01T00:00:00.000',
        'expenses': <Map<String, dynamic>>[],
      };
      await DatabaseMigrator.animalsStore
          .record('animal_unique_1')
          .put(testDb, initialAnimal);

      // Première exécution
      final r1 = await DatabaseMigrator.migrate(testDb);
      expect(r1.performedMigration, isTrue);
      expect(r1.animalsMigrated, 1);

      // Deuxième exécution
      final r2 = await DatabaseMigrator.migrate(testDb);
      expect(r2.performedMigration, isFalse);
      expect(r2.versionBefore, 5);
      expect(r2.versionAfter, 5);

      // Troisième exécution
      final r3 = await DatabaseMigrator.migrate(testDb);
      expect(r3.performedMigration, isFalse);

      // Vérification du nombre de fermes et d'animaux
      final farmsCount = await DatabaseMigrator.farmsStore.count(testDb);
      final animalsCount = await DatabaseMigrator.animalsStore.count(testDb);
      expect(farmsCount, 1);
      expect(animalsCount, 1);
    });

    // ─── 5. Reprise sûre après un échec transactionnel ───────────────────────
    test('Transaction atomicity rolls back all changes if an error occurs',
        () async {
      final memoryFactory = newDatabaseFactoryMemory();
      final rollbackDb =
          await memoryFactory.openDatabase('test_rollback_atomic.db');
      addTearDown(() => rollbackDb.close());

      // Écriture d'un animal ancien
      await DatabaseMigrator.animalsStore.record('a_pre').put(rollbackDb, {
        'id': 'a_pre',
        'name': 'Pre',
        'type': 'bovin',
        'ageMonths': 12,
        'weightKg': 200.0,
        'healthStatus': 'sain',
        'createdAt': '2026-01-01T00:00:00.000',
        'expenses': [],
      });

      // Simulation d'une transaction interrompue
      try {
        await rollbackDb.transaction((txn) async {
          await DatabaseMigrator.farmsStore.record('temp_farm').put(txn, {
            'id': 'temp_farm',
            'name': 'Ferme Temporaire',
            'createdAt': DateTime.now().toIso8601String(),
          });
          throw Exception('Erreur imprévue pendant la migration');
        });
      } catch (_) {}

      // Vérification que le store farms est resté vide
      final farmExists =
          await DatabaseMigrator.farmsStore.record('temp_farm').get(rollbackDb);
      expect(farmExists, isNull);

      // Ensuite, la vraie migration réussit proprement
      final result = await DatabaseMigrator.migrate(rollbackDb);
      expect(result.performedMigration, isTrue);

      final defaultFarm = await DatabaseMigrator.farmsStore
          .record(DatabaseMigrator.defaultFarmId)
          .get(rollbackDb);
      expect(defaultFarm, isNotNull);
    });

    // ─── 6. Distinction entre les données de démo et les réelles ─────────────
    test(
        'Only historical seed IDs are marked isDemo: true, user animals remain real',
        () async {
      // Insertion d'un lot mixte avant migration
      final testAnimals = [
        // IDs du seed officiel
        {
          'id': 'a001',
          'name': 'Bakary',
          'type': 'bovin',
          'ageMonths': 36,
          'weightKg': 320.0,
          'healthStatus': 'sain',
          'createdAt': '2026-01-15T00:00:00.000',
        },
        {
          'id': 'a012',
          'name': 'Djata',
          'type': 'bovin',
          'ageMonths': 8,
          'weightKg': 115.0,
          'healthStatus': 'sain',
          'createdAt': '2026-09-15T00:00:00.000',
        },
        // Animaux créés par l'utilisateur (même avec un ID commençant par 'a')
        {
          'id': 'a_custom_eleveur_01',
          'name': 'Bovin Éleveur',
          'type': 'bovin',
          'ageMonths': 15,
          'weightKg': 210.0,
          'healthStatus': 'sain',
          'createdAt': '2026-05-01T00:00:00.000',
        },
        {
          'id': 'chevre_senegalaise_99',
          'name': 'Chèvre Locale',
          'type': 'caprin',
          'ageMonths': 18,
          'weightKg': 30.0,
          'healthStatus': 'sain',
          'createdAt': '2026-06-01T00:00:00.000',
        },
      ];

      for (final raw in testAnimals) {
        await DatabaseMigrator.animalsStore
            .record(raw['id'] as String)
            .put(testDb, raw);
      }

      await DatabaseMigrator.migrate(testDb);

      final a001 = Animal.fromMap(
          (await DatabaseMigrator.animalsStore.record('a001').get(testDb))!);
      final a012 = Animal.fromMap(
          (await DatabaseMigrator.animalsStore.record('a012').get(testDb))!);
      final custom1 = Animal.fromMap((await DatabaseMigrator.animalsStore
          .record('a_custom_eleveur_01')
          .get(testDb))!);
      final custom2 = Animal.fromMap((await DatabaseMigrator.animalsStore
          .record('chevre_senegalaise_99')
          .get(testDb))!);

      // Démo
      expect(a001.isDemo, isTrue);
      expect(a012.isDemo, isTrue);

      // Réelles
      expect(custom1.isDemo, isFalse);
      expect(custom2.isDemo, isFalse);
    });

    // ─── 7. Migration v2 -> v3 : Statut de synchronisation & remoteId ─────────
    test(
        'Migration v2 to v3 assigns default syncStatus to animals and expenses',
        () async {
      // Préparer une base au schéma v2
      await DatabaseMigrator.metadataStore.record('schema').put(testDb, {
        'version': 2,
        'migratedAt': '2026-10-20T10:00:00.000',
      });

      // Insérer un animal sans syncStatus ni remoteId (état v2 typique)
      final v2Animal = {
        'id': 'anim_v2_migration',
        'farmId': DatabaseMigrator.defaultFarmId,
        'name': 'Taureau V2',
        'type': 'bovin',
        'ageMonths': 24,
        'weightKg': 350.0,
        'healthStatus': 'sain',
        'isDemo': false,
        'createdAt': '2026-10-01T08:00:00.000',
        'expenses': [
          {
            'id': 'exp_v2_1',
            'label': 'Fourrage sec',
            'amount': 12000.0,
            'date': '2026-10-02T09:00:00.000',
            'category': 'alimentation',
          },
        ],
      };
      await DatabaseMigrator.animalsStore
          .record('anim_v2_migration')
          .put(testDb, v2Animal);

      // Exécuter la migration
      final initialVersion = await DatabaseMigrator.getSchemaVersion(testDb);
      expect(initialVersion, 2);

      final result = await DatabaseMigrator.migrate(testDb);
      expect(result.performedMigration, isTrue);
      expect(result.versionBefore, 2);
      expect(result.versionAfter, 5);
      expect(result.animalsMigrated, 1);

      // Recharger l'enregistrement migré
      final raw = await DatabaseMigrator.animalsStore
          .record('anim_v2_migration')
          .get(testDb);
      expect(raw, isNotNull);

      final migratedAnimal = Animal.fromMap(raw!);
      expect(migratedAnimal.id, 'anim_v2_migration');
      expect(migratedAnimal.syncStatus, SyncStatus.synced);
      expect(migratedAnimal.remoteId, isNull);
      expect(migratedAnimal.isDemo, isFalse);
      expect(migratedAnimal.farmId, DatabaseMigrator.defaultFarmId);

      // Vérifier les dépenses imbriquées migrées
      expect(migratedAnimal.expenses.length, 1);
      final expense = migratedAnimal.expenses.first;
      expect(expense.id, 'exp_v2_1');
      expect(expense.syncStatus, SyncStatus.synced);
      expect(expense.remoteId, isNull);
      expect(expense.amount, 12000.0);
    });

    test('Migration v2 to v4 preserves existing remoteId and custom syncStatus',
        () async {
      await DatabaseMigrator.metadataStore.record('schema').put(testDb, {
        'version': 2,
        'migratedAt': '2026-10-20T10:00:00.000',
      });

      // Animal possédant déjà un remoteId et un syncStatus explicite
      final animalWithRemote = {
        'id': 'anim_with_remote',
        'farmId': DatabaseMigrator.defaultFarmId,
        'remoteId': '550e8400-e29b-41d4-a716-446655440000',
        'syncStatus': 'pendingUpdate',
        'name': 'Génisse Alpha',
        'type': 'bovin',
        'ageMonths': 16,
        'weightKg': 210.0,
        'healthStatus': 'aSurveiller',
        'isDemo': false,
        'createdAt': '2026-10-05T08:00:00.000',
        'expenses': [
          {
            'id': 'exp_pending',
            'remoteId': '6ba7b810-9dad-11d1-80b4-00c04fd430c8',
            'syncStatus': 'pendingCreate',
            'label': 'Vaccin',
            'amount': 5000.0,
            'date': '2026-10-06T09:00:00.000',
            'category': 'sante',
          },
        ],
      };
      await DatabaseMigrator.animalsStore
          .record('anim_with_remote')
          .put(testDb, animalWithRemote);

      final result = await DatabaseMigrator.migrate(testDb);
      expect(result.performedMigration, isTrue);
      expect(result.versionAfter, 5);

      final raw = await DatabaseMigrator.animalsStore
          .record('anim_with_remote')
          .get(testDb);
      final animal = Animal.fromMap(raw!);
      expect(animal.remoteId, '550e8400-e29b-41d4-a716-446655440000');
      expect(animal.syncStatus, SyncStatus.pendingUpdate);
      expect(animal.expenses.first.remoteId,
          '6ba7b810-9dad-11d1-80b4-00c04fd430c8');
      expect(animal.expenses.first.syncStatus, SyncStatus.pendingCreate);
    });

    test(
        'Migration preserves the 12 demo animals and their 25 expenses with syncStatus: synced',
        () async {
      // Seeding initial
      final seededRepo = AnimalsRepository(
        database: Future.value(testDb),
        autoSeed: true,
      );
      final animals = await seededRepo.fetchAnimals();
      expect(animals.length, 12);

      // Calcul du total des dépenses de démo
      final totalExpensesCount =
          animals.fold<int>(0, (sum, a) => sum + a.expenses.length);
      expect(totalExpensesCount, 25);

      // Vérifier que tous sont migrés au schéma v5 avec syncStatus == synced
      final currentVersion = await DatabaseMigrator.getSchemaVersion(testDb);
      expect(currentVersion, 5);

      for (final a in animals) {
        expect(a.syncStatus, SyncStatus.synced);
        expect(a.remoteId, isNull);
        expect(a.isDemo, isTrue);
        expect(a.versionId, 1);
        expect(DatabaseMigrator.knownDemoAnimalIds.contains(a.id), isTrue);
        for (final exp in a.expenses) {
          expect(exp.syncStatus, SyncStatus.synced);
          expect(exp.remoteId, isNull);
          expect(exp.versionId, 1);
        }
      }
    });

    // ─── 8. Migration v3 -> v4 : Création du store sync_queue sans auto-enqueue ───
    test(
        'Migration v3 to v4 initializes sync_queue store, does not auto-populate queue, and preserves all data',
        () async {
      // Préparer une base au schéma v3 avec un animal et une dépense
      await DatabaseMigrator.metadataStore.record('schema').put(testDb, {
        'version': 3,
        'migratedAt': '2026-10-25T10:00:00.000',
      });
      await DatabaseMigrator.farmsStore.record('farm_v3_test').put(testDb, {
        'id': 'farm_v3_test',
        'name': 'Ferme V3',
        'createdAt': '2026-10-25T10:00:00.000',
      });
      await DatabaseMigrator.animalsStore.record('anim_v3_1').put(testDb, {
        'id': 'anim_v3_1',
        'farmId': 'farm_v3_test',
        'name': 'Brebis V3',
        'type': 'ovin',
        'ageMonths': 12,
        'weightKg': 40.0,
        'healthStatus': 'sain',
        'syncStatus': 'synced',
        'remoteId': 'remote-uuid-1234',
        'createdAt': '2026-10-25T10:00:00.000',
        'expenses': [
          {
            'id': 'exp_v3_1',
            'farmId': 'farm_v3_test',
            'animalId': 'anim_v3_1',
            'label': 'Soin',
            'amount': 5000.0,
            'date': '2026-10-25T11:00:00.000',
            'category': 'sante',
            'syncStatus': 'synced',
          }
        ],
      });

      final initialVersion = await DatabaseMigrator.getSchemaVersion(testDb);
      expect(initialVersion, 3);

      final result = await DatabaseMigrator.migrate(testDb);
      expect(result.performedMigration, isTrue);
      expect(result.versionBefore, 3);
      expect(result.versionAfter, 5);

      // Le store sync_queue existe et est vide (aucun enqueue automatique)
      final queueCount = await DatabaseMigrator.syncQueueStore.count(testDb);
      expect(queueCount, 0);

      // Les données de l'animal et de la ferme sont parfaitement préservées
      final farmRaw =
          await DatabaseMigrator.farmsStore.record('farm_v3_test').get(testDb);
      expect(farmRaw, isNotNull);
      expect(farmRaw!['name'], 'Ferme V3');

      final animalRaw =
          await DatabaseMigrator.animalsStore.record('anim_v3_1').get(testDb);
      expect(animalRaw, isNotNull);
      final animal = Animal.fromMap(animalRaw!);
      expect(animal.name, 'Brebis V3');
      expect(animal.remoteId, 'remote-uuid-1234');
      expect(animal.expenses.length, 1);
      expect(animal.expenses.first.label, 'Soin');
    });

    // ─── 9. Migration v4 -> v5 : Store conflicts et versionId optimiste ──────
    test(
        'Migration v4 to v5 sets versionId to 1 for existing animals and expenses and creates conflicts store',
        () async {
      await DatabaseMigrator.metadataStore.record('schema').put(testDb, {
        'version': 4,
        'migratedAt': '2026-10-26T10:00:00.000',
      });
      await DatabaseMigrator.farmsStore.record('farm_v4_test').put(testDb, {
        'id': 'farm_v4_test',
        'name': 'Ferme V4',
        'createdAt': '2026-10-26T10:00:00.000',
      });
      await DatabaseMigrator.animalsStore.record('anim_v4_1').put(testDb, {
        'id': 'anim_v4_1',
        'farmId': 'farm_v4_test',
        'name': 'Brebis V4',
        'type': 'ovin',
        'ageMonths': 14,
        'weightKg': 42.0,
        'healthStatus': 'sain',
        'syncStatus': 'synced',
        'createdAt': '2026-10-26T10:00:00.000',
        'expenses': [
          {
            'id': 'exp_v4_1',
            'farmId': 'farm_v4_test',
            'animalId': 'anim_v4_1',
            'label': 'Soin V4',
            'amount': 3500.0,
            'date': '2026-10-26T11:00:00.000',
            'category': 'sante',
            'syncStatus': 'synced',
          }
        ],
      });

      final initialVersion = await DatabaseMigrator.getSchemaVersion(testDb);
      expect(initialVersion, 4);

      final result = await DatabaseMigrator.migrate(testDb);
      expect(result.performedMigration, isTrue);
      expect(result.versionBefore, 4);
      expect(result.versionAfter, 5);

      final conflictsCount =
          await DatabaseMigrator.conflictsStore.count(testDb);
      expect(conflictsCount, 0);

      final animalRaw =
          await DatabaseMigrator.animalsStore.record('anim_v4_1').get(testDb);
      expect(animalRaw, isNotNull);
      final animal = Animal.fromMap(animalRaw!);
      expect(animal.versionId, 1);
      expect(animal.expenses.first.versionId, 1);
    });
  });

  group('AnimalsRepository Multi-Farm & CRUD Operations', () {
    late Database testDb;
    late AnimalsRepository repository;

    setUp(() async {
      testDb = await AppDatabase.openInMemory(
        name: 'repo_multifarm_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      repository = AnimalsRepository(
        database: Future.value(testDb),
        autoSeed: false,
      );
    });

    tearDown(() async {
      await testDb.close();
    });

    // ─── 7. Gestion complète des fermes (CRUD) ────────────────────────────────
    test(
        'Farm CRUD: createFarm, getFarmById, fetchFarms, updateFarm, farmExists',
        () async {
      // 1. Initialement, la ferme par défaut a été créée par la migration
      final initialFarms = await repository.fetchFarms();
      expect(initialFarms.length, 1);
      expect(initialFarms.first.id, DatabaseMigrator.defaultFarmId);
      expect(
          await repository.farmExists(DatabaseMigrator.defaultFarmId), isTrue);
      expect(await repository.farmExists('inexistant_farm'), isFalse);

      // 2. Créer une nouvelle ferme
      final newFarm = Farm(
        id: 'farm_niayes_01',
        name: 'Ferme des Niayes',
        region: 'Thiès',
        isDemo: false,
        createdAt: DateTime(2026, 5, 1),
      );
      final created = await repository.createFarm(newFarm);
      expect(created.id, 'farm_niayes_01');

      // 3. Lire par ID
      final fetched = await repository.getFarmById('farm_niayes_01');
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Ferme des Niayes');
      expect(fetched.region, 'Thiès');

      // 4. Lister toutes les fermes
      final allFarms = await repository.fetchFarms();
      expect(allFarms.length, 2);

      // 5. Mettre à jour une ferme
      final updated = await repository.updateFarm(
        fetched.copyWith(name: 'Ferme des Niayes Bio', region: 'Thiès Sud'),
      );
      expect(updated.name, 'Ferme des Niayes Bio');
      expect(updated.region, 'Thiès Sud');
      expect(updated.createdAt, DateTime(2026, 5, 1)); // Préservé

      // 6. Gestion d'erreurs
      expect(
        () => repository.createFarm(newFarm),
        throwsA(isA<StateError>()),
      );
      expect(
        () => repository.updateFarm(
          Farm(
            id: 'fantome',
            name: 'Non existante',
            createdAt: DateTime.now(),
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    // ─── 8. Filtrage par farmId et isolation multi-fermes ─────────────────────
    test('Filtering and isolation between two farms', () async {
      // Créer deux fermes
      await repository.createFarm(Farm(
        id: 'farm_a',
        name: 'Ferme A',
        createdAt: DateTime.now(),
      ));
      await repository.createFarm(Farm(
        id: 'farm_b',
        name: 'Ferme B',
        createdAt: DateTime.now(),
      ));

      // Ajouter 2 animaux dans la ferme A
      await repository.addAnimal(
        Animal(
          id: 'a_farm_a_1',
          name: 'Vache Alpha',
          type: AnimalType.bovin,
          ageMonths: 24,
          weightKg: 300,
          healthStatus: HealthStatus.sain,
          expenses: const [],
          createdAt: DateTime.now(),
        ),
        targetFarmId: 'farm_a',
      );
      await repository.addAnimal(
        Animal(
          id: 'a_farm_a_2',
          name: 'Vache Beta',
          type: AnimalType.bovin,
          ageMonths: 18,
          weightKg: 280,
          healthStatus: HealthStatus.sain,
          expenses: const [],
          createdAt: DateTime.now(),
        ),
        targetFarmId: 'farm_a',
      );

      // Ajouter 1 animal dans la ferme B
      await repository.addAnimal(
        Animal(
          id: 'a_farm_b_1',
          name: 'Mouton Gamma',
          type: AnimalType.ovin,
          ageMonths: 12,
          weightKg: 45,
          healthStatus: HealthStatus.sain,
          expenses: const [],
          createdAt: DateTime.now(),
        ),
        targetFarmId: 'farm_b',
      );

      // Vérifier le filtrage
      final animalsFarmA = await repository.fetchAnimals(farmId: 'farm_a');
      final animalsFarmB = await repository.fetchAnimals(farmId: 'farm_b');
      final allAnimals = await repository.fetchAnimals(); // Sans filtre

      expect(animalsFarmA.length, 2);
      expect(animalsFarmA.every((a) => a.farmId == 'farm_a'), isTrue);

      expect(animalsFarmB.length, 1);
      expect(animalsFarmB.first.id, 'a_farm_b_1');
      expect(animalsFarmB.first.farmId, 'farm_b');

      expect(allAnimals.length, 3);

      // Vérifier l'isolation lors d'une suppression
      await repository.deleteAnimal('a_farm_a_1');

      final animalsFarmAAfter = await repository.fetchAnimals(farmId: 'farm_a');
      final animalsFarmBAfter = await repository.fetchAnimals(farmId: 'farm_b');

      expect(animalsFarmAAfter.length, 1);
      expect(animalsFarmBAfter.length, 1); // Ferme B totalement inchangée
    });

    // ─── 9. Propagation automatique de farmId aux dépenses ───────────────────
    test(
        'addExpense automatically associates animalId and farmId to the expense',
        () async {
      await repository.createFarm(Farm(
        id: 'farm_kolda',
        name: 'Ferme Kolda',
        createdAt: DateTime.now(),
      ));

      final animal = await repository.addAnimal(
        Animal(
          id: 'anim_kolda_1',
          farmId: 'farm_kolda',
          name: 'Taureau Kolda',
          type: AnimalType.bovin,
          ageMonths: 30,
          weightKg: 400,
          healthStatus: HealthStatus.sain,
          expenses: const [],
          createdAt: DateTime.now(),
        ),
      );

      final addedExpense = await repository.addExpense(
        animal.id,
        Expense(
          id: 'exp_auto_ids',
          label: 'Aliment concentré',
          amount: 15000,
          date: DateTime.now(),
          category: ExpenseCategory.alimentation,
        ),
      );

      expect(addedExpense.animalId, 'anim_kolda_1');
      expect(addedExpense.farmId, 'farm_kolda');

      final reloadedAnimal = await repository.getAnimalById(animal.id);
      expect(reloadedAnimal!.expenses.first.animalId, 'anim_kolda_1');
      expect(reloadedAnimal.expenses.first.farmId, 'farm_kolda');
    });

    // ─── 10. Fonctionnement du seed existant avec la nouvelle architecture ───
    test(
        'Default autoSeed populates 12 demo animals tagged with defaultFarm and isDemo',
        () async {
      final seededRepo = AnimalsRepository(
        database: Future.value(testDb),
        autoSeed: true,
      );

      final animals = await seededRepo.fetchAnimals();
      expect(animals.length, 12);
      expect(animals.every((a) => a.farmId == DatabaseMigrator.defaultFarmId),
          isTrue);
      expect(animals.every((a) => a.isDemo == true), isTrue);

      final farms = await seededRepo.fetchFarms();
      expect(farms.length, 1);
      expect(farms.first.id, DatabaseMigrator.defaultFarmId);
    });
  });
}
