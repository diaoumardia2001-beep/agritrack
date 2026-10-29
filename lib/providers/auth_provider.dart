// lib/providers/auth_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../models/user_profile.dart';

// ─── Statut d'authentification ───────────────────────────────────────────────
enum AuthStatus {
  unauthenticated, // Mode local / visiteur (aucun compte distant actif)
  authenticated, // Utilisateur connecté avec session active
  loading, // Opération en cours (connexion, inscription, etc.)
  error, // Erreur lors d'une tentative d'authentification
}

// ─── État d'authentification de l'application ───────────────────────────────
class AppAuthState {
  final AuthStatus status;
  final User? user;
  final UserProfile? profile;
  final String? errorMessage;
  final bool isClientAvailable;
  final bool needsEmailConfirmation;

  const AppAuthState({
    required this.status,
    this.user,
    this.profile,
    this.errorMessage,
    this.isClientAvailable = true,
    this.needsEmailConfirmation = false,
  });

  const AppAuthState.unauthenticated({
    bool isClientAvailable = true,
    String? errorMessage,
    bool needsEmailConfirmation = false,
  }) : this(
          status: AuthStatus.unauthenticated,
          isClientAvailable: isClientAvailable,
          errorMessage: errorMessage,
          needsEmailConfirmation: needsEmailConfirmation,
        );

  const AppAuthState.loading({
    User? currentUser,
    UserProfile? currentProfile,
    bool isClientAvailable = true,
  }) : this(
          status: AuthStatus.loading,
          user: currentUser,
          profile: currentProfile,
          isClientAvailable: isClientAvailable,
        );

  const AppAuthState.authenticated({
    required User user,
    UserProfile? profile,
    bool isClientAvailable = true,
  }) : this(
          status: AuthStatus.authenticated,
          user: user,
          profile: profile,
          isClientAvailable: isClientAvailable,
        );

  const AppAuthState.error(
    String message, {
    User? user,
    UserProfile? profile,
    bool isClientAvailable = true,
  }) : this(
          status: AuthStatus.error,
          user: user,
          profile: profile,
          errorMessage: message,
          isClientAvailable: isClientAvailable,
        );

  AppAuthState copyWith({
    AuthStatus? status,
    User? user,
    UserProfile? profile,
    String? errorMessage,
    bool? isClientAvailable,
    bool? needsEmailConfirmation,
    bool clearError = false,
  }) {
    return AppAuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      profile: profile ?? this.profile,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isClientAvailable: isClientAvailable ?? this.isClientAvailable,
      needsEmailConfirmation:
          needsEmailConfirmation ?? this.needsEmailConfirmation,
    );
  }

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;
  bool get isLoading => status == AuthStatus.loading;
  bool get isUnauthenticated => status == AuthStatus.unauthenticated;
  bool get hasError => status == AuthStatus.error && errorMessage != null;

  String? get userId => user?.id;
  String? get email => user?.email ?? profile?.email;
  String get displayName => profile?.fullName ?? email ?? 'Éleveur';
}

// ─── Abstraction du service d'authentification pour les tests ────────────────
abstract class IAuthService {
  Stream<AuthState> get onAuthStateChange;
  Session? get currentSession;
  User? get currentUser;
  bool get isAvailable;

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  });

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
    String? emailRedirectTo,
  });

  Future<void> resendEmailConfirmation({
    required String email,
    String? emailRedirectTo,
  });

  Future<void> signOut();

  Future<UserProfile?> fetchProfile(String userId);
}

// ─── Implémentation réelle avec Supabase ─────────────────────────────────────
class SupabaseAuthService implements IAuthService {
  final SupabaseClient? _client;

