// lib/data/database/app_database_stub.dart
import 'package:sembast/sembast.dart';

/// Implémentation de repli pour les plateformes non supportées.
Future<Database> createDatabase([String dbName = 'agritrack.db']) async {
  throw UnsupportedError(
    'La plateforme actuelle n\'est pas prise en charge pour la persistance locale Sembast.',
  );
}
