// lib/core/supabase_config.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuration centralisée et sécurisée pour le client Supabase d'AgriTrack.
///
/// Gère la résolution d'URL par plateforme (Web, Windows, Android, etc.),
/// l'injection de variables de compilation `--dart-define`, la protection
/// contre les fuites de clés privilégiées et la tolérance de panne en mode local.
class SupabaseConfig {
  SupabaseConfig._();

  // ─── Clés et URLs par défaut pour l'instance locale Supabase ──────────────
  static const String _defaultLocalHostUrl = 'http://127.0.0.1:54321';
  static const String _defaultAndroidEmulatorUrl = 'http://10.0.2.2:54321';

  /// URL officielle du projet Supabase Cloud AgriTrack de production
  static const String cloudProductionUrl =
      'https://uzquikczddvawxsjwwuk.supabase.co';

  /// Clé publique client publishable pour l'instance Supabase Cloud AgriTrack.
  /// Strictement publique, restreinte par RLS côté serveur (ne jamais injecter service_role).
  static const String _defaultCloudPublishableKey =
      'sb_publishable_7jSX8EVtdXzzd9PbCKCcow_LPLUzqTP';

  /// Clé publique anon par défaut générée pour l'instance locale de dev Supabase.
  /// Cette clé est strictement publique (publishable) et régie par les politiques RLS.
  /// IMPORTANT : Ne jamais injecter de clé `service_role` dans l'application.
  static const String _defaultLocalAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

  static bool _isInitialized = false;
  static String? _activeUrl;
  static String? _activeAnonKey;

  /// Indique si le client Supabase a été initialisé avec succès.
  static bool get isInitialized => _isInitialized;

  /// URL actuellement configurée ou résolue pour la plateforme active.
  static String get url => _activeUrl ?? resolveUrl();

  /// Clé anonyme publique actuellement configurée.
  static String get anonKey => _activeAnonKey ?? _resolveAnonKey();

  /// Accès sécurisé au client Supabase : retourne `null` si non initialisé
  /// au lieu de lever une exception non rattrapée.
  static SupabaseClient? get safeClient {
    if (!_isInitialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Accès direct au client Supabase (à utiliser lorsque `isInitialized == true`).
  static SupabaseClient get client {
    if (!_isInitialized) {
      throw StateError(
        'SupabaseConfig n\'est pas encore initialisé. Vérifiez `SupabaseConfig.isInitialized` ou utilisez `SupabaseConfig.safeClient`.',
      );
    }
    return Supabase.instance.client;
  }

  /// Détermine si l'environnement d'exécution Web est hébergé sur un domaine public/production.
  static bool isProductionWebHost([String? webHost]) {
    String currentHost = webHost ?? '';
    if (currentHost.isEmpty && kIsWeb) {
      try {
        currentHost = Uri.base.host;
      } catch (_) {}
    }
    return currentHost.isNotEmpty &&
        currentHost != 'localhost' &&
        currentHost != '127.0.0.1';
  }

  /// Résout l'URL Supabase appropriée selon la plateforme d'exécution
  /// et les variables `--dart-define`.
  static String resolveUrl({
    TargetPlatform? platform,
    bool? isWeb,
    String? webHost,
  }) {
    // 1. Priorité absolue : variable de compilation `--dart-define=SUPABASE_URL=...`
    const envUrl = String.fromEnvironment('SUPABASE_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }

    final runningOnWeb = isWeb ?? kIsWeb;
    if (runningOnWeb) {
      if (isProductionWebHost(webHost)) {
        // Version Web de production (ex: agritrack-olive.vercel.app) :
        // Empêche formellement une connexion silencieuse erronée à 127.0.0.1
        return cloudProductionUrl;
      }
      return _defaultLocalHostUrl;
    }

    final target = platform ?? defaultTargetPlatform;
    switch (target) {
      case TargetPlatform.android:
        // L'émulateur Android standard route vers l'hôte de dev via 10.0.2.2
        return _defaultAndroidEmulatorUrl;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return _defaultLocalHostUrl;
    }
  }

  /// Résout la clé publique anonyme selon les variables `--dart-define`.
  static String _resolveAnonKey({bool? isWeb, String? webHost}) {
    const envKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (envKey.isNotEmpty) {
      _assertNotServiceRoleKey(envKey);
      return envKey;
    }

    final runningOnWeb = isWeb ?? kIsWeb;
    if (runningOnWeb && isProductionWebHost(webHost)) {
      return _defaultCloudPublishableKey;
    }

    return _defaultLocalAnonKey;
  }

  /// Garde-fou de sécurité : empêche l'injection accidentelle d'une clé `service_role`.
  static void _assertNotServiceRoleKey(String key) {
    if (key.toLowerCase().contains('service_role') ||
        key.startsWith('sb_secret_')) {
      throw ArgumentError(
        'SÉCURITÉ VIOLÉE : Une clé secrète/service_role ne doit JAMAIS être incluse dans le client Flutter.',
      );
    }
  }

  /// Initialise le client Supabase de manière résiliente.
  ///
  /// Si Supabase n'est pas joignable ou si une erreur survient, l'exception est
  /// capturée pour que l'application puisse démarrer normalement en mode local (Sembast).
  static Future<bool> initialize({
    String? customUrl,
    String? customAnonKey,
    String? webHost,
  }) async {
    final targetUrl = customUrl ?? resolveUrl(webHost: webHost);
    final targetKey = customAnonKey ?? _resolveAnonKey(webHost: webHost);

    // Garde-fou strict de sécurité : lève immédiatement ArgumentError si une clé secrète est passée
    _assertNotServiceRoleKey(targetKey);

    try {
      await Supabase.initialize(
        url: targetUrl,
        publishableKey: targetKey,
        debug: kDebugMode,
      );

      _activeUrl = targetUrl;
      _activeAnonKey = targetKey;
      _isInitialized = true;

      debugPrint(
        '[SupabaseConfig] Initialisation réussie sur $targetUrl (mode cloud/auth prêt)',
      );
      return true;
    } catch (e, st) {
      _isInitialized = false;
      debugPrint(
        '[SupabaseConfig] Supabase indisponible ou non initialisé : $e. '
        'L\'application poursuit son démarrage en mode local (Sembast).',
      );
      if (kDebugMode) {
        debugPrint(st.toString());
      }
      return false;
    }
  }

  /// Réinitialise l'état pour les tests unitaires.
  @visibleForTesting
  static void resetForTesting() {
    _isInitialized = false;
    _activeUrl = null;
    _activeAnonKey = null;
  }

  /// Définit l'état d'initialisation pour les tests.
  @visibleForTesting
  static void setInitializedForTesting(bool value, {String? url, String? key}) {
    _isInitialized = value;
    _activeUrl = url;
    _activeAnonKey = key;
  }
}
