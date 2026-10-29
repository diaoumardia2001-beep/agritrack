// lib/services/sync/connectivity_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/supabase_config.dart';

/// Abstraction du service de connectivité réseau pour AgriTrack.
/// Permet l'injection de dépendance et des tests unitaires fiables sans matériel réel.
abstract class IConnectivityService {
  /// Indique le dernier état de connectivité connu.
  bool get isOnline;

  /// Flux notifiant les transitions de connectivité (true = en ligne, false = hors-ligne).
  Stream<bool> get onConnectivityChanged;

  /// Vérifie ponctuellement si une connectivité réseau utilisable est disponible.
  Future<bool> checkConnectivity();

  /// Libère les ressources du service.
  void dispose();
}

/// Implémentation de référence sans dépendance externe lourde.
/// Vérifie la connectivité en sondant l'accessibilité de l'infrastructure Supabase.
class ConnectivityService implements IConnectivityService {
  final StreamController<bool> _controller =
      StreamController<bool>.broadcast();
  bool _lastKnownStatus = true;
  Timer? _pollingTimer;

  ConnectivityService({bool autoStartPolling = false, Duration? pollInterval}) {
    if (autoStartPolling) {
      _pollingTimer = Timer.periodic(
        pollInterval ?? const Duration(seconds: 30),
        (_) => checkConnectivity(),
      );
    }
  }

  @override
  bool get isOnline => _lastKnownStatus;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  /// Notifie manuellement d'un changement de statut réseau (utile pour tests et hooks OS).
  void setOnlineStatus(bool isOnline) {
    if (_lastKnownStatus != isOnline) {
      _lastKnownStatus = isOnline;
      if (!_controller.isClosed) {
        _controller.add(isOnline);
      }
      debugPrint(
        '[ConnectivityService] Connectivité réseau basculée : ${isOnline ? "EN LIGNE" : "HORS-LIGNE"}',
      );
    }
  }

  @override
  Future<bool> checkConnectivity() async {
    try {
      final client = SupabaseConfig.safeClient;
      if (client == null) {
        setOnlineStatus(false);
        return false;
      }

      // Test de joignabilité rapide avec timeout de 3 secondes
      // Utilise l'appel RPC de santé ou une requête légère avec limite
      final isReachable = await Future.any<bool>([
        client
            .from('farms')
            .select('id')
            .limit(1)
            .maybeSingle()
            .then((_) => true)
            .catchError((_) => false),
        Future.delayed(const Duration(seconds: 3), () => false),
      ]);

      setOnlineStatus(isReachable);
      return isReachable;
    } catch (_) {
      setOnlineStatus(false);
      return false;
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _controller.close();
  }
}

/// Fake injectable pour les tests unitaires et d'intégration.
class FakeConnectivityService implements IConnectivityService {
  final StreamController<bool> _controller =
      StreamController<bool>.broadcast();
  bool _isOnline;

  FakeConnectivityService({bool initialOnline = true})
      : _isOnline = initialOnline;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  @override
  bool get isOnline => _isOnline;

  void emit(bool online) {
    _isOnline = online;
    _controller.add(online);
  }

  @override
  Future<bool> checkConnectivity() async => _isOnline;

  @override
  void dispose() {
    _controller.close();
  }
}
