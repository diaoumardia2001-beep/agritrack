// lib/screens/add_animal_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/animal.dart';
import '../models/expense.dart';
import '../providers/animals_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/agri_card.dart';
import '../widgets/agri_icon_container.dart';
import '../widgets/health_status_badge.dart';
import '../widgets/species_avatar.dart';

/// Écran moderne d'ajout et de modification d'un animal.
/// Propose une saisie structurée, accessible et responsive
/// avec aperçu en temps réel de la fiche avant enregistrement.
class AddAnimalScreen extends ConsumerStatefulWidget {
  final Animal? animalToEdit;

  const AddAnimalScreen({
    super.key,
    this.animalToEdit,
  });

  bool get isEditing => animalToEdit != null;

  @override
  ConsumerState<AddAnimalScreen> createState() => _AddAnimalScreenState();
}

class _AddAnimalScreenState extends ConsumerState<AddAnimalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();

  late AnimalType _selectedType;
  late HealthStatus _selectedHealth;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final toEdit = widget.animalToEdit;
    if (toEdit != null) {
      _nameController.text = toEdit.name;
      _ageController.text = toEdit.ageMonths.toString();
      _weightController.text = toEdit.weightKg.toString();
      _selectedType = toEdit.type;
      _selectedHealth = toEdit.healthStatus;
    } else {
      _selectedType = AnimalType.bovin;
      _selectedHealth = HealthStatus.sain;
    }

    _nameController.addListener(_onFieldChanged);
    _ageController.addListener(_onFieldChanged);
    _weightController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFieldChanged);
    _ageController.removeListener(_onFieldChanged);
    _weightController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final name = _nameController.text.trim();
    final ageMonths = int.parse(_ageController.text.trim());
    final weightKg = double.parse(_weightController.text.trim());

    try {
      if (widget.isEditing) {
        final current = widget.animalToEdit!;
        final updated = current.copyWith(
          name: name,
          type: _selectedType,
          ageMonths: ageMonths,
          weightKg: weightKg,
          healthStatus: _selectedHealth,
        );

        await ref.read(animalsNotifierProvider.notifier).updateAnimal(updated);

        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${updated.name} modifié avec succès ! ${updated.type.emoji}',
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1B5E20),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 3),
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        final newAnimal = Animal(
          id: 'a_${DateTime.now().microsecondsSinceEpoch}',
          name: name,
          type: _selectedType,
          ageMonths: ageMonths,
          weightKg: weightKg,
          healthStatus: _selectedHealth,
          expenses: const <Expense>[],
          createdAt: DateTime.now(),
        );

        await ref.read(animalsNotifierProvider.notifier).addAnimal(newAnimal);

        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${newAnimal.name} ajouté avec succès ! ${newAnimal.type.emoji}',
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF2E7D32),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 3),
            ),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'enregistrement : $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Modifier l\'animal' : 'Ajouter un animal',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── 1. Aperçu visuel en direct ───────────────────────────
                  _buildLivePreviewCard(theme, isDark),
                  const SizedBox(height: 20),

                  // ─── 2. Section Identification ────────────────────────────
                  AgriCard(
                    padding: const EdgeInsets.all(20),
                    borderRadius: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AgriIconContainer(
                              icon: Icons.badge_outlined,
                              color: AppColors.forSpecies(_selectedType),
                              size: 38,
                              iconSize: 20,
                              borderRadius: 10,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Identification',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Nom usuel et espèce de l\'animal',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.isEditing)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.darkSurfaceSubtle
                                      : AppColors.lightSurfaceSubtle,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDark
                                        ? AppColors.darkCardBorder
                                        : AppColors.lightCardBorder,
                                  ),
                                ),
                                child: Text(
                                  '#${widget.animalToEdit!.id}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontFamily: 'monospace',
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Nom de l'animal (Index 0 parmi les TextFormField)
                        const _FieldLabel(label: 'Nom de l\'animal *'),
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration(
                            context,
                            hintText: 'ex. Bakary',
                            icon: Icons.pets,
                            helperText: 'Nom ou numéro de marquage unique',
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
                        const SizedBox(height: 22),

                        // Espèce animale
                        const _FieldLabel(label: 'Espèce animale *'),
                        _buildSpeciesSelector(theme, isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ─── 3. Section Caractéristiques physiques ────────────────
                  AgriCard(
                    padding: const EdgeInsets.all(20),
                    borderRadius: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const AgriIconContainer(
                              icon: Icons.tune_outlined,
                              color: Color(0xFF0284C7),
                              size: 38,
                              iconSize: 20,
                              borderRadius: 10,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Caractéristiques physiques',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Âge, masse corporelle et état de santé',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Âge en mois (Index 1 parmi les TextFormField)
                        const _FieldLabel(label: 'Âge (en mois) *'),
                        TextFormField(
                          controller: _ageController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: _inputDecoration(
                            context,
                            hintText: 'ex. 24',
                            icon: Icons.calendar_today_outlined,
                            helperText: _ageHelperText(_ageController.text),
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

                        // Poids en kg (Index 2 parmi les TextFormField)
                        const _FieldLabel(label: 'Poids (kg) *'),
                        TextFormField(
                          controller: _weightController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,2}'))
                          ],
                          decoration: _inputDecoration(
                            context,
                            hintText: 'ex. 45.5',
                            icon: Icons.monitor_weight_outlined,
                            helperText: 'Poids vif en kilogrammes',
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
                        const SizedBox(height: 22),

                        // Statut sanitaire
                        const _FieldLabel(label: 'Statut sanitaire *'),
                        _buildHealthSelector(theme, isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ─── 4. Bouton de soumission ──────────────────────────────
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
                        : Icon(widget.isEditing
                            ? Icons.check_circle_outline
                            : Icons.add_circle_outline),
                    label: Text(
                      _isSubmitting
                          ? 'Enregistrement...'
                          : (widget.isEditing
                              ? 'Enregistrer les modifications'
                              : 'Ajouter l\'animal'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 54),
                      backgroundColor: isDark
                          ? AppColors.darkPrimary
                          : AppColors.lightPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Carte d'aperçu en direct ─────────────────────────────────────────────
  Widget _buildLivePreviewCard(ThemeData theme, bool isDark) {
    final typedName = _nameController.text.trim();
    final displayName = typedName.isEmpty ? 'Nom de l\'animal' : typedName;
    final speciesColor = AppColors.forSpecies(_selectedType);
    final typedWeight = _weightController.text.trim();
    final displayWeight = typedWeight.isEmpty ? '0.0 kg' : '$typedWeight kg';
    final ageFormatted = _formatAgePreview(_ageController.text.trim());

    return AgriCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Aperçu de la fiche',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkPrimaryContainer
                      : AppColors.lightPrimaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'TEMPS RÉEL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color:
                        isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SpeciesAvatar(
                type: _selectedType,
                size: 54,
                borderRadius: 14,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: typedName.isEmpty
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: speciesColor.withValues(
                                alpha: isDark ? 0.25 : 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: speciesColor.withValues(
                                  alpha: isDark ? 0.4 : 0.25),
                            ),
                          ),
                          child: Text(
                            _selectedType.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: speciesColor,
                            ),
                          ),
                        ),
                        HealthStatusBadge(
                          status: _selectedHealth,
                          compact: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Poids: $displayWeight • Âge: $ageFormatted',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Sélecteur d'espèce professionnel ──────────────────────────────────────
  Widget _buildSpeciesSelector(ThemeData theme, bool isDark) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: AnimalType.values.map((type) {
        final selected = _selectedType == type;
        final speciesColor = AppColors.forSpecies(type);

        IconData speciesIcon;
        switch (type) {
          case AnimalType.bovin:
            speciesIcon = Icons.agriculture_rounded;
            break;
          case AnimalType.caprin:
            speciesIcon = Icons.terrain_rounded;
            break;
          case AnimalType.ovin:
            speciesIcon = Icons.filter_vintage_rounded;
            break;
          case AnimalType.volaille:
            speciesIcon = Icons.egg_rounded;
            break;
        }

        return Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('species_tile_${type.name}'),
            onTap: () => setState(() => _selectedType = type),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: const BoxConstraints(minHeight: 48),
              decoration: BoxDecoration(
                color: selected
                    ? speciesColor.withValues(alpha: isDark ? 0.25 : 0.12)
                    : (isDark
                        ? AppColors.darkSurfaceSubtle
                        : AppColors.lightSurfaceSubtle),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? speciesColor
                      : (isDark
                          ? AppColors.darkCardBorder
                          : AppColors.lightCardBorder),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    speciesIcon,
                    size: 20,
                    color: selected
                        ? speciesColor
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    type.label,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                      color: selected
                          ? (isDark ? Colors.white : speciesColor)
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: speciesColor,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Sélecteur de statut sanitaire ─────────────────────────────────────────
  Widget _buildHealthSelector(ThemeData theme, bool isDark) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: HealthStatus.values.map((status) {
        final selected = _selectedHealth == status;

        Color statusColor;
        IconData statusIcon;
        switch (status) {
          case HealthStatus.sain:
            statusColor = const Color(0xFF16A34A);
            statusIcon = Icons.check_circle_outline_rounded;
            break;
          case HealthStatus.aSurveiller:
            statusColor = const Color(0xFFD97706);
            statusIcon = Icons.warning_amber_rounded;
            break;
          case HealthStatus.malade:
            statusColor = const Color(0xFFDC2626);
            statusIcon = Icons.error_outline_rounded;
            break;
        }

        return Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('health_tile_${status.name}'),
            onTap: () => setState(() => _selectedHealth = status),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: const BoxConstraints(minHeight: 48),
              decoration: BoxDecoration(
                color: selected
                    ? statusColor.withValues(alpha: isDark ? 0.25 : 0.12)
                    : (isDark
                        ? AppColors.darkSurfaceSubtle
                        : AppColors.lightSurfaceSubtle),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? statusColor
                      : (isDark
                          ? AppColors.darkCardBorder
                          : AppColors.lightCardBorder),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    statusIcon,
                    size: 18,
                    color: selected
                        ? statusColor
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    status.label,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                      color: selected
                          ? (isDark ? Colors.white : statusColor)
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: statusColor,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String hintText,
    required IconData icon,
    String? helperText,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InputDecoration(
      hintText: hintText,
      helperText: helperText,
      helperMaxLines: 2,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor:
          isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: theme.colorScheme.error,
          width: 1.5,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: theme.colorScheme.error,
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  String _ageHelperText(String text) {
    final age = int.tryParse(text.trim());
    if (age == null || age < 0) return 'Âge de l\'animal en mois révolus';
    if (age < 12) return '$age mois révolus';
    final years = age ~/ 12;
    final months = age % 12;
    if (months == 0) {
      return 'Soit exactement $years an${years > 1 ? 's' : ''}';
    }
    return 'Soit $years an${years > 1 ? 's' : ''} et $months mois';
  }

  String _formatAgePreview(String text) {
    final age = int.tryParse(text);
    if (age == null || age <= 0) return '0 mois';
    if (age < 12) return '$age mois';
    final years = age ~/ 12;
    final months = age % 12;
    if (months == 0) {
      return years == 1 ? '1 an' : '$years ans';
    }
    return '$years an${years > 1 ? 's' : ''} $months m';
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
      ),
    );
  }
}
