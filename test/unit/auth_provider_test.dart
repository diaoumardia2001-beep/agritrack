// test/unit/auth_provider_test.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:agritrack/models/user_profile.dart';
import 'package:agritrack/providers/auth_provider.dart';

/// Implémentation de test en mémoire (Fake) de IAuthService.
/// Ne déclenche AUCUN appel réseau.
class FakeAuthService implements IAuthService {
  final StreamController<AuthState> _authStreamController =
      StreamController<AuthState>.broadcast();

  bool simulateClientAvailable;
  User? mockUser;
  Session? mockSession;
  UserProfile? mockProfile;
  Exception? signInError;
  Exception? signUpError;
  bool signUpRequiresConfirmation;
  bool signOutCalled = false;
  Exception? resendError;
  int resendCallCount = 0;
  String? lastResentEmail;
  String? lastSignUpEmailRedirectTo;
  String? lastResendEmailRedirectTo;

  FakeAuthService({
    this.simulateClientAvailable = true,
    this.mockUser,
    this.mockSession,
    this.mockProfile,
    this.signInError,
    this.signUpError,
    this.signUpRequiresConfirmation = false,
    this.resendError,
  });

  @override
  bool get isAvailable => simulateClientAvailable;

  @override
  Stream<AuthState> get onAuthStateChange => _authStreamController.stream;

  @override
  Session? get currentSession => mockSession;

  @override
  User? get currentUser => mockUser;

  void emitAuthState(AuthChangeEvent event, Session? session) {
    _authStreamController.add(AuthState(event, session));
  }

  @override
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    if (!simulateClientAvailable) {
      throw const AuthException('Client non initialisé');
    }
    if (signInError != null) {
      throw signInError!;
    }
    final user = mockUser ??
        User(
          id: 'mock_uid_123',
          appMetadata: {},
          userMetadata: {'full_name': 'Moussa Diop'},
          aud: 'authenticated',
          createdAt: DateTime(2026, 1, 1).toIso8601String(),
          email: email,
        );
    final session = mockSession ??
        Session(
          accessToken: 'fake_jwt_token',
          tokenType: 'bearer',
          user: user,
        );
    mockUser = user;
    mockSession = session;
    emitAuthState(AuthChangeEvent.signedIn, session);
    return AuthResponse(session: session, user: user);
  }

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
    String? emailRedirectTo,
  }) async {
    lastSignUpEmailRedirectTo = emailRedirectTo;
    if (!simulateClientAvailable) {
      throw const AuthException('Client non initialisé');
    }
    if (signUpError != null) {
      throw signUpError!;
    }
    final user = User(
      id: 'mock_new_uid_456',
      appMetadata: {},
      userMetadata: {
        'full_name': fullName,
        if (phoneNumber != null) 'phone_number': phoneNumber,
      },
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: email,
    );
    if (signUpRequiresConfirmation) {
      return AuthResponse(session: null, user: user);
    }
    final session = Session(
      accessToken: 'fake_jwt_token_signup',
      tokenType: 'bearer',
      user: user,
    );
    mockUser = user;
    mockSession = session;
    emitAuthState(AuthChangeEvent.signedIn, session);
    return AuthResponse(session: session, user: user);
  }

  @override
  Future<void> resendEmailConfirmation({
    required String email,
    String? emailRedirectTo,
  }) async {
    lastResendEmailRedirectTo = emailRedirectTo;
    if (!simulateClientAvailable) {
      throw const AuthException('Client non initialisé');
    }
    if (resendError != null) {
      throw resendError!;
    }
    resendCallCount++;
    lastResentEmail = email;
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
    mockUser = null;
    mockSession = null;
    emitAuthState(AuthChangeEvent.signedOut, null);
  }

  @override
  Future<UserProfile?> fetchProfile(String userId) async {
    return mockProfile;
  }

  void dispose() {
    _authStreamController.close();
  }
}

