import 'package:flutter_test/flutter_test.dart';
import 'package:agritrack/data/database/app_database.dart';

void main() {
  group('AppDatabase Tests', () {
    tearDown(() async {
      await AppDatabase.resetForTesting();
    });

    test(
        'openInMemory creates a functional in-memory database without disk access',
        () async {
      final db = await AppDatabase.openInMemory(name: 'test_in_memory.db');
      addTearDown(() => db.close());

      expect(db, isNotNull);
      expect(db.path, 'test_in_memory.db');

      final store = stringMapStoreFactory.store('test_store');
      await store.record('k1').put(db, {'value': 42, 'name': 'AgriTrack'});

      final record = await store.record('k1').get(db);
      expect(record, isNotNull);
      expect(record!['value'], 42);
      expect(record['name'], 'AgriTrack');
    });

    test('openInMemory databases are properly isolated', () async {
      final db1 = await AppDatabase.openInMemory(name: 'db1.db');
      final db2 = await AppDatabase.openInMemory(name: 'db2.db');
      addTearDown(() async {
        await db1.close();
        await db2.close();
      });

      final store = stringMapStoreFactory.store('test_store');
      await store.record('key').put(db1, {'owner': 'db1'});

      final val1 = await store.record('key').get(db1);
      final val2 = await store.record('key').get(db2);

      expect(val1?['owner'], 'db1');
      expect(val2, isNull);
    });

    test('setInstanceForTesting injects in-memory database into singleton',
        () async {
      final mockDb = await AppDatabase.openInMemory(name: 'mock_singleton.db');
      addTearDown(() => mockDb.close());

      AppDatabase.setInstanceForTesting(mockDb);

      final db = await AppDatabase.instance.database;
      expect(identical(db, mockDb), isTrue);

      final store = stringMapStoreFactory.store('test_singleton');
      await store.record('k').put(db, {'status': 'active'});

      final read = await store.record('k').get(mockDb);
      expect(read?['status'], 'active');
    });

    test('close and resetForTesting cleanly closes database and clears state',
        () async {
      final mockDb = await AppDatabase.openInMemory(name: 'close_test.db');
      AppDatabase.setInstanceForTesting(mockDb);

      await AppDatabase.instance.close();
      // Database should be closed
      expect(
        () async =>
            stringMapStoreFactory.store('s').record('1').put(mockDb, {'a': 1}),
        throwsA(anything),
      );

      await AppDatabase.resetForTesting();
    });
  });
}
