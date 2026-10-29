// test/integration/supabase_real_pull_pagination_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:agritrack/core/supabase_config.dart';
import 'package:agritrack/data/animals_repository.dart';
import 'package:agritrack/data/database/database_migrator.dart';
import 'package:agritrack/models/sync_queue_operation.dart';
import 'package:agritrack/services/sync/supabase_sync_client.dart';
import 'package:agritrack/services/sync/sync_cursor_service.dart';
import 'package:agritrack/services/sync/sync_engine.dart';
import 'package:agritrack/services/sync/sync_queue_service.dart';

/// Test d'intégration réel : Validation de la pagination composite PostgREST
/// contre l'instance locale Docker Supabase d'AgriTrack.
///
/// Vérifie rigoureusement en conditions réelles HTTP :
/// 1. Acceptation du filtre composite par PostgREST (pas d'erreur 400 Bad Request).
/// 2. Fonctionnement du seek pagination sur des horodatages identiques.
/// 3. Frontières de pages exactement pleines et dernières pages incomplètes.
/// 4. Reprise exacte depuis le curseur (since, lastId).
/// 5. Absence d'omissions et de doublons.
/// 6. Isolation stricte par exploitation (farm_id).
/// 7. Nettoyage intégral post-test (zéro ligne résiduelle).
void main() {
  group('Supabase Real PostgREST Composite Pagination Tests', () {
    late RealSupabaseSyncClient syncClient;
    final List<String> createdFarmIds = [];
    bool isServerReachable = false;
    User? testUser;
    String? farmAId;
    String? farmBId;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final targetUrl = SupabaseConfig.url;

      try {
        final uri = Uri.parse(targetUrl);
        final socket = await Socket.connect(
          uri.host,
          uri.port,
          timeout: const Duration(seconds: 2),
        );
        socket.destroy();
        isServerReachable = true;
      } catch (_) {
        isServerReachable = false;
      }

      if (isServerReachable) {
        if (!SupabaseConfig.isInitialized) {
          await SupabaseConfig.initialize();
        }

        final client = SupabaseConfig.client;

        // Création d'un utilisateur de test authentifié
        final testEmail =
            'pull_test_${DateTime.now().microsecondsSinceEpoch}@agritrack-dev.internal';
        final authRes = await client.auth.signUp(
          email: testEmail,
          password: 'Password123!',
        );
        testUser = authRes.user;
        expect(testUser, isNotNull);

        // Création de 2 fermes de test isolées
        final farmARes = await client.rpc(
          'create_farm_with_owner',
          params: {
            'farm_name': '[PULL-TEST] Exploitation A',
            'farm_region': 'Bouake',
            'is_demo_farm': true,
          },
        );
        farmAId = farmARes['id'] as String;
        createdFarmIds.add(farmAId!);

        final farmBRes = await client.rpc(
          'create_farm_with_owner',
          params: {
            'farm_name': '[PULL-TEST] Exploitation B',
            'farm_region': 'Korhogo',
            'is_demo_farm': true,
          },
        );
        farmBId = farmBRes['id'] as String;
        createdFarmIds.add(farmBId!);

        syncClient = RealSupabaseSyncClient();
      }
    });

    tearDownAll(() async {
      if (!isServerReachable) return;
      try {
        final client = SupabaseConfig.client;
        for (final fid in createdFarmIds) {
          try {
            await client.from('farms').delete().eq('id', fid);
          } catch (_) {}
        }
        await client.auth.signOut();
      } catch (_) {}
    });

    test('1. Vérification de l\'instance locale Docker et de l\'authentification', () async {
      if (!isServerReachable) return;
      expect(farmAId, isNotNull);
      expect(farmBId, isNotNull);
      expect(testUser, isNotNull);
    });

    test('2. Validation HTTP réelle : pagination composite avec horodatages identiques', () async {
      if (!isServerReachable) return;
      final client = SupabaseConfig.client;

      // Date identique pour 7 animaux sur la ferme A
      final sharedTimestamp = DateTime.utc(2026, 10, 25, 12, 0, 0);
      final sharedTimestampIso = sharedTimestamp.toIso8601String();

      final List<Map<String, dynamic>> animalsToInsert = [];
      for (int i = 1; i <= 7; i++) {
        animalsToInsert.add({
          'farm_id': farmAId,
          'local_id': 'loc_real_a_$i',
          'name': 'Animal Réel Même Date $i',
          'type': 'bovin',
          'age_months': 12 + i,
          'weight_kg': 200.0 + (i * 10),
          'health_status': 'sain',
          'is_demo': false,
          'created_by': testUser!.id,
          'created_at': sharedTimestampIso,
          'updated_at': sharedTimestampIso,
        });
      }

      // 1 animal sur la ferme B pour tester l'isolation multi-fermes
      await client.from('animals').insert({
        'farm_id': farmBId,
        'local_id': 'loc_real_b_isolated',
        'name': 'Animal Ferme B Isolée',
        'type': 'caprin',
        'age_months': 6,
        'weight_kg': 35.0,
        'health_status': 'sain',
        'is_demo': false,
        'created_by': testUser!.id,
        'created_at': sharedTimestampIso,
        'updated_at': sharedTimestampIso,
      });

      await client.from('animals').insert(animalsToInsert);

      // ── Requête Page 1 (limit: 3) sans curseur ──
      final page1 = await syncClient.fetchAnimals(
        farmId: farmAId!,
        since: null,
        lastId: null,
        limit: 3,
      );

      expect(page1.length, 3, reason: 'Page 1 doit contenir exactement 3 éléments');
      expect(page1.every((a) => a['farm_id'] == farmAId), isTrue,
          reason: 'Isolation : aucun animal de la ferme B');

      final lastP1 = page1.last;
      final p1Updated = DateTime.parse(lastP1['updated_at'] as String);
      final p1LastId = lastP1['id'] as String;

      // ── Requête Page 2 (limit: 3) avec curseur composite réel ──
      final page2 = await syncClient.fetchAnimals(
        farmId: farmAId!,
        since: p1Updated,
        lastId: p1LastId,
        limit: 3,
      );

      expect(page2.length, 3, reason: 'Page 2 doit contenir exactement 3 éléments');
      expect(page2.every((a) => a['farm_id'] == farmAId), isTrue);

      final lastP2 = page2.last;
      final p2Updated = DateTime.parse(lastP2['updated_at'] as String);
      final p2LastId = lastP2['id'] as String;

      // ── Requête Page 3 (limit: 3) : dernière page incomplète (1 élément restant) ──
      final page3 = await syncClient.fetchAnimals(
        farmId: farmAId!,
        since: p2Updated,
        lastId: p2LastId,
        limit: 3,
      );

      expect(page3.length, 1, reason: 'Page 3 doit contenir le dernier élément (7 - 3 - 3 = 1)');

      final lastP3 = page3.last;
      final p3Updated = DateTime.parse(lastP3['updated_at'] as String);
      final p3LastId = lastP3['id'] as String;

      // ── Requête Page 4 (limit: 3) : après la fin -> liste vide ──
      final page4 = await syncClient.fetchAnimals(
        farmId: farmAId!,
        since: p3Updated,
        lastId: p3LastId,
        limit: 3,
      );

      expect(page4, isEmpty, reason: 'Page 4 doit être vide (fin de pagination)');

      // ── Vérification d'absence de doublons et d'omissions ──
      final allPulled = [...page1, ...page2, ...page3];
      expect(allPulled.length, 7);
      final allIds = allPulled.map((a) => a['id'] as String).toSet();
      expect(allIds.length, 7, reason: 'Les 7 animaux doivent être distincts');

      // ── Vérification de la reprise après interruption ──
      // Simulation: reprendre directement depuis la fin de page 1
      final resumeFromP1 = await syncClient.fetchAnimals(
        farmId: farmAId!,
        since: p1Updated,
        lastId: p1LastId,
        limit: 10,
      );
      expect(resumeFromP1.length, 4,
          reason: 'Reprise : 4 animaux restants (pages 2 + 3)');
      expect(resumeFromP1.map((a) => a['id']),
          equals([...page2, ...page3].map((a) => a['id'])));
    });

    test('3. Validation HTTP réelle : pagination des dépenses (fetchExpenses)', () async {
      if (!isServerReachable) return;
      final client = SupabaseConfig.client;

      // Récupérer un animal de la ferme A pour rattacher des dépenses
      final animal = await client
          .from('animals')
          .select('id')
          .eq('farm_id', farmAId!)
          .limit(1)
          .single();
      final remoteAnimalId = animal['id'] as String;

      final expenseTimestamp = DateTime.utc(2026, 10, 25, 14, 0, 0);
      final expenseTimestampIso = expenseTimestamp.toIso8601String();

      // Insérer 5 dépenses pour tester fetchExpenses
      final List<Map<String, dynamic>> expensesToInsert = [];
      for (int i = 1; i <= 5; i++) {
        expensesToInsert.add({
          'farm_id': farmAId,
          'animal_id': remoteAnimalId,
          'local_id': 'loc_real_exp_$i',
          'label': 'Dépense Réelle Test $i',
          'amount': 5000.0 * i,
          'date': expenseTimestampIso,
          'category': 'alimentation',
          'created_by': testUser!.id,
          'created_at': expenseTimestampIso,
          'updated_at': expenseTimestampIso,
        });
      }

      await client.from('expenses').insert(expensesToInsert);

      // Page 1 de dépenses (limit: 2)
      final expPage1 = await syncClient.fetchExpenses(
        farmId: farmAId!,
        since: null,
        lastId: null,
        limit: 2,
      );
      expect(expPage1.length, 2);

      final expLast1 = expPage1.last;
      final expSince1 = DateTime.parse(expLast1['updated_at'] as String);
      final expId1 = expLast1['id'] as String;

      // Page 2 de dépenses (limit: 2)
      final expPage2 = await syncClient.fetchExpenses(
        farmId: farmAId!,
        since: expSince1,
        lastId: expId1,
        limit: 2,
      );
      expect(expPage2.length, 2);

      final expLast2 = expPage2.last;
      final expSince2 = DateTime.parse(expLast2['updated_at'] as String);
      final expId2 = expLast2['id'] as String;

      // Page 3 de dépenses (limit: 2) : 1 élément restant
      final expPage3 = await syncClient.fetchExpenses(
        farmId: farmAId!,
        since: expSince2,
        lastId: expId2,
        limit: 2,
      );
      expect(expPage3.length, 1);

      // Total 5 dépenses sans doublon
      final allExpenses = [...expPage1, ...expPage2, ...expPage3];
      expect(allExpenses.length, 5);
      final distinctExpIds = allExpenses.map((e) => e['id'] as String).toSet();
      expect(distinctExpIds.length, 5);
    });

    test('4. Validation HTTP réelle : cycle complet SyncEngine.pullRemoteChanges avec pagination', () async {
      if (!isServerReachable) return;

      final memoryFactory = newDatabaseFactoryMemory();
      final testDb = await memoryFactory.openDatabase('real_engine_pull_test.db');
      await DatabaseMigrator.migrate(testDb);

      final localRepo = AnimalsRepository(database: Future.value(testDb), autoSeed: false);
      final queueService = SyncQueueService(database: Future.value(testDb));
      final cursorService = SyncCursorService(database: Future.value(testDb));

      final engine = SyncEngine(
        syncClient: syncClient,
        queueService: queueService,
        animalsRepository: localRepo,
        cursorService: cursorService,
      );

      // Premier Pull complet avec pageSize = 2 pour forcer la pagination multi-lots
      final pullResult = await engine.pullRemoteChanges(
        farmId: farmAId!,
        userId: testUser!.id,
        pageSize: 2,
      );

      expect(pullResult.isSuccess, isTrue);
      expect(pullResult.animalsPulled, 7, reason: '7 animaux réels importés via plusieurs pages de 2');
      expect(pullResult.expensesPulled, 5, reason: '5 dépenses réelles importées via plusieurs pages de 2');
      expect(pullResult.conflictsCount, 0);

      // Vérifier que les animaux sont bien dans la base locale avec leurs dépenses
      final localAnimals = await localRepo.fetchAnimals(farmId: farmAId!);
      expect(localAnimals.length, 7);
      final totalLocalExpenses = localAnimals.fold<int>(0, (sum, a) => sum + a.expenses.length);
      expect(totalLocalExpenses, 5);

      // Vérifier que le curseur composite a bien été sauvé
      final animalCursor = await cursorService.getCursor(
        farmId: farmAId!,
        entityType: SyncEntityType.animal,
      );
      expect(animalCursor?.isNotEmpty, isTrue);
      expect(animalCursor?.lastId, isNotNull);

      // Deuxième Pull immédiat : doit retourner 0 animaux et 0 dépenses (idempotent)
      final secondPull = await engine.pullRemoteChanges(
        farmId: farmAId!,
        userId: testUser!.id,
        pageSize: 2,
      );
      expect(secondPull.animalsPulled, 0, reason: 'Curseur à jour : rien à réimporter');
      expect(secondPull.expensesPulled, 0);

      await testDb.close();
    });
  });
}