void main() {
  group('AuthProvider Unit Tests', () {
    late FakeAuthService fakeAuth;
    late ProviderContainer container;

    setUp(() {
      fakeAuth = FakeAuthService();
      container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(fakeAuth),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      fakeAuth.dispose();
    });

    test('1. Initial state is unauthenticated when no session exists', () {
      final state = container.read(authProvider);

      expect(state.status, equals(AuthStatus.unauthenticated));
      expect(state.isAuthenticated, isFalse);
      expect(state.isUnauthenticated, isTrue);
      expect(state.user, isNull);
      expect(state.errorMessage, isNull);
    });

    test(
        '2. Handles absence of Supabase client gracefully (offline/local mode)',
        () {
      final offlineService = FakeAuthService(simulateClientAvailable: false);
      final offlineContainer = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(offlineService),
        ],
      );

      final state = offlineContainer.read(authProvider);
      expect(state.status, equals(AuthStatus.unauthenticated));
      expect(state.isClientAvailable, isFalse);

      offlineContainer.dispose();
      offlineService.dispose();
    });

    test('3. Restores existing active session on initialisation', () {
      final existingUser = User(
        id: 'restored_uid_999',
        appMetadata: {},
        userMetadata: {'full_name': 'Fatou Ndiaye'},
        aud: 'authenticated',
        createdAt: DateTime(2026, 1, 1).toIso8601String(),
        email: 'fatou@agritrack.sn',
      );
      final existingSession = Session(
        accessToken: 'valid_restored_token',
        tokenType: 'bearer',
        user: existingUser,
      );

      final restoredService = FakeAuthService(
        mockUser: existingUser,
        mockSession: existingSession,
        mockProfile: UserProfile(
          id: existingUser.id,
          email: existingUser.email!,
          fullName: 'Fatou Ndiaye',
          createdAt: DateTime(2026, 1, 1),
        ),
      );

      final restoredContainer = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(restoredService),
        ],
      );

      final state = restoredContainer.read(authProvider);
      expect(state.status, equals(AuthStatus.authenticated));
      expect(state.isAuthenticated, isTrue);
      expect(state.userId, equals('restored_uid_999'));
      expect(state.email, equals('fatou@agritrack.sn'));

      restoredContainer.dispose();
      restoredService.dispose();
    });

    test(
        '4. Successful signIn updates state to authenticated and loads profile',
        () async {
      fakeAuth.mockProfile = UserProfile(
        id: 'mock_uid_123',
        email: 'eleveur@agritrack.sn',
        fullName: 'Cheikh Sall',
        createdAt: DateTime(2026, 1, 1),
      );

      final notifier = container.read(authProvider.notifier);
      final success = await notifier.signIn(
        email: 'eleveur@agritrack.sn',
        password: 'Password123!',
      );

      expect(success, isTrue);
      final state = container.read(authProvider);
      expect(state.status, equals(AuthStatus.authenticated));
      expect(state.isAuthenticated, isTrue);
      expect(state.user?.email, equals('eleveur@agritrack.sn'));
      expect(state.profile?.fullName, equals('Cheikh Sall'));
      expect(state.displayName, equals('Cheikh Sall'));
    });

    test('5. Handles login error with friendly translated message', () async {
      fakeAuth.signInError = const AuthException('Invalid login credentials');

      final notifier = container.read(authProvider.notifier);
      final success = await notifier.signIn(
        email: 'wrong@agritrack.sn',
        password: 'BadPassword',
      );

      expect(success, isFalse);
      final state = container.read(authProvider);
      expect(state.status, equals(AuthStatus.error));
      expect(state.hasError, isTrue);
      expect(state.errorMessage,
          equals('Adresse email ou mot de passe incorrect.'));
    });

    test('6. Handles network failure on login without crashing', () async {
      fakeAuth.signInError =
          Exception('ClientException: SocketException: Failed host lookup');

      final notifier = container.read(authProvider.notifier);
      final success = await notifier.signIn(
        email: 'test@agritrack.sn',
        password: 'Password123!',
      );

      expect(success, isFalse);
      final state = container.read(authProvider);
      expect(state.status, equals(AuthStatus.error));
      expect(state.errorMessage,
          contains('Connexion impossible. Vérifiez votre réseau.'));
    });

    test('7. Successful signUp updates state to authenticated', () async {
      fakeAuth.mockProfile = UserProfile(
        id: 'mock_new_uid_456',
        email: 'nouveau@agritrack.sn',
        fullName: 'Awa Ba',
        createdAt: DateTime.now(),
      );

      final notifier = container.read(authProvider.notifier);
      final success = await notifier.signUp(
        email: 'nouveau@agritrack.sn',
        password: 'Password123!',
        fullName: 'Awa Ba',
        phoneNumber: '+221771234567',
      );

      expect(success, isTrue);
      final state = container.read(authProvider);
      expect(state.status, equals(AuthStatus.authenticated));
      expect(state.user?.email, equals('nouveau@agritrack.sn'));
    });

    test('8. Handles duplicate email error on signUp with friendly message',
        () async {
      fakeAuth.signUpError = const AuthException('User already registered');

      final notifier = container.read(authProvider.notifier);
      final success = await notifier.signUp(
        email: 'existant@agritrack.sn',
        password: 'Password123!',
        fullName: 'Doublon',
      );

      expect(success, isFalse);
      final state = container.read(authProvider);
      expect(state.status, equals(AuthStatus.error));
      expect(state.errorMessage,
          equals('Un compte existe déjà avec cette adresse email.'));
    });

    test('9. signOut resets state to unauthenticated cleanly', () async {
      // D'abord on connecte l'utilisateur
      final notifier = container.read(authProvider.notifier);
      await notifier.signIn(
        email: 'user@agritrack.sn',
        password: 'Password123!',
      );
      expect(container.read(authProvider).isAuthenticated, isTrue);

      // Puis on se déconnecte
      await notifier.signOut();

      expect(fakeAuth.signOutCalled, isTrue);
      final state = container.read(authProvider);
      expect(state.status, equals(AuthStatus.unauthenticated));
      expect(state.isAuthenticated, isFalse);
      expect(state.user, isNull);
    });

    test(
        '10. signUp requiring email confirmation sets needsEmailConfirmation to true and stays unauthenticated',
        () async {
      fakeAuth.signUpRequiresConfirmation = true;

      final notifier = container.read(authProvider.notifier);
      final success = await notifier.signUp(
        email: 'confirmation@agritrack.sn',
        password: 'Password123!',
        fullName: 'Ibrahima Fall',
      );

      expect(success, isTrue);
      final state = container.read(authProvider);
      expect(state.status, equals(AuthStatus.unauthenticated));
      expect(state.isAuthenticated, isFalse);
      expect(state.needsEmailConfirmation, isTrue);
      expect(state.user, isNull);
    });

    test('11. clearError resets error state and email confirmation cleanly',
        () async {
      fakeAuth.signInError = const AuthException('Invalid login credentials');

      final notifier = container.read(authProvider.notifier);
      await notifier.signIn(
        email: 'wrong@agritrack.sn',
        password: 'BadPassword',
      );
      expect(container.read(authProvider).hasError, isTrue);

      notifier.clearError();
      final clearedState = container.read(authProvider);
      expect(clearedState.hasError, isFalse);
      expect(clearedState.errorMessage, isNull);
      expect(clearedState.needsEmailConfirmation, isFalse);
    });

    test('12. resendConfirmationEmail succeeds and tracks call', () async {
      final notifier = container.read(authProvider.notifier);
      final success =
          await notifier.resendConfirmationEmail('confirmation@agritrack.sn');

      expect(success, isTrue);
      expect(fakeAuth.resendCallCount, equals(1));
      expect(fakeAuth.lastResentEmail, equals('confirmation@agritrack.sn'));
      expect(container.read(authProvider).hasError, isFalse);
    });

    test(
        '13. resendConfirmationEmail handles rate limiting and error humanization',
        () async {
      fakeAuth.resendError = const AuthException(
          'For security purposes, you can only request this once every 60 seconds');

      final notifier = container.read(authProvider.notifier);
      final success =
          await notifier.resendConfirmationEmail('rate@agritrack.sn');

      expect(success, isFalse);
      final state = container.read(authProvider);
      expect(state.hasError, isTrue);
      expect(
        state.errorMessage,
        equals(
            'Trop de tentatives. Veuillez patienter un instant avant de renvoyer un e-mail.'),
      );
    });

    test('14. resendConfirmationEmail fails safely when client unavailable',
        () async {
      fakeAuth.simulateClientAvailable = false;

      final notifier = container.read(authProvider.notifier);
      final success =
          await notifier.resendConfirmationEmail('offline@agritrack.sn');

      expect(success, isFalse);
      final state = container.read(authProvider);
      expect(state.hasError, isTrue);
      expect(state.isClientAvailable, isFalse);
    });

    test('15. signUp passes emailRedirectTo down to auth service', () async {
      final notifier = container.read(authProvider.notifier);
      final success = await notifier.signUp(
        email: 'redirect_test@agritrack.sn',
        password: 'Password123!',
        fullName: 'Redirect Tester',
        emailRedirectTo: 'https://agritrack-olive.vercel.app',
      );

      expect(success, isTrue);
      expect(fakeAuth.lastSignUpEmailRedirectTo,
          equals('https://agritrack-olive.vercel.app'));
    });

    test('16. resendConfirmationEmail passes emailRedirectTo to auth service',
        () async {
      final notifier = container.read(authProvider.notifier);
      final success = await notifier.resendConfirmationEmail(
        'redirect_resend@agritrack.sn',
        emailRedirectTo: 'https://agritrack-olive.vercel.app',
      );

      expect(success, isTrue);
      expect(fakeAuth.lastResendEmailRedirectTo,
          equals('https://agritrack-olive.vercel.app'));
    });

    test(
        '17. SupabaseAuthService.resolveEmailRedirectTo prioritizes custom URL',
        () {
      final resolved = SupabaseAuthService.resolveEmailRedirectTo(
          'https://custom.agritrack.sn');
      expect(resolved, equals('https://custom.agritrack.sn'));
    });
  });
}
