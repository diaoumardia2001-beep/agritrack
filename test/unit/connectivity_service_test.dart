import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:agritrack/services/sync/connectivity_service.dart';

void main() {
  group('ConnectivityService', () {
    late ConnectivityService service;

    setUp(() {
      service = ConnectivityService(autoStartPolling: false);
    });

    tearDown(() {
      service.dispose();
    });

    test('Initial status is online by default', () {
      expect(service.isOnline, isTrue);
    });

    test('setOnlineStatus modifies isOnline and emits event on stream', () async {
      final events = <bool>[];
      final subscription = service.onConnectivityChanged.listen(events.add);

      service.setOnlineStatus(false);
      service.setOnlineStatus(false); // Should not emit duplicate
      service.setOnlineStatus(true);

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(events, equals([false, true]));
      expect(service.isOnline, isTrue);

      await subscription.cancel();
    });

    test('isNetworkFailure correctly distinguishes network failures from application/RLS errors', () {
      // Network failures
      expect(
        ConnectivityService.isNetworkFailure(const SocketException('Failed host lookup')),
        isTrue,
      );
      expect(
        ConnectivityService.isNetworkFailure(Exception('ClientException: Failed to fetch')),
        isTrue,
      );
      expect(
        ConnectivityService.isNetworkFailure(Exception('XMLHttpRequest error')),
        isTrue,
      );
      expect(
        ConnectivityService.isNetworkFailure(Exception('Connection refused')),
        isTrue,
      );
      expect(
        ConnectivityService.isNetworkFailure(Exception('Network is unreachable')),
        isTrue,
      );

      // Non-network failures (RLS, server response, permissions)
      const postgrestError = PostgrestException(
        message: 'permission denied for table farms',
        code: '42501',
      );
      expect(ConnectivityService.isNetworkFailure(postgrestError), isFalse);

      const authError = AuthException('Invalid login credentials');
      expect(ConnectivityService.isNetworkFailure(authError), isFalse);

      const formatError = FormatException('Invalid JSON payload');
      expect(ConnectivityService.isNetworkFailure(formatError), isFalse);
    });

    test('checkConnectivity returns false if SupabaseConfig.safeClient is null', () async {
      // Supabase is not initialized in standard unit tests, so safeClient is null
      final result = await service.checkConnectivity();
      expect(result, isFalse);
      expect(service.isOnline, isFalse);
    });
  });

  group('FakeConnectivityService', () {
    test('allows simulating online and offline transitions', () async {
      final fake = FakeConnectivityService(initialOnline: true);
      expect(fake.isOnline, isTrue);

      final events = <bool>[];
      final subscription = fake.onConnectivityChanged.listen(events.add);

      fake.emit(false);
      expect(fake.isOnline, isFalse);
      expect(await fake.checkConnectivity(), isFalse);

      fake.emit(true);
      expect(fake.isOnline, isTrue);
      expect(await fake.checkConnectivity(), isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(events, equals([false, true]));

      await subscription.cancel();
      fake.dispose();
    });
  });
}