  SupabaseAuthService({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.safeClient;

  @override
  bool get isAvailable => _client != null;

  @override
  Stream<AuthState> get onAuthStateChange =>
      _client?.auth.onAuthStateChange ?? const Stream.empty();

  @override
  Session? get currentSession => _client?.auth.currentSession;

  @override
  User? get currentUser => _client?.auth.currentUser;

  @override
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      throw const AuthException(
        'Service d\'authentification indisponible (client Supabase non initialisé).',
      );
    }
    return await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Résout l'URL de redirection pour la confirmation d'e-mail (Web origin par défaut).
  static String? resolveEmailRedirectTo([String? customRedirectTo]) {
    if (customRedirectTo != null && customRedirectTo.trim().isNotEmpty) {
      return customRedirectTo.trim();
    }
    if (kIsWeb) {
      try {
        final origin = Uri.base.origin;
        if (origin.isNotEmpty && origin != 'null') {
          return origin;
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
    String? emailRedirectTo,
  }) async {
    final client = _client;
    if (client == null) {
      throw const AuthException(
        'Service d\'authentification indisponible (client Supabase non initialisé).',
      );
    }
    final redirect = resolveEmailRedirectTo(emailRedirectTo);
    return await client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: redirect,
      data: {
        'full_name': fullName.trim(),
        if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
          'phone_number': phoneNumber.trim(),
      },
    );
  }

  @override
  Future<void> resendEmailConfirmation({
    required String email,
    String? emailRedirectTo,
  }) async {
    final client = _client;
    if (client == null) {
      throw const AuthException(
        'Service d\'authentification indisponible (client Supabase non initialisé).',
      );
    }
    final redirect = resolveEmailRedirectTo(emailRedirectTo);
    await client.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      emailRedirectTo: redirect,
    );
  }

  @override
  Future<void> signOut() async {
    final client = _client;
    if (client != null) {
      await client.auth.signOut();
    }
  }

  @override
  Future<UserProfile?> fetchProfile(String userId) async {
    final client = _client;
    if (client == null) return null;
    try {
      final response =
          await client.from('profiles').select().eq('id', userId).maybeSingle();

      if (response == null) return null;
      return UserProfile.fromMap(response);
    } catch (e) {
      debugPrint('[AuthService] Impossible de récupérer le profil : $e');
      return null;
    }
  }
}

// ─── Providers Riverpod ──────────────────────────────────────────────────────
final authServiceProvider = Provider<IAuthService>((ref) {
  return SupabaseAuthService();
});

class AuthNotifier extends StateNotifier<AppAuthState> {
  final IAuthService _authService;
  StreamSubscription<AuthState>? _authSubscription;

  AuthNotifier(this._authService)
      : super(AppAuthState.unauthenticated(
          isClientAvailable: _authService.isAvailable,
        )) {
    _init();
  }

  void _init() {
    if (!_authService.isAvailable) {
      state = const AppAuthState.unauthenticated(isClientAvailable: false);
      return;
    }

    // 1. Restauration synchrone de session si déjà présente dans le stockage local
    final currentSession = _authService.currentSession;
    final currentUser = _authService.currentUser;

    if (currentSession != null && currentUser != null) {
      state = AppAuthState.authenticated(user: currentUser);
      // Préchauffage asynchrone du profil sans bloquer l'état initial
      _loadProfile(currentUser.id);
    } else {
      state = const AppAuthState.unauthenticated(isClientAvailable: true);
    }

    // 2. Écoute des événements de session Supabase (connexion, déconnexion, rafraîchissement)
    _authSubscription = _authService.onAuthStateChange.listen((data) {
      final session = data.session;
      final user = session?.user;

      if (session != null && user != null) {
        state = AppAuthState.authenticated(
          user: user,
          profile: state.profile,
          isClientAvailable: true,
        );
        _loadProfile(user.id);
      } else {
        state = const AppAuthState.unauthenticated(isClientAvailable: true);
      }
    }, onError: (e) {
      debugPrint('[AuthNotifier] Erreur flux d\'authentification : $e');
    });
  }

  Future<void> _loadProfile(String userId) async {
    try {
      final profile = await _authService.fetchProfile(userId);
      if (profile != null && mounted && state.isAuthenticated) {
        state = AppAuthState.authenticated(
          user: state.user!,
          profile: profile,
          isClientAvailable: true,
        );
      }
    } catch (e) {
      debugPrint('[AuthNotifier] Erreur chargement profil : $e');
    }
  }

  /// Connexion explicite par email et mot de passe
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    if (!_authService.isAvailable) {
      state = const AppAuthState.error(
        'Service d\'authentification indisponible (mode local actif).',
        isClientAvailable: false,
      );
      return false;
    }

