// lib/data/database/database_migrator.dart
import 'package:sembast/sembast.dart';
import '../../models/farm.dart';
import '../../models/sync_status.dart';

/// Résultat d'une opération de migration de schéma.
class MigrationResult {
  final int versionBefore;
  final int versionAfter;
  final bool performedMigration;
  final bool defaultFarmCreated;
  final int animalsMigrated;

  const MigrationResult({
    required this.versionBefore,
    required this.versionAfter,
    required this.performedMigration,
    this.defaultFarmCreated = false,
    this.animalsMigrated = 0,
  });
}

/// Service de migration versionnée et transactionnelle pour la base locale Sembast.
/// Garantit l'idempotence, la préservation intégrale des données et la compatibilité multi-plateformes.
class DatabaseMigrator {
  static const int currentSchemaVersion = 5;
  static const String defaultFarmId = 'local_default_farm';
  static const String defaultFarmName = 'Mon Exploitation';

  static final StoreRef<String, Map<String, dynamic>> metadataStore =
      stringMapStoreFactory.store('metadata');
  static final StoreRef<String, Map<String, dynamic>> farmsStore =
      stringMapStoreFactory.store('farms');
  static final StoreRef<String, Map<String, dynamic>> animalsStore =
      stringMapStoreFactory.store('animals');
  static final StoreRef<String, Map<String, dynamic>> syncQueueStore =
      stringMapStoreFactory.store('sync_queue');
  static final StoreRef<String, Map<String, dynamic>> orphanExpensesStore =
      stringMapStoreFactory.store('orphan_expenses');
  static final StoreRef<String, Map<String, dynamic>> conflictsStore =
      stringMapStoreFactory.store('conflicts');

  /// Identifiants historiques des 12 animaux de démonstration du seed initial.
  static const Set<String> knownDemoAnimalIds = {
    'a001',
    'a002',
    'a003',
    'a004',
    'a005',
    'a006',
    'a007',
    'a008',
    'a009',
    'a010',
    'a011',
    'a012',
  };

  /// Identifiants historiques des 25 dépenses de démonstration du seed initial.
  static const Set<String> knownDemoExpenseIds = {
    'e001',
    'e002',
    'e003',
    'e004',
    'e005',
    'e006',
    'e007',
    'e008',
    'e009',
    'e010',
    'e011',
    'e012',
    'e013',
    'e014',
    'e015',
    'e016',
    'e017',
    'e018',
    'e019',
    'e020',
    'e021',
    'e022',
    'e023',
    'e024',
    'e025',
  };

