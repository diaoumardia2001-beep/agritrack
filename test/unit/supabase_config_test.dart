// test/unit/supabase_config_test.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agritrack/core/supabase_config.dart';

void main() {
  group('SupabaseConfig - Multi-Platform URL Resolution', () {
    tearDown(() {
      SupabaseConfig.resetForTesting();
    });

    test('1. Resolves Android emulator loopback URL (10.0.2.2:54321)', () {
      final url = SupabaseConfig.resolveUrl(
        platform: TargetPlatform.android,
        isWeb: false,
      );
      expect(url, equals('http://10.0.2.2:54321'));
    });

    test('2. Resolves localhost URL on Web (127.0.0.1:54321)', () {
      final url = SupabaseConfig.resolveUrl(
        platform:
            TargetPlatform.android, // même si platform est android, isWeb prime
        isWeb: true,
      );
      expect(url, equals('http://127.0.0.1:54321'));
    });

    test('3. Resolves localhost URL on Windows, Linux and macOS', () {
      for (final platform in [
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.macOS,
      ]) {
        final url = SupabaseConfig.resolveUrl(
          platform: platform,
          isWeb: false,
        );
        expect(url, equals('http://127.0.0.1:54321'),
            reason: 'Échec sur la plateforme $platform');
      }
    });

    test('4. Resolves localhost URL on iOS simulator', () {
      final url = SupabaseConfig.resolveUrl(
        platform: TargetPlatform.iOS,
        isWeb: false,
      );
      expect(url, equals('http://127.0.0.1:54321'));
    });
  });

  group('SupabaseConfig - Security & Key Validation', () {
    tearDown(() {
      SupabaseConfig.resetForTesting();
    });

    test('5. Default anon key is publishable and not a secret/service_role',
        () {
      final key = SupabaseConfig.anonKey;
      expect(key, isNotEmpty);
      expect(key.toLowerCase(), isNot(contains('service_role')));
      expect(key, isNot(startsWith('sb_secret_')));
    });

    test('6. Rejects service_role key initialization with ArgumentError',
        () async {
      expect(
        () => SupabaseConfig.initialize(
          customUrl: 'http://127.0.0.1:54321',
          customAnonKey: 'eyJhbGciOi...service_role...secret',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('7. Rejects secret key with sb_secret_ prefix', () async {
      expect(
        () => SupabaseConfig.initialize(
          customUrl: 'http://127.0.0.1:54321',
          customAnonKey: 'sb_secret_abcdef123456',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('SupabaseConfig - Offline Resilience & Safe Accessors', () {
    tearDown(() {
      SupabaseConfig.resetForTesting();
    });

    test(
        '8. safeClient returns null when Supabase is not initialized without throwing',
        () {
      SupabaseConfig.resetForTesting();
      expect(SupabaseConfig.isInitialized, isFalse);
      expect(SupabaseConfig.safeClient, isNull);
    });

    test(
        '9. Direct client getter throws explicit StateError when not initialized',
        () {
      SupabaseConfig.resetForTesting();
      expect(
        () => SupabaseConfig.client,
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('SupabaseConfig n\'est pas encore initialisé'),
        )),
      );
    });

    test('10. setInitializedForTesting updates internal state safely for tests',
        () {
      SupabaseConfig.setInitializedForTesting(
        true,
        url: 'http://custom-test.local',
        key: 'custom-anon-key',
      );
      expect(SupabaseConfig.isInitialized, isTrue);
      expect(SupabaseConfig.url, equals('http://custom-test.local'));
      expect(SupabaseConfig.anonKey, equals('custom-anon-key'));

      SupabaseConfig.resetForTesting();
      expect(SupabaseConfig.isInitialized, isFalse);
    });
  });
}
