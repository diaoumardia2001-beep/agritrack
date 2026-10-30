// lib/data/database/demo_database_manager.dart
import 'dart:async';
import 'package:sembast/sembast_memory.dart';
import '../animals_repository.dart';
import 'database_migrator.dart';

/// Gestionnaire de la base de données Sembast isolée en mémoire vive pour le mode Démo.
///
/// Garanties :
/// 1. Utilise exclusivement [newDatabaseFactoryMemory], sans jamais ouvrir ni toucher
///    à la base IndexedDB ou au système de fichiers de production.
/// 2. Initialise automatiquement le schéma via [DatabaseMigrator.migrate].
/// 3. Permet de réinitialiser le jeu de données en mémoire en une fraction de seconde
///    en restaurant l'état initial des 12 animaux et 25 dépenses sans recharger la page.
class DemoDatabaseManager {
  static Database? _memoryDb;
  static Future<Database>? _openFuture;

  /// Retourne la base de données de démo en mémoire, en l'ouvrant si nécessaire.
  static Future<Database> getDatabase() async {
    if (_memoryDb != null) {
      return _memoryDb!;
    }

    if (_openFuture != null) {
      return await _openFuture!;
    }

    _openFuture = _openInternal();
    try {
      _memoryDb = await _openFuture!;
      return _memoryDb!;
    } finally {
      _openFuture = null;
    }
  }

  static Future<Database> _openInternal() async {
    final factory = newDatabaseFactoryMemory();
    final dbName =
        'agritrack_demo_memory_${DateTime.now().microsecondsSinceEpoch}.db';
    final db = await factory.openDatabase(dbName);
    await DatabaseMigrator.migrate(db);
    return db;
  }

  /// Réinitialise l'état des données dans la base mémoire active
  /// en restaurant exactement les 12 animaux initiaux et leurs 25 dépenses.
  static Future<void> resetData(Database db) async {
    await db.transaction((txn) async {
      final animalsStore = DatabaseMigrator.animalsStore;
      final metadataStore = DatabaseMigrator.metadataStore;
      final syncQueueStore = DatabaseMigrator.syncQueueStore;

      // 1. Purger les magasins en mémoire
      await animalsStore.delete(txn);
      await syncQueueStore.delete(txn);
      await metadataStore.record('seeding').delete(txn);

      // 2. Insérer une copie indépendante et profonde des 12 animaux initiaux
      for (final animal in AnimalsRepository.demoAnimals) {
        // Copie profonde via sérialisation de sécurité
        final rawMap = Map<String, dynamic>.from(animal.toMap());
        await animalsStore.record(animal.id).put(txn, rawMap);
      }

      // 3. Marquer le seeding comme effectué pour stabiliser le magasin
      await metadataStore.record('seeding').put(txn, {
        'seeded': true,
        'seededAt': DateTime.now().toIso8601String(),
        'version': 1,
        'count': AnimalsRepository.demoAnimals.length,
        'demoReset': true,
      });
    });
  }

  /// Ferme et libère la base mémoire active (utile pour les tests ou le nettoyage).
  static Future<void> closeAndReset() async {
    if (_memoryDb != null) {
      await _memoryDb!.close();
      _memoryDb = null;
    }
    _openFuture = null;
  }
}

