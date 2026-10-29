import 'package:sembast/sembast_memory.dart';

import 'app_database_stub.dart'
    if (dart.library.io) 'app_database_io.dart'
    if (dart.library.js_interop) 'app_database_web.dart'
    if (dart.library.html) 'app_database_web.dart';

export 'package:sembast/sembast.dart';

/// Module centralisé d'accès à la base de données Sembast pour AgriTrack.
class AppDatabase {
  static const String defaultDatabaseName = 'agritrack.db';

  static AppDatabase? _instance;
  static Database? _database;
  static Future<Database>? _openFuture;

  AppDatabase._();

  /// Accès à l'instance singleton.
  static AppDatabase get instance => _instance ??= AppDatabase._();

  /// Retourne la base de données ouverte, ou l'ouvre si nécessaire.
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    return await open();
  }

  /// Ouvre la base de données de manière asynchrone et thread-safe.
  /// Empêche l'ouverture concurrente de plusieurs connexions.
  Future<Database> open({String name = defaultDatabaseName}) async {
    if (_database != null) {
      return _database!;
    }

    if (_openFuture != null) {
      return await _openFuture!;
    }

    _openFuture = _openInternal(name);
    try {
      _database = await _openFuture!;
      return _database!;
    } finally {
      _openFuture = null;
    }
  }

  Future<Database> _openInternal(String name) async {
    return await createDatabase(name);
  }

  /// Ouvre une base de données isolée en mémoire vive (pour les tests).
  /// Ne fait aucun appel à path_provider ni au système de fichiers.
  static Future<Database> openInMemory({
    String name = 'test.db',
    DatabaseFactory? customMemoryFactory,
  }) async {
    final factory = customMemoryFactory ?? newDatabaseFactoryMemory();
    return await factory.openDatabase(name);
  }

  /// Injecte une instance de base de données (ex: en mémoire) pour les tests.
  static void setInstanceForTesting(Database db) {
    _database = db;
  }

  /// Ferme la connexion active si elle existe.
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    _openFuture = null;
  }

  /// Réinitialise complètement le singleton (utile dans les tearDown de tests).
  static Future<void> resetForTesting() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    _openFuture = null;
    _instance = null;
  }
}
