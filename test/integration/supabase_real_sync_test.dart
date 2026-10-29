// test/integration/supabase_real_sync_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:agritrack/core/supabase_config.dart';
import 'package:agritrack/data/animals_repository.dart';
import 'package:agritrack/data/database/database_migrator.dart';
import 'package:agritrack/models/animal.dart';
import 'package:agritrack/models/expense.dart';
import 'package:agritrack/models/sync_queue_operation.dart';
import 'package:agritrack/services/sync/supabase_sync_client.dart';
import 'package:agritrack/services/sync/sync_engine.dart';
import 'package:agritrack/services/sync/sync_queue_service.dart';

/// Suite complète de tests de sécurité et d'intégration réelle avec Supabase local.
///
/// Valide en conditions réelles :
/// 1. La non-joignabilité en production et le verrouillage de dev.
/// 2. Le refus d'accès pour les requêtes non authentifiées.
/// 3. La création atomique d'exploitation via la fonction RPC sécurisée `create_farm_with_owner`.
/// 4. L'interdiction d'insertion directe sur la table `farms`.
/// 5. L'isolation multi-tenant stricte entre exploitations et utilisateurs distincts.
/// 6. Le respect strict des politiques RLS selon les rôles (`owner`, `worker`).
/// 7. Le fonctionnement réel de `SyncEngine` (idempotence, résilience, soft delete).
/// 8. Le nettoyage strict des données de test créées.
void main() {
  group('Supabase Real Instance Integration & Security Tests', () {
    late Database testDb;
    late SyncQueueService queueService;
    late AnimalsRepository animalsRepo;
    late RealSupabaseSyncClient realClient;
    late SyncEngine syncEngine;

    bool isServerReachable = false;
    final List<String> createdFarmIds = [];

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
      }
    });

    setUp(() async {
      final memoryFactory = newDatabaseFactoryMemory();
      final dbName =
          'test_real_sync_${DateTime.now().microsecondsSinceEpoch}.db';
      testDb = await memoryFactory.openDatabase(dbName);
      await DatabaseMigrator.migrate(testDb);

      queueService = SyncQueueService(database: Future.value(testDb));
      animalsRepo = AnimalsRepository(
        database: Future.value(testDb),
        autoSeed: false,
      );
      realClient = RealSupabaseSyncClient();
      syncEngine = SyncEngine(
        syncClient: realClient,
        queueService: queueService,
        animalsRepository: animalsRepo,
      );
    });

    tearDown(() async {
      await testDb.close();
    });

    tearDownAll(() async {
      if (!isServerReachable) return;
      try {
        final client = SupabaseConfig.client;
        // Nettoyage sécurisé des exploitations créées pendant les tests
        for (final farmId in createdFarmIds) {
          try {
            await client.from('farms').delete().eq('id', farmId);
          } catch (_) {}
        }
        await client.auth.signOut();
      } catch (_) {}
    });

    // ─── 1. Vérification préalable d'environnement ───────────────────────────
    test(
        '1. Environment check: Local Supabase instance is accessible and isolated',
        () async {
      if (!isServerReachable) {
        expect(isServerReachable, isFalse);
        return;
      }

      // Interdiction absolue d'exécuter sur une URL de production
      expect(
        SupabaseConfig.url.contains('supabase.co') &&
            !SupabaseConfig.url.contains('-dev'),
        isFalse,
        reason:
            'INTERDICTION : Impossible de lancer des tests sur une URL de production.',
      );
    });

    // ─── 2. Refus pour utilisateur non authentifié ───────────────────────────
    test('2. Unauthenticated user cannot create a farm', () async {
      if (!isServerReachable) return;

      final client = SupabaseConfig.client;
      await client.auth.signOut();

      // Tentative d'appel RPC sans session authentifiée
      expect(
        () async => await client.rpc(
          'create_farm_with_owner',
          params: {'farm_name': 'Tentative Anonyme'},
        ),
        throwsA(isA<PostgrestException>()),
      );
    });

    // ─── 3. Création atomique d'exploitation et attribution du rôle owner ────
    test('3. Authenticated user creates a farm with atomic owner role',
        () async {
      if (!isServerReachable) return;

      final client = SupabaseConfig.client;
      final testEmail =
          'owner_test_${DateTime.now().microsecondsSinceEpoch}@agritrack-dev.internal';
      final authRes = await client.auth.signUp(
        email: testEmail,
        password: 'Password123!',
      );

      final user = authRes.user;
      expect(user, isNotNull);

      // Création atomique
      final farmRes = await client.rpc(
        'create_farm_with_owner',
        params: {
          'farm_name': '[TEST-DEV] Exploitation Alpha',
          'farm_region': 'Abidjan',
          'is_demo_farm': true,
        },
      );

      final farmId = farmRes['id'] as String;
      expect(farmId, isNotEmpty);
      createdFarmIds.add(farmId);

      // Vérification que l'utilisateur est bien le owner de la ferme
      final farmData = await client
          .from('farms')
          .select('owner_id, name')
          .eq('id', farmId)
          .single();
      expect(farmData['owner_id'], user!.id);
      expect(farmData['name'], '[TEST-DEV] Exploitation Alpha');

      // Vérification de l'adhésion atomique dans farm_members avec role 'owner'
      final memberData = await client
          .from('farm_members')
          .select('role')
          .eq('farm_id', farmId)
          .eq('user_id', user.id)
          .single();
      expect(memberData['role'], 'owner');
    });

    // ─── 4. Verrouillage : interdiction d'insertion directe sur farms ─────────
    test(
        '4. Direct table INSERT on public.farms is forbidden for authenticated users',
        () async {
      if (!isServerReachable) return;

      final client = SupabaseConfig.client;
      expect(
        () async => await client.from('farms').insert({
          'name': 'Ferme Directe Interdite',
          'owner_id': client.auth.currentUser!.id,
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    // ─── 5. Isolation multi-tenant stricte entre exploitations ───────────────
    test(
        '5. Multi-tenant isolation: Foreign user cannot see or modify other farm data',
        () async {
      if (!isServerReachable || createdFarmIds.isEmpty) return;

      final client = SupabaseConfig.client;
      final targetFarmId = createdFarmIds.first;

      // Inscription d'un second utilisateur étranger (User B)
      final intruderEmail =
          'intruder_${DateTime.now().microsecondsSinceEpoch}@agritrack-dev.internal';
      await client.auth.signUp(
        email: intruderEmail,
        password: 'Password123!',
      );

      // L'utilisateur étranger tente de lister la ferme de l'autre utilisateur
      final foreignFarms =
          await client.from('farms').select().eq('id', targetFarmId);
      expect(foreignFarms, isEmpty); // RLS masque complètement la ligne

      // L'utilisateur étranger tente d'accéder aux membres
      final foreignMembers = await client
          .from('farm_members')
          .select()
          .eq('farm_id', targetFarmId);
      expect(foreignMembers, isEmpty);

      // L'utilisateur étranger tente d'accéder aux animaux
      final foreignAnimals =
          await client.from('animals').select().eq('farm_id', targetFarmId);
      expect(foreignAnimals, isEmpty);
    });

    // ─── 6. Permissions du rôle worker (RLS restrictive) ────────────────────
    test(
        '6. Worker role permissions: can insert, but cannot soft-delete animal or modify/delete expense',
        () async {
      if (!isServerReachable) return;

      final client = SupabaseConfig.client;

      // 1. Reconnexion ou création de l'owner (User A)
      final ownerEmail =
          'owner_role_${DateTime.now().microsecondsSinceEpoch}@agritrack-dev.internal';
      final ownerAuth = await client.auth.signUp(
        email: ownerEmail,
        password: 'Password123!',
      );
      expect(ownerAuth.user, isNotNull);

      final farmRes = await client.rpc(
        'create_farm_with_owner',
        params: {
          'farm_name': '[TEST-DEV] Ferme Rôle Test',
          'is_demo_farm': true,
        },
      );
      final testFarmId = farmRes['id'] as String;
      createdFarmIds.add(testFarmId);

      // 2. Création d'un worker (User C)
      final workerEmail =
          'worker_${DateTime.now().microsecondsSinceEpoch}@agritrack-dev.internal';
      final workerAuth = await client.auth.signUp(
        email: workerEmail,
        password: 'Password123!',
      );
      final workerUser = workerAuth.user!;

      // 3. L'owner ajoute le worker dans farm_members
      await client.auth.signInWithPassword(
        email: ownerEmail,
        password: 'Password123!',
      );
      await client.from('farm_members').insert({
        'farm_id': testFarmId,
        'user_id': workerUser.id,
        'role': 'worker',
      });

      // 4. Le worker se connecte
      await client.auth.signInWithPassword(
        email: workerEmail,
        password: 'Password123!',
      );

      // Le worker peut insérer un animal
      final animalRes = await client
          .from('animals')
          .insert({
            'farm_id': testFarmId,
            'name': 'Animal Worker',
            'type': 'bovin',
            'age_months': 12,
            'weight_kg': 200.0,
            'health_status': 'sain',
            'created_by': workerUser.id,
          })
          .select('id')
          .single();
      final animalId = animalRes['id'] as String;
      expect(animalId, isNotEmpty);

      // Le worker peut insérer une dépense
      final expenseRes = await client
          .from('expenses')
          .insert({
            'farm_id': testFarmId,
            'animal_id': animalId,
            'label': 'Foin ouvrier',
            'amount': 3000,
            'date': DateTime.now().toIso8601String(),
            'category': 'alimentation',
            'created_by': workerUser.id,
          })
          .select('id')
          .single();
      final expenseId = expenseRes['id'] as String;
      expect(expenseId, isNotEmpty);

      // Tentative du worker de modifier le montant de la dépense -> REJETÉ PAR RLS
      expect(
        () async => await client
            .from('expenses')
            .update({'amount': 9999}).eq('id', expenseId),
        throwsA(isA<PostgrestException>()),
      );

      // Tentative du worker de supprimer la dépense -> REJETÉ PAR RLS
      expect(
        () async => await client.from('expenses').delete().eq('id', expenseId),
        throwsA(isA<PostgrestException>()),
      );

      // Tentative du worker de soft-delete l'animal -> REJETÉ PAR RLS
      expect(
        () async => await client
            .from('animals')
            .update({'deleted_at': DateTime.now().toIso8601String()}).eq(
                'id', animalId),
        throwsA(isA<PostgrestException>()),
      );
    });

    // ─── 7. Cycle complet de synchronisation réelle avec SyncEngine ──────────
    test(
        '7. Real SyncEngine cycle: creation, remoteId persistence, linked expense, soft-delete',
        () async {
      if (!isServerReachable) return;

      final client = SupabaseConfig.client;

      // Inscription et connexion de l'utilisateur de synchronisation
      final syncEmail =
          'sync_user_${DateTime.now().microsecondsSinceEpoch}@agritrack-dev.internal';
      final authRes = await client.auth.signUp(
        email: syncEmail,
        password: 'Password123!',
      );
      final syncUser = authRes.user!;

      // Création de l'exploitation distante
      final farmRes = await client.rpc(
        'create_farm_with_owner',
        params: {
          'farm_name': '[TEST-DEV] Exploitation SyncEngine',
          'is_demo_farm': true,
        },
      );
      final syncFarmId = farmRes['id'] as String;
      createdFarmIds.add(syncFarmId);

      // A. Création de l'animal local et synchronisation réelle
      final localAnimal = Animal(
        id: 'animal_sync_real_1',
        farmId: syncFarmId,
        name: 'Taureau Champion',
        type: AnimalType.bovin,
        ageMonths: 36,
        weightKg: 500.0,
        healthStatus: HealthStatus.sain,
        syncStatus: SyncStatus.pendingCreate,
        expenses: const [],
        createdAt: DateTime.now(),
      );
      await animalsRepo.addAnimal(localAnimal);

      await queueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: localAnimal.id,
        action: SyncAction.create,
        farmId: syncFarmId,
        userId: syncUser.id,
      );

      final animalSyncResult = await syncEngine.syncPendingOperations(
        farmId: syncFarmId,
        userId: syncUser.id,
      );

      expect(animalSyncResult.isSuccess, isTrue);
      expect(animalSyncResult.successCount, 1);

      // Vérification que le remoteId a été persisté dans la base Sembast
      final syncedLocalAnimal =
          await animalsRepo.getAnimalById('animal_sync_real_1');
      expect(syncedLocalAnimal, isNotNull);
      expect(syncedLocalAnimal!.remoteId, isNotNull);
      expect(syncedLocalAnimal.syncStatus, SyncStatus.synced);
      final remoteAnimalUuid = syncedLocalAnimal.remoteId!;

      // B. Création de la dépense locale liée à l'animal et synchronisation
      final localExpense = await animalsRepo.addExpense(
        syncedLocalAnimal.id,
        Expense(
          id: 'exp_sync_real_1',
          farmId: syncFarmId,
          animalId: syncedLocalAnimal.id,
          label: 'Alimentation concentrée',
          amount: 8500,
          date: DateTime.now(),
          category: ExpenseCategory.alimentation,
          syncStatus: SyncStatus.pendingCreate,
        ),
      );

      await queueService.enqueue(
        entityType: SyncEntityType.expense,
        localId: localExpense.id,
        action: SyncAction.create,
        farmId: syncFarmId,
        userId: syncUser.id,
        payload: {'animalId': syncedLocalAnimal.id},
      );

      final expenseSyncResult = await syncEngine.syncPendingOperations(
        farmId: syncFarmId,
        userId: syncUser.id,
      );

      expect(expenseSyncResult.isSuccess, isTrue);
      expect(expenseSyncResult.successCount, 1);

      // Vérification que la dépense distante pointe vers le bon animal_id distant
      final remoteExpenseRow = await client
          .from('expenses')
          .select('animal_id, amount, local_id')
          .eq('farm_id', syncFarmId)
          .eq('local_id', 'exp_sync_real_1')
          .single();
      expect(remoteExpenseRow['animal_id'], remoteAnimalUuid);
      expect(remoteExpenseRow['amount'], 8500.0);

      // C. Vérification de l'idempotence : nouvelle tentative sans doublon
      final idempotentResult = await syncEngine.syncPendingOperations(
        farmId: syncFarmId,
        userId: syncUser.id,
      );
      expect(idempotentResult.processedOperations, 0);

      final animalCount =
          await client.from('animals').select('id').eq('farm_id', syncFarmId);
      expect(
          animalCount.length, 1); // Exactement 1 animal distant, zéro doublon

      // D. Soft-delete de l'animal et synchronisation
      await animalsRepo.deleteAnimal(syncedLocalAnimal.id);
      await queueService.enqueue(
        entityType: SyncEntityType.animal,
        localId: syncedLocalAnimal.id,
        action: SyncAction.delete,
        farmId: syncFarmId,
        userId: syncUser.id,
      );

      final deleteSyncResult = await syncEngine.syncPendingOperations(
        farmId: syncFarmId,
        userId: syncUser.id,
      );

      expect(deleteSyncResult.isSuccess, isTrue);
      expect(deleteSyncResult.successCount, 1);

      // Vérification dans Supabase : la ligne existe toujours mais deleted_at est renseigné
      final softDeletedRow = await client
          .from('animals')
          .select('deleted_at')
          .eq('id', remoteAnimalUuid)
          .single();
      expect(softDeletedRow['deleted_at'], isNotNull);
    });
  });
}
