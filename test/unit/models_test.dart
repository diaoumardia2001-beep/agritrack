// test/unit/models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:agritrack/models/animal.dart';
import 'package:agritrack/models/expense.dart';
import 'package:agritrack/models/farm.dart';
import 'package:agritrack/models/sync_conflict.dart';
import 'package:agritrack/models/sync_queue_operation.dart';
import 'package:agritrack/models/user_profile.dart';

void main() {
  group('Animal Model Tests', () {
    test('Animal instantiation with default values', () {
      final created = DateTime(2026, 1, 10);
      final animal = Animal(
        id: 'test_1',
        name: 'Moussa',
        type: AnimalType.bovin,
        ageMonths: 18,
        weightKg: 210.5,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: created,
      );

      expect(animal.id, 'test_1');
      expect(animal.name, 'Moussa');
      expect(animal.type, AnimalType.bovin);
      expect(animal.ageMonths, 18);
      expect(animal.weightKg, 210.5);
      expect(animal.healthStatus, HealthStatus.sain);
      expect(animal.expenses, isEmpty);
      expect(animal.totalExpenses, 0);
      expect(animal.createdAt, created);
    });

    test('Animal totalExpenses computes sum of expenses correctly', () {
      final animal = Animal(
        id: 'test_2',
        name: 'Koffi',
        type: AnimalType.caprin,
        ageMonths: 12,
        weightKg: 35.0,
        healthStatus: HealthStatus.aSurveiller,
        expenses: [
          Expense(
            id: 'e1',
            label: 'Aliment',
            amount: 5000,
            date: DateTime(2026, 9, 1),
            category: ExpenseCategory.alimentation,
          ),
          Expense(
            id: 'e2',
            label: 'Vaccin',
            amount: 7500,
            date: DateTime(2026, 9, 15),
            category: ExpenseCategory.sante,
          ),
        ],
        createdAt: DateTime(2026, 2, 1),
      );

      expect(animal.expenses.length, 2);
      expect(animal.totalExpenses, 12500);
    });

    test(
        'Animal monthlyExpensesFor filters by year and month deterministically',
        () {
      final animal = Animal(
        id: 'test_monthly',
        name: 'Diarra',
        type: AnimalType.bovin,
        ageMonths: 24,
        weightKg: 290.0,
        healthStatus: HealthStatus.sain,
        expenses: [
          Expense(
            id: 'e_curr',
            label: 'Aliment Octobre 2026',
            amount: 10000,
            date: DateTime(2026, 10, 5),
            category: ExpenseCategory.alimentation,
          ),
          Expense(
            id: 'e_curr_2',
            label: 'Soin Octobre 2026',
            amount: 5000,
            date: DateTime(2026, 10, 20),
            category: ExpenseCategory.sante,
          ),
          Expense(
            id: 'e_past_month',
            label: 'Aliment Septembre 2026',
            amount: 8000,
            date: DateTime(2026, 9, 15),
            category: ExpenseCategory.alimentation,
          ),
          Expense(
            id: 'e_past_year',
            label: 'Aliment Octobre 2025',
            amount: 7000,
            date: DateTime(2025, 10, 10),
            category: ExpenseCategory.alimentation,
          ),
          Expense(
            id: 'e_future_month',
            label: 'Aliment Novembre 2026',
            amount: 6000,
            date: DateTime(2026, 11, 1),
            category: ExpenseCategory.alimentation,
          ),
        ],
        createdAt: DateTime(2025, 1, 1),
      );

      // Total includes all expenses: 10000 + 5000 + 8000 + 7000 + 6000 = 36000
      expect(animal.totalExpenses, 36000);

      // Octobre 2026 expenses: e_curr (10000) + e_curr_2 (5000) = 15000
      final oct2026 = animal.monthlyExpensesFor(DateTime(2026, 10, 1));
      expect(oct2026, 15000);

      // Septembre 2026 expenses: e_past_month (8000)
      final sep2026 = animal.monthlyExpensesFor(DateTime(2026, 9, 1));
      expect(sep2026, 8000);

      // Octobre 2025 expenses: e_past_year (7000) - ignores Octobre 2026
      final oct2025 = animal.monthlyExpensesFor(DateTime(2025, 10, 1));
      expect(oct2025, 7000);

      // Month with no expenses: returns 0.0
      final jan2026 = animal.monthlyExpensesFor(DateTime(2026, 1, 1));
      expect(jan2026, 0.0);
    });

    test('Animal monthlyExpenses returns 0.0 when expenses list is empty', () {
      final emptyAnimal = Animal(
        id: 'test_empty',
        name: 'Vide',
        type: AnimalType.caprin,
        ageMonths: 6,
        weightKg: 15.0,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime.now(),
      );

      expect(emptyAnimal.totalExpenses, 0.0);
      expect(emptyAnimal.monthlyExpenses, 0.0);
      expect(emptyAnimal.monthlyExpensesFor(DateTime(2026, 10, 1)), 0.0);
    });

    test('Animal copyWith updates fields immutably', () {
      final original = Animal(
        id: 'test_3',
        name: 'Awa',
        type: AnimalType.ovin,
        ageMonths: 10,
        weightKg: 28.0,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime(2026, 3, 1),
      );

      final updated = original.copyWith(
        weightKg: 32.5,
        healthStatus: HealthStatus.malade,
      );

      expect(updated.id, original.id);
      expect(updated.name, original.name);
      expect(updated.weightKg, 32.5);
      expect(updated.healthStatus, HealthStatus.malade);
      expect(original.weightKg, 28.0);
      expect(original.healthStatus, HealthStatus.sain);
    });

    test('AnimalType labels and emojis', () {
      expect(AnimalType.bovin.label, 'Bovin');
      expect(AnimalType.bovin.emoji, '🐄');
      expect(AnimalType.caprin.label, 'Caprin');
      expect(AnimalType.caprin.emoji, '🐐');
      expect(AnimalType.ovin.label, 'Ovin');
      expect(AnimalType.ovin.emoji, '🐑');
      expect(AnimalType.volaille.label, 'Volaille');
      expect(AnimalType.volaille.emoji, '🐓');
    });

    test('HealthStatus labels', () {
      expect(HealthStatus.sain.label, 'Sain');
      expect(HealthStatus.aSurveiller.label, 'À surveiller');
      expect(HealthStatus.malade.label, 'Malade');
    });

    test('Animal toMap() serializes all fields including expenses and imageUrl',
        () {
      final date = DateTime(2026, 1, 15, 8, 30);
      final expenseDate = DateTime(2026, 2, 10, 14, 0);
      final animal = Animal(
        id: 'a001',
        name: 'Bakary',
        type: AnimalType.bovin,
        ageMonths: 36,
        weightKg: 320.5,
        healthStatus: HealthStatus.sain,
        imageUrl: 'https://example.com/bakary.jpg',
        expenses: [
          Expense(
            id: 'e001',
            label: 'Aliment concentré',
            amount: 8500.0,
            date: expenseDate,
            category: ExpenseCategory.alimentation,
          ),
        ],
        createdAt: date,
      );

      final map = animal.toMap();

      expect(map['id'], 'a001');
      expect(map['name'], 'Bakary');
      expect(map['type'], 'bovin');
      expect(map['ageMonths'], 36);
      expect(map['weightKg'], 320.5);
      expect(map['healthStatus'], 'sain');
      expect(map['imageUrl'], 'https://example.com/bakary.jpg');
      expect(map['createdAt'], '2026-01-15T08:30:00.000');
      expect(map['expenses'], isA<List>());
      expect((map['expenses'] as List).length, 1);
      expect((map['expenses'] as List).first['id'], 'e001');
    });

    test(
        'Animal fromMap() restores animal with null imageUrl and empty expenses',
        () {
      final date = DateTime(2026, 3, 20);
      final original = Animal(
        id: 'a002',
        name: 'Fanta',
        type: AnimalType.caprin,
        ageMonths: 24,
        weightKg: 45.0,
        healthStatus: HealthStatus.aSurveiller,
        imageUrl: null,
        expenses: const [],
        createdAt: date,
      );

      final map = original.toMap();
      expect(map['imageUrl'], isNull);
      expect(map['expenses'], isEmpty);

      final restored = Animal.fromMap(map);
      expect(restored.id, 'a002');
      expect(restored.name, 'Fanta');
      expect(restored.type, AnimalType.caprin);
      expect(restored.ageMonths, 24);
      expect(restored.weightKg, 45.0);
      expect(restored.healthStatus, HealthStatus.aSurveiller);
      expect(restored.imageUrl, isNull);
      expect(restored.expenses, isEmpty);
      expect(restored.createdAt, date);
    });

    test('Animal roundtrip with multiple expenses preserves all data and order',
        () {
      final animal = Animal(
        id: 'a003',
        name: 'Koné',
        type: AnimalType.bovin,
        ageMonths: 48,
        weightKg: 410.0,
        healthStatus: HealthStatus.sain,
        imageUrl: null,
        expenses: [
          Expense(
            id: 'e007',
            label: 'Foin et paille',
            amount: 10500,
            date: DateTime(2026, 10, 1),
            category: ExpenseCategory.alimentation,
          ),
          Expense(
            id: 'e008',
            label: 'Vermifuge',
            amount: 4500,
            date: DateTime(2026, 9, 10),
            category: ExpenseCategory.sante,
          ),
        ],
        createdAt: DateTime(2025, 8, 10),
      );

      final restored = Animal.fromMap(animal.toMap());

      expect(restored.id, animal.id);
      expect(restored.name, animal.name);
      expect(restored.type, animal.type);
      expect(restored.ageMonths, animal.ageMonths);
      expect(restored.weightKg, animal.weightKg);
      expect(restored.healthStatus, animal.healthStatus);
      expect(restored.expenses.length, 2);
      expect(restored.expenses[0].id, 'e007');
      expect(restored.expenses[0].amount, 10500.0);
      expect(restored.expenses[1].id, 'e008');
      expect(restored.expenses[1].amount, 4500.0);
      expect(restored.totalExpenses, 15000.0);
    });

    test('Animal fromMap() converts numeric types safely from int or double',
        () {
      final map = {
        'id': 'a_num',
        'name': 'Num Test',
        'type': 'volaille',
        'ageMonths': 6.0, // double
        'weightKg': 2, // int
        'healthStatus': 'sain',
        'imageUrl': null,
        'expenses': null,
        'createdAt': '2026-06-01T00:00:00.000',
      };

      final animal = Animal.fromMap(map);
      expect(animal.ageMonths, 6);
      expect(animal.ageMonths, isA<int>());
      expect(animal.weightKg, 2.0);
      expect(animal.weightKg, isA<double>());
      expect(animal.expenses, isEmpty);
    });

    test(
        'Animal fromMap() deserializes every valid AnimalType and HealthStatus',
        () {
      for (final type in AnimalType.values) {
        for (final health in HealthStatus.values) {
          final map = {
            'id': 'a_${type.name}_${health.name}',
            'name': 'Animal ${type.label}',
            'type': type.name,
            'ageMonths': 12,
            'weightKg': 100.0,
            'healthStatus': health.name,
            'createdAt': '2026-01-01T00:00:00.000',
          };
          final animal = Animal.fromMap(map);
          expect(animal.type, type);
          expect(animal.healthStatus, health);
        }
      }
    });

    test('Animal fromMap() also accepts healthStatus value (e.g. a_surveiller)',
        () {
      final map = {
        'id': 'a_val',
        'name': 'Test Val',
        'type': 'caprin',
        'ageMonths': 10,
        'weightKg': 30.0,
        'healthStatus': 'a_surveiller',
        'createdAt': '2026-01-01T00:00:00.000',
      };
      final animal = Animal.fromMap(map);
      expect(animal.healthStatus, HealthStatus.aSurveiller);
    });

    test('Animal fromMap() throws FormatException on invalid or corrupted data',
        () {
      final validMap = {
        'id': 'a001',
        'name': 'Bakary',
        'type': 'bovin',
        'ageMonths': 36,
        'weightKg': 320.0,
        'healthStatus': 'sain',
        'createdAt': '2026-01-15T00:00:00.000',
      };

      // Empty ID
      expect(
          () => Animal.fromMap({...validMap, 'id': ''}), throwsFormatException);
      expect(() => Animal.fromMap({...validMap, 'id': 123}),
          throwsFormatException);

      // Empty Name
      expect(() => Animal.fromMap({...validMap, 'name': '  '}),
          throwsFormatException);

      // Unknown AnimalType
      expect(() => Animal.fromMap({...validMap, 'type': 'cheval'}),
          throwsFormatException);

      // Unknown HealthStatus
      expect(() => Animal.fromMap({...validMap, 'healthStatus': 'inconnu'}),
          throwsFormatException);

      // Invalid ageMonths (negative, string, NaN)
      expect(() => Animal.fromMap({...validMap, 'ageMonths': -5}),
          throwsFormatException);
      expect(() => Animal.fromMap({...validMap, 'ageMonths': 'dix'}),
          throwsFormatException);
      expect(() => Animal.fromMap({...validMap, 'ageMonths': double.nan}),
          throwsFormatException);

      // Invalid weightKg (zero, negative, NaN)
      expect(() => Animal.fromMap({...validMap, 'weightKg': 0}),
          throwsFormatException);
      expect(() => Animal.fromMap({...validMap, 'weightKg': -10.0}),
          throwsFormatException);

      // Invalid createdAt
      expect(() => Animal.fromMap({...validMap, 'createdAt': 'pas-une-date'}),
          throwsFormatException);

      // Invalid expenses list
      expect(
          () => Animal.fromMap({
                ...validMap,
                'expenses': ['pas-une-map']
              }),
          throwsFormatException);
    });
  });

  group('Expense Model Tests', () {
    test('Expense instantiation and fields', () {
      final date = DateTime(2026, 10, 1);
      final expense = Expense(
        id: 'exp_1',
        label: 'Vermifuge',
        amount: 4500,
        date: date,
        category: ExpenseCategory.sante,
      );

      expect(expense.id, 'exp_1');
      expect(expense.label, 'Vermifuge');
      expect(expense.amount, 4500);
      expect(expense.date, date);
      expect(expense.category, ExpenseCategory.sante);
    });

    test('ExpenseCategory labels and icons', () {
      expect(ExpenseCategory.alimentation.label, 'Alimentation');
      expect(ExpenseCategory.sante.label, 'Santé');
      expect(ExpenseCategory.autre.label, 'Autre');
    });

    test('Expense toMap() serializes all fields into expected format', () {
      final date = DateTime(2026, 10, 15, 14, 30);
      final expense = Expense(
        id: 'e_100',
        label: 'Sac de sel minéral',
        amount: 6500.5,
        date: date,
        category: ExpenseCategory.alimentation,
      );

      final map = expense.toMap();

      expect(map['id'], 'e_100');
      expect(map['label'], 'Sac de sel minéral');
      expect(map['amount'], 6500.5);
      expect(map['date'], '2026-10-15T14:30:00.000');
      expect(map['category'], 'alimentation');
    });

    test('Expense fromMap() restores Expense correctly and preserves roundtrip',
        () {
      final original = Expense(
        id: 'e_101',
        label: 'Vaccination CBPP',
        amount: 12000.0,
        date: DateTime(2026, 9, 20, 11, 15),
        category: ExpenseCategory.sante,
      );

      final restored = Expense.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.label, original.label);
      expect(restored.amount, original.amount);
      expect(restored.date, original.date);
      expect(restored.category, original.category);
    });

    test('Expense fromMap() safely converts int amount to double', () {
      final map = {
        'id': 'e_int',
        'label': 'Achat matériel',
        'amount': 25000, // integer
        'date': '2026-10-01T00:00:00.000',
        'category': 'autre',
      };

      final expense = Expense.fromMap(map);

      expect(expense.amount, 25000.0);
      expect(expense.amount, isA<double>());
    });

    test('Expense fromMap() deserializes every valid ExpenseCategory', () {
      for (final cat in ExpenseCategory.values) {
        final map = {
          'id': 'e_${cat.name}',
          'label': 'Test ${cat.label}',
          'amount': 5000.0,
          'date': '2026-10-01T00:00:00.000',
          'category': cat.name,
        };

        final expense = Expense.fromMap(map);
        expect(expense.category, cat);
      }
    });

    test(
        'Expense fromMap() throws FormatException on invalid or corrupted data',
        () {
      final validMap = {
        'id': 'e_001',
        'label': 'Vaccin',
        'amount': 4500.0,
        'date': '2026-10-01T00:00:00.000',
        'category': 'sante',
      };

      // Empty / non-string id
      expect(() => Expense.fromMap({...validMap, 'id': ''}),
          throwsFormatException);
      expect(() => Expense.fromMap({...validMap, 'id': null}),
          throwsFormatException);
      expect(() => Expense.fromMap({...validMap, 'id': 123}),
          throwsFormatException);

      // Empty / non-string label
      expect(() => Expense.fromMap({...validMap, 'label': '   '}),
          throwsFormatException);
      expect(() => Expense.fromMap({...validMap, 'label': null}),
          throwsFormatException);

      // Invalid amounts (0, negative, non-numeric, NaN, infinite)
      expect(() => Expense.fromMap({...validMap, 'amount': 0}),
          throwsFormatException);
      expect(() => Expense.fromMap({...validMap, 'amount': -500}),
          throwsFormatException);
      expect(() => Expense.fromMap({...validMap, 'amount': 'cinq_mille'}),
          throwsFormatException);
      expect(() => Expense.fromMap({...validMap, 'amount': double.nan}),
          throwsFormatException);
      expect(() => Expense.fromMap({...validMap, 'amount': double.infinity}),
          throwsFormatException);

      // Invalid date
      expect(() => Expense.fromMap({...validMap, 'date': 'invalid-date'}),
          throwsFormatException);
      expect(() => Expense.fromMap({...validMap, 'date': null}),
          throwsFormatException);

      // Unknown category
      expect(() => Expense.fromMap({...validMap, 'category': 'transport'}),
          throwsFormatException);
      expect(() => Expense.fromMap({...validMap, 'category': 123}),
          throwsFormatException);
    });

    test('Expense backward compatibility with legacy map (missing new fields)',
        () {
      final legacyMap = {
        'id': 'exp_legacy_1',
        'label': 'Fourrage',
        'amount': 15000.0,
        'date': '2026-05-10T14:30:00.000',
        'category': 'alimentation',
      };

      final expense = Expense.fromMap(legacyMap);
      expect(expense.id, 'exp_legacy_1');
      expect(expense.label, 'Fourrage');
      expect(expense.amount, 15000.0);
      expect(expense.animalId, isNull);
      expect(expense.farmId, isNull);
      expect(expense.createdBy, isNull);
      expect(expense.updatedAt, isNull);
      expect(expense.deletedAt, isNull);
    });

    test('Expense with multi-tenant fields roundtrip via toMap/fromMap', () {
      final date = DateTime(2026, 6, 1, 10, 0);
      final updated = DateTime(2026, 6, 2, 12, 0);
      final deleted = DateTime(2026, 6, 3, 14, 0);

      final expense = Expense(
        id: 'exp_mt_1',
        animalId: 'anim_99',
        farmId: 'farm_alpha',
        createdBy: 'usr_owner_1',
        updatedAt: updated,
        deletedAt: deleted,
        label: 'Consultation vétérinaire',
        amount: 25000.0,
        date: date,
        category: ExpenseCategory.sante,
      );

      final map = expense.toMap();
      expect(map['id'], 'exp_mt_1');
      expect(map['animalId'], 'anim_99');
      expect(map['farmId'], 'farm_alpha');
      expect(map['createdBy'], 'usr_owner_1');
      expect(map['updatedAt'], updated.toIso8601String());
      expect(map['deletedAt'], deleted.toIso8601String());

      final restored = Expense.fromMap(map);
      expect(restored, expense);
      expect(restored.animalId, 'anim_99');
      expect(restored.farmId, 'farm_alpha');
      expect(restored.createdBy, 'usr_owner_1');
      expect(restored.updatedAt, updated);
      expect(restored.deletedAt, deleted);
    });

    test('Expense copyWith updates multi-user and audit fields', () {
      final base = Expense(
        id: 'exp_copy_base',
        label: 'Vitamines',
        amount: 3000,
        date: DateTime(2026, 4, 1),
        category: ExpenseCategory.sante,
      );

      final updated = base.copyWith(
        animalId: 'anim_target',
        farmId: 'farm_beta',
        createdBy: 'usr_vet',
        updatedAt: DateTime(2026, 4, 2),
      );

      expect(updated.id, base.id);
      expect(updated.label, base.label);
      expect(updated.animalId, 'anim_target');
      expect(updated.farmId, 'farm_beta');
      expect(updated.createdBy, 'usr_vet');
      expect(updated.updatedAt, DateTime(2026, 4, 2));
      expect(base.animalId, isNull);
    });

    test('Expense equality and hashCode', () {
      final date = DateTime(2026, 7, 1);
      final e1 = Expense(
        id: 'e_same',
        label: 'Aliment',
        amount: 5000,
        date: date,
        category: ExpenseCategory.alimentation,
      );
      final e2 = Expense(
        id: 'e_same',
        label: 'Aliment',
        amount: 5000,
        date: date,
        category: ExpenseCategory.alimentation,
      );
      final e3 = e1.copyWith(amount: 6000);

      expect(e1, equals(e2));
      expect(e1.hashCode, equals(e2.hashCode));
      expect(e1 == e3, isFalse);
    });
  });

  group('Animal Model - Multi-User & Backward Compatibility', () {
    test(
        'Animal default constructor assigns local_default_farm and isDemo false',
        () {
      final animal = Animal(
        id: 'a_default_farm',
        name: 'Bella',
        type: AnimalType.bovin,
        ageMonths: 15,
        weightKg: 200,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime(2026, 1, 1),
      );

      expect(animal.farmId, 'local_default_farm');
      expect(animal.isDemo, isFalse);
      expect(animal.createdBy, isNull);
      expect(animal.updatedAt, isNull);
      expect(animal.deletedAt, isNull);
    });

    test(
        'Animal.fromMap handles legacy map without farmId or isDemo gracefully',
        () {
      final legacyMap = {
        'id': 'a_legacy_01',
        'name': 'Fanta',
        'type': 'caprin',
        'ageMonths': 12,
        'weightKg': 30.0,
        'healthStatus': 'sain',
        'expenses': [],
        'createdAt': '2026-02-15T08:00:00.000',
      };

      final animal = Animal.fromMap(legacyMap);
      expect(animal.id, 'a_legacy_01');
      expect(animal.farmId, 'local_default_farm');
      expect(animal.isDemo, isFalse);
      expect(animal.createdBy, isNull);
      expect(animal.updatedAt, isNull);
      expect(animal.deletedAt, isNull);
    });

    test('Animal.fromMap deserializes multi-user fields when present', () {
      final fullMap = {
        'id': 'a_modern_01',
        'farmId': 'farm_touba_01',
        'isDemo': true,
        'createdBy': 'user_owner_42',
        'updatedAt': '2026-03-01T10:00:00.000',
        'deletedAt': '2026-03-10T12:00:00.000',
        'name': 'Samba',
        'type': 'ovin',
        'ageMonths': 8,
        'weightKg': 24.5,
        'healthStatus': 'aSurveiller',
        'imageUrl': 'https://example.com/samba.jpg',
        'expenses': [],
        'createdAt': '2026-01-01T00:00:00.000',
      };

      final animal = Animal.fromMap(fullMap);
      expect(animal.farmId, 'farm_touba_01');
      expect(animal.isDemo, isTrue);
      expect(animal.createdBy, 'user_owner_42');
      expect(animal.updatedAt, DateTime(2026, 3, 1, 10, 0));
      expect(animal.deletedAt, DateTime(2026, 3, 10, 12, 0));
    });

    test('Animal copyWith modifies multi-user fields immutably', () {
      final animal = Animal(
        id: 'a_copy_mu',
        name: 'Moussa',
        type: AnimalType.bovin,
        ageMonths: 18,
        weightKg: 210.5,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime(2026, 1, 1),
      );

      final updated = animal.copyWith(
        farmId: 'farm_new_id',
        isDemo: true,
        createdBy: 'usr_new',
        updatedAt: DateTime(2026, 5, 1),
        deletedAt: DateTime(2026, 5, 2),
      );

      expect(updated.farmId, 'farm_new_id');
      expect(updated.isDemo, isTrue);
      expect(updated.createdBy, 'usr_new');
      expect(updated.updatedAt, DateTime(2026, 5, 1));
      expect(updated.deletedAt, DateTime(2026, 5, 2));
      expect(animal.farmId, 'local_default_farm');
      expect(animal.isDemo, isFalse);
    });

    test('Animal toMap includes farmId, isDemo and audit fields', () {
      final animal = Animal(
        id: 'a_map_check',
        farmId: 'farm_kolda',
        isDemo: true,
        createdBy: 'user_123',
        updatedAt: DateTime(2026, 8, 1, 12, 0),
        deletedAt: DateTime(2026, 8, 2, 12, 0),
        name: 'Diallo',
        type: AnimalType.volaille,
        ageMonths: 4,
        weightKg: 2.1,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime(2026, 7, 1),
      );

      final map = animal.toMap();
      expect(map['farmId'], 'farm_kolda');
      expect(map['isDemo'], isTrue);
      expect(map['createdBy'], 'user_123');
      expect(map['updatedAt'], '2026-08-01T12:00:00.000');
      expect(map['deletedAt'], '2026-08-02T12:00:00.000');
    });
  });

  group('Farm Model Tests', () {
    test('Farm instantiation with default isDemo false and optional nulls', () {
      final now = DateTime(2026, 1, 1);
      final farm = Farm(
        id: 'farm_001',
        name: 'Ferme du Niayes',
        createdAt: now,
      );

      expect(farm.id, 'farm_001');
      expect(farm.name, 'Ferme du Niayes');
      expect(farm.region, isNull);
      expect(farm.ownerId, isNull);
      expect(farm.isDemo, isFalse);
      expect(farm.createdAt, now);
      expect(farm.updatedAt, isNull);
    });

    test('Farm copyWith updates immutably', () {
      final farm = Farm(
        id: 'farm_002',
        name: 'Ferme Sine Saloum',
        region: 'Fatick',
        createdAt: DateTime(2026, 1, 1),
      );

      final updated = farm.copyWith(
        name: 'Ferme Sine Saloum Moderne',
        ownerId: 'usr_owner_10',
        isDemo: true,
        updatedAt: DateTime(2026, 2, 1),
      );

      expect(updated.id, farm.id);
      expect(updated.name, 'Ferme Sine Saloum Moderne');
      expect(updated.region, 'Fatick');
      expect(updated.ownerId, 'usr_owner_10');
      expect(updated.isDemo, isTrue);
      expect(updated.updatedAt, DateTime(2026, 2, 1));
      expect(farm.name, 'Ferme Sine Saloum');
      expect(farm.ownerId, isNull);
    });

    test('Farm serialization roundtrip toMap and fromMap', () {
      final created = DateTime(2026, 1, 1, 10, 0);
      final updated = DateTime(2026, 1, 15, 16, 30);
      final farm = Farm(
        id: 'farm_full',
        name: 'Ferme Démo Thiès',
        region: 'Thiès',
        ownerId: 'usr_99',
        isDemo: true,
        createdAt: created,
        updatedAt: updated,
      );

      final map = farm.toMap();
      expect(map['id'], 'farm_full');
      expect(map['name'], 'Ferme Démo Thiès');
      expect(map['region'], 'Thiès');
      expect(map['ownerId'], 'usr_99');
      expect(map['isDemo'], isTrue);
      expect(map['createdAt'], created.toIso8601String());
      expect(map['updatedAt'], updated.toIso8601String());

      final restored = Farm.fromMap(map);
      expect(restored, farm);
      expect(restored.hashCode, farm.hashCode);
    });

    test(
        'Farm.fromMap handles legacy map with missing optional fields without throwing',
        () {
      final minimalMap = {
        'id': 'farm_min',
        'name': 'Ferme Locale Minimale',
      };

      final farm = Farm.fromMap(minimalMap);
      expect(farm.id, 'farm_min');
      expect(farm.name, 'Ferme Locale Minimale');
      expect(farm.region, isNull);
      expect(farm.ownerId, isNull);
      expect(farm.isDemo, isFalse);
      expect(farm.createdAt, isA<DateTime>());
      expect(farm.updatedAt, isNull);
    });

    test('Farm.fromMap throws FormatException when id or name is invalid', () {
      expect(() => Farm.fromMap({'id': '', 'name': 'Valide'}),
          throwsFormatException);
      expect(() => Farm.fromMap({'id': null, 'name': 'Valide'}),
          throwsFormatException);
      expect(
          () => Farm.fromMap({'id': 'f1', 'name': ''}), throwsFormatException);
      expect(() => Farm.fromMap({'id': 'f1', 'name': '   '}),
          throwsFormatException);
      expect(() => Farm.fromMap({'id': 'f1', 'name': null}),
          throwsFormatException);
    });

    test('Farm equality and inequality', () {
      final f1 = Farm(
        id: 'f_eq',
        name: 'Ferme',
        createdAt: DateTime(2026, 1, 1),
      );
      final f2 = Farm(
        id: 'f_eq',
        name: 'Ferme',
        createdAt: DateTime(2026, 1, 1),
      );
      final f3 = f1.copyWith(name: 'Autre');

      expect(f1, equals(f2));
      expect(f1 == f3, isFalse);
    });
  });

  group('UserProfile Model Tests', () {
    test('UserRole labels and fromString fallback behavior', () {
      expect(UserRole.owner.label, 'Propriétaire');
      expect(UserRole.manager.label, 'Gestionnaire');
      expect(UserRole.worker.label, 'Éleveur / Ouvrier');

      expect(UserRole.fromString('owner'), UserRole.owner);
      expect(UserRole.fromString('manager'), UserRole.manager);
      expect(UserRole.fromString('worker'), UserRole.worker);

      // Case insensitivity
      expect(UserRole.fromString('OWNER'), UserRole.owner);
      expect(UserRole.fromString('Manager'), UserRole.manager);

      // Null or invalid defaults to owner
      expect(UserRole.fromString(null), UserRole.owner);
      expect(UserRole.fromString('superadmin_inexistant'), UserRole.owner);
    });

    test('UserProfile instantiation and defaults', () {
      final created = DateTime(2026, 1, 1);
      final profile = UserProfile(
        id: 'usr_abc',
        email: 'amadou@agritrack.sn',
        fullName: 'Amadou Sow',
        createdAt: created,
      );

      expect(profile.id, 'usr_abc');
      expect(profile.email, 'amadou@agritrack.sn');
      expect(profile.fullName, 'Amadou Sow');
      expect(profile.phoneNumber, isNull);
      expect(profile.role, UserRole.owner);
      expect(profile.createdAt, created);
      expect(profile.updatedAt, isNull);
    });

    test('UserProfile copyWith updates immutably', () {
      final profile = UserProfile(
        id: 'usr_xyz',
        email: 'fatou@agritrack.sn',
        fullName: 'Fatou Diallo',
        createdAt: DateTime(2026, 1, 1),
      );

      final updated = profile.copyWith(
        fullName: 'Fatou Diallo Ba',
        phoneNumber: '+221770000000',
        role: UserRole.manager,
        updatedAt: DateTime(2026, 3, 1),
      );

      expect(updated.id, profile.id);
      expect(updated.fullName, 'Fatou Diallo Ba');
      expect(updated.phoneNumber, '+221770000000');
      expect(updated.role, UserRole.manager);
      expect(updated.updatedAt, DateTime(2026, 3, 1));
      expect(profile.fullName, 'Fatou Diallo');
      expect(profile.phoneNumber, isNull);
    });

    test('UserProfile serialization roundtrip toMap and fromMap', () {
      final created = DateTime(2026, 2, 1, 9, 30);
      final updated = DateTime(2026, 2, 5, 15, 0);
      final profile = UserProfile(
        id: 'usr_roundtrip',
        email: 'cheikh@agritrack.sn',
        fullName: 'Cheikh Ndiaye',
        phoneNumber: '+221761112233',
        role: UserRole.worker,
        createdAt: created,
        updatedAt: updated,
      );

      final map = profile.toMap();
      expect(map['id'], 'usr_roundtrip');
      expect(map['email'], 'cheikh@agritrack.sn');
      expect(map['fullName'], 'Cheikh Ndiaye');
      expect(map['phoneNumber'], '+221761112233');
      expect(map['role'], 'worker');
      expect(map['createdAt'], created.toIso8601String());
      expect(map['updatedAt'], updated.toIso8601String());

      final restored = UserProfile.fromMap(map);
      expect(restored, profile);
      expect(restored.hashCode, profile.hashCode);
    });

    test('UserProfile.fromMap handles missing optional fields safely', () {
      final map = {
        'id': 'usr_min',
        'email': 'min@agritrack.sn',
      };

      final profile = UserProfile.fromMap(map);
      expect(profile.id, 'usr_min');
      expect(profile.email, 'min@agritrack.sn');
      expect(profile.fullName, 'Éleveur'); // Safe fallback
      expect(profile.phoneNumber, isNull);
      expect(profile.role, UserRole.owner);
      expect(profile.createdAt, isA<DateTime>());
      expect(profile.updatedAt, isNull);
    });

    test(
        'UserProfile.fromMap throws FormatException when id or email is missing',
        () {
      expect(() => UserProfile.fromMap({'id': '', 'email': 'valid@test.com'}),
          throwsFormatException);
      expect(() => UserProfile.fromMap({'id': null, 'email': 'valid@test.com'}),
          throwsFormatException);
      expect(() => UserProfile.fromMap({'id': 'u1', 'email': ''}),
          throwsFormatException);
      expect(() => UserProfile.fromMap({'id': 'u1', 'email': '   '}),
          throwsFormatException);
      expect(() => UserProfile.fromMap({'id': 'u1', 'email': null}),
          throwsFormatException);
    });

    test('UserProfile equality and inequality', () {
      final p1 = UserProfile(
        id: 'p_eq',
        email: 'p@test.com',
        fullName: 'User P',
        createdAt: DateTime(2026, 1, 1),
      );
      final p2 = UserProfile(
        id: 'p_eq',
        email: 'p@test.com',
        fullName: 'User P',
        createdAt: DateTime(2026, 1, 1),
      );
      final p3 = p1.copyWith(role: UserRole.manager);

      expect(p1, equals(p2));
      expect(p1 == p3, isFalse);
    });
  });

  group('SyncStatus & Synchronization Fields Tests', () {
    test('SyncStatus enum properties and fromString behavior', () {
      expect(SyncStatus.synced.label, 'Synchronisé');
      expect(SyncStatus.pendingCreate.label, 'Création en attente');
      expect(SyncStatus.pendingUpdate.label, 'Mise à jour en attente');
      expect(SyncStatus.pendingDelete.label, 'Suppression en attente');
      expect(SyncStatus.error.label, 'Erreur de synchronisation');

      expect(SyncStatus.synced.isSynced, isTrue);
      expect(SyncStatus.synced.isPending, isFalse);
      expect(SyncStatus.pendingCreate.isPending, isTrue);
      expect(SyncStatus.pendingUpdate.isPending, isTrue);
      expect(SyncStatus.pendingDelete.isPending, isTrue);
      expect(SyncStatus.error.isPending, isFalse);

      expect(SyncStatus.fromString('synced'), SyncStatus.synced);
      expect(SyncStatus.fromString('pendingCreate'), SyncStatus.pendingCreate);
      expect(SyncStatus.fromString('pendingUpdate'), SyncStatus.pendingUpdate);
      expect(SyncStatus.fromString('pendingDelete'), SyncStatus.pendingDelete);
      expect(SyncStatus.fromString('error'), SyncStatus.error);
      expect(SyncStatus.fromString(null), SyncStatus.synced);
      expect(SyncStatus.fromString('unknown_status'), SyncStatus.synced);
    });

    test('HealthStatus conversion for PostgreSQL Supabase', () {
      expect(HealthStatus.sain.toSupabaseValue(), 'sain');
      expect(HealthStatus.aSurveiller.toSupabaseValue(), 'a_surveiller');
      expect(HealthStatus.malade.toSupabaseValue(), 'malade');

      expect(HealthStatus.fromSupabaseValue('sain'), HealthStatus.sain);
      expect(HealthStatus.fromSupabaseValue('a_surveiller'),
          HealthStatus.aSurveiller);
      expect(HealthStatus.fromSupabaseValue('malade'), HealthStatus.malade);
      expect(
        () => HealthStatus.fromSupabaseValue('inconnu'),
        throwsA(isA<FormatException>()),
      );
    });

    test(
        'Animal retrocompatibility: fromMap handles legacy maps without sync fields',
        () {
      final legacyMap = {
        'id': 'a001',
        'name': 'Bakary',
        'type': 'bovin',
        'ageMonths': 36,
        'weightKg': 320.0,
        'healthStatus': 'sain',
        'createdAt': '2026-01-15T00:00:00.000',
      };

      final animal = Animal.fromMap(legacyMap);
      expect(animal.id, 'a001');
      expect(animal.remoteId, isNull);
      expect(animal.syncStatus, SyncStatus.synced);
      expect(animal.farmId, 'local_default_farm');
    });

    test('Animal toMap and fromMap with remoteId and syncStatus', () {
      final animal = Animal(
        id: 'anim_sync_test',
        remoteId: 'uuid-1234-5678',
        syncStatus: SyncStatus.pendingUpdate,
        name: 'Taureau Alpha',
        type: AnimalType.bovin,
        ageMonths: 20,
        weightKg: 310.0,
        healthStatus: HealthStatus.aSurveiller,
        expenses: const [],
        createdAt: DateTime(2026, 2, 1),
      );

      final map = animal.toMap();
      expect(map['remoteId'], 'uuid-1234-5678');
      expect(map['syncStatus'], 'pendingUpdate');

      final reconstructed = Animal.fromMap(map);
      expect(reconstructed.id, 'anim_sync_test');
      expect(reconstructed.remoteId, 'uuid-1234-5678');
      expect(reconstructed.syncStatus, SyncStatus.pendingUpdate);
      expect(reconstructed.healthStatus, HealthStatus.aSurveiller);
    });

    test(
        'Animal toSupabaseMap produces SQL-compliant payload with converted healthStatus',
        () {
      final animal = Animal(
        id: 'a002',
        remoteId: 'remote-uuid-002',
        name: 'Fanta',
        type: AnimalType.bovin,
        ageMonths: 24,
        weightKg: 265.0,
        healthStatus: HealthStatus.aSurveiller,
        expenses: const [],
        createdAt: DateTime(2026, 3, 22),
      );

      final supabasePayload =
          animal.toSupabaseMap(remoteFarmId: 'farm-uuid-999');
      expect(supabasePayload['id'], 'remote-uuid-002');
      expect(supabasePayload['farm_id'], 'farm-uuid-999');
      expect(supabasePayload['local_id'], 'a002');
      expect(supabasePayload['name'], 'Fanta');
      expect(supabasePayload['type'], 'bovin');
      expect(supabasePayload['age_months'], 24);
      expect(supabasePayload['weight_kg'], 265.0);
      expect(supabasePayload['health_status'],
          'a_surveiller'); // Explicitement converti
      expect(supabasePayload['is_demo'], isFalse);
    });

    test('Animal fromSupabaseMap accurately reconstructs Animal model', () {
      final supabaseRecord = {
        'id': 'remote-uuid-42',
        'farm_id': 'farm-uuid-1',
        'local_id': 'local-42',
        'name': 'Djata',
        'type': 'bovin',
        'age_months': 8,
        'weight_kg': 115.0,
        'health_status': 'a_surveiller',
        'is_demo': false,
        'created_at': '2026-09-15T00:00:00.000Z',
      };

      final animal = Animal.fromSupabaseMap(supabaseRecord);
      expect(animal.id, 'local-42');
      expect(animal.remoteId, 'remote-uuid-42');
      expect(animal.farmId, 'farm-uuid-1');
      expect(animal.healthStatus, HealthStatus.aSurveiller);
      expect(animal.syncStatus, SyncStatus.synced);
    });

    test(
        'Expense retrocompatibility: fromMap handles legacy maps without sync fields',
        () {
      final legacyMap = {
        'id': 'e001',
        'label': 'Foin 50kg',
        'amount': 8500.0,
        'date': '2026-10-01T00:00:00.000',
        'category': 'alimentation',
      };

      final expense = Expense.fromMap(legacyMap);
      expect(expense.id, 'e001');
      expect(expense.remoteId, isNull);
      expect(expense.syncStatus, SyncStatus.synced);
    });

    test('Expense toMap and fromMap with remoteId and syncStatus', () {
      final expense = Expense(
        id: 'e_test_sync',
        remoteId: 'exp-remote-uuid',
        syncStatus: SyncStatus.pendingCreate,
        label: 'Vermifuge',
        amount: 4500,
        date: DateTime(2026, 9, 10),
        category: ExpenseCategory.sante,
      );

      final map = expense.toMap();
      expect(map['remoteId'], 'exp-remote-uuid');
      expect(map['syncStatus'], 'pendingCreate');

      final reconstructed = Expense.fromMap(map);
      expect(reconstructed, expense);
      expect(reconstructed.remoteId, 'exp-remote-uuid');
      expect(reconstructed.syncStatus, SyncStatus.pendingCreate);
    });

    test('Expense toSupabaseMap produces SQL-compliant payload', () {
      final expense = Expense(
        id: 'e010',
        remoteId: 'exp-uuid-10',
        label: 'Vaccin PPR',
        amount: 3500,
        date: DateTime(2026, 8, 20),
        category: ExpenseCategory.sante,
      );

      final payload = expense.toSupabaseMap(
        remoteFarmId: 'farm-uuid-1',
        remoteAnimalId: 'animal-uuid-4',
      );

      expect(payload['id'], 'exp-uuid-10');
      expect(payload['farm_id'], 'farm-uuid-1');
      expect(payload['animal_id'], 'animal-uuid-4');
      expect(payload['local_id'], 'e010');
      expect(payload['label'], 'Vaccin PPR');
      expect(payload['amount'], 3500.0);
      expect(payload['category'], 'sante');
    });

    test('Expense fromSupabaseMap accurately reconstructs Expense model', () {
      final record = {
        'id': 'exp-server-uuid',
        'local_id': 'e020',
        'farm_id': 'farm-uuid-1',
        'animal_id': 'animal-uuid-10',
        'label': 'Aliment pondeuse',
        'amount': 5200.0,
        'date': '2026-10-01T00:00:00.000Z',
        'category': 'alimentation',
      };

      final expense = Expense.fromSupabaseMap(record);
      expect(expense.id, 'e020');
      expect(expense.remoteId, 'exp-server-uuid');
      expect(expense.animalId, 'animal-uuid-10');
      expect(expense.farmId, 'farm-uuid-1');
      expect(expense.category, ExpenseCategory.alimentation);
      expect(expense.syncStatus, SyncStatus.synced);
    });
  });

  group('Optimistic Concurrency & Conflict Model Tests', () {
    test('Animal versionId defaults to 1 and is preserved via copyWith, toMap, fromMap', () {
      final animal = Animal(
        id: 'anim_v1',
        name: 'Sahel',
        type: AnimalType.bovin,
        ageMonths: 24,
        weightKg: 280.0,
        healthStatus: HealthStatus.sain,
        expenses: const [],
        createdAt: DateTime(2026, 1, 1),
      );

      expect(animal.versionId, 1);

      final updated = animal.copyWith(versionId: 5);
      expect(updated.versionId, 5);

      final map = updated.toMap();
      expect(map['versionId'], 5);

      final fromMapAnimal = Animal.fromMap(map);
      expect(fromMapAnimal.versionId, 5);

      // Compatibilité données historiques sans versionId
      final legacyMap = Map<String, dynamic>.from(map)..remove('versionId');
      final legacyAnimal = Animal.fromMap(legacyMap);
      expect(legacyAnimal.versionId, 1);

      // Supabase serialization
      final supaMap = updated.toSupabaseMap(remoteFarmId: 'farm-123');
      expect(supaMap['version_id'], 5);

      final fromSupa = Animal.fromSupabaseMap({
        'id': 'remote-1',
        'local_id': 'anim_v1',
        'farm_id': 'farm-123',
        'name': 'Sahel',
        'type': 'bovin',
        'age_months': 24,
        'weight_kg': 280.0,
        'health_status': 'sain',
        'created_at': '2026-01-01T00:00:00.000Z',
        'version_id': 8,
      });
      expect(fromSupa.versionId, 8);
    });

    test('Expense versionId defaults to 1 and is preserved via copyWith, toMap, fromMap', () {
      final expense = Expense(
        id: 'exp_v1',
        label: 'Aliment',
        amount: 5000,
        date: DateTime(2026, 1, 1),
        category: ExpenseCategory.alimentation,
      );

      expect(expense.versionId, 1);

      final updated = expense.copyWith(versionId: 3);
      expect(updated.versionId, 3);

      final map = updated.toMap();
      expect(map['versionId'], 3);

      final fromMapExpense = Expense.fromMap(map);
      expect(fromMapExpense.versionId, 3);

      // Compatibilité données historiques sans versionId
      final legacyMap = Map<String, dynamic>.from(map)..remove('versionId');
      final legacyExpense = Expense.fromMap(legacyMap);
      expect(legacyExpense.versionId, 1);

      // Supabase serialization
      final supaMap = updated.toSupabaseMap(remoteFarmId: 'farm-123', remoteAnimalId: 'anim-123');
      expect(supaMap['version_id'], 3);

      final fromSupa = Expense.fromSupabaseMap({
        'id': 'exp-remote-1',
        'local_id': 'exp_v1',
        'farm_id': 'farm-123',
        'animal_id': 'anim-123',
        'label': 'Aliment',
        'amount': 5000.0,
        'date': '2026-01-01T00:00:00.000Z',
        'category': 'alimentation',
        'version_id': 6,
      });
      expect(fromSupa.versionId, 6);
    });

    test('SyncConflict model serialization roundtrip', () {
      final conflict = SyncConflict(
        id: 'conf_123',
        farmId: 'farm_alpha',
        operationId: 'op_abc',
        entityType: SyncEntityType.animal,
        localId: 'anim_local_99',
        remoteId: 'remote-uuid-99',
        expectedVersion: 1,
        serverVersion: 3,
        localPayload: {'name': 'Local Name', 'weightKg': 300.0},
        serverData: {'name': 'Server Name', 'weightKg': 320.0},
        createdAt: DateTime(2026, 10, 27, 10, 0, 0),
        resolved: false,
      );

      final map = conflict.toMap();
      expect(map['id'], 'conf_123');
      expect(map['farmId'], 'farm_alpha');
      expect(map['entityType'], 'animal');
      expect(map['localId'], 'anim_local_99');
      expect(map['serverVersion'], 3);
      expect(map['resolved'], isFalse);

      final restored = SyncConflict.fromMap(map);
      expect(restored.id, conflict.id);
      expect(restored.farmId, conflict.farmId);
      expect(restored.entityType, SyncEntityType.animal);
      expect(restored.localId, conflict.localId);
      expect(restored.remoteId, conflict.remoteId);
      expect(restored.expectedVersion, 1);
      expect(restored.serverVersion, 3);
      expect(restored.localPayload['name'], 'Local Name');
      expect(restored.serverData?['name'], 'Server Name');
      expect(restored.resolved, isFalse);

      final resolvedConflict = restored.copyWith(
        resolved: true,
        resolvedAt: DateTime(2026, 10, 27, 11, 0, 0),
        resolutionStrategy: 'keep_server',
      );
      expect(resolvedConflict.resolved, isTrue);
      expect(resolvedConflict.resolutionStrategy, 'keep_server');
    });
  });
}
