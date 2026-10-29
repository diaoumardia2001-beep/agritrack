// lib/models/farm.dart

/// Exploitation agricole / élevage.
/// Unité de cloisonnement multi-tenant pour les animaux et les dépenses.
class Farm {
  final String id;
  final String name;
  final String? region;
  final String? ownerId;
  final bool isDemo;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Farm({
    required this.id,
    required this.name,
    this.region,
    this.ownerId,
    this.isDemo = false,
    required this.createdAt,
    this.updatedAt,
  });

  Farm copyWith({
    String? id,
    String? name,
    String? region,
    String? ownerId,
    bool? isDemo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Farm(
      id: id ?? this.id,
      name: name ?? this.name,
      region: region ?? this.region,
      ownerId: ownerId ?? this.ownerId,
      isDemo: isDemo ?? this.isDemo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Indique si cette exploitation est purement locale (Sembast) ou distante (Supabase).
  bool get isLocal => id == 'local_default_farm' || id.startsWith('local_');
  bool get isRemote => !isLocal;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      if (region != null) 'region': region,
      if (ownerId != null) 'ownerId': ownerId,
      'isDemo': isDemo,
      'createdAt': createdAt.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  factory Farm.fromMap(Map<String, dynamic> map) {
    final idRaw = map['id'];
    if (idRaw is! String || idRaw.trim().isEmpty) {
      throw const FormatException('Champ "id" invalide ou manquant dans Farm');
    }

    final nameRaw = map['name'];
    if (nameRaw is! String || nameRaw.trim().isEmpty) {
      throw const FormatException(
          'Champ "name" invalide ou manquant dans Farm');
    }

    final regionRaw = map['region'];
    final String? region = (regionRaw is String && regionRaw.trim().isNotEmpty)
        ? regionRaw.trim()
        : null;

    final ownerIdRaw = map['ownerId'] ?? map['owner_id'];
    final String? ownerId =
        (ownerIdRaw is String && ownerIdRaw.trim().isNotEmpty)
            ? ownerIdRaw.trim()
            : null;

    final isDemo = (map['isDemo'] ?? map['is_demo']) as bool? ?? false;

    final createdAtRaw = map['createdAt'] ?? map['created_at'];
    final DateTime createdAt;
    if (createdAtRaw is String) {
      createdAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
    } else if (createdAtRaw is DateTime) {
      createdAt = createdAtRaw;
    } else {
      createdAt = DateTime.now();
    }

    final updatedAtRaw = map['updatedAt'] ?? map['updated_at'];
    final DateTime? updatedAt;
    if (updatedAtRaw is String) {
      updatedAt = DateTime.tryParse(updatedAtRaw);
    } else if (updatedAtRaw is DateTime) {
      updatedAt = updatedAtRaw;
    } else {
      updatedAt = null;
    }

    return Farm(
      id: idRaw.trim(),
      name: nameRaw.trim(),
      region: region,
      ownerId: ownerId,
      isDemo: isDemo,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Farm &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          region == other.region &&
          ownerId == other.ownerId &&
          isDemo == other.isDemo &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      region.hashCode ^
      ownerId.hashCode ^
      isDemo.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;
}
