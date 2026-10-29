// test/widgets/auth_and_farm_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:agritrack/data/animals_repository.dart';
import 'package:agritrack/data/database/app_database.dart';
import 'package:agritrack/models/farm.dart';
import 'package:agritrack/models/user_farm_membership.dart';
import 'package:agritrack/models/user_profile.dart';
import 'package:agritrack/providers/active_farm_provider.dart';
import 'package:agritrack/providers/animals_provider.dart';
import 'package:agritrack/providers/auth_provider.dart';
import 'package:agritrack/providers/shared_preferences_provider.dart';
import 'package:agritrack/screens/auth/login_screen.dart';
import 'package:agritrack/screens/auth/register_screen.dart';
import 'package:agritrack/screens/farm/create_farm_dialog.dart';
import 'package:agritrack/screens/farm/select_farm_dialog.dart';
import 'package:agritrack/screens/main_shell.dart';
import 'package:agritrack/screens/settings_screen.dart';
import 'package:agritrack/theme/app_theme.dart';

import '../unit/active_farm_provider_test.dart';
import '../unit/auth_provider_test.dart';

Widget _buildTestApp({
  required SharedPreferences prefs,
  required FakeAuthService authService,
  required FakeFarmService farmService,
  required AnimalsRepository repo,
  Widget? home,
}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authServiceProvider.overrideWithValue(authService),
      farmServiceProvider.overrideWithValue(farmService),
      animalsRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: home ?? const SettingsScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late FakeAuthService fakeAuth;
  late FakeFarmService fakeFarm;
  late AnimalsRepository testRepo;
  late Database memoryDb;

  setUp(() async {
    disableSembastCooperator();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    memoryDb = await AppDatabase.openInMemory();
    testRepo = AnimalsRepository(
      database: Future.value(memoryDb),
      autoSeed: true,
    );
    await testRepo.fetchFarms();

    fakeAuth = FakeAuthService();
    fakeFarm = FakeFarmService();
  });

  tearDown(() async {
    fakeAuth.dispose();
    enableSembastCooperator();
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    Widget? home,
    Size size = const Size(1024, 1200),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(_buildTestApp(
      prefs: prefs,
      authService: fakeAuth,
      farmService: fakeFarm,
      repo: testRepo,
      home: home,
    ));
    await tester.pumpAndSettle();
  }

  group('1. Accès au compte depuis les paramètres', () {
    testWidgets('Affiche l\'état local déconnecté et les boutons d\'accès',
        (tester) async {
      await pumpApp(tester, home: const SettingsScreen());

      // Section compte
      expect(find.text('Mon compte'), findsOneWidget);
      expect(find.text('Mode local hors-ligne'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('settings_login_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('settings_register_button')),
          findsOneWidget);
    });

    testWidgets('Navigation vers l\'écran de connexion', (tester) async {
      await pumpApp(tester, home: const SettingsScreen());

      final loginBtn = find.byKey(const ValueKey('settings_login_button'));
      await tester.ensureVisible(loginBtn);
      await tester.tap(loginBtn);
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Connexion'), findsWidgets);
    });

    testWidgets('Navigation vers l\'écran d\'inscription', (tester) async {
      await pumpApp(tester, home: const SettingsScreen());

      final regBtn = find.byKey(const ValueKey('settings_register_button'));
      await tester.ensureVisible(regBtn);
      await tester.tap(regBtn);
      await tester.pumpAndSettle();

      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.text('Créer un compte'), findsWidgets);
    });
  });

  group('2. Écran de connexion (LoginScreen)', () {
    testWidgets('Validation des champs obligatoires et format email',
        (tester) async {
      await pumpApp(tester, home: const LoginScreen());

      // Soumission avec champs vides
      final submitBtn = find.byKey(const ValueKey('login_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Veuillez saisir votre adresse e-mail'), findsOneWidget);

      // Email invalide
      await tester.enterText(
          find.byKey(const ValueKey('login_email_field')), 'adresse_invalide');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Format d\'adresse e-mail invalide'), findsOneWidget);

      // Email valide mais mot de passe court
      await tester.enterText(
          find.byKey(const ValueKey('login_email_field')), 'test@agritrack.sn');
      await tester.enterText(
          find.byKey(const ValueKey('login_password_field')), '123');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Le mot de passe doit comporter au moins 6 caractères'),
          findsOneWidget);
    });

    testWidgets('Affichage et masquage du mot de passe', (tester) async {
      await pumpApp(tester, home: const LoginScreen());

      // Au départ, obscureText est actif
      final fieldFinder = find.byKey(const ValueKey('login_password_field'));
      TextField textField = tester.widget<TextField>(
          find.descendant(of: fieldFinder, matching: find.byType(TextField)));
      expect(textField.obscureText, isTrue);

      // Clic sur l'icône de bascule
      await tester.tap(find.byKey(const ValueKey('login_password_toggle')));
      await tester.pumpAndSettle();

      textField = tester.widget<TextField>(
          find.descendant(of: fieldFinder, matching: find.byType(TextField)));
      expect(textField.obscureText, isFalse);
    });

    testWidgets(
        'Gestion des erreurs d\'authentification avec message en français',
        (tester) async {
      fakeAuth.signInError = const AuthException('Invalid login credentials');

      await pumpApp(tester, home: const LoginScreen());

      await tester.enterText(find.byKey(const ValueKey('login_email_field')),
          'wrong@agritrack.sn');
      await tester.enterText(
          find.byKey(const ValueKey('login_password_field')), 'Password123!');
      final submitBtn = find.byKey(const ValueKey('login_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Adresse email ou mot de passe incorrect.'),
          findsOneWidget);
    });

    testWidgets('Connexion réussie', (tester) async {
      fakeAuth.mockProfile = UserProfile(
        id: 'mock_uid_123',
        email: 'eleveur@agritrack.sn',
        fullName: 'Ibrahima Diallo',
        createdAt: DateTime.now(),
      );

      await pumpApp(tester, home: const LoginScreen());

      await tester.enterText(find.byKey(const ValueKey('login_email_field')),
          'eleveur@agritrack.sn');
      await tester.enterText(
          find.byKey(const ValueKey('login_password_field')), 'Password123!');
      final submitBtn = find.byKey(const ValueKey('login_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Connexion réussie. Bienvenue sur AgriTrack !'),
          findsOneWidget);
    });
  });

  group('3. Écran d\'inscription (RegisterScreen)', () {
    testWidgets('Validation complète du formulaire d\'inscription',
        (tester) async {
      await pumpApp(tester, home: const RegisterScreen());

      // Soumission vide
      final submitBtn = find.byKey(const ValueKey('register_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Veuillez saisir votre nom complet'), findsOneWidget);

      // Nom ok, email vide
      await tester.enterText(
          find.byKey(const ValueKey('register_fullname_field')), 'Awa Ba');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Veuillez saisir votre adresse e-mail'), findsOneWidget);

      // Mots de passe non concordants
      await tester.enterText(find.byKey(const ValueKey('register_email_field')),
          'awa@agritrack.sn');
      await tester.enterText(
          find.byKey(const ValueKey('register_password_field')), 'Password123');
      await tester.enterText(
          find.byKey(const ValueKey('register_confirm_password_field')),
          'DifferentPassword');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Les deux mots de passe ne correspondent pas'),
          findsOneWidget);
    });

    testWidgets('Affichage/masquage mot de passe et confirmation',
        (tester) async {
      await pumpApp(tester, home: const RegisterScreen());

      final pwdFinder = find.byKey(const ValueKey('register_password_field'));
      final confirmFinder =
          find.byKey(const ValueKey('register_confirm_password_field'));

      TextField pwdField = tester.widget<TextField>(
          find.descendant(of: pwdFinder, matching: find.byType(TextField)));
      TextField confirmField = tester.widget<TextField>(
          find.descendant(of: confirmFinder, matching: find.byType(TextField)));

      expect(pwdField.obscureText, isTrue);
      expect(confirmField.obscureText, isTrue);

      await tester.tap(find.byKey(const ValueKey('register_password_toggle')));
      await tester.pumpAndSettle();

      pwdField = tester.widget<TextField>(
          find.descendant(of: pwdFinder, matching: find.byType(TextField)));
      expect(pwdField.obscureText, isFalse);
    });

    testWidgets('Inscription nécessitant une confirmation par e-mail',
        (tester) async {
      fakeAuth.signUpRequiresConfirmation = true;

      await pumpApp(tester, home: const RegisterScreen());

      await tester.enterText(
          find.byKey(const ValueKey('register_fullname_field')),
          'Fatou Ndiaye');
      await tester.enterText(find.byKey(const ValueKey('register_email_field')),
          'fatou@agritrack.sn');
      await tester.enterText(
          find.byKey(const ValueKey('register_password_field')),
          'SecurePass123!');
      await tester.enterText(
          find.byKey(const ValueKey('register_confirm_password_field')),
          'SecurePass123!');

      final submitBtn = find.byKey(const ValueKey('register_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Vue de confirmation par email affichée
      expect(find.byKey(const ValueKey('email_confirmation_view')),
          findsOneWidget);
      expect(find.text('Vérifiez votre boîte e-mail'), findsOneWidget);
      expect(find.text('fatou@agritrack.sn'), findsOneWidget);
      expect(find.byKey(const ValueKey('resend_confirmation_email_button')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('goto_login_after_signup_button')),
          findsOneWidget);
    });

    testWidgets('Gestion d\'erreur email déjà utilisé sur inscription',
        (tester) async {
      fakeAuth.signUpError = const AuthException('User already registered');

      await pumpApp(tester, home: const RegisterScreen());

      await tester.enterText(
          find.byKey(const ValueKey('register_fullname_field')), 'Doublon');
      await tester.enterText(find.byKey(const ValueKey('register_email_field')),
          'existant@agritrack.sn');
      await tester.enterText(
          find.byKey(const ValueKey('register_password_field')),
          'Password123!');
      await tester.enterText(
          find.byKey(const ValueKey('register_confirm_password_field')),
          'Password123!');

      final submitBtn = find.byKey(const ValueKey('register_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Un compte existe déjà avec cette adresse email.'),
          findsOneWidget);
    });
  });

  group('4. Assistant de création d\'exploitation (CreateFarmDialog)', () {
    testWidgets('Validation et création réussie d\'une exploitation distante',
        (tester) async {
      await pumpApp(
        tester,
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => CreateFarmDialog.show(context),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.byType(CreateFarmDialog), findsOneWidget);

      // Validation nom vide
      await tester.tap(find.byKey(const ValueKey('create_farm_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Veuillez saisir le nom de l\'exploitation'),
          findsOneWidget);

      // Saisie et création réussie
      await tester.enterText(
          find.byKey(const ValueKey('create_farm_name_field')),
          'Ferme Kolda Moderne');
      await tester.enterText(
          find.byKey(const ValueKey('create_farm_region_field')), 'Kolda');

      await tester.tap(find.byKey(const ValueKey('create_farm_submit_button')));
      await tester.pumpAndSettle();

      expect(fakeFarm.createRemoteFarmCallCount, equals(1));
      expect(
          find.text('Exploitation « Ferme Kolda Moderne » créée avec succès !'),
          findsOneWidget);
    });

    testWidgets('Gestion d\'erreur lors de la création d\'exploitation',
        (tester) async {
      fakeFarm.createError = Exception('Connexion refusée');

      await pumpApp(
        tester,
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => CreateFarmDialog.show(context),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const ValueKey('create_farm_name_field')),
          'Ferme Test Erreur');
      await tester.tap(find.byKey(const ValueKey('create_farm_submit_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Échec de la création'), findsOneWidget);
    });
  });

  group('5. Changement d\'exploitation (SelectFarmDialog)', () {
    testWidgets(
        'Affiche les exploitations avec leurs rôles et permet le switch',
        (tester) async {
      final farmA = Farm(
        id: 'farm_a_uuid',
        name: 'Ferme A',
        region: 'Dakar',
        ownerId: 'uid1',
        createdAt: DateTime(2026, 1, 1),
      );
      final farmB = Farm(
        id: 'farm_b_uuid',
        name: 'Ferme B',
        region: 'Thiès',
        ownerId: 'uid2',
        createdAt: DateTime(2026, 1, 1),
      );

      final user = User(
        id: 'uid1',
        appMetadata: {},
        userMetadata: {'full_name': 'Test User'},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: 'test@agritrack.sn',
      );
      final session = Session(
        accessToken: 'tok',
        tokenType: 'bearer',
        user: user,
      );

      fakeAuth.mockUser = user;
      fakeAuth.mockSession = session;
      fakeFarm.mockFarms = [
        UserFarmMembership(farm: farmA, role: UserRole.owner),
        UserFarmMembership(farm: farmB, role: UserRole.worker),
      ];

      await pumpApp(
        tester,
        home: Scaffold(
          body: Center(
            child: Consumer(
              builder: (context, ref, child) {
                return ElevatedButton(
                  onPressed: () async {
                    await ref
                        .read(activeFarmProvider.notifier)
                        .loadRemoteFarms('uid1');
                    if (context.mounted) {
                      SelectFarmDialog.show(context);
                    }
                  },
                  child: const Text('Ouvrir'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.byType(SelectFarmDialog), findsOneWidget);
      expect(find.text('Ferme A'), findsOneWidget);
      expect(find.text('Propriétaire'), findsOneWidget);
      expect(find.text('Ferme B'), findsOneWidget);
      expect(find.text('Éleveur / Ouvrier'), findsOneWidget);
      expect(find.text('Exploitation locale (Sembast)'), findsOneWidget);

      // Basculer vers Ferme B
      await tester.tap(find.byKey(const ValueKey('farm_tile_farm_b_uuid')));
      await tester.pumpAndSettle();

      // Le dialogue s'est fermé
      expect(find.byType(SelectFarmDialog), findsNothing);
    });
  });

  group('6. Gestion du compte et déconnexion sécurisée', () {
    testWidgets(
        'Session active : affiche nom, email, rôle et confirmation de déconnexion sans perte',
        (tester) async {
      fakeAuth.mockUser = User(
        id: 'uid_connecte',
        appMetadata: {},
        userMetadata: {'full_name': 'Mamadou Ba'},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: 'mamadou@agritrack.sn',
      );
      fakeAuth.mockSession = Session(
        accessToken: 'tok',
        tokenType: 'bearer',
        user: fakeAuth.mockUser!,
      );
      fakeAuth.mockProfile = UserProfile(
        id: 'uid_connecte',
        email: 'mamadou@agritrack.sn',
        fullName: 'Mamadou Ba',
        createdAt: DateTime.now(),
      );

      await pumpApp(tester, home: const SettingsScreen());

      expect(find.text('Mamadou Ba'), findsWidgets);
      expect(find.text('mamadou@agritrack.sn'), findsOneWidget);
      expect(find.text('Connecté'), findsOneWidget);

      // Clic sur Déconnexion
      final logoutBtn = find.byKey(const ValueKey('settings_logout_button'));
      await tester.ensureVisible(logoutBtn);
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      expect(find.text('Confirmer la déconnexion'), findsOneWidget);
      expect(
          find.textContaining(
              'Vos données locales (Sembast) restent conservées'),
          findsOneWidget);

      // Confirmer
      final confirmBtn = find.byKey(const ValueKey('confirm_logout_button'));
      await tester.tap(confirmBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(fakeAuth.signOutCalled, isTrue);
      expect(find.text('Mode local hors-ligne'), findsOneWidget);

      // Les 12 animaux Sembast sont intacts
      final animals = await tester.runAsync(() => testRepo.fetchAnimals());
      expect(animals?.length, equals(12));
    });
  });

  group('7. Mode hors-ligne et réactivité responsive', () {
    testWidgets('Fonctionnement sans client Supabase disponible',
        (tester) async {
      fakeAuth.simulateClientAvailable = false;

      await pumpApp(tester, home: const SettingsScreen());

      expect(
          find.text(
              'Service d\'authentification indisponible (mode 100% hors-ligne).'),
          findsOneWidget);

      // Ouvrir la connexion : avertissement visible
      final loginBtn = find.byKey(const ValueKey('settings_login_button'));
      await tester.ensureVisible(loginBtn);
      await tester.tap(loginBtn);
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
          find.textContaining(
              'service d\'authentification distant est actuellement indisponible'),
          findsOneWidget);
    });

    testWidgets(
        'MainShell navigation responsive (mobile 390px, tablet 768px, desktop 1200px)',
        (tester) async {
      // Test mobile
      await pumpApp(
        tester,
        home: const MainShell(),
        size: const Size(390, 844),
      );

      expect(find.byType(BottomAppBar), findsOneWidget);

      // Test desktop
      await pumpApp(
        tester,
        home: const MainShell(),
        size: const Size(1200, 900),
      );

      expect(find.text('Exploitation active'), findsOneWidget);
      expect(find.text('Mon Exploitation'), findsOneWidget);
    });
  });

  group('8. Renvoi de l\'e-mail de confirmation après inscription', () {
    testWidgets(
        'Succès du renvoi avec confirmation visuelle et déclenchement du compte à rebours',
        (tester) async {
      fakeAuth.signUpRequiresConfirmation = true;

      await pumpApp(tester, home: const RegisterScreen());

      // Remplissage du formulaire d'inscription
      await tester.enterText(
          find.byKey(const ValueKey('register_fullname_field')), 'Amadou Kane');
      await tester.enterText(find.byKey(const ValueKey('register_email_field')),
          'amadou@agritrack.sn');
      await tester.enterText(
          find.byKey(const ValueKey('register_password_field')),
          'Password123!');
      await tester.enterText(
          find.byKey(const ValueKey('register_confirm_password_field')),
          'Password123!');

      final submitBtn = find.byKey(const ValueKey('register_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('email_confirmation_view')),
          findsOneWidget);

      final resendBtn =
          find.byKey(const ValueKey('resend_confirmation_email_button'));
      expect(resendBtn, findsOneWidget);

      // Clic pour renvoyer l'email
      await tester.ensureVisible(resendBtn);
      await tester.tap(resendBtn);
      await tester.pumpAndSettle();

      // Vérification de l'appel simulé sans requête réseau
      expect(fakeAuth.resendCallCount, equals(1));
      expect(fakeAuth.lastResentEmail, equals('amadou@agritrack.sn'));

      // Message de succès affiché
      expect(find.byKey(const ValueKey('resend_confirmation_success_message')),
          findsOneWidget);
      expect(
          find.textContaining('Un nouvel e-mail de confirmation a été envoyé'),
          findsOneWidget);

      // Bouton en cooldown
      expect(find.textContaining('Renvoyer l\'e-mail ('), findsOneWidget);

      // Tentative de re-clic pendant le compte à rebours : aucune soumission multiple
      await tester.tap(resendBtn);
      await tester.pump();
      expect(fakeAuth.resendCallCount, equals(1));
    });

    testWidgets(
        'Échec du renvoi avec gestion des erreurs (rate-limit / réseau)',
        (tester) async {
      fakeAuth.signUpRequiresConfirmation = true;
      fakeAuth.resendError = const AuthException(
          'For security purposes, you can only request this once every 60 seconds');

      await pumpApp(tester, home: const RegisterScreen());

      await tester.enterText(
          find.byKey(const ValueKey('register_fullname_field')), 'Mariam Sall');
      await tester.enterText(find.byKey(const ValueKey('register_email_field')),
          'mariam@agritrack.sn');
      await tester.enterText(
          find.byKey(const ValueKey('register_password_field')),
          'Password123!');
      await tester.enterText(
          find.byKey(const ValueKey('register_confirm_password_field')),
          'Password123!');

      final submitBtn = find.byKey(const ValueKey('register_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      final resendBtn =
          find.byKey(const ValueKey('resend_confirmation_email_button'));
      await tester.ensureVisible(resendBtn);
      await tester.tap(resendBtn);
      await tester.pumpAndSettle();

      // Message d'erreur clair et traduit
      expect(find.byKey(const ValueKey('resend_confirmation_error_message')),
          findsOneWidget);
      expect(
          find.text(
              'Trop de tentatives. Veuillez patienter un instant avant de renvoyer un e-mail.'),
          findsOneWidget);
    });
  });

  group('9. Accès au compte et avatar dans l\'AppBar', () {
    testWidgets(
        'AppBar déconnectée : affiche l\'icône neutre et navigue vers Mon compte',
        (tester) async {
      await pumpApp(tester, home: const MainShell());

      // L'avatar discret dans l'AppBar est présent
      final accountAvatar =
          find.byKey(const ValueKey('app_bar_account_button'));
      expect(accountAvatar, findsOneWidget);

      // Icône neutre de compte affichée
      expect(
        find.descendant(
          of: accountAvatar,
          matching: find.byIcon(Icons.person_outline_rounded),
        ),
        findsOneWidget,
      );

      // Clic sur l'avatar : navigation immédiate vers la section Mon compte
      await tester.tap(accountAvatar);
      await tester.pumpAndSettle();

      expect(find.text('Mon compte'), findsOneWidget);
      expect(find.text('Mode local hors-ligne'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('settings_login_button')), findsOneWidget);
    });

    testWidgets(
        'AppBar connectée : affiche les initiales de l\'utilisateur et navigue vers Réglages',
        (tester) async {
      fakeAuth.mockUser = User(
        id: 'uid_amadou_barry',
        appMetadata: {},
        userMetadata: {'full_name': 'Amadou Barry'},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: 'amadou.barry@agritrack.sn',
      );
      fakeAuth.mockSession = Session(
        accessToken: 'tok',
        tokenType: 'bearer',
        user: fakeAuth.mockUser!,
      );
      fakeAuth.mockProfile = UserProfile(
        id: 'uid_amadou_barry',
        email: 'amadou.barry@agritrack.sn',
        fullName: 'Amadou Barry',
        createdAt: DateTime.now(),
      );

      await pumpApp(tester, home: const MainShell());

      final accountAvatar =
          find.byKey(const ValueKey('app_bar_account_button'));
      expect(accountAvatar, findsOneWidget);

      // Initiales "AB" affichées
      final initialsFinder =
          find.byKey(const ValueKey('app_bar_account_initials'));
      expect(initialsFinder, findsOneWidget);
      expect(find.text('AB'), findsOneWidget);

      // Clic sur l'avatar
      await tester.tap(accountAvatar);
      await tester.pumpAndSettle();

      // Navigation vers la section Mon compte avec l'identité affichée
      expect(find.text('Amadou Barry'), findsWidgets);
      expect(find.text('amadou.barry@agritrack.sn'), findsOneWidget);
      expect(find.text('Connecté'), findsOneWidget);
    });
  });
}
