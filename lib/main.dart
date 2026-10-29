// lib/main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/supabase_config.dart';
import 'l10n/app_localizations.dart';
import 'providers/locale_provider.dart';
import 'providers/shared_preferences_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/main_shell.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint('Failed to initialize SharedPreferences: $e');
  }

  // Initialisation résiliente de Supabase (tolérance hors-ligne / mode local Sembast)
  await SupabaseConfig.initialize();

  runApp(
    ProviderScope(
      overrides: [
        if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const AgriTrackApp(),
    ),
  );
}

class AgriTrackApp extends ConsumerWidget {
  final bool? skipSplash;

  const AgriTrackApp({
    super.key,
    this.skipSplash,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final shouldSkipSplash = skipSplash ?? kIsWeb;

    return MaterialApp(
      title: 'AgriTrack',
      debugShowCheckedModeBanner: false,

      // ─── i18n ──────────────────────────────────────────────────────
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,

      // ─── Theme Mode ────────────────────────────────────────────────
      themeMode: themeMode,

      // ─── Light Theme ───────────────────────────────────────────────
      theme: AppTheme.lightTheme,

      // ─── Dark Theme ────────────────────────────────────────────────
      darkTheme: AppTheme.darkTheme,

      home: shouldSkipSplash ? const MainShell() : const SplashScreen(),
    );
  }
}
