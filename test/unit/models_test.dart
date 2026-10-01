// test/unit/models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:agritrack/models/animal.dart';
import 'package:agritrack/models/expense.dart';

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
  });
}
