// lib/models/animal.dart
import 'expense.dart';

class Animal {
  final String id;
  final String name;
  final AnimalType type;
  final int ageMonths;
  final double weightKg;
  final HealthStatus healthStatus;
  final String? imageUrl;
  final List<Expense> expenses;
  final DateTime createdAt;

  const Animal({
    required this.id,
    required this.name,
    required this.type,
    required this.ageMonths,
    required this.weightKg,
    required this.healthStatus,
    this.imageUrl,
    required this.expenses,
    required this.createdAt,
  });

  Animal copyWith({
    String? id,
    String? name,
    AnimalType? type,
    int? ageMonths,
    double? weightKg,
    HealthStatus? healthStatus,
    String? imageUrl,
    List<Expense>? expenses,
    DateTime? createdAt,
  }) {
    return Animal(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      ageMonths: ageMonths ?? this.ageMonths,
      weightKg: weightKg ?? this.weightKg,
      healthStatus: healthStatus ?? this.healthStatus,
      imageUrl: imageUrl ?? this.imageUrl,
      expenses: expenses ?? this.expenses,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  double get totalExpenses =>
      expenses.fold(0.0, (sum, e) => sum + e.amount);

  double get monthlyExpenses {
    final now = DateTime.now();
    return expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .fold(0.0, (sum, e) => sum + e.amount);
  }
}

enum AnimalType {
  bovin('Bovin', '🐄'),
  caprin('Caprin', '🐐'),
  ovin('Ovin', '🐑'),
  volaille('Volaille', '🐓');

  const AnimalType(this.label, this.emoji);
  final String label;
  final String emoji;
}

enum HealthStatus {
  sain('Sain', 'sain'),
  aSurveiller('À surveiller', 'a_surveiller'),
  malade('Malade', 'malade');

  const HealthStatus(this.label, this.value);
  final String label;
  final String value;
}
