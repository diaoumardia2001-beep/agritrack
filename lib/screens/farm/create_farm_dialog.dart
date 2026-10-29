// lib/screens/farm/create_farm_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/farm.dart';
import '../../providers/active_farm_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/agri_icon_container.dart';

/// Dialogue assistant pour la création explicite d'une exploitation distante.
/// Conforme au contrat atomique RPC `create_farm_with_owner` de Supabase.
class CreateFarmDialog extends ConsumerStatefulWidget {
  const CreateFarmDialog({super.key});

  /// Méthode d'ouverture statique pratique
  static Future<Farm?> show(BuildContext context) {
    return showDialog<Farm?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CreateFarmDialog(),
    );
  }

  @override
  ConsumerState<CreateFarmDialog> createState() => _CreateFarmDialogState();
}

class _CreateFarmDialogState extends ConsumerState<CreateFarmDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _regionController = TextEditingController();

  bool _isSubmitting = false;
  String? _localErrorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (_isSubmitting) return;

    setState(() => _localErrorMessage = null);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final name = _nameController.text.trim();
    final region = _regionController.text.trim();

    try {
      final farmNotifier = ref.read(activeFarmProvider.notifier);
      final createdFarm = await farmNotifier.createRemoteFarm(
        name: name,
        region: region.isNotEmpty ? region : null,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (createdFarm != null) {
        // Confirmation visuelle explicite
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Exploitation « ${createdFarm.name} » créée avec succès !',
            ),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(createdFarm);
      } else {
        final farmState = ref.read(activeFarmProvider);
        setState(() {
          _localErrorMessage = farmState.errorMessage ??
              'Impossible de créer l\'exploitation. Veuillez réessayer.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _localErrorMessage = 'Erreur inattendue : $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final farmState = ref.watch(activeFarmProvider);

    final isLoading = _isSubmitting || farmState.isLoading;

    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      title: Row(
        children: [
          AgriIconContainer(
            icon: Icons.add_business_rounded,
            color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
            size: 40,
            iconSize: 22,
            borderRadius: 10,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nouvelle exploitation',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Création dans le cloud',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Vous serez automatiquement désigné comme propriétaire de cette nouvelle exploitation.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),

                // Message d'erreur éventuel
                if (_localErrorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626)
                          .withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFDC2626)
                            .withValues(alpha: isDark ? 0.5 : 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 18, color: Color(0xFFDC2626)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _localErrorMessage!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? const Color(0xFFFCA5A5)
                                  : const Color(0xFFB91C1C),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Champ Nom de l'exploitation (obligatoire)
                Text(
                  'Nom de l\'exploitation *',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  key: const ValueKey('create_farm_name_field'),
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  enabled: !isLoading,
                  decoration: InputDecoration(
                    hintText: 'ex: Ferme Espoir Korhogo',
                    prefixIcon: const Icon(Icons.agriculture_rounded, size: 20),
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkSurfaceSubtle
                        : AppColors.lightSurfaceSubtle,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.darkCardBorder
                            : AppColors.lightCardBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.darkCardBorder
                            : AppColors.lightCardBorder,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Veuillez saisir le nom de l\'exploitation';
                    }
                    if (value.trim().length < 2) {
                      return 'Le nom doit comporter au moins 2 caractères';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Champ Région (facultative)
                Text(
                  'Région (facultative)',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  key: const ValueKey('create_farm_region_field'),
                  controller: _regionController,
                  textInputAction: TextInputAction.done,
                  enabled: !isLoading,
                  onFieldSubmitted: (_) => _handleCreate(),
                  decoration: InputDecoration(
                    hintText: 'ex: Poro, Bouaké, Savanes...',
                    prefixIcon: const Icon(Icons.place_outlined, size: 20),
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkSurfaceSubtle
                        : AppColors.lightSurfaceSubtle,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.darkCardBorder
                            : AppColors.lightCardBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.darkCardBorder
                            : AppColors.lightCardBorder,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Note informative
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isDark
                            ? AppColors.darkPrimary
                            : AppColors.lightPrimary)
                        .withValues(alpha: isDark ? 0.12 : 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (isDark
                              ? AppColors.darkPrimary
                              : AppColors.lightPrimary)
                          .withValues(alpha: isDark ? 0.25 : 0.15),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 16,
                        color: isDark
                            ? AppColors.darkPrimary
                            : AppColors.lightPrimary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Les autres utilisateurs ne pourront rejoindre cette exploitation que via une invitation explicite.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          key: const ValueKey('create_farm_cancel_button'),
          onPressed: isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          key: const ValueKey('create_farm_submit_button'),
          onPressed: isLoading ? null : _handleCreate,
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Créer l\'exploitation'),
        ),
      ],
    );
  }
}
