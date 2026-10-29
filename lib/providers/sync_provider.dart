import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sync/connectivity_service.dart';
import '../services/sync/supabase_sync_client.dart';
import '../services/sync/sync_coordinator.dart';
import '../services/sync/sync_cursor_service.dart';
import '../services/sync/sync_engine.dart';
import '../services/sync/sync_queue_service.dart';
import 'animals_provider.dart';

/// Provider pour le service de gestion des curseurs de synchronisation.
final syncCursorServiceProvider = Provider<SyncCursorService>((ref) {
  return SyncCursorService();
});

/// Provider pour le service de connectivité réseau.
final connectivityServiceProvider = Provider<IConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider pour le service de gestion de la file d'attente de synchronisation.
final syncQueueServiceProvider = Provider<SyncQueueService>((ref) {
  return SyncQueueService();
});

/// Provider pour le client de synchronisation réseau Supabase.
final supabaseSyncClientProvider = Provider<ISupabaseSyncClient>((ref) {
  return RealSupabaseSyncClient();
});

/// Provider pour le moteur de synchronisation Sembast ↔ Supabase.
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final syncClient = ref.watch(supabaseSyncClientProvider);
  final queueService = ref.watch(syncQueueServiceProvider);
  final animalsRepository = ref.watch(animalsRepositoryProvider);
  final cursorService = ref.watch(syncCursorServiceProvider);

  return SyncEngine(
    syncClient: syncClient,
    queueService: queueService,
    animalsRepository: animalsRepository,
    cursorService: cursorService,
  );
});

/// Provider pour le coordinateur de synchronisation automatique (connectivité, lifecycle, outbox).
final syncCoordinatorProvider =
    StateNotifierProvider<SyncCoordinator, SyncCoordinatorState>((ref) {
  final syncEngine = ref.watch(syncEngineProvider);
  final queueService = ref.watch(syncQueueServiceProvider);
  final animalsRepository = ref.watch(animalsRepositoryProvider);
  final connectivityService = ref.watch(connectivityServiceProvider);

  final coordinator = SyncCoordinator(
    syncEngine: syncEngine,
    queueService: queueService,
    animalsRepository: animalsRepository,
    connectivityService: connectivityService,
    ref: ref,
  );

  return coordinator;
});