    state = const AppAuthState.loading();
    try {
      final response = await _authService.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user != null) {
        state = AppAuthState.authenticated(user: user);
        await _loadProfile(user.id);
        return true;
      } else {
        state = const AppAuthState.error(
            'Aucune session retournée après connexion.');
        return false;
      }
    } on AuthException catch (e) {
      final friendly = _humanizeAuthError(e.message);
      state = AppAuthState.error(friendly);
      return false;
    } catch (e) {
      state = const AppAuthState.error(
          'Connexion impossible. Vérifiez votre réseau.');
      return false;
    }
  }

  /// Inscription explicite d'un éleveur
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
    String? emailRedirectTo,
  }) async {
    if (!_authService.isAvailable) {
      state = const AppAuthState.error(
        'Service d\'authentification indisponible (mode local actif).',
        isClientAvailable: false,
      );
      return false;
    }

    state = const AppAuthState.loading();
    try {
      final response = await _authService.signUp(
        email: email,
        password: password,
        fullName: fullName,
        phoneNumber: phoneNumber,
        emailRedirectTo: emailRedirectTo,
      );

      final user = response.user;
      final session = response.session;
      if (user != null) {
        if (session == null) {
          state = AppAuthState.unauthenticated(
            isClientAvailable: _authService.isAvailable,
            needsEmailConfirmation: true,
          );
          return true;
        } else {
          state = AppAuthState.authenticated(user: user);
          await _loadProfile(user.id);
          return true;
        }
      } else {
        state = const AppAuthState.error('Échec de la création de compte.');
        return false;
      }
    } on AuthException catch (e) {
      final friendly = _humanizeAuthError(e.message);
      state = AppAuthState.error(friendly);
      return false;
    } catch (e) {
      state = const AppAuthState.error(
          'Inscription impossible. Vérifiez votre réseau.');
      return false;
    }
  }

  /// Renvoi de l'e-mail de confirmation après inscription
  Future<bool> resendConfirmationEmail(
    String email, {
    String? emailRedirectTo,
  }) async {
    if (!_authService.isAvailable) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage:
            'Service d\'authentification indisponible (mode local actif).',
        isClientAvailable: false,
      );
      return false;
    }

    try {
      await _authService.resendEmailConfirmation(
        email: email.trim(),
        emailRedirectTo: emailRedirectTo,
      );
      return true;
    } on AuthException catch (e) {
      final friendly = _humanizeAuthError(e.message);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: friendly,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage:
            'Impossible de renvoyer l\'e-mail. Vérifiez votre connexion Internet.',
      );
      return false;
    }
  }

  /// Réinitialise les erreurs et les indicateurs temporaires
  void clearError() {
    state = state.copyWith(
      clearError: true,
      needsEmailConfirmation: false,
      status: state.isAuthenticated
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
    );
  }

  /// Déconnexion explicite
  /// GARANTIE : Ne supprime aucune donnée locale Sembast !
  Future<void> signOut() async {
    state = const AppAuthState.loading();
    try {
      await _authService.signOut();
    } catch (e) {
      debugPrint('[AuthNotifier] Erreur lors du signOut : $e');
    } finally {
      state = AppAuthState.unauthenticated(
        isClientAvailable: _authService.isAvailable,
      );
    }
  }

  /// Traduction des messages d'erreur d'authentification pour l'utilisateur
  static String _humanizeAuthError(String rawMessage) {
    final lower = rawMessage.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid credentials')) {
      return 'Adresse email ou mot de passe incorrect.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Veuillez confirmer votre adresse email pour vous connecter.';
    }
    if (lower.contains('user already registered') ||
        lower.contains('already exists')) {
      return 'Un compte existe déjà avec cette adresse email.';
    }
    if (lower.contains('password should be at least') ||
        lower.contains('weak password') ||
        lower.contains('password is too weak')) {
      return 'Le mot de passe doit comporter au moins 6 caractères.';
    }
    if (lower.contains('invalid email') || lower.contains('valid email')) {
      return 'Format d\'adresse email invalide.';
    }
    if (lower.contains('rate limit') ||
        lower.contains('over_email_send_rate_limit') ||
        lower.contains('security purposes') ||
        lower.contains('too many requests')) {
      return 'Trop de tentatives. Veuillez patienter un instant avant de renvoyer un e-mail.';
    }
    if (lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('timeout')) {
      return 'Impossible de joindre le serveur. Vérifiez votre connexion Internet.';
    }
    return rawMessage;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AppAuthState>((ref) {
  final service = ref.watch(authServiceProvider);
  return AuthNotifier(service);
});

final currentUserProfileProvider = Provider<UserProfile?>((ref) {
  return ref.watch(authProvider).profile;
});
