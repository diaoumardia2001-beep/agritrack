// lib/screens/animal_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/animal.dart';
import '../models/expense.dart';
import '../widgets/health_status_badge.dart';

class AnimalDetailScreen extends StatelessWidget {
  final Animal animal;

  const AnimalDetailScreen({super.key, required this.animal});

  Color _typeColor(AnimalType type) {
    switch (type) {
      case AnimalType.bovin:
        return const Color(0xFF5D4037);
      case AnimalType.caprin:
        return const Color(0xFF558B2F);
      case AnimalType.ovin:
        return const Color(0xFF1565C0);
      case AnimalType.volaille:
        return const Color(0xFFF57F17);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _typeColor(animal.type);
    final dateFormat = DateFormat('dd MMM yyyy', 'fr_FR');
    final currencyFmt = NumberFormat.currency(
      locale: 'fr_CI',
      symbol: 'FCFA',
      decimalDigits: 0,
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ─── Hero App Bar ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: color,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                animal.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black38,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color.withValues(alpha: 0.7), color],
                  ),
                ),
                child: Center(
                  child: Hero(
                    tag: 'animal-avatar-${animal.id}',
                    child: Text(
                      animal.type.emoji,
                      style: const TextStyle(fontSize: 90),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ─── Content ───────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ─── Type + Health badge ─────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${animal.type.emoji} ${animal.type.label}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    HealthStatusBadge(status: animal.healthStatus),
                  ],
                ),
                const SizedBox(height: 20),

                // ─── Info Cards ──────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.monitor_weight_outlined,
                        label: 'Poids',
                        value: '${animal.weightKg} kg',
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.calendar_today_outlined,
                        label: 'Âge',
                        value: _formatAge(animal.ageMonths),
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Dépenses',
                        value: '${(animal.totalExpenses / 1000).toStringAsFixed(0)}k FCFA',
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ─── Date d'enregistrement ───────────────────────
                Row(
                  children: [
                    Icon(Icons.event_note_outlined,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      'Enregistré le ${dateFormat.format(animal.createdAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ─── Expenses history ────────────────────────────
                Text(
                  'Historique des dépenses',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                if (animal.expenses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'Aucune dépense enregistrée.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  ...animal.expenses.map((expense) => _ExpenseTile(
                        expense: expense,
                        formatter: currencyFmt,
                        dateFormat: dateFormat,
                      )),
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAge(int months) {
    if (months >= 12) {
      final years = months ~/ 12;
      final rem = months % 12;
      return rem == 0 ? '$years an${years > 1 ? 's' : ''}' : '$years a $rem m';
    }
    return '$months mois';
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  final Expense expense;
  final NumberFormat formatter;
  final DateFormat dateFormat;

  const _ExpenseTile({
    required this.expense,
    required this.formatter,
    required this.dateFormat,
  });

  Color _categoryColor() {
    switch (expense.category) {
      case ExpenseCategory.alimentation:
        return const Color(0xFF2E7D32);
      case ExpenseCategory.sante:
        return const Color(0xFF1565C0);
      case ExpenseCategory.autre:
        return const Color(0xFF6A1B9A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catColor = _categoryColor();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  expense.category.emoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.label,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${expense.category.label} • ${dateFormat.format(expense.date)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              formatter.format(expense.amount),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: catColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
