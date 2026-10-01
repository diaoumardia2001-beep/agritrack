// lib/screens/add_animal_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/animal.dart';
import '../models/expense.dart';
import '../providers/animals_provider.dart';

class AddAnimalScreen extends ConsumerStatefulWidget {
  const AddAnimalScreen({super.key});

  @override
  ConsumerState<AddAnimalScreen> createState() => _AddAnimalScreenState();
}

class _AddAnimalScreenState extends ConsumerState<AddAnimalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();

  AnimalType _selectedType = AnimalType.bovin;
  HealthStatus _selectedHealth = HealthStatus.sain;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final newAnimal = Animal(
      id: 'a_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      type: _selectedType,
      ageMonths: int.parse(_ageController.text.trim()),
      weightKg: double.parse(_weightController.text.trim()),
      healthStatus: _selectedHealth,
      expenses: const <Expense>[],
      createdAt: DateTime.now(),
    );

    final repo = ref.read(animalsRepositoryProvider);
    await repo.addAnimal(newAnimal);

    // Invalide le cache du provider pour forcer un rechargement
    ref.invalidate(animalsProvider);

    setState(() => _isSubmitting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 10),
              Text('${newAnimal.name} ajouté avec succès ! ${newAnimal.type.emoji}'),
            ],
          ),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ajouter un animal',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Nom ──────────────────────────────────────────────
              const _SectionLabel(label: 'Nom de l\'animal'),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDecoration(
                  context,
                  hintText: 'ex. Bakary',
                  icon: Icons.pets,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Veuillez saisir un nom';
                  }
                  if (v.trim().length < 2) {
                    return 'Le nom doit contenir au moins 2 caractères';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ─── Type ─────────────────────────────────────────────
              const _SectionLabel(label: 'Type d\'animal'),
              Wrap(
                spacing: 10,
                children: AnimalType.values.map((type) {
                  final selected = _selectedType == type;
                  return ChoiceChip(
                    label: Text('${type.emoji} ${type.label}'),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedType = type),
                    selectedColor: theme.colorScheme.primaryContainer,
                    labelStyle: TextStyle(
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                      color: selected
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // ─── Âge ──────────────────────────────────────────────
              const _SectionLabel(label: 'Âge (en mois)'),
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _inputDecoration(
                  context,
                  hintText: 'ex. 24',
                  icon: Icons.calendar_today_outlined,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Veuillez saisir l\'âge';
                  }
                  final age = int.tryParse(v.trim());
                  if (age == null || age < 0) {
                    return 'Âge invalide';
                  }
                  if (age > 300) {
                    return 'Âge trop élevé (max 300 mois)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ─── Poids ────────────────────────────────────────────
              const _SectionLabel(label: 'Poids (kg)'),
              TextFormField(
                controller: _weightController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                ],
                decoration: _inputDecoration(
                  context,
                  hintText: 'ex. 45.5',
                  icon: Icons.monitor_weight_outlined,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Veuillez saisir le poids';
                  }
                  final weight = double.tryParse(v.trim());
                  if (weight == null || weight <= 0) {
                    return 'Poids invalide';
                  }
                  if (weight > 2000) {
                    return 'Poids trop élevé (max 2000 kg)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ─── Statut santé ─────────────────────────────────────
              const _SectionLabel(label: 'État de santé'),
              Wrap(
                spacing: 10,
                children: HealthStatus.values.map((status) {
                  final selected = _selectedHealth == status;
                  Color chipColor;
                  switch (status) {
                    case HealthStatus.sain:
                      chipColor = const Color(0xFF1B5E20);
                      break;
                    case HealthStatus.aSurveiller:
                      chipColor = const Color(0xFFE65100);
                      break;
                    case HealthStatus.malade:
                      chipColor = const Color(0xFFB71C1C);
                      break;
                  }
                  return ChoiceChip(
                    label: Text(status.label),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _selectedHealth = status),
                    selectedColor: chipColor,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : theme.colorScheme.onSurface,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                  );
                }).toList(),
              ),
              const SizedBox(height: 36),

              // ─── Submit ───────────────────────────────────────────
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add_circle_outline),
                label: Text(
                  _isSubmitting ? 'Enregistrement...' : 'Ajouter l\'animal',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String hintText,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            BorderSide(color: theme.colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            BorderSide(color: theme.colorScheme.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            BorderSide(color: theme.colorScheme.error, width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
