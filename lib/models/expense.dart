// lib/models/expense.dart
import 'sync_status.dart';

export 'sync_status.dart';

class Expense {
  final String id;
  final String? remoteId;
  final SyncStatus syncStatus;
  final String? animalId;
  final String? farmId;
  final String? createdBy;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final int versionId;
  final String label;
  final double amount;
  final DateTime date;
  final ExpenseCategory category;

  const Expense({
    required this.id,
    this.remoteId,
    this.syncStatus = SyncStatus.synced,
    this.animalId,
    this.farmId,
    this.createdBy,
    this.updatedAt,
    this.deletedAt,
    this.versionId = 1,
    required this.label,
    required this.amount,
    required this.date,
    required this.category,
  });

  Expense copyWith({
    String? id,
    String? remoteId,
    bool clearRemoteId = false,
    SyncStatus? syncStatus,
    String? animalId,
    String? farmId,
    String? createdBy,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    int? versionId,
    String? label,
    double? amount,
    DateTime? date,
    ExpenseCategory? category,
  }) {
    return Expense(
      id: id ?? this.id,
      remoteId: clearRemoteId ? null : (remoteId ?? this.remoteId),
      syncStatus: syncStatus ?? this.syncStatus,
      animalId: animalId ?? this.animalId,
      farmId: farmId ?? this.farmId,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      versionId: versionId ?? this.versionId,
      label: label ?? this.label,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      if (remoteId != null) 'remoteId': remoteId,
      'syncStatus': syncStatus.name,
      if (animalId != null) 'animalId': animalId,
      if (farmId != null) 'farmId': farmId,
      if (createdBy != null) 'createdBy': createdBy,
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
      'versionId': versionId,
      'label': label,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category.name,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    final id = map['id'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException(
          'Champ "id" invalide ou manquant dans Expense');
    }

    final remoteIdRaw = map['remoteId'];
    final String? remoteId =
        (remoteIdRaw is String && remoteIdRaw.trim().isNotEmpty)
            ? remoteIdRaw.trim()
            : null;

    final syncStatusRaw = map['syncStatus'] as String?;
    final syncStatus = syncStatusRaw != null
        ? SyncStatus.fromString(syncStatusRaw)
        : SyncStatus.synced;

    final animalIdRaw = map['animalId'];
    final String? animalId =
        (animalIdRaw is String && animalIdRaw.trim().isNotEmpty)
            ? animalIdRaw.trim()
            : null;

    final farmIdRaw = map['farmId'];
    final String? farmId = (farmIdRaw is String && farmIdRaw.trim().isNotEmpty)
        ? farmIdRaw.trim()
        : null;

    final createdByRaw = map['createdBy'];
    final String? createdBy =
        (createdByRaw is String && createdByRaw.trim().isNotEmpty)
            ? createdByRaw.trim()
            : null;

    final updatedAtRaw = map['updatedAt'];
    final DateTime? updatedAt;
    if (updatedAtRaw is String) {
      updatedAt = DateTime.tryParse(updatedAtRaw);
    } else if (updatedAtRaw is DateTime) {
      updatedAt = updatedAtRaw;
    } else {
      updatedAt = null;
    }

    final deletedAtRaw = map['deletedAt'];
    final DateTime? deletedAt;
    if (deletedAtRaw is String) {
      deletedAt = DateTime.tryParse(deletedAtRaw);
    } else if (deletedAtRaw is DateTime) {
      deletedAt = deletedAtRaw;
    } else {
      deletedAt = null;
    }

    final label = map['label'];
    if (label is! String || label.trim().isEmpty) {
      throw const FormatException(
          'Champ "label" invalide ou manquant dans Expense');
    }

    final amountRaw = map['amount'];
    if (amountRaw is! num ||
        amountRaw.isNaN ||
        amountRaw.isInfinite ||
        amountRaw <= 0) {
      throw FormatException('Champ "amount" invalide dans Expense: $amountRaw');
    }
    final amount = amountRaw.toDouble();

    final dateRaw = map['date'];
    final DateTime date;
    if (dateRaw is String) {
      date = DateTime.parse(dateRaw);
    } else if (dateRaw is DateTime) {
      date = dateRaw;
    } else {
      throw const FormatException(
          'Champ "date" invalide ou manquant dans Expense');
    }

    final categoryStr = map['category'];
    if (categoryStr is! String) {
      throw const FormatException(
          'Champ "category" manquant ou non textuel dans Expense');
    }
    final category = ExpenseCategory.values.firstWhere(
      (c) => c.name == categoryStr,
      orElse: () => throw FormatException(
          'Catégorie de dépense inconnue: "$categoryStr"'),
    );

    final versionIdRaw = map['versionId'] ?? map['version_id'];
    final int versionId = (versionIdRaw is num) ? versionIdRaw.toInt() : 1;

    return Expense(
      id: id,
      remoteId: remoteId,
      syncStatus: syncStatus,
      animalId: animalId,
      farmId: farmId,
      createdBy: createdBy,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      versionId: versionId,
      label: label,
      amount: amount,
      date: date,
      category: category,
    );
  }

  /// Prépare le payload spécifique destiné à l'API PostgreSQL / Supabase.
  Map<String, dynamic> toSupabaseMap({
    required String remoteFarmId,
    required String remoteAnimalId,
  }) {
    return {
      if (remoteId != null) 'id': remoteId,
      'farm_id': remoteFarmId,
      'animal_id': remoteAnimalId,
      'local_id': id,
      'label': label,
      'amount': amount,
      'date': date.toUtc().toIso8601String(),
      'category': category.name,
      'version_id': versionId,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
      if (deletedAt != null) 'deleted_at': deletedAt!.toUtc().toIso8601String(),
    };
  }

  /// Reconstruit une [Expense] depuis un enregistrement PostgreSQL Supabase.
  factory Expense.fromSupabaseMap(Map<String, dynamic> map) {
    final serverId = map['id'] as String;
    final localId = (map['local_id'] as String?)?.trim();
    final versionIdRaw = map['version_id'] ?? map['versionId'];
    final int versionId = (versionIdRaw is num) ? versionIdRaw.toInt() : 1;

    return Expense(
      id: (localId != null && localId.isNotEmpty) ? localId : serverId,
      remoteId: serverId,
      syncStatus: SyncStatus.synced,
      animalId: map['animal_id'] as String?,
      farmId: map['farm_id'] as String?,
      createdBy: map['created_by'] as String?,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
      deletedAt: map['deleted_at'] != null
          ? DateTime.tryParse(map['deleted_at'] as String)
          : null,
      versionId: versionId,
      label: map['label'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      category: ExpenseCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => ExpenseCategory.autre,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Expense &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          remoteId == other.remoteId &&
          syncStatus == other.syncStatus &&
          animalId == other.animalId &&
          farmId == other.farmId &&
          createdBy == other.createdBy &&
          updatedAt == other.updatedAt &&
          deletedAt == other.deletedAt &&
          versionId == other.versionId &&
          label == other.label &&
          amount == other.amount &&
          date == other.date &&
          category == other.category;

  @override
  int get hashCode =>
      id.hashCode ^
      remoteId.hashCode ^
      syncStatus.hashCode ^
      animalId.hashCode ^
      farmId.hashCode ^
      createdBy.hashCode ^
      updatedAt.hashCode ^
      deletedAt.hashCode ^
      versionId.hashCode ^
      label.hashCode ^
      amount.hashCode ^
      date.hashCode ^
      category.hashCode;
}

enum ExpenseCategory {
  alimentation('Alimentation', '🌾'),
  sante('Santé', '💊'),
  autre('Autre', '📦');

  const ExpenseCategory(this.label, this.emoji);
  final String label;
  final String emoji;
}
