// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shared_preferences_provider.dart';

/// SharedPreferences key for persisting the chosen theme mode.
const String themePreferenceKey = 'agritrack_theme_mode';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  SharedPreferences? _prefs;
  bool _userHasChangedState = false;

  ThemeModeNotifier([this._prefs]) : super(_initialThemeMode(_prefs)) {
    if (_prefs == null) {
      _loadFromPrefsAsync();
    }
  }

  static ThemeMode _initialThemeMode(SharedPreferences? prefs) {
    if (prefs == null) return ThemeMode.light;
    try {
      final raw = prefs.getString(themePreferenceKey);
      return parseThemeMode(raw);
    } catch (_) {
      return ThemeMode.light;
    }
  }

  /// Parses a persisted string into a [ThemeMode] with a safe fallback to [ThemeMode.light].
  static ThemeMode parseThemeMode(String? value) {
    if (value == null) return ThemeMode.light;
    switch (value.toLowerCase().trim()) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  Future<void> _loadFromPrefsAsync() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      final p = await SharedPreferences.getInstance();
      _prefs ??= p;
      if (!_userHasChangedState) {
        final raw = p.getString(themePreferenceKey);
        if (!_userHasChangedState && raw != null) {
          state = parseThemeMode(raw);
        }
      }
    } catch (_) {
      // Gracefully maintain current state on storage error
    }
  }

  Future<void> toggle() async {
    _userHasChangedState = true;
    state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await _persistThemeMode(state);
  }

  Future<void> setMode(ThemeMode mode) async {
    _userHasChangedState = true;
    state = mode;
    await _persistThemeMode(mode);
  }

  Future<void> _persistThemeMode(ThemeMode mode) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      final p = _prefs ?? await SharedPreferences.getInstance();
      _prefs = p;
      await p.setString(themePreferenceKey, mode.name);
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeModeNotifier(prefs);
});
