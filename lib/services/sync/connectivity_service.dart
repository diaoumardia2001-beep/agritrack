// lib/services/sync/connectivity_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

      // Sonde la joignabilité de l'infrastructure Supabase.
      // IMPORTANT SÉCURITÉ : La table 'farms' est protégée par RLS et restreinte pour 'anon'.
      // Une réponse d'erreur PostgREST (ex: code 42501 "permission denied", code 401 ou 403)
      // prouve que le serveur Supabase est en ligne et a répondu, et ne doit
      // PAS être interprétée comme une absence de réseau.
      try {
        await client
            .from('farms')
            .select('id')
            .limit(1)
            .maybeSingle()
            .timeout(const Duration(seconds: 3));
        setOnlineStatus(true);
        return true;
      } on PostgrestException catch (_) {
        // Le serveur Supabase a répondu (refus d'accès RLS ou absence de session valide).
        // L'infrastructure réseau et serveur est parfaitement en ligne.
        setOnlineStatus(true);
        return true;
      } on TimeoutException {
        // Le serveur n'a pas répondu dans le délai imparti
        setOnlineStatus(false);
        return false;
      } catch (e) {
        if (isNetworkFailure(e)) {
          setOnlineStatus(false);
          return false;
        }
        // Toute autre erreur non liée à une coupure socket/réseau
        setOnlineStatus(true);
        return true;
      }
    } catch (_) {
      setOnlineStatus(false);
      return false;
    }
  }

  /// Détermine si une exception correspond à une indisponibilité réseau ou socket.
  static bool isNetworkFailure(Object error) {
    final errStr = error.toString().toLowerCase();
    return errStr.contains('socketexception') ||
        errStr.contains('failed to fetch') ||
        errStr.contains('network is unreachable') ||
        errStr.contains('connection refused') ||
        errStr.contains('connection timed out') ||
        errStr.contains('connection reset') ||
        errStr.contains('clientexception') ||
        errStr.contains('xmlhttprequest') ||
        errStr.contains('handshakeexception');
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
