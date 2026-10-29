// lib/data/database/app_database_io.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/sembast_memory.dart';

/// Ouvre ou réutilise la base de données Sembast sur les plateformes natives (Android, iOS, Windows, etc.).
Future<Database> createDatabase([String dbName = 'agritrack.db']) async {
  try {
    // En environnement de test automatisé, repli transparent sur la mémoire vive
    // pour éviter les MissingPluginException de path_provider en headless.
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return await newDatabaseFactoryMemory().openDatabase(dbName);
    }

    final Directory appDocDir = await getApplicationDocumentsDirectory();
    if (!await appDocDir.exists()) {
      await appDocDir.create(recursive: true);
    }
    final String dbPath = p.join(appDocDir.path, dbName);
    return await databaseFactoryIo.openDatabase(dbPath);
  } catch (e, st) {
    throw StateError(
        'Erreur lors de l\'ouverture de la base de données Sembast (IO): $e\n$st');
  }
}
