// lib/providers/active_farm_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../data/database/database_migrator.dart';
import '../models/farm.dart';
import '../models/user_farm_membership.dart';
import '../models/user_profile.dart';
import 'animals_provider.dart';
import 'auth_provider.dart';

// ─── État de l'exploitation active et des exploitations accessibles ──────────
class ActiveFarmState {
  /// L'exploitation active couramment sélectionnée
  final Farm activeFarm;

  /// Le rôle de l'utilisateur sur l'exploitation active
  /// (Sur la ferme locale ou par défaut : UserRole.owner)
  final UserRole userRoleOnActiveFarm;

  /// Liste des exploitations distantes accessibles à l'utilisateur connecté via RLS
  final List<UserFarmMembership> accessibleRemoteFarms;

  /// Liste des exploitations locales issues de Sembast
  final List<Farm> localFarms;

  /// Indicateur de chargement en cours
  final bool isLoading;

  /// Message d'erreur éventuel
  final String? errorMessage;

  const ActiveFarmState({
    required this.activeFarm,
    this.userRoleOnActiveFarm = UserRole.owner,
    this.accessibleRemoteFarms = const [],
    this.localFarms = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isLocal => activeFarm.isLocal;
  bool get isRemote => !isLocal;
  bool get isOwner => userRoleOnActiveFarm == UserRole.owner;
  bool get isManager => userRoleOnActiveFarm == UserRole.manager;
  bool get isWorker => userRoleOnActiveFarm == UserRole.worker;
  bool get canManage => isOwner || isManager;
  bool get hasRemoteFarms => accessibleRemoteFarms.isNotEmpty;

  // Permissions d'actions sur l'exploitation active
  bool get canAddAnimal => userRoleOnActiveFarm.canAddAnimal;
  bool get canUpdateAnimal => userRoleOnActiveFarm.canUpdateAnimal;
  bool get canDeleteAnimal => userRoleOnActiveFarm.canDeleteAnimal;
  bool get canAddExpense => userRoleOnActiveFarm.canAddExpense;
  bool get canUpdateExpense => userRoleOnActiveFarm.canUpdateExpense;
  bool get canDeleteExpense => userRoleOnActiveFarm.canDeleteExpense;
  bool get canManageMembers => userRoleOnActiveFarm.canManageMembers;
  bool get canEditFarm => userRoleOnActiveFarm.canEditFarm;

  ActiveFarmState copyWith({
    Farm? activeFarm,
    UserRole? userRoleOnActiveFarm,
    List<UserFarmMembership>? accessibleRemoteFarms,
    List<Farm>? localFarms,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ActiveFarmState(
      activeFarm: activeFarm ?? this.activeFarm,
      userRoleOnActiveFarm: userRoleOnActiveFarm ?? this.userRoleOnActiveFarm,
      accessibleRemoteFarms:
          accessibleRemoteFarms ?? this.accessibleRemoteFarms,
      localFarms: localFarms ?? this.localFarms,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ─── Abstraction du service d'exploitation pour injection et tests ───────────
abstract class IFarmService {
  /// Récupère la liste des exploitations autorisées et le rôle associé
  Future<List<UserFarmMembership>> fetchUserFarms(String userId);

  /// Crée une exploitation distante atomique via RPC create_farm_with_owner
  Future<Farm> createRemoteFarm({
    required String name,
    String? region,
    bool isDemo = false,
  });
}

// ─── Implémentation réelle avec Supabase ─────────────────────────────────────
class SupabaseFarmService implements IFarmService {
  final SupabaseClient? _client;

  SupabaseFarmService({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.safeClient;

  @override
  Future<List<UserFarmMembership>> fetchUserFarms(String userId) async {
    final client = _client;
    if (client == null) return const [];

    try {
      // Requête RLS sur farm_members avec jointure sécurisée sur farms
      final List<dynamic> response = await client
          .from('farm_members')
          .select(
              'farm_id, role, farms:farm_id(id, name, region, owner_id, is_demo, created_at, updated_at)')
          .eq('user_id', userId);

      final List<UserFarmMembership> memberships = [];
      for (final item in response) {
        if (item is Map<String, dynamic>) {
          final roleStr = item['role'] as String?;
          final role = UserRole.fromString(roleStr);
          final farmData = item['farms'];
          if (farmData is Map<String, dynamic>) {
            final farm = Farm.fromMap(farmData);
            memberships.add(UserFarmMembership(farm: farm, role: role));
          }
        }
      }
      return memberships;
    } catch (e) {
      debugPrint(
          '[FarmService] Erreur lors du chargement des exploitations : $e');
      rethrow;
    }
  }

  @override
  Future<Farm> createRemoteFarm({
    required String name,
    String? region,
    bool isDemo = false,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Client Supabase non initialisé.');
    }

    // Appel exclusif et obligatoire de la fonction RPC atomique create_farm_with_owner
    final response = await client.rpc('create_farm_with_owner', params: {
      'farm_name': name.trim(),
      if (region != null && region.trim().isNotEmpty)
        'farm_region': region.trim(),
      'is_demo_farm': isDemo,
    });

    if (response is Map<String, dynamic>) {
      return Farm.fromMap(response);
    }
    throw StateError('Réponse inattendue de create_farm_with_owner: $response');
  }
}

// ─── Providers Riverpod ──────────────────────────────────────────────────────
final farmServiceProvider = Provider<IFarmService>((ref) {
  return SupabaseFarmService();
});

class ActiveFarmNotifier extends StateNotifier<ActiveFarmState> {
  final Ref _ref;
  final IFarmService _farmService;

  static final Farm _defaultLocalFarm = Farm(
    id: DatabaseMigrator.defaultFarmId,
    name: DatabaseMigrator.defaultFarmName,
    region: 'Sénégal',
    isDemo: false,
    createdAt: DateTime(2026, 1, 1),
  );

  ActiveFarmNotifier(this._ref, this._farmService)
      : super(ActiveFarmState(activeFarm: _defaultLocalFarm)) {
    // 1. Écouter les changements d'état d'authentification SYNCHRONEMENT lors du montage
    _ref.listen<AppAuthState>(authProvider, (previous, current) {
      if (!mounted) return;
      if (current.isAuthenticated && current.userId != null) {
        loadRemoteFarms(current.userId!);
      } else if (current.isUnauthenticated) {
        switchToLocalFarm();
      }
    });

    // 2. Initialiser les données locales sans bloquer
    _init();
  }

  Future<void> _init() async {
    // Charger immédiatement les fermes locales Sembast (disponible hors-ligne)
    await loadLocalFarms();
    if (!mounted) return;

    // Si déjà authentifié lors de l'initialisation du provider
    final currentAuth = _ref.read(authProvider);
    if (currentAuth.isAuthenticated && currentAuth.userId != null) {
      await loadRemoteFarms(currentAuth.userId!);
    }
  }

  /// Charge les exploitations locales persistées dans Sembast
  Future<void> loadLocalFarms() async {
    if (!mounted) return;
    try {
      final repo = _ref.read(animalsRepositoryProvider);
      final farms = await repo.fetchFarms();
      if (!mounted) return;
      final active = farms.isNotEmpty ? farms.first : _defaultLocalFarm;
      state = state.copyWith(
        localFarms: farms,
        activeFarm: state.isLocal ? active : state.activeFarm,
      );
    } catch (e) {
      if (mounted) {
        debugPrint('[ActiveFarmNotifier] Erreur chargement fermes locales: $e');
      }
    }
  }

  /// Charge les exploitations distantes autorisées pour l'utilisateur connecté via RLS
  Future<void> loadRemoteFarms(String userId) async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final remoteMemberships = await _farmService.fetchUserFarms(userId);
      if (!mounted) return;
      if (remoteMemberships.isNotEmpty) {
        // Préserver l'exploitation active si elle fait partie des autorisées, sinon prendre la 1ère
        final existingMatch = remoteMemberships.firstWhere(
          (m) => m.farm.id == state.activeFarm.id,
          orElse: () => remoteMemberships.first,
        );

        state = state.copyWith(
          accessibleRemoteFarms: remoteMemberships,
          activeFarm: existingMatch.farm,
          userRoleOnActiveFarm: existingMatch.role,
          isLoading: false,
        );
      } else {
        // Utilisateur connecté sans exploitation distante existante
        state = state.copyWith(
          accessibleRemoteFarms: const [],
          isLoading: false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de charger les exploitations distantes : $e',
      );
    }
  }

  /// Sélectionne explicitement une exploitation active
  void selectFarm(Farm farm, {UserRole role = UserRole.owner}) {
    if (!mounted) return;
    if (farm.isLocal) {
      state = state.copyWith(
        activeFarm: farm,
        userRoleOnActiveFarm: UserRole.owner,
        clearError: true,
      );
    } else {
      final match = state.accessibleRemoteFarms.firstWhere(
        (m) => m.farm.id == farm.id,
        orElse: () => UserFarmMembership(farm: farm, role: role),
      );

      state = state.copyWith(
        activeFarm: match.farm,
        userRoleOnActiveFarm: match.role,
        clearError: true,
      );
    }
  }

  /// Bascule sur l'exploitation locale Sembast sans détruire les données
  void switchToLocalFarm() {
    if (!mounted) return;
    final localFarm = state.localFarms.isNotEmpty
        ? state.localFarms.first
        : _defaultLocalFarm;

    state = state.copyWith(
      activeFarm: localFarm,
      userRoleOnActiveFarm: UserRole.owner,
      accessibleRemoteFarms: const [],
      clearError: true,
      isLoading: false,
    );
  }

  /// Crée une exploitation distante via la fonction RPC atomique create_farm_with_owner
  Future<Farm?> createRemoteFarm({
    required String name,
    String? region,
    bool isDemo = false,
  }) async {
    if (!mounted) return null;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final created = await _farmService.createRemoteFarm(
        name: name,
        region: region,
        isDemo: isDemo,
      );
      if (!mounted) return created;

      final membership = UserFarmMembership(
        farm: created,
        role: UserRole.owner,
      );

      final updatedList = [...state.accessibleRemoteFarms, membership];
      state = state.copyWith(
        accessibleRemoteFarms: updatedList,
        activeFarm: created,
        userRoleOnActiveFarm: UserRole.owner,
        isLoading: false,
      );
      return created;
    } catch (e) {
      if (!mounted) return null;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Échec de la création de l\'exploitation : $e',
      );
      return null;
    }
  }
}

final activeFarmProvider =
    StateNotifierProvider<ActiveFarmNotifier, ActiveFarmState>((ref) {
  final farmService = ref.watch(farmServiceProvider);
  return ActiveFarmNotifier(ref, farmService);
});

/// Provider pratique exposant uniquement l'identifiant de la ferme active
final activeFarmIdProvider = Provider<String>((ref) {
  return ref.watch(activeFarmProvider).activeFarm.id;
});
