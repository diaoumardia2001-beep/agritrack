// lib/services/sync/sync_cursor_service.dart
import 'dart:async';
import '../../data/database/app_database.dart';
import '../../data/database/database_migrator.dart';
import '../../models/sync_queue_operation.dart';

/// Curseur composite pour la synchronisation différentielle (horodatage + ID de départage).
class SyncCursor {
  final DateTime? updatedAt;
  final String? lastId;

  const SyncCursor({
    this.updatedAt,
    this.lastId,
  });

  bool get isEmpty => updatedAt == null && lastId == null;
  bool get isNotEmpty => !isEmpty;

  Map<String, dynamic> toMap() => {
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
        if (lastId != null) 'lastId': lastId,
      };

  factory SyncCursor.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const SyncCursor();
    final rawTs = map['updatedAt'];
    final DateTime? ts = rawTs is String ? DateTime.tryParse(rawTs) : null;
    final lastId = map['lastId'] as String?;
    return SyncCursor(updatedAt: ts, lastId: lastId);
  }

  @override
  String toString() => 'SyncCursor(updatedAt: $updatedAt, lastId: $lastId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncCursor &&
          runtimeType == other.runtimeType &&
          updatedAt == other.updatedAt &&
          lastId == other.lastId;

  @override
  int get hashCode => updatedAt.hashCode ^ lastId.hashCode;
}

/// Service de gestion et persistance des curseurs de synchronisation par exploitation.
///
/// Utilise le magasin officiel [DatabaseMigrator.metadataStore] de Sembast
/// sans altérer le schéma ni nécessiter de migration supplémentaire.
class SyncCursorService {
  final Future<Database> Function()? _databaseProvider;
  final StoreRef<String, Map<String, dynamic>> _store =
      DatabaseMigrator.metadataStore;

  SyncCursorService({
    Future<Database>? database,
    Future<Database> Function()? databaseProvider,
  }) : _databaseProvider =
            database != null ? (() => database) : databaseProvider;

  Future<Database> _getDb() async {
    if (_databaseProvider != null) {
      return await _databaseProvider!();
    }
    return await AppDatabase.instance.database;
  }

  String _recordKey(String farmId) => 'sync_cursor_${farmId.trim()}';

  /// Récupère le dernier curseur de synchronisation pour une exploitation et un type d'entité donnés.
  Future<SyncCursor?> getCursor({
    required String farmId,
    required SyncEntityType entityType,
  }) async {
    final cleanFarmId = farmId.trim();
    if (cleanFarmId.isEmpty) return null;

    final db = await _getDb();
    final record = await _store.record(_recordKey(cleanFarmId)).get(db);
    if (record == null) return null;

    final fieldName = entityType == SyncEntityType.animal
        ? 'animalsCursor'
        : 'expensesCursor';

    final cursorData = record[fieldName];
    if (cursorData is Map<String, dynamic>) {
      return SyncCursor.fromMap(cursorData);
    }
    return null;
  }

  /// Persiste le curseur de synchronisation après traitement réussi.
  Future<void> saveCursor({
    required String farmId,
    required SyncEntityType entityType,
    required SyncCursor cursor,
  }) async {
    final cleanFarmId = farmId.trim();
    if (cleanFarmId.isEmpty) return;

    final db = await _getDb();
    final key = _recordKey(cleanFarmId);

    await db.transaction((txn) async {
      final existing = await _store.record(key).get(txn) ?? <String, dynamic>{};
      final updated = Map<String, dynamic>.from(existing);

      updated['farmId'] = cleanFarmId;
      final fieldName = entityType == SyncEntityType.animal
          ? 'animalsCursor'
          : 'expensesCursor';
      updated[fieldName] = cursor.toMap();
      updated['lastSyncAt'] = DateTime.now().toIso8601String();

      await _store.record(key).put(txn, updated);
    });
  }

  /// Réinitialise les curseurs d'une exploitation (pour les tests ou une resynchronisation complète).
  Future<void> clearCursor({required String farmId}) async {
    final cleanFarmId = farmId.trim();
    if (cleanFarmId.isEmpty) return;

    final db = await _getDb();
    await _store.record(_recordKey(cleanFarmId)).delete(db);
  }
}
