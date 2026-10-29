// test/integration/supabase_real_concurrency_and_idempotence_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:agritrack/core/supabase_config.dart';

/// Suite de tests d'intégration serveur vérifiant :
/// 1. Le contrôle de concurrence optimiste via `version_id`
/// 2. Les RPC transactionnelles `sync_push_animal` et `sync_push_expense`
/// 3. L'idempotence des opérations (`sync_operations_log`)
/// 4. L'étanchéité multi-tenant et la gestion des conflits
void main() {
  group('Supabase Real Instance Concurrency & Idempotence Tests', () {
    final List<String> createdFarmIds = [];
    bool isServerReachable = false;
    User? userOwnerA;
    User? userForeignB;
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

        // 1. Inscription Utilisateur A (Owner de Farm A)
        final emailA =
            'owner_concurrency_${DateTime.now().microsecondsSinceEpoch}@agritrack-dev.internal';
        final authA = await client.auth.signUp(
          email: emailA,
          password: 'Password123!',
        );
        userOwnerA = authA.user;
        expect(userOwnerA, isNotNull);

        // 2. Création de l'exploitation A
        final farmARes = await client.rpc(
          'create_farm_with_owner',
          params: {
            'farm_name': '[CONCURRENCY-TEST] Ferme Principale A',
            'farm_region': 'Bouake',
            'is_demo_farm': true,
          },
        );
        farmAId = farmARes['id'] as String;
        createdFarmIds.add(farmAId!);

        // 3. Inscription Utilisateur B (Étranger / Owner de Farm B)
        final emailB =
            'foreign_concurrency_${DateTime.now().microsecondsSinceEpoch}@agritrack-dev.internal';
        final authB = await client.auth.signUp(
          email: emailB,
          password: 'Password123!',
        );
        userForeignB = authB.user;
        expect(userForeignB, isNotNull);

        // 4. Création de l'exploitation B
        final farmBRes = await client.rpc(
          'create_farm_with_owner',
          params: {
            'farm_name': '[CONCURRENCY-TEST] Ferme Étrangère B',
            'farm_region': 'Korhogo',
            'is_demo_farm': true,
          },
        );
        farmBId = farmBRes['id'] as String;
        createdFarmIds.add(farmBId!);

        // Reconnexion en tant qu'utilisateur A pour le début des tests
        await client.auth.signInWithPassword(
          email: emailA,
          password: 'Password123!',
        );
      }
    });

    tearDownAll(() async {
      if (!isServerReachable) return;
      try {
        final client = SupabaseConfig.client;
        for (final farmId in createdFarmIds) {
          try {
            await client.from('farms').delete().eq('id', farmId);
          } catch (_) {}
        }
        await client.auth.signOut();
      } catch (_) {}
    });

    String? createdAnimalRemoteId;
    String? createdExpenseRemoteId;
    final testOpIdAnimalCreate = 'op_anim_create_${DateTime.now().microsecondsSinceEpoch}';
    final testOpIdAnimalUpdate = 'op_anim_update_${DateTime.now().microsecondsSinceEpoch}';

    // ─── 1. Création d'un animal via RPC ──────────────────────────────────────
    test('1. Création d\'un animal via sync_push_animal avec version_id initial', () async {
      if (!isServerReachable) return;
      final client = SupabaseConfig.client;

      final res = await client.rpc('sync_push_animal', params: {
        'p_operation_id': testOpIdAnimalCreate,
        'p_farm_id': farmAId,
        'p_action': 'create',
        'p_local_id': 'loc_a001',
        'p_name': 'Vache Marguerite',
        'p_type': 'bovin',
        'p_age_months': 36,
        'p_weight_kg': 420.5,
        'p_health_status': 'sain',
      });

      expect(res, isA<Map>());
      expect(res['status'], 'success');
      expect(res['action'], 'create');
      expect(res['version_id'], 1);
      expect(res['remote_id'], isNotEmpty);

      createdAnimalRemoteId = res['remote_id'] as String;

      // Vérification directe dans PostgreSQL
      final row = await client.from('animals').select().eq('id', createdAnimalRemoteId!).single();
      expect(row['name'], 'Vache Marguerite');
      expect(row['version_id'], 1);
      expect(row['deleted_at'], isNull);
    });

    // ─── 2. Mise à jour avec une version correcte ─────────────────────────────
    test('2. Mise à jour avec version_id attendu correct incrémente la version', () async {
      if (!isServerReachable) return;
      final client = SupabaseConfig.client;

      final res = await client.rpc('sync_push_animal', params: {
        'p_operation_id': testOpIdAnimalUpdate,
        'p_farm_id': farmAId,
        'p_action': 'update',
        'p_remote_id': createdAnimalRemoteId,
        'p_expected_version': 1,
        'p_name': 'Marguerite Modifiée',
        'p_weight_kg': 445.0,
      });

      expect(res['status'], 'success');
      expect(res['action'], 'update');
      expect(res['version_id'], 2);

      final row = await client.from('animals').select().eq('id', createdAnimalRemoteId!).single();
      expect(row['name'], 'Marguerite Modifiée');
      expect(row['weight_kg'], 445.0);
      expect(row['version_id'], 2);
    });

    // ─── 3. Rejet d'une mise à jour basée sur une version obsolète (Conflit) ──
    test('3. Rejet d\'une mise à jour basée sur une version obsolète retourne un conflit sans modifier la donnée', () async {
      if (!isServerReachable) return;
      final client = SupabaseConfig.client;

      // La version actuelle sur le serveur est 2. On tente de mettre à jour avec version 1.
      final obsoleteOpId = 'op_anim_obsolete_${DateTime.now().microsecondsSinceEpoch}';
      final res = await client.rpc('sync_push_animal', params: {
        'p_operation_id': obsoleteOpId,
        'p_farm_id': farmAId,
        'p_action': 'update',
        'p_remote_id': createdAnimalRemoteId,
        'p_expected_version': 1, // OBSOLÈTE
        'p_name': 'Tentative Écrasement Silencieux',
        'p_weight_kg': 999.0,
      });

      expect(res['status'], 'conflict');
      expect(res['action'], 'update');
      expect(res['server_version'], 2);
      expect(res['expected_version'], 1);
      expect(res['server_data'], isNotNull);
      expect(res['server_data']['name'], 'Marguerite Modifiée');
      expect(res['server_data']['version_id'], 2);

      // Vérifier que la donnée n'a absolument pas été écrasée
      final row = await client.from('animals').select().eq('id', createdAnimalRemoteId!).single();
      expect(row['name'], 'Marguerite Modifiée');
      expect(row['weight_kg'], 445.0);
      expect(row['version_id'], 2);
    });

    // ─── 4. Deux mises à jour concurrentes simultanées ────────────────────────
    test('4. Deux mises à jour concurrentes avec la même version initiale : une seule est acceptée', () async {
      if (!isServerReachable) return;
      final client = SupabaseConfig.client;

      final opIdConc1 = 'op_conc_1_${DateTime.now().microsecondsSinceEpoch}';
      final opIdConc2 = 'op_conc_2_${DateTime.now().microsecondsSinceEpoch}';

      // Deux requêtes simultanées ciblant expected_version = 2
      final results = await Future.wait([
        client.rpc('sync_push_animal', params: {
          'p_operation_id': opIdConc1,
          'p_farm_id': farmAId,
          'p_action': 'update',
          'p_remote_id': createdAnimalRemoteId,
          'p_expected_version': 2,
          'p_name': 'Nom Concurrence Client A',
        }),
        client.rpc('sync_push_animal', params: {
          'p_operation_id': opIdConc2,
          'p_farm_id': farmAId,
          'p_action': 'update',
          'p_remote_id': createdAnimalRemoteId,
          'p_expected_version': 2,
          'p_name': 'Nom Concurrence Client B',
        }),
      ]);

      final statuses = results.map((r) => r['status']).toList();
      expect(statuses, contains('success'));
      expect(statuses, contains('conflict'));

      final successRes = results.firstWhere((r) => r['status'] == 'success');
      expect(successRes['version_id'], 3);

      final conflictRes = results.firstWhere((r) => r['status'] == 'conflict');
      expect(conflictRes['server_version'], 3);
      expect(conflictRes['expected_version'], 2);
    });

    // ─── 5. Rejeu d'une opération déjà appliquée (Idempotence) ────────────────
    test('5. Rejeu d\'une opération déjà appliquée retourne le résultat original sans ré-appliquer', () async {
      if (!isServerReachable) return;
      final client = SupabaseConfig.client;

      // On rejoue testOpIdAnimalUpdate avec exactement le même contenu
      final replayRes = await client.rpc('sync_push_animal', params: {
        'p_operation_id': testOpIdAnimalUpdate,
        'p_farm_id': farmAId,
        'p_action': 'update',
        'p_remote_id': createdAnimalRemoteId,
        'p_expected_version': 1,
        'p_name': 'Marguerite Modifiée',
        'p_weight_kg': 445.0,
      });

      expect(replayRes['status'], 'success');
      expect(replayRes['version_id'], 2);

      // La version actuelle en base reste 3 (celle obtenue après le test 4), elle n'a pas bougé
      final row = await client.from('animals').select().eq('id', createdAnimalRemoteId!).single();
      expect(row['version_id'], 3);
    });

    // ─── 6. Réutilisation d'un identifiant avec payload différent ─────────────
    test('6. Réutilisation d\'un operation_id avec un payload différent est refusée avec une exception', () async {
      if (!isServerReachable) return;
      final client = SupabaseConfig.client;

      // On réutilise testOpIdAnimalUpdate mais avec un nom différent
      expect(
        () async => await client.rpc('sync_push_animal', params: {
          'p_operation_id': testOpIdAnimalUpdate,
          'p_farm_id': farmAId,
          'p_action': 'update',
          'p_remote_id': createdAnimalRemoteId,
          'p_expected_version': 1,
          'p_name': 'Nom Frauduleux Rejoué',
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    // ─── 7. Suppression logique avec contrôle de version ──────────────────────
    test('7. Suppression logique vérifie la version et incrémente version_id', () async {
      if (!isServerReachable) return;
      final client = SupabaseConfig.client;

      // Tentative avec version obsolète
      final obsoleteDeleteRes = await client.rpc('sync_push_animal', params: {
        'p_operation_id': 'op_del_obs_${DateTime.now().microsecondsSinceEpoch}',
        'p_farm_id': farmAId,
        'p_action': 'delete',
        'p_remote_id': createdAnimalRemoteId,
        'p_expected_version': 1, // La version courante est 3
      });
      expect(obsoleteDeleteRes['status'], 'conflict');

      // Suppression avec version exacte (3)
      final validDeleteOpId = 'op_del_valid_${DateTime.now().microsecondsSinceEpoch}';
      final validDeleteRes = await client.rpc('sync_push_animal', params: {
        'p_operation_id': validDeleteOpId,
        'p_farm_id': farmAId,
        'p_action': 'delete',
        'p_remote_id': createdAnimalRemoteId,
        'p_expected_version': 3,
      });

      expect(validDeleteRes['status'], 'success');
      expect(validDeleteRes['action'], 'delete');
      expect(validDeleteRes['version_id'], 4);

      final row = await client.from('animals').select().eq('id', createdAnimalRemoteId!).single();
      expect(row['deleted_at'], isNotNull);
      expect(row['version_id'], 4);
    });

    // ─── 8. Dépenses : création, modification et contrôle optimiste ───────────
    test('8. Création et modification d\'une dépense liée à un animal via sync_push_expense', () async {
      if (!isServerReachable) return;
      final client = SupabaseConfig.client;

      final expCreateOpId = 'op_exp_create_${DateTime.now().microsecondsSinceEpoch}';
      final createRes = await client.rpc('sync_push_expense', params: {
        'p_operation_id': expCreateOpId,
        'p_farm_id': farmAId,
        'p_action': 'create',
        'p_animal_id': createdAnimalRemoteId,
        'p_local_id': 'loc_e001',
        'p_label': 'Vaccin Antibio',
        'p_amount': 25000.0,
        'p_category': 'sante',
      });

      expect(createRes['status'], 'success');
      expect(createRes['version_id'], 1);
      createdExpenseRemoteId = createRes['remote_id'] as String;

      // Mise à jour de la dépense avec version 1
      final expUpdateOpId = 'op_exp_update_${DateTime.now().microsecondsSinceEpoch}';
      final updateRes = await client.rpc('sync_push_expense', params: {
        'p_operation_id': expUpdateOpId,
        'p_farm_id': farmAId,
        'p_action': 'update',
        'p_remote_id': createdExpenseRemoteId,
        'p_expected_version': 1,
        'p_amount': 27500.0,
        'p_label': 'Vaccin Antibio Plus',
      });

      expect(updateRes['status'], 'success');
      expect(updateRes['version_id'], 2);

      // Conflit sur dépense avec version obsolète
      final conflictRes = await client.rpc('sync_push_expense', params: {
        'p_operation_id': 'op_exp_conf_${DateTime.now().microsecondsSinceEpoch}',
        'p_farm_id': farmAId,
        'p_action': 'update',
        'p_remote_id': createdExpenseRemoteId,
        'p_expected_version': 1, // Obsolète
        'p_amount': 50000.0,
      });

      expect(conflictRes['status'], 'conflict');
      expect(conflictRes['server_version'], 2);
    });

    // ─── 9. Accès interdit à une exploitation étrangère ───────────────────────
    test('9. Accès interdit à une exploitation dont l\'utilisateur n\'est pas membre', () async {
      if (!isServerReachable) return;
      final client = SupabaseConfig.client;

      // L'utilisateur A (connecté) tente de créer un animal sur farmBId (qui appartient à B)
      expect(
        () async => await client.rpc('sync_push_animal', params: {
          'p_operation_id': 'op_intruder_${DateTime.now().microsecondsSinceEpoch}',
          'p_farm_id': farmBId, // Ferme étrangère
          'p_action': 'create',
          'p_name': 'Animal Intrus',
          'p_type': 'bovin',
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    // ─── 10. Refus des appels anonymes ────────────────────────────────────────
    test('10. Refus d\'accès pour les appels anonymes non authentifiés', () async {
      if (!isServerReachable) return;
      final client = SupabaseConfig.client;

      // Déconnexion
      await client.auth.signOut();

      expect(
        () async => await client.rpc('sync_push_animal', params: {
          'p_operation_id': 'op_anon_${DateTime.now().microsecondsSinceEpoch}',
          'p_farm_id': farmAId,
          'p_action': 'create',
          'p_name': 'Animal Anon',
          'p_type': 'bovin',
        }),
        throwsA(isA<PostgrestException>()),
      );

      // Reconnexion de userOwnerA pour les tests suivants
      await client.auth.signInWithPassword(
        email: userOwnerA!.email!,
        password: 'Password123!',
      );
    });

    // ─── 11. Absence de doublons après nouvelle tentative ─────────────────────
    test('11. Absence absolue de doublons dans animals et expenses après rejeux', () async {
      if (!isServerReachable) return;
      final client = SupabaseConfig.client;

      // Rejouer la création de l'animal initial
      final replayCreateRes = await client.rpc('sync_push_animal', params: {
        'p_operation_id': testOpIdAnimalCreate,
        'p_farm_id': farmAId,
        'p_action': 'create',
        'p_local_id': 'loc_a001',
        'p_name': 'Vache Marguerite',
        'p_type': 'bovin',
        'p_age_months': 36,
        'p_weight_kg': 420.5,
        'p_health_status': 'sain',
      });

      expect(replayCreateRes['status'], 'success');
      expect(replayCreateRes['remote_id'], createdAnimalRemoteId);

      // Compter le nombre d'animaux ayant le local_id 'loc_a001'
      final animalsWithLocalId = await client
          .from('animals')
          .select('id')
          .eq('farm_id', farmAId!)
          .eq('local_id', 'loc_a001');

      expect(animalsWithLocalId.length, 1); // Exactement 1 seul enregistrement !
    });

    // ─── 12. Compatibilité avec les lignes existantes (sans version initiale) ──
    test('12. Compatibilité : une ligne existante initialisée à version_id=1 est mise à jour avec succès', () async {
      if (!isServerReachable) return;
      final client = SupabaseConfig.client;

      // Insertion directe simulant un animal préexistant à la migration
      final legacyInsert = await client.from('animals').insert({
        'farm_id': farmAId,
        'local_id': 'legacy_001',
        'name': 'Animal Ancien',
        'type': 'ovin',
        'age_months': 12,
        'weight_kg': 45.0,
        'health_status': 'sain',
        'version_id': 1,
      }).select().single();

      final legacyId = legacyInsert['id'] as String;
      expect(legacyInsert['version_id'], 1);

      // Exécution de la RPC sync_push_animal sur cette ligne existante
      final legacyOpId = 'op_legacy_${DateTime.now().microsecondsSinceEpoch}';
      final updateLegacyRes = await client.rpc('sync_push_animal', params: {
        'p_operation_id': legacyOpId,
        'p_farm_id': farmAId,
        'p_action': 'update',
        'p_remote_id': legacyId,
        'p_expected_version': 1,
        'p_name': 'Animal Ancien Actualisé',
      });

      expect(updateLegacyRes['status'], 'success');
      expect(updateLegacyRes['version_id'], 2);

      final updatedRow = await client.from('animals').select().eq('id', legacyId).single();
      expect(updatedRow['name'], 'Animal Ancien Actualisé');
      expect(updatedRow['version_id'], 2);
    });
  });
}
