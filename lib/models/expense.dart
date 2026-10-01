// lib/models/expense.dart
class Expense {
  final String id;
  final String label;
  final double amount;
  final DateTime date;
  final ExpenseCategory category;

  const Expense({
    required this.id,
    required this.label,
    required this.amount,
    required this.date,
    required this.category,
  });
}

enum ExpenseCategory {
  alimentation('Alimentation', '🌾'),
  sante('Santé', '💊'),
  autre('Autre', '📦');

  const ExpenseCategory(this.label, this.emoji);
  final String label;
  final String emoji;
}
