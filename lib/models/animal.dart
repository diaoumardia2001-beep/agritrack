// lib/models/animal.dart
import 'expense.dart';

export 'sync_status.dart';

class Animal {
  final String id;
  final String farmId;
  final String? remoteId;
  final SyncStatus syncStatus;
  final bool isDemo;
  final String? createdBy;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final int versionId;
  final String name;
  final AnimalType type;
  final int ageMonths;
  final double weightKg;
  final HealthStatus healthStatus;
  final String? imageUrl;
  final List<Expense> expenses;
  final DateTime createdAt;

  const Animal({
    required this.id,
    this.farmId = 'local_default_farm',
    this.remoteId,
    this.syncStatus = SyncStatus.synced,
    this.isDemo = false,
    this.createdBy,
    this.updatedAt,
    this.deletedAt,
    this.versionId = 1,
    required this.name,
    required this.type,
    required this.ageMonths,
    required this.weightKg,
    required this.healthStatus,
    this.imageUrl,
    required this.expenses,
    required this.createdAt,
  });

  Animal copyWith({
    String? id,
    String? farmId,
    String? remoteId,
    bool clearRemoteId = false,
    SyncStatus? syncStatus,
    bool? isDemo,
    String? createdBy,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    int? versionId,
    String? name,
    AnimalType? type,
    int? ageMonths,
    double? weightKg,
    HealthStatus? healthStatus,
    String? imageUrl,
    List<Expense>? expenses,
    DateTime? createdAt,
  }) {
    return Animal(
      id: id ?? this.id,
      farmId: farmId ?? this.farmId,
      remoteId: clearRemoteId ? null : (remoteId ?? this.remoteId),
      syncStatus: syncStatus ?? this.syncStatus,
      isDemo: isDemo ?? this.isDemo,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      versionId: versionId ?? this.versionId,
      name: name ?? this.name,
      type: type ?? this.type,
      ageMonths: ageMonths ?? this.ageMonths,
      weightKg: weightKg ?? this.weightKg,
      healthStatus: healthStatus ?? this.healthStatus,
      imageUrl: imageUrl ?? this.imageUrl,
      expenses: expenses ?? this.expenses,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'farmId': farmId,
      if (remoteId != null) 'remoteId': remoteId,
      'syncStatus': syncStatus.name,
      'isDemo': isDemo,
      if (createdBy != null) 'createdBy': createdBy,
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
      'versionId': versionId,
      'name': name,
      'type': type.name,
      'ageMonths': ageMonths,
      'weightKg': weightKg,
      'healthStatus': healthStatus.name,
      'imageUrl': imageUrl,
      'expenses': expenses.map((e) => e.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Animal.fromMap(Map<String, dynamic> map) {
    final id = map['id'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException(
          'Champ "id" invalide ou manquant dans Animal');
    }

    final farmIdRaw = map['farmId'];
    final String farmId = (farmIdRaw is String && farmIdRaw.trim().isNotEmpty)
        ? farmIdRaw.trim()
        : 'local_default_farm';

    final remoteIdRaw = map['remoteId'];
    final String? remoteId =
        (remoteIdRaw is String && remoteIdRaw.trim().isNotEmpty)
            ? remoteIdRaw.trim()
            : null;

    final syncStatusRaw = map['syncStatus'] as String?;
    final syncStatus = syncStatusRaw != null
        ? SyncStatus.fromString(syncStatusRaw)
        : SyncStatus.synced;

    final isDemo = map['isDemo'] as bool? ?? false;
    final createdBy = map['createdBy'] as String?;

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

    final name = map['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException(
          'Champ "name" invalide ou manquant dans Animal');
    }

    final typeStr = map['type'];
    if (typeStr is! String) {
      throw const FormatException(
          'Champ "type" manquant ou non textuel dans Animal');
    }
    final type = AnimalType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => throw FormatException('Type d\'animal inconnu: "$typeStr"'),
    );

    final ageRaw = map['ageMonths'];
    if (ageRaw is! num || ageRaw.isNaN || ageRaw.isInfinite || ageRaw < 0) {
      throw FormatException(
          'Champ "ageMonths" invalide ou manquant dans Animal: $ageRaw');
    }
    final ageMonths = ageRaw.toInt();

    final weightRaw = map['weightKg'];
    if (weightRaw is! num ||
        weightRaw.isNaN ||
        weightRaw.isInfinite ||
        weightRaw <= 0) {
      throw FormatException(
          'Champ "weightKg" invalide ou manquant dans Animal: $weightRaw');
    }
    final weightKg = weightRaw.toDouble();

    final healthStr = map['healthStatus'];
    if (healthStr is! String) {
      throw const FormatException(
          'Champ "healthStatus" manquant ou non textuel dans Animal');
    }
    final healthStatus = HealthStatus.values.firstWhere(
      (h) => h.name == healthStr || h.value == healthStr,
      orElse: () =>
          throw FormatException('Statut sanitaire inconnu: "$healthStr"'),
    );

    final imageUrlRaw = map['imageUrl'];
    final String? imageUrl;
    if (imageUrlRaw == null) {
      imageUrl = null;
    } else if (imageUrlRaw is String) {
      imageUrl = imageUrlRaw.trim().isEmpty ? null : imageUrlRaw;
    } else {
      throw const FormatException('Champ "imageUrl" invalide dans Animal');
    }

    final expensesRaw = map['expenses'];
    final List<Expense> expenses;
    if (expensesRaw == null) {
      expenses = const <Expense>[];
    } else if (expensesRaw is List) {
      expenses = expensesRaw.map((e) {
        if (e is! Map) {
          throw const FormatException(
              'Élément de dépense invalide dans Animal');
        }
        return Expense.fromMap(Map<String, dynamic>.from(e));
      }).toList();
    } else {
      throw const FormatException('Champ "expenses" invalide dans Animal');
    }

    final createdAtRaw = map['createdAt'];
    final DateTime createdAt;
    if (createdAtRaw is String) {
      createdAt = DateTime.parse(createdAtRaw);
    } else if (createdAtRaw is DateTime) {
      createdAt = createdAtRaw;
    } else {
      throw const FormatException(
          'Champ "createdAt" invalide ou manquant dans Animal');
    }

    final versionIdRaw = map['versionId'] ?? map['version_id'];
    final int versionId = (versionIdRaw is num) ? versionIdRaw.toInt() : 1;

    return Animal(
      id: id,
      farmId: farmId,
      remoteId: remoteId,
      syncStatus: syncStatus,
      isDemo: isDemo,
      createdBy: createdBy,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      versionId: versionId,
      name: name,
      type: type,
      ageMonths: ageMonths,
      weightKg: weightKg,
      healthStatus: healthStatus,
      imageUrl: imageUrl,
      expenses: expenses,
      createdAt: createdAt,
    );
  }

  /// Prépare le payload spécifique destiné à l'API PostgreSQL / Supabase.
  /// Convertit explicitement [healthStatus] via [toSupabaseValue] pour respecter
  /// la contrainte SQL CHECK ('sain', 'a_surveiller', 'malade').
  Map<String, dynamic> toSupabaseMap({required String remoteFarmId}) {
    return {
      if (remoteId != null) 'id': remoteId,
      'farm_id': remoteFarmId,
      'local_id': id,
      'name': name,
      'type': type.name,
      'age_months': ageMonths,
      'weight_kg': weightKg,
      'health_status': healthStatus.toSupabaseValue(),
      if (imageUrl != null) 'image_url': imageUrl,
      'is_demo': isDemo,
      'version_id': versionId,
      if (createdBy != null) 'created_by': createdBy,
      'created_at': createdAt.toUtc().toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
      if (deletedAt != null) 'deleted_at': deletedAt!.toUtc().toIso8601String(),
    };
  }

  /// Reconstruit un [Animal] depuis un enregistrement PostgreSQL Supabase.
  factory Animal.fromSupabaseMap(
    Map<String, dynamic> map, {
    List<Expense> expenses = const [],
  }) {
    final serverId = map['id'] as String;
    final localId = (map['local_id'] as String?)?.trim();
    final farmId = map['farm_id'] as String;
    final versionIdRaw = map['version_id'] ?? map['versionId'];
    final int versionId = (versionIdRaw is num) ? versionIdRaw.toInt() : 1;

    return Animal(
      id: (localId != null && localId.isNotEmpty) ? localId : serverId,
      remoteId: serverId,
      farmId: farmId,
      syncStatus: SyncStatus.synced,
      isDemo: (map['is_demo'] as bool?) ?? false,
      createdBy: map['created_by'] as String?,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
      deletedAt: map['deleted_at'] != null
          ? DateTime.tryParse(map['deleted_at'] as String)
          : null,
      versionId: versionId,
      name: map['name'] as String,
      type: AnimalType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => AnimalType.bovin,
      ),
      ageMonths: (map['age_months'] as num).toInt(),
      weightKg: (map['weight_kg'] as num).toDouble(),
      healthStatus:
          HealthStatus.fromSupabaseValue(map['health_status'] as String),
      imageUrl: map['image_url'] as String?,
      expenses: expenses,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Liste des dépenses actives (exclut les dépenses supprimées logiquement).
  List<Expense> get activeExpenses =>
      expenses.where((e) => e.deletedAt == null).toList();

  double get totalExpenses =>
      activeExpenses.fold(0.0, (sum, e) => sum + e.amount);

  /// Calcule le total des dépenses pour un mois donné (par défaut, le mois courant).
  double monthlyExpensesFor([DateTime? referenceDate]) {
    final ref = referenceDate ?? DateTime.now();
    return activeExpenses
        .where((e) => e.date.year == ref.year && e.date.month == ref.month)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get monthlyExpenses => monthlyExpensesFor();
}

enum AnimalType {
  bovin('Bovin', '🐄'),
  caprin('Caprin', '🐐'),
  ovin('Ovin', '🐑'),
  volaille('Volaille', '🐓');

  const AnimalType(this.label, this.emoji);
  final String label;
  final String emoji;
}

enum HealthStatus {
  sain('Sain', 'sain'),
  aSurveiller('À surveiller', 'a_surveiller'),
  malade('Malade', 'malade');

  const HealthStatus(this.label, this.value);
  final String label;
  final String value;

  /// Convertit le statut sanitaire vers la valeur attendue par la contrainte PostgreSQL Supabase:
  /// 'sain' -> 'sain', 'aSurveiller' -> 'a_surveiller', 'malade' -> 'malade'.
  String toSupabaseValue() => value;

  /// Désérialise depuis une valeur issue de PostgreSQL Supabase.
  static HealthStatus fromSupabaseValue(String supabaseVal) {
    final normalized = supabaseVal.trim().toLowerCase();
    return HealthStatus.values.firstWhere(
      (h) => h.value.toLowerCase() == normalized,
      orElse: () => throw FormatException(
          'Valeur Supabase inconnue pour HealthStatus: "$supabaseVal"'),
    );
  }
}
