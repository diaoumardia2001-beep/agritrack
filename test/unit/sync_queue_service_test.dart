// test/unit/sync_queue_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:agritrack/data/database/database_migrator.dart';
import 'package:agritrack/models/animal.dart';
import 'package:agritrack/models/expense.dart';
import 'package:agritrack/models/sync_queue_operation.dart';
import 'package:agritrack/services/sync/sync_queue_service.dart';

void main() {
  group('SyncQueueService & sync_queue Store Tests', () {
    late Database testDb;
    late SyncQueueService syncQueueService;
    late DatabaseFactory memoryFactory;
    late String dbName;

    setUp(() async {
      memoryFactory = newDatabaseFactoryMemory();
      dbName = 'test_sync_queue_${DateTime.now().microsecondsSinceEpoch}.db';
      testDb = await memoryFactory.openDatabase(dbName);
      await DatabaseMigrator.migrate(testDb);
      syncQueueService = SyncQueueService(database: Future.value(testDb));
    });

    tearDown(() async {
      await testDb.close();
    });

    // ─── 1. Création et lecture d'une opération ──────────────────────────────
    test(
        '1. Enqueue creates and persists a valid operation with pending status',
        () async {
      final op = await syncQueueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'animal_test_1',
        action: SyncAction.create,
        farmId: 'farm_cloud_alpha',
        userId: 'user_uuid_101',
        payload: {
          'name': 'Belle Vache',
          'type': 'bovin',
          'ageMonths': 24,
          'weightKg': 320.0,
        },
      );

      expect(op, isNotNull);
      expect(op!.entityType, SyncEntityType.animal);
      expect(op.localId, 'animal_test_1');
      expect(op.action, SyncAction.create);
      expect(op.farmId, 'farm_cloud_alpha');
      expect(op.userId, 'user_uuid_101');
      expect(op.status, SyncOperationStatus.pending);
      expect(op.retryCount, 0);
      expect(op.lastAttemptAt, isNull);
      expect(op.lastErrorMessage, isNull);
      expect(op.payload?['name'], 'Belle Vache');

      // Lecture par ID
      final retrieved = await syncQueueService.getOperationById(op.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.id, op.id);
      expect(retrieved.localId, 'animal_test_1');
      expect(retrieved.payload?['type'], 'bovin');
    });

    // ─── 2. Persistance après réouverture de la base ─────────────────────────
    test('2. Operations persist across database close and reopen', () async {
      final persistentDbName =
          'reopen_test_${DateTime.now().microsecondsSinceEpoch}.db';
      var db = await memoryFactory.openDatabase(persistentDbName);
      await DatabaseMigrator.migrate(db);
      var service = SyncQueueService(database: Future.value(db));

      final created = await service.enqueue(
        entityType: SyncEntityType.expense,
        localId: 'exp_persisted_99',
        action: SyncAction.create,
        farmId: 'farm_cloud_beta',
        userId: 'user_uuid_202',
        payload: {
          'label': 'Achat Fourrage',
          'amount': 45000.0,
          'category': 'alimentation',
        },
      );
      expect(created, isNotNull);

      // Fermeture complète de la base
      await db.close();

      // Réouverture de la même base
      db = await memoryFactory.openDatabase(persistentDbName);
      service = SyncQueueService(database: Future.value(db));

      final reloaded = await service.getOperationById(created!.id);
      expect(reloaded, isNotNull);
      expect(reloaded!.id, created.id);
      expect(reloaded.localId, 'exp_persisted_99');
      expect(reloaded.payload?['label'], 'Achat Fourrage');
      expect(reloaded.payload?['amount'], 45000.0);

      await db.close();
    });

    // ─── 3. Filtrage par exploitation et par utilisateur ─────────────────────
    test('3. Filtering by farmId and userId returns only matching operations',
        () async {
      await syncQueueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'anim_user1_farm1',
        action: SyncAction.create,
        farmId: 'farm_one',
        userId: 'user_one',
      );
      await syncQueueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'anim_user2_farm1',
        action: SyncAction.create,
        farmId: 'farm_one',
        userId: 'user_two',
      );
      await syncQueueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'anim_user1_farm2',
        action: SyncAction.create,
        farmId: 'farm_two',
        userId: 'user_one',
      );

      // Par ferme
      final farm1Ops = await syncQueueService.getOperationsByFarm('farm_one');
      expect(farm1Ops.length, 2);
      expect(farm1Ops.every((o) => o.farmId == 'farm_one'), isTrue);

      final farm2Ops = await syncQueueService.getOperationsByFarm('farm_two');
      expect(farm2Ops.length, 1);
      expect(farm2Ops.first.localId, 'anim_user1_farm2');

      // Par utilisateur
      final user1Ops = await syncQueueService.getOperationsByUser('user_one');
      expect(user1Ops.length, 2);
      expect(user1Ops.every((o) => o.userId == 'user_one'), isTrue);

      final user2Ops = await syncQueueService.getOperationsByUser('user_two');
      expect(user2Ops.length, 1);
      expect(user2Ops.first.localId, 'anim_user2_farm1');

      // Pending combiné (farmId + userId)
      final specificPending = await syncQueueService.getPendingOperations(
        farmId: 'farm_one',
        userId: 'user_one',
      );
      expect(specificPending.length, 1);
      expect(specificPending.first.localId, 'anim_user1_farm1');
    });

    // ─── 4. Gestion des tentatives et des erreurs ─────────────────────────────
    test(
        '4. recordFailure increments retryCount, updates lastErrorMessage, and does not drop operation',
        () async {
      final op = await syncQueueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'anim_retry_test',
        action: SyncAction.create,
        farmId: 'farm_cloud_retry',
      );
      expect(op, isNotNull);
      expect(op!.retryCount, 0);

      // Première erreur
      await syncQueueService.recordFailure(
        op.id,
        'Réseau indisponible (SocketException)',
      );

      var updated = await syncQueueService.getOperationById(op.id);
      expect(updated, isNotNull);
      expect(updated!.status, SyncOperationStatus.error);
      expect(updated.retryCount, 1);
      expect(updated.lastErrorMessage, 'Réseau indisponible (SocketException)');
      expect(updated.lastAttemptAt, isNotNull);

      // Deuxième erreur
      await syncQueueService.recordFailure(
        op.id,
        '504 Gateway Timeout',
      );

      updated = await syncQueueService.getOperationById(op.id);
      expect(updated, isNotNull);
      expect(updated!.status, SyncOperationStatus.error);
      expect(updated.retryCount, 2);
      expect(updated.lastErrorMessage, '504 Gateway Timeout');

      // L'opération reste récupérable parmi les opérations en attente
      final pendingList = await syncQueueService.getPendingOperations();
      expect(pendingList.any((o) => o.id == op.id), isTrue);
    });

    // ─── 5. Transition des statuts ───────────────────────────────────────────
    test('5. Status transitions: pending -> inProgress -> error', () async {
      final op = await syncQueueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'anim_transition',
        action: SyncAction.create,
        farmId: 'farm_transition',
      );
      expect(op!.status, SyncOperationStatus.pending);

      // Passage en cours
      await syncQueueService.markInProgress(op.id);
      var current = await syncQueueService.getOperationById(op.id);
      expect(current!.status, SyncOperationStatus.inProgress);
      expect(current.lastAttemptAt, isNotNull);

      // En cours n'est pas dans getPendingOperations
      final pending = await syncQueueService.getPendingOperations();
      expect(pending.any((o) => o.id == op.id), isFalse);

      // Échec : passage en error
      await syncQueueService.recordFailure(op.id, 'Erreur de connexion');
      current = await syncQueueService.getOperationById(op.id);
      expect(current!.status, SyncOperationStatus.error);

      // Les opérations en erreur réapparaissent dans getPendingOperations
      final pendingAfterError = await syncQueueService.getPendingOperations();
      expect(pendingAfterError.any((o) => o.id == op.id), isTrue);
    });

    // ─── 6. Suppression d'une opération terminée ─────────────────────────────
    test('6. completeOperation removes the finished operation from the queue',
        () async {
      final op = await syncQueueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'anim_to_complete',
        action: SyncAction.create,
        farmId: 'farm_complete',
      );
      expect(op, isNotNull);

      final success = await syncQueueService.completeOperation(op!.id);
      expect(success, isTrue);

      final check = await syncQueueService.getOperationById(op.id);
      expect(check, isNull);

      final total = await syncQueueService.count();
      expect(total, 0);
    });

    // ─── 7. Idempotence et prévention des doublons ───────────────────────────
    test(
        '7a. create followed by update merges payloads into existing create operation',
        () async {
      final initial = await syncQueueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'anim_coalesce_1',
        action: SyncAction.create,
        farmId: 'farm_coalesce',
        payload: {'name': 'Nom Initial', 'weightKg': 200.0},
      );
      expect(initial, isNotNull);

      final updated = await syncQueueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'anim_coalesce_1',
        action: SyncAction.update,
        farmId: 'farm_coalesce',
        payload: {'name': 'Nom Modifié', 'ageMonths': 18},
      );
      expect(updated, isNotNull);
      expect(updated!.id, initial!.id);
      expect(updated.action, SyncAction.create); // Toujours create!
      expect(updated.payload?['name'], 'Nom Modifié');
      expect(updated.payload?['weightKg'], 200.0);
      expect(updated.payload?['ageMonths'], 18);

      final total = await syncQueueService.count();
      expect(total, 1);
    });

    test(
        '7b. create followed by delete neutralizes local creation and cancels pending expenses',
        () async {
      // Animal créé localement
      final animOp = await syncQueueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'anim_ephemeral_1',
        action: SyncAction.create,
        farmId: 'farm_coalesce',
      );
      expect(animOp, isNotNull);

      // Dépense rattachée à cet animal en attente
      final expOp = await syncQueueService.enqueue(
        entityType: SyncEntityType.expense,
        localId: 'exp_ephemeral_1',
        action: SyncAction.create,
        farmId: 'farm_coalesce',
        payload: {'animalId': 'anim_ephemeral_1', 'amount': 1000.0},
      );
      expect(expOp, isNotNull);
      expect(await syncQueueService.count(), 2);

      // L'animal est supprimé avant toute synchronisation distante
      final deleteResult = await syncQueueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'anim_ephemeral_1',
        action: SyncAction.delete,
        farmId: 'farm_coalesce',
      );

      // Neutralisation complète : ni création ni suppression envoyée au cloud
      expect(deleteResult, isNull);

      final remaining = await syncQueueService.getAllOperations();
      expect(remaining.isEmpty, isTrue);
    });

    test('7c. multiple successive updates coalesce into single update',
        () async {
      final initial = await syncQueueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'anim_multi_update',
        action: SyncAction.update,
        farmId: 'farm_coalesce',
        payload: {'healthStatus': 'aSurveiller'},
      );
      expect(initial, isNotNull);

      final second = await syncQueueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'anim_multi_update',
        action: SyncAction.update,
        farmId: 'farm_coalesce',
        payload: {'healthStatus': 'sain', 'weightKg': 250.0},
      );
      expect(second, isNotNull);
      expect(second!.id, initial!.id);
      expect(second.action, SyncAction.update);
      expect(second.payload?['healthStatus'], 'sain');
      expect(second.payload?['weightKg'], 250.0);

      expect(await syncQueueService.count(), 1);
    });

    test('7d. update followed by delete replaces update with delete operation',
        () async {
      final updateOp = await syncQueueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'anim_up_then_del',
        action: SyncAction.update,
        farmId: 'farm_coalesce',
        payload: {'name': 'Changement'},
      );
      expect(updateOp, isNotNull);

      final deleteOp = await syncQueueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'anim_up_then_del',
        action: SyncAction.delete,
        farmId: 'farm_coalesce',
      );
      expect(deleteOp, isNotNull);
      expect(deleteOp!.id, updateOp!.id);
      expect(deleteOp.action, SyncAction.delete);

      expect(await syncQueueService.count(), 1);
    });

    test('7e. duplicate delete operations are idempotent', () async {
      final del1 = await syncQueueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'anim_double_del',
        action: SyncAction.delete,
        farmId: 'farm_coalesce',
      );
      expect(del1, isNotNull);

      final del2 = await syncQueueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'anim_double_del',
        action: SyncAction.delete,
        farmId: 'farm_coalesce',
      );
      expect(del2, isNotNull);
      expect(del2!.id, del1!.id);
      expect(await syncQueueService.count(), 1);
    });

    // ─── 8. Isolation des exploitations ──────────────────────────────────────
    test('8. Strict isolation: operations on Farm A do not affect Farm B',
        () async {
      await syncQueueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'anim_100',
        action: SyncAction.create,
        farmId: 'farm_saloum',
      );
      await syncQueueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'anim_100',
        action: SyncAction.create,
        farmId: 'farm_casamance',
      );

      final saloumOps =
          await syncQueueService.getOperationsByFarm('farm_saloum');
      final casamanceOps =
          await syncQueueService.getOperationsByFarm('farm_casamance');

      expect(saloumOps.length, 1);
      expect(casamanceOps.length, 1);
      expect(saloumOps.first.farmId, 'farm_saloum');
      expect(casamanceOps.first.farmId, 'farm_casamance');
      expect(saloumOps.first.id != casamanceOps.first.id, isTrue);
    });

    // ─── 9. Refus des données de démonstration ───────────────────────────────
    test(
        '9. Rejection of demo animals (a001-a012), demo expenses (e001-e025), isDemo flag, and local_default_farm',
        () async {
      // 1. Animaux de démo par ID
      for (final id in DatabaseMigrator.knownDemoAnimalIds) {
        final res = await syncQueueService.enqueue(
          entityType: SyncEntityType.animal,
          localId: id,
          action: SyncAction.create,
          farmId: 'farm_cloud_valid',
        );
        expect(res, isNull, reason: 'Animal de démo $id doit être refusé');
      }

      // 2. Dépenses de démo par ID
      for (final id in DatabaseMigrator.knownDemoExpenseIds) {
        final res = await syncQueueService.enqueue(
          entityType: SyncEntityType.expense,
          localId: id,
          action: SyncAction.create,
          farmId: 'farm_cloud_valid',
        );
        expect(res, isNull, reason: 'Dépense de démo $id doit être refusée');
      }

      // 3. Flag isDemo explicite
      final explicitDemo = await syncQueueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'custom_animal_marked_demo',
        action: SyncAction.create,
        farmId: 'farm_cloud_valid',
        isDemo: true,
      );
      expect(explicitDemo, isNull);

      // 4. Exploitation locale par défaut (hors cloud)
      final localDefaultFarmAnimal = await syncQueueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'user_animal_local_only',
        action: SyncAction.create,
        farmId: DatabaseMigrator.defaultFarmId,
      );
      expect(localDefaultFarmAnimal, isNull);

      final prefixLocalFarmAnimal = await syncQueueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'user_animal_prefix_local',
        action: SyncAction.create,
        farmId: 'local_custom_offline',
      );
      expect(prefixLocalFarmAnimal, isNull);

      // 5. Entités réelles sur ferme cloud : acceptées
      final validOp = await syncQueueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: 'real_cow_42',
        action: SyncAction.create,
        farmId: 'farm_real_cloud_123',
        isDemo: false,
      );
      expect(validOp, isNotNull);

      // Vérifier que la file ne contient que l'opération valide
      expect(await syncQueueService.count(), 1);
    });

    // ─── 10. Préservation des données existantes pendant la migration v3 → v4 ─
    test(
        '10. Migration v3 to v4 preserves all animals, expenses, and farms intact',
        () async {
      final migrationDb =
          await memoryFactory.openDatabase('migration_v3_to_v4_test.db');
      addTearDown(() => migrationDb.close());

      // Établir un schéma v3
      await DatabaseMigrator.metadataStore.record('schema').put(migrationDb, {
        'version': 3,
        'migratedAt': '2026-10-25T10:00:00.000',
      });

      // Ferme v3
      await DatabaseMigrator.farmsStore.record('farm_preserved_1').put(
        migrationDb,
        {
          'id': 'farm_preserved_1',
          'name': 'Ferme Saloum Préservée',
          'createdAt': '2026-05-01T10:00:00.000',
        },
      );

      // Animal v3 avec remoteId et dépenses
      final v3Animal = Animal(
        id: 'anim_preserved_1',
        farmId: 'farm_preserved_1',
        name: 'Vache Ndama',
        type: AnimalType.bovin,
        ageMonths: 30,
        weightKg: 280.0,
        healthStatus: HealthStatus.sain,
        syncStatus: SyncStatus.synced,
        remoteId: 'remote-saloum-001',
        createdAt: DateTime(2026, 5, 2),
        expenses: [
          Expense(
            id: 'exp_preserved_1',
            farmId: 'farm_preserved_1',
            animalId: 'anim_preserved_1',
            label: 'Vermifuge',
            amount: 7500.0,
            date: DateTime(2026, 5, 3),
            category: ExpenseCategory.sante,
            syncStatus: SyncStatus.synced,
            remoteId: 'remote-exp-001',
          )
        ],
      );

      await DatabaseMigrator.animalsStore
          .record('anim_preserved_1')
          .put(migrationDb, v3Animal.toMap());

      // Exécuter la migration vers v4
      final result = await DatabaseMigrator.migrate(migrationDb);
      expect(result.performedMigration, isTrue);
      expect(result.versionBefore, 3);
      expect(result.versionAfter, 5);

      // Vérifier la ferme
      final farmRaw = await DatabaseMigrator.farmsStore
          .record('farm_preserved_1')
          .get(migrationDb);
      expect(farmRaw, isNotNull);
      expect(farmRaw!['name'], 'Ferme Saloum Préservée');

      // Vérifier l'animal et ses dépenses
      final animalRaw = await DatabaseMigrator.animalsStore
          .record('anim_preserved_1')
          .get(migrationDb);
      expect(animalRaw, isNotNull);
      final reloadedAnimal = Animal.fromMap(animalRaw!);
      expect(reloadedAnimal.name, 'Vache Ndama');
      expect(reloadedAnimal.remoteId, 'remote-saloum-001');
      expect(reloadedAnimal.expenses.length, 1);
      expect(reloadedAnimal.expenses.first.label, 'Vermifuge');
      expect(reloadedAnimal.expenses.first.remoteId, 'remote-exp-001');
    });

    // ─── 11. Migrations successives depuis les versions antérieures ───────────
    test('11. Sequential migrations: v1 -> v4 and v2 -> v4 upgrade cleanly',
        () async {
      // Cas A : v1 vers v4
      final dbV1 = await memoryFactory.openDatabase('seq_v1_to_v4.db');
      addTearDown(() => dbV1.close());
      expect(await DatabaseMigrator.getSchemaVersion(dbV1), 1);

      final resV1 = await DatabaseMigrator.migrate(dbV1);
      expect(resV1.performedMigration, isTrue);
      expect(resV1.versionBefore, 1);
      expect(resV1.versionAfter, 5);
      expect(resV1.defaultFarmCreated, isTrue);

      // Cas B : v2 vers v4
      final dbV2 = await memoryFactory.openDatabase('seq_v2_to_v4.db');
      addTearDown(() => dbV2.close());
      await DatabaseMigrator.metadataStore.record('schema').put(dbV2, {
        'version': 2,
        'migratedAt': '2026-10-01T00:00:00.000',
      });
      expect(await DatabaseMigrator.getSchemaVersion(dbV2), 2);

      final resV2 = await DatabaseMigrator.migrate(dbV2);
      expect(resV2.performedMigration, isTrue);
      expect(resV2.versionBefore, 2);
      expect(resV2.versionAfter, 5);

      // Le store sync_queue est fonctionnel dans les deux cas
      expect(await DatabaseMigrator.syncQueueStore.count(dbV1), 0);
      expect(await DatabaseMigrator.syncQueueStore.count(dbV2), 0);
    });

    // ─── 12. Absence de création automatique d'opérations pour anciennes données
    test(
        '12. Migration does not auto-populate sync_queue with legacy animals or expenses',
        () async {
      final db = await memoryFactory.openDatabase('no_auto_enqueue_test.db');
      addTearDown(() => db.close());

      // Insérer 5 animaux au schéma v2
      await DatabaseMigrator.metadataStore.record('schema').put(db, {
        'version': 2,
        'migratedAt': '2026-10-15T00:00:00.000',
      });

      for (int i = 1; i <= 5; i++) {
        await DatabaseMigrator.animalsStore.record('legacy_anim_$i').put(db, {
          'id': 'legacy_anim_$i',
          'farmId': 'farm_existing_$i',
          'name': 'Animal $i',
          'type': 'caprin',
          'ageMonths': 12,
          'weightKg': 25.0,
          'healthStatus': 'sain',
          'createdAt': '2026-10-15T00:00:00.000',
          'expenses': [
            {
              'id': 'legacy_exp_$i',
              'label': 'Frais $i',
              'amount': 2000.0,
              'date': '2026-10-15T00:00:00.000',
              'category': 'autre',
            }
          ],
        });
      }

      final res = await DatabaseMigrator.migrate(db);
      expect(res.performedMigration, isTrue);
      expect(res.versionAfter, 5);

      // Vérifier que la file sync_queue est strictement VIDE
      final queueCount = await DatabaseMigrator.syncQueueStore.count(db);
      expect(queueCount, 0,
          reason:
              'Aucune opération ne doit être générée automatiquement lors de la migration');

      final service = SyncQueueService(database: Future.value(db));
      final allOps = await service.getAllOperations();
      expect(allOps, isEmpty);
    });
  });
}
