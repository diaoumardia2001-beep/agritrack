// lib/screens/animal_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/animal.dart';
import '../models/expense.dart';
import '../providers/active_farm_provider.dart';
import '../providers/animals_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/agri_card.dart';
import '../widgets/agri_icon_container.dart';
import '../widgets/health_status_badge.dart';
import '../widgets/species_avatar.dart';
import 'add_animal_screen.dart';

class AnimalDetailScreen extends ConsumerWidget {
  final Animal animal;

  const AnimalDetailScreen({super.key, required this.animal});

  static const _frenchMonths = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  static const _frenchMonthsShort = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];

  static String _formatFrenchDate(DateTime date, {bool short = false}) {
    final m = short
        ? _frenchMonthsShort[date.month - 1]
        : _frenchMonths[date.month - 1];
    return '${date.day} $m ${date.year}';
  }

  void _showAddExpenseDialog(BuildContext context, Animal animal) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddExpenseDialog(animal: animal),
    );
  }

  Future<void> _confirmDeleteAnimal(
    BuildContext context,
    WidgetRef ref,
    Animal animal,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text(
          'Voulez-vous vraiment supprimer "${animal.name}" ?\nL\'animal sera archivé en attente de synchronisation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(animalsNotifierProvider.notifier)
            .deleteAnimal(animal.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${animal.name} a été supprimé.'),
              backgroundColor: Colors.red.shade700,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveAnimal = ref.watch(animalByIdProvider(animal.id));
    final currentAnimal = liveAnimal ?? animal;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final speciesColor = AppColors.forSpecies(currentAnimal.type);
    final canDelete = ref.watch(activeFarmProvider).canDeleteAnimal;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpenseDialog(context, currentAnimal),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter une dépense'),
        elevation: 4,
        backgroundColor:
            isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
        foregroundColor: Colors.white,
      ),
      body: CustomScrollView(
        slivers: [
          // ─── En-tête AppBar moderne avec actions ───────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor:
                isDark ? AppColors.darkSurface : AppColors.lightSurface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: const BackButton(),
            actions: [
              IconButton(
                tooltip: 'Modifier l\'animal',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        AddAnimalScreen(animalToEdit: currentAnimal),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Ajouter une dépense',
                icon: const Icon(Icons.add_card_rounded),
                onPressed: () => _showAddExpenseDialog(context, currentAnimal),
              ),
              if (canDelete)
                IconButton(
                  tooltip: 'Supprimer l\'animal',
                  icon:
                      const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () =>
                      _confirmDeleteAnimal(context, ref, currentAnimal),
                ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.only(left: 56, right: 112, bottom: 12),
              title: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SpeciesAvatar(
                      type: currentAnimal.type,
                      imageUrl: currentAnimal.imageUrl,
                      size: 26,
                      borderRadius: 8,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currentAnimal.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Contenu principal centré ──────────────────────────────
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Profil complet de l'animal
                      _buildProfileCard(
                          currentAnimal, theme, isDark, speciesColor),
                      const SizedBox(height: 16),

                      // 2. Grille d'informations physiques
                      _buildInfoGrid(
                          currentAnimal, theme, isDark, speciesColor),
                      const SizedBox(height: 16),

                      // 3. Résumé financier
                      _buildFinancialSummary(currentAnimal, theme, isDark),
                      const SizedBox(height: 24),

                      // 4. Historique des dépenses
                      _buildExpensesSection(
                          context, currentAnimal, theme, isDark),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Profil : Avatar, Nom, Espèce, Statut & Identifiant ───────────
  Widget _buildProfileCard(
    Animal animal,
    ThemeData theme,
    bool isDark,
    Color speciesColor,
  ) {
    return AgriCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 18,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar vectoriel généreux ou photo
          SpeciesAvatar(
            type: animal.type,
            imageUrl: animal.imageUrl,
            size: 64,
            borderRadius: 18,
          ),
          const SizedBox(width: 16),

          // Identité complète
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        animal.name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    HealthStatusBadge(status: animal.healthStatus),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: speciesColor.withValues(
                            alpha: isDark ? 0.22 : 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        animal.type.label,
                        style: TextStyle(
                          color: speciesColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ID: ${animal.id}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.event_note_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Enregistré le ${_formatFrenchDate(animal.createdAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Grille des informations physiques ────────────────────────────
  Widget _buildInfoGrid(
    Animal animal,
    ThemeData theme,
    bool isDark,
    Color speciesColor,
  ) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            icon: Icons.monitor_weight_outlined,
            label: 'Poids',
            value: '${animal.weightKg} kg',
            color: const Color(0xFFD97706),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            icon: Icons.calendar_today_outlined,
            label: 'Âge',
            value: _formatAge(animal.ageMonths),
            color: const Color(0xFF0284C7),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            icon: Icons.health_and_safety_outlined,
            label: 'Santé',
            value: animal.healthStatus.label,
            color: animal.healthStatus == HealthStatus.sain
                ? const Color(0xFF16A34A)
                : (animal.healthStatus == HealthStatus.aSurveiller
                    ? const Color(0xFFD97706)
                    : const Color(0xFFDC2626)),
          ),
        ),
      ],
    );
  }

  // ─── Résumé financier ─────────────────────────────────────────────
  Widget _buildFinancialSummary(
    Animal animal,
    ThemeData theme,
    bool isDark,
  ) {
    final totalExp = animal.totalExpenses;
    final monthlyExp = animal.monthlyExpenses;

    return AgriCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AgriIconContainer(
                icon: Icons.account_balance_wallet_outlined,
                color: Color(0xFF0284C7),
                size: 36,
                iconSize: 18,
                borderRadius: 10,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Résumé financier',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Suivi des investissements et soins dédiés',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _FinanceKpiTile(
                  label: 'Dépenses cumulées',
                  value: _formatTotalExpenses(totalExp),
                  subtitle: '${_formatExpenseAmount(totalExp)} total',
                  color: const Color(0xFF0284C7),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FinanceKpiTile(
                  label: 'Ce mois-ci',
                  value: _formatTotalExpenses(monthlyExp),
                  subtitle: 'Mois en cours',
                  color: const Color(0xFF16A34A),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FinanceKpiTile(
                  label: 'Actes enregistrés',
                  value: '${animal.activeExpenses.length}',
                  subtitle: animal.activeExpenses.isEmpty
                      ? 'Aucun'
                      : (animal.activeExpenses.length > 1
                          ? 'opérations'
                          : 'opération'),
                  color: const Color(0xFFD97706),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Section Historique des dépenses ──────────────────────────────
  Widget _buildExpensesSection(
    BuildContext context,
    Animal animal,
    ThemeData theme,
    bool isDark,
  ) {
    final sortedExpenses = [...animal.activeExpenses]
      ..sort((a, b) => b.date.compareTo(a.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Historique des dépenses',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _showAddExpenseDialog(context, animal),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (animal.activeExpenses.isEmpty)
          AgriCard(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            borderRadius: 16,
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 44,
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Aucune dépense enregistrée.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () => _showAddExpenseDialog(context, animal),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Enregistrer une première dépense'),
                  ),
                ],
              ),
            ),
          )
        else
          ...sortedExpenses.map(
            (expense) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ExpenseTile(
                expense: expense,
              ),
            ),
          ),
      ],
    );
  }

  static String _formatAge(int months) {
    if (months >= 12) {
      final years = months ~/ 12;
      final rem = months % 12;
      return rem == 0 ? '$years an${years > 1 ? 's' : ''}' : '$years a $rem m';
    }
    return '$months mois';
  }

  static String _formatTotalExpenses(double amount) {
    if (amount >= 1000) {
      final k = (amount / 1000).toStringAsFixed(0);
      return '${k}k FCFA';
    }
    return '${amount.toStringAsFixed(0)} FCFA';
  }
}

// ─── Carte métrique d'information physique ──────────────────────────────────
class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color:
            isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
        ),
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
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tuile KPI du résumé financier ──────────────────────────────────────────
class _FinanceKpiTile extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final Color color;

  const _FinanceKpiTile({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:
            isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Tuile d'une dépense individuelle ───────────────────────────────────────
class _ExpenseTile extends StatelessWidget {
  final Expense expense;

  const _ExpenseTile({
    required this.expense,
  });

  IconData _categoryIcon() {
    switch (expense.category) {
      case ExpenseCategory.alimentation:
        return Icons.grass_rounded;
      case ExpenseCategory.sante:
        return Icons.medical_services_outlined;
      case ExpenseCategory.autre:
        return Icons.inventory_2_outlined;
    }
  }

  Color _categoryColor() {
    switch (expense.category) {
      case ExpenseCategory.alimentation:
        return const Color(0xFF16A34A);
      case ExpenseCategory.sante:
        return const Color(0xFF0284C7);
      case ExpenseCategory.autre:
        return const Color(0xFFD97706);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final catColor = _categoryColor();
    final catIcon = _categoryIcon();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
        ),
      ),
      child: Row(
        children: [
          AgriIconContainer(
            icon: catIcon,
            color: catColor,
            size: 40,
            iconSize: 20,
            borderRadius: 10,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${expense.category.label} • ${AnimalDetailScreen._formatFrenchDate(expense.date, short: true)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _formatExpenseAmount(expense.amount),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: catColor,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatExpenseAmount(double amount) {
  final hasDecimals = (amount % 1) != 0;
  final formatter = NumberFormat.currency(
    locale: 'fr_CI',
    symbol: 'FCFA',
    decimalDigits: hasDecimals ? 2 : 0,
  );
  return formatter.format(amount);
}

// ─── Modal / Dialog d'ajout d'une dépense ───────────────────────────────────
class _AddExpenseDialog extends ConsumerStatefulWidget {
  final Animal animal;

  const _AddExpenseDialog({required this.animal});

  @override
  ConsumerState<_AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends ConsumerState<_AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _amountController = TextEditingController();

  ExpenseCategory _selectedCategory = ExpenseCategory.alimentation;
  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _labelController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5),
      locale: const Locale('fr', 'CI'),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final rawAmount = _amountController.text.trim().replaceAll(',', '.');
    final amount = double.parse(rawAmount);
    final label = _labelController.text.trim();

    final newExpense = Expense(
      id: '',
      label: label,
      amount: amount,
      date: _selectedDate,
      category: _selectedCategory,
    );

    try {
      await ref.read(animalsNotifierProvider.notifier).addExpense(
            animalId: widget.animal.id,
            expense: newExpense,
          );

      if (mounted) {
        setState(() => _isSubmitting = false);
        Navigator.of(context).pop();
        final formattedAmount = _formatExpenseAmount(amount);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Dépense "$label" de $formattedAmount enregistrée !',
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'enregistrement : $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── Header ──────────────────────────────────────
                  Row(
                    children: [
                      AgriIconContainer(
                        icon: Icons.receipt_long_rounded,
                        color: isDark
                            ? AppColors.darkPrimary
                            : AppColors.lightPrimary,
                        size: 40,
                        iconSize: 20,
                        borderRadius: 12,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ajouter une dépense',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Pour ${widget.animal.name} (${widget.animal.type.label})',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        tooltip: 'Fermer',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ─── Libellé ─────────────────────────────────────
                  Text(
                    'Libellé de la dépense',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _labelController,
                    textCapitalization: TextCapitalization.sentences,
                    enabled: !_isSubmitting,
                    decoration: InputDecoration(
                      hintText: 'ex. Vaccination, Achat d\'aliments',
                      prefixIcon: const Icon(Icons.edit_note_rounded),
                      filled: true,
                      fillColor: isDark
                          ? AppColors.darkSurfaceSubtle
                          : AppColors.lightSurfaceSubtle,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark
                              ? AppColors.darkCardBorder
                              : AppColors.lightCardBorder,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark
                              ? AppColors.darkCardBorder
                              : AppColors.lightCardBorder,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Veuillez saisir un libellé';
                      }
                      if (v.trim().length < 2) {
                        return 'Le libellé doit comporter au moins 2 caractères';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ─── Montant en FCFA ─────────────────────────────
                  Text(
                    'Montant (FCFA)',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    enabled: !_isSubmitting,
                    decoration: InputDecoration(
                      hintText: 'ex. 7500',
                      prefixIcon: const Icon(Icons.payments_outlined),
                      suffixText: 'FCFA',
                      filled: true,
                      fillColor: isDark
                          ? AppColors.darkSurfaceSubtle
                          : AppColors.lightSurfaceSubtle,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark
                              ? AppColors.darkCardBorder
                              : AppColors.lightCardBorder,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark
                              ? AppColors.darkCardBorder
                              : AppColors.lightCardBorder,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Veuillez saisir un montant';
                      }
                      final cleaned = v.trim().replaceAll(',', '.');
                      final amount = double.tryParse(cleaned);
                      if (amount == null || !amount.isFinite) {
                        return 'Veuillez saisir un montant numérique valide';
                      }
                      if (amount <= 0) {
                        return 'Le montant doit être strictement supérieur à 0';
                      }
                      if (amount > 100000000) {
                        return 'Montant trop élevé (max 100 000 000 FCFA)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ─── Catégorie ───────────────────────────────────
                  Text(
                    'Catégorie',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: ExpenseCategory.values.map((cat) {
                      final selected = _selectedCategory == cat;
                      return ChoiceChip(
                        label: Text('${cat.emoji} ${cat.label}'),
                        selected: selected,
                        onSelected: _isSubmitting
                            ? null
                            : (_) => setState(() => _selectedCategory = cat),
                        selectedColor: (isDark
                                ? AppColors.darkPrimary
                                : AppColors.lightPrimary)
                            .withValues(alpha: 0.25),
                        labelStyle: TextStyle(
                          color: selected
                              ? (isDark
                                  ? AppColors.darkPrimary
                                  : AppColors.lightPrimary)
                              : theme.colorScheme.onSurface,
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: selected
                                ? (isDark
                                    ? AppColors.darkPrimary
                                    : AppColors.lightPrimary)
                                : (isDark
                                    ? AppColors.darkCardBorder
                                    : AppColors.lightCardBorder),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // ─── Date ────────────────────────────────────────
                  Text(
                    'Date de la dépense',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _isSubmitting ? null : _pickDate,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurfaceSubtle
                            : AppColors.lightSurfaceSubtle,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkCardBorder
                              : AppColors.lightCardBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                            color: isDark
                                ? AppColors.darkPrimary
                                : AppColors.lightPrimary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              AnimalDetailScreen._formatFrenchDate(
                                  _selectedDate),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            'Modifier',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkPrimary
                                  : AppColors.lightPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ─── Actions ─────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _isSubmitting ? null : _submit,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check, size: 18),
                        label: Text(_isSubmitting
                            ? 'Enregistrement...'
                            : 'Enregistrer'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
