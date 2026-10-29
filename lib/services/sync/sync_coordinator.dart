// lib/services/sync/sync_coordinator.dart
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/animals_repository.dart';
import '../../data/database/database_migrator.dart';
import '../../providers/active_farm_provider.dart';
import '../../providers/animals_provider.dart';
import '../../providers/auth_provider.dart';
import 'connectivity_service.dart';
import 'sync_engine.dart';
import 'sync_queue_service.dart';

/// État réactif de la synchronisation automatique globale.
class SyncCoordinatorState {
  final bool isSyncing;
  final bool isOnline;
  final DateTime? lastSyncTime;
  final SyncResult? lastResult;
  final String? errorMessage;

  const SyncCoordinatorState({
    this.isSyncing = false,
    this.isOnline = true,
    this.lastSyncTime,
    this.lastResult,
    this.errorMessage,
  });

  SyncCoordinatorState copyWith({
    bool? isSyncing,
    bool? isOnline,
    DateTime? lastSyncTime,
    SyncResult? lastResult,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SyncCoordinatorState(
      isSyncing: isSyncing ?? this.isSyncing,
      isOnline: isOnline ?? this.isOnline,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastResult: lastResult ?? this.lastResult,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Coordinateur et déclencheur automatique de synchronisation pour AgriTrack.
///
/// Responsabilités :
/// 1. Détecte le retour de la connectivité réseau via [IConnectivityService].
/// 2. Détecte le retour de l'application au premier plan via [WidgetsBindingObserver].
/// 3. Garantit l'absence de synchronisations concurrentes pour une même exploitation (mutex).
/// 4. Exécute la réconciliation de la file d'attente (outbox recovery) avant chaque transmission.
/// 5. Déclenche [SyncEngine.syncPendingOperations] dans le respect strict des rôles et dépendances.
/// 6. Conserve intégralement les opérations locales Sembast et la file d'attente en cas d'erreur.
class SyncCoordinator extends StateNotifier<SyncCoordinatorState>
    with WidgetsBindingObserver {
  final SyncEngine _syncEngine;
  final SyncQueueService _queueService;
  final AnimalsRepository _animalsRepository;
  final IConnectivityService _connectivityService;
  final Ref _ref;

  final Set<String> _syncingFarms = {};
  StreamSubscription<bool>? _connectivitySub;
  bool _isObserverRegistered = false;

  SyncCoordinator({
    required SyncEngine syncEngine,
    required SyncQueueService queueService,
    required AnimalsRepository animalsRepository,
    required IConnectivityService connectivityService,
    required Ref ref,
    bool autoStart = true,
  })  : _syncEngine = syncEngine,
        _queueService = queueService,
        _animalsRepository = animalsRepository,
        _connectivityService = connectivityService,
        _ref = ref,
        super(SyncCoordinatorState(isOnline: connectivityService.isOnline)) {
    if (autoStart) {
      init();
    }
  }

  /// Initialise les écoutes réseau et cycle de vie.
  void init() {
    // 1. Abonnement aux transitions de connectivité
    _connectivitySub = _connectivityService.onConnectivityChanged.listen((isOnline) {
      final wasOffline = !state.isOnline;
      state = state.copyWith(isOnline: isOnline);

      if (isOnline && wasOffline) {
        debugPrint(
          '[SyncCoordinator] Rétablissement de la connexion réseau détecté -> déclenchement synchronisation',
        );
        syncActiveFarm(triggerReason: 'connectivity_restored');
      }
    });

    // 2. Enregistrement auprès de WidgetsBinding si l'environnement graphique est prêt
    try {
      final binding = WidgetsBinding.instance;
      binding.addObserver(this);
      _isObserverRegistered = true;
    } catch (_) {
      // Dans certains environnements de test headless, WidgetsBinding.instance peut être indisponible
    }
  }

  /// Détecte le cycle de vie de l'application Flutter.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      debugPrint(
        '[SyncCoordinator] Application revenue au premier plan (resumed) -> tentative de synchronisation',
      );
      syncActiveFarm(triggerReason: 'app_resumed');
    }
  }

  Future<SyncResult>? _currentSyncFuture;
  Future<SyncResult>? get currentSyncFuture => _currentSyncFuture;

  /// Indique si une synchronisation est actuellement en cours pour une exploitation donnée.
  bool isSyncingFarm(String farmId) => _syncingFarms.contains(farmId.trim());

  /// Déclenche la synchronisation de l'exploitation active.
  ///
  /// Garantit :
  /// - Absence de synchronisation concurrente sur la même ferme (verrou).
  /// - Exclusion des fermes locales et démo.
  /// - Réconciliation de la file d'attente avant envoi.
  /// - Conservation des opérations en cas de panne réseau ou expiration de session.
  Future<SyncResult> syncActiveFarm({String triggerReason = 'manual'}) {
    final future = _performSync(triggerReason);
    _currentSyncFuture = future;
    return future;
  }

  Future<SyncResult> _performSync(String triggerReason) async {
    final activeFarmState = _ref.read(activeFarmProvider);
    final authState = _ref.read(authProvider);

    final farmId = activeFarmState.activeFarm.id.trim();
    final userId = authState.userId?.trim();

    // 1. Vérification session utilisateur
    if (userId == null || userId.isEmpty) {
      debugPrint(
        '[SyncCoordinator] Synchronisation ignorée ($triggerReason) : aucun utilisateur connecté.',
      );
      return const SyncResult(
        hasFatalError: true,
        fatalErrorMessage: 'Session utilisateur absente ou expirée.',
      );
    }

    // 2. Vérification exploitation distante éligible
    if (farmId.isEmpty ||
        farmId == DatabaseMigrator.defaultFarmId ||
        farmId.startsWith('local_')) {
      debugPrint(
        '[SyncCoordinator] Synchronisation ignorée ($triggerReason) : exploitation "$farmId" locale.',
      );
      return const SyncResult(
        hasFatalError: true,
        fatalErrorMessage: 'L\'exploitation active est locale et non synchronisable.',
      );
    }

    // 3. Verrou d'exclusion mutuelle : empêcher plusieurs synchronisations concurrentes
    if (_syncingFarms.contains(farmId)) {
      debugPrint(
        '[SyncCoordinator] Synchronisation concurrente bloquée pour $farmId ($triggerReason) : traitement déjà en cours.',
      );
      return SyncResult.empty();
    }

    _syncingFarms.add(farmId);
    if (mounted) {
      state = state.copyWith(isSyncing: true, clearError: true);
    }

    try {
      debugPrint(
        '[SyncCoordinator] Démarrage du cycle de synchronisation pour farm=$farmId, user=$userId ($triggerReason)',
      );

      // 4. Réconciliation de la file (Outbox Recovery)
      // Réinsère de manière idempotente toute mutation locale n'ayant pas d'opération correspondante
      await _queueService.reconcile(
        repository: _animalsRepository,
        farmId: farmId,
        userId: userId,
      );

      // 5. Exécution ordonnée du moteur de synchronisation (PUSH)
      final pushResult = await _syncEngine.syncPendingOperations(
        farmId: farmId,
        userId: userId,
      );

      SyncResult combinedResult = pushResult;

      // 6. Exécution de la synchronisation descendante (PULL) si le push a réussi sans échec
      if (!pushResult.hasFatalError && pushResult.failureCount == 0) {
        final pullResult = await _syncEngine.pullRemoteChanges(
          farmId: farmId,
          userId: userId,
        );

        combinedResult = SyncResult(
          processedOperations: pushResult.processedOperations,
          successCount: pushResult.successCount,
          failureCount: pushResult.failureCount + pullResult.failureCount,
          blockedCount: pushResult.blockedCount,
          errors: [...pushResult.errors, ...pullResult.errors],
          hasFatalError: pushResult.hasFatalError || pullResult.hasFatalError,
          fatalErrorMessage:
              pushResult.fatalErrorMessage ?? pullResult.fatalErrorMessage,
          animalsPulled: pullResult.animalsPulled,
          expensesPulled: pullResult.expensesPulled,
          conflictsCount:
              pushResult.conflictsCount + pullResult.conflictsCount,
        );
      }

      // 7. Si des entités ont été créées, modifiées ou importées, actualiser le cache local Riverpod
      if (combinedResult.hasChanges) {
        _ref.invalidate(animalsProvider);
      }

      if (mounted) {
        state = state.copyWith(
          isSyncing: false,
          lastSyncTime: DateTime.now(),
          lastResult: combinedResult,
          errorMessage: combinedResult.hasFatalError
              ? combinedResult.fatalErrorMessage
              : null,
        );
      }

      return combinedResult;
    } catch (e, st) {
      final msg = 'Erreur inattendue lors de la synchronisation ($triggerReason): $e';
      debugPrint('[SyncCoordinator] $msg\n$st');

      if (mounted) {
        state = state.copyWith(
          isSyncing: false,
          errorMessage: msg,
        );
      }

      return SyncResult.fatal(msg);
    } finally {
      _syncingFarms.remove(farmId);
      if (mounted && state.isSyncing) {
        state = state.copyWith(isSyncing: false);
      }
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    if (_isObserverRegistered) {
      try {
        WidgetsBinding.instance.removeObserver(this);
      } catch (_) {}
    }
    super.dispose();
  }
}
