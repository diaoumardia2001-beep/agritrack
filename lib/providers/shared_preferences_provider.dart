// lib/providers/shared_preferences_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for accessing [SharedPreferences].
///
/// Overridden in [main] using [SharedPreferences.getInstance] so that
/// settings (theme, locale) are available synchronously on the first frame,
/// avoiding any visual flicker or delayed language change.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) {
  return null;
});
