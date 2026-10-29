// lib/models/user_farm_membership.dart
import 'farm.dart';
import 'user_profile.dart';

/// Association d'un utilisateur à une exploitation agricole avec son rôle spécifique.
///
/// Reflète la table relationnelle `public.farm_members (farm_id, user_id, role)`.
/// Le rôle (`owner`, `manager`, `worker`) est propre à chaque exploitation et
/// constitue la seule source d'autorité pour les permissions sur cette ferme.
class UserFarmMembership {
  final Farm farm;
  final UserRole role;

  const UserFarmMembership({
    required this.farm,
    required this.role,
  });

  /// Indique si l'utilisateur est le propriétaire de cette exploitation.
  bool get isOwner => role == UserRole.owner;

  /// Indique si l'utilisateur est gestionnaire de cette exploitation.
  bool get isManager => role == UserRole.manager;

  /// Indique si l'utilisateur est simple ouvrier / éleveur sur cette exploitation.
  bool get isWorker => role == UserRole.worker;

  /// Indique si l'utilisateur a des droits d'administration ou de gestion (owner ou manager).
  bool get canManage => isOwner || isManager;

  bool get canAddAnimal => role.canAddAnimal;
  bool get canUpdateAnimal => role.canUpdateAnimal;
  bool get canDeleteAnimal => role.canDeleteAnimal;
  bool get canAddExpense => role.canAddExpense;
  bool get canUpdateExpense => role.canUpdateExpense;
  bool get canDeleteExpense => role.canDeleteExpense;
  bool get canManageMembers => role.canManageMembers;
  bool get canEditFarm => role.canEditFarm;

  UserFarmMembership copyWith({
    Farm? farm,
    UserRole? role,
  }) {
    return UserFarmMembership(
      farm: farm ?? this.farm,
      role: role ?? this.role,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'farm': farm.toMap(),
      'role': role.name,
    };
  }

  factory UserFarmMembership.fromMap(Map<String, dynamic> map) {
    final farmData = map['farm'] ?? map['farms'];
    if (farmData is! Map<String, dynamic>) {
      throw const FormatException(
          'Données d\'exploitation manquantes ou invalides dans UserFarmMembership');
    }

    final roleStr = map['role'] as String?;
    final role = UserRole.fromString(roleStr);

    return UserFarmMembership(
      farm: Farm.fromMap(farmData),
      role: role,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserFarmMembership &&
          runtimeType == other.runtimeType &&
          farm == other.farm &&
          role == other.role;

  @override
  int get hashCode => farm.hashCode ^ role.hashCode;

  @override
  String toString() =>
      'UserFarmMembership(farm: ${farm.name}, role: ${role.label})';
}
