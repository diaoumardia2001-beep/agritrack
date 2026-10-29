import 'package:sembast_web/sembast_web.dart';

/// Ouvre la base de données Sembast dans le navigateur Web via IndexedDB.
Future<Database> createDatabase([String dbName = 'agritrack.db']) async {
  try {
    return await databaseFactoryWeb.openDatabase(dbName);
  } catch (e, st) {
    throw StateError(
        'Erreur lors de l\'ouverture de la base de données Sembast (Web): $e\n$st');
  }
}