  /// Exécute la migration de schéma de façon atomique et transactionnelle.
  /// Couvre [metadataStore], [farmsStore] et [animalsStore] au sein de la même transaction Sembast.
  static Future<MigrationResult> migrate(Database db) async {
    return await db.transaction((txn) async {
      final schemaRecord = await metadataStore.record('schema').get(txn);
      final int versionBefore =
          (schemaRecord != null && schemaRecord['version'] is num)
              ? (schemaRecord['version'] as num).toInt()
              : 1;

      if (versionBefore >= currentSchemaVersion) {
        return MigrationResult(
          versionBefore: versionBefore,
          versionAfter: versionBefore,
          performedMigration: false,
        );
      }

      bool defaultFarmCreated = false;
      final Set<String> migratedAnimalKeys = {};

      // ─── Migration v1 -> v2 (Multi-fermes et enrichissement des modèles) ──
      if (versionBefore < 2) {
        // 1. Créer la ferme locale par défaut si nécessaire
        final existingDefaultFarm =
            await farmsStore.record(defaultFarmId).get(txn);
        if (existingDefaultFarm == null) {
          final defaultFarm = Farm(
            id: defaultFarmId,
            name: defaultFarmName,
            region: 'Sénégal',
            isDemo: false,
            createdAt: DateTime.now(),
          );
          await farmsStore.record(defaultFarmId).put(txn, defaultFarm.toMap());
          defaultFarmCreated = true;
        }

        // 2. Mettre à niveau les animaux existants (farmId et isDemo)
        final allAnimalRecords = await animalsStore.find(txn);
        for (final record in allAnimalRecords) {
          final rawMap = Map<String, dynamic>.from(record.value);
          bool modified = false;

          // Assigner farmId si absent ou vide
          final farmId = rawMap['farmId'];
          if (farmId == null || (farmId is String && farmId.trim().isEmpty)) {
            rawMap['farmId'] = defaultFarmId;
            modified = true;
          }

          // Déterminer isDemo sans préjugé
          if (!rawMap.containsKey('isDemo') || rawMap['isDemo'] == null) {
            // Seuls les 12 IDs exacts du seed officiel sont classés en démo
            if (knownDemoAnimalIds.contains(record.key)) {
              rawMap['isDemo'] = true;
            } else {
              rawMap['isDemo'] = false;
            }
            modified = true;
          }

          if (modified) {
            await animalsStore.record(record.key).put(txn, rawMap);
            migratedAnimalKeys.add(record.key);
          }
        }
      }

      // ─── Migration v2 -> v3 (Statut de synchronisation & remoteId) ─────────
      if (versionBefore < 3) {
        final allAnimalRecords = await animalsStore.find(txn);
        for (final record in allAnimalRecords) {
          final rawMap = Map<String, dynamic>.from(record.value);
          bool modified = false;

          // Initialiser syncStatus si absent
          if (!rawMap.containsKey('syncStatus') ||
              rawMap['syncStatus'] == null) {
            rawMap['syncStatus'] = SyncStatus.synced.name;
            modified = true;
          }

          // Initialiser syncStatus pour les dépenses imbriquées si nécessaire
          final expensesRaw = rawMap['expenses'];
          if (expensesRaw is List) {
            final List<Map<String, dynamic>> updatedExpenses = [];
            bool expensesModified = false;
            for (final exp in expensesRaw) {
              if (exp is Map) {
                final expMap = Map<String, dynamic>.from(exp);
                if (!expMap.containsKey('syncStatus') ||
                    expMap['syncStatus'] == null) {
                  expMap['syncStatus'] = SyncStatus.synced.name;
                  expensesModified = true;
                }
                updatedExpenses.add(expMap);
              }
            }
            if (expensesModified) {
              rawMap['expenses'] = updatedExpenses;
              modified = true;
            }
          }

          if (modified) {
            await animalsStore.record(record.key).put(txn, rawMap);
            migratedAnimalKeys.add(record.key);
          }
        }
      }

      // ─── Migration v3 -> v4 (Store de synchronisation sync_queue) ────────
      if (versionBefore < 4) {
        // Le store `sync_queue` est initialisé à vide sans ajouter automatiquement les animaux existants.
      }

      // ─── Migration v4 -> v5 (Store des conflits & versionId monotone) ──────
      if (versionBefore < 5) {
        // Initialiser versionId = 1 sur les animaux et dépenses existants
        final allAnimalRecords = await animalsStore.find(txn);
        for (final record in allAnimalRecords) {
          final rawMap = Map<String, dynamic>.from(record.value);
          bool modified = false;

          if (!rawMap.containsKey('versionId') || rawMap['versionId'] == null) {
            rawMap['versionId'] = 1;
            modified = true;
          }

          final expensesRaw = rawMap['expenses'];
          if (expensesRaw is List) {
            final List<Map<String, dynamic>> updatedExpenses = [];
            bool expModified = false;
            for (final exp in expensesRaw) {
              if (exp is Map) {
                final expMap = Map<String, dynamic>.from(exp);
                if (!expMap.containsKey('versionId') ||
                    expMap['versionId'] == null) {
                  expMap['versionId'] = 1;
                  expModified = true;
                }
                updatedExpenses.add(expMap);
              }
            }
            if (expModified) {
              rawMap['expenses'] = updatedExpenses;
              modified = true;
            }
          }

          if (modified) {
            await animalsStore.record(record.key).put(txn, rawMap);
            migratedAnimalKeys.add(record.key);
          }
        }
      }

      // 3. Enregistrer la nouvelle version dans les métadonnées
      await metadataStore.record('schema').put(txn, {
        'version': currentSchemaVersion,
        'migratedAt': DateTime.now().toIso8601String(),
        'previousVersion': versionBefore,
      });

      return MigrationResult(
        versionBefore: versionBefore,
        versionAfter: currentSchemaVersion,
        performedMigration: true,
        defaultFarmCreated: defaultFarmCreated,
        animalsMigrated: migratedAnimalKeys.length,
      );
    });
  }

  /// Lit la version actuelle du schéma sans exécuter de migration.
  static Future<int> getSchemaVersion(Database db) async {
    final schemaRecord = await metadataStore.record('schema').get(db);
    if (schemaRecord != null && schemaRecord['version'] is num) {
      return (schemaRecord['version'] as num).toInt();
    }
    return 1;
  }
}
