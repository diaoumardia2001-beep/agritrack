// lib/models/user_profile.dart

enum UserRole {
  owner('Propriétaire'),
  manager('Gestionnaire'),
  worker('Éleveur / Ouvrier');

  final String label;
  const UserRole(this.label);

  static UserRole fromString(String? roleStr) {
    if (roleStr == null) return UserRole.owner;
    return UserRole.values.firstWhere(
      (r) => r.name.toLowerCase() == roleStr.toLowerCase(),
      orElse: () => UserRole.owner,
    );
  }

  static UserRole? tryFromString(String? roleStr) {
    if (roleStr == null) return null;
    try {
      return UserRole.values.firstWhere(
        (r) => r.name.toLowerCase() == roleStr.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Permissions alignées avec les politiques RLS de Supabase :
  /// - owner et manager ont les pleins pouvoirs de gestion des animaux et des dépenses
  /// - worker peut ajouter des animaux et dépenses, modifier les données des animaux,
  ///   mais ne peut ni supprimer d'animaux, ni modifier/supprimer de dépenses.
  bool get canAddAnimal => true;
  bool get canUpdateAnimal => true;
  bool get canDeleteAnimal =>
      this == UserRole.owner || this == UserRole.manager;
  bool get canAddExpense => true;
  bool get canUpdateExpense =>
      this == UserRole.owner || this == UserRole.manager;
  bool get canDeleteExpense =>
      this == UserRole.owner || this == UserRole.manager;
  bool get canManageMembers => this == UserRole.owner;
  bool get canEditFarm => this == UserRole.owner;
}

/// Profil éleveur / utilisateur.
/// Conçu pour être relié à auth.users de Supabase (id = auth.uid()).
class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final UserRole role;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    this.phoneNumber,
    this.role = UserRole.owner,
    required this.createdAt,
    this.updatedAt,
  });

  UserProfile copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phoneNumber,
    UserRole? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      'role': role.name,
      'createdAt': createdAt.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final idRaw = map['id'];
    if (idRaw is! String || idRaw.trim().isEmpty) {
      throw const FormatException(
          'Champ "id" invalide ou manquant dans UserProfile');
    }

    final emailRaw = map['email'];
    if (emailRaw is! String || emailRaw.trim().isEmpty) {
      throw const FormatException(
          'Champ "email" invalide ou manquant dans UserProfile');
    }

    final fullNameRaw = map['fullName'] ?? map['full_name'];
    final String fullName =
        (fullNameRaw is String && fullNameRaw.trim().isNotEmpty)
            ? fullNameRaw.trim()
            : 'Éleveur';

    final phoneRaw = map['phoneNumber'] ?? map['phone_number'];
    final String? phoneNumber =
        (phoneRaw is String && phoneRaw.trim().isNotEmpty)
            ? phoneRaw.trim()
            : null;

    final role = UserRole.fromString(map['role'] as String?);

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

    return UserProfile(
      id: idRaw.trim(),
      email: emailRaw.trim(),
      fullName: fullName,
      phoneNumber: phoneNumber,
      role: role,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email &&
          fullName == other.fullName &&
          phoneNumber == other.phoneNumber &&
          role == other.role &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      email.hashCode ^
      fullName.hashCode ^
      phoneNumber.hashCode ^
      role.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;
}
