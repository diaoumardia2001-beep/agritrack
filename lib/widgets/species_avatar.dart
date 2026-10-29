// lib/widgets/species_avatar.dart
import 'package:flutter/material.dart';
import '../models/animal.dart';
import '../theme/app_colors.dart';

/// Avatar vectoriel moderne pour un animal ou une espèce.
/// Remplace les emojis système par des pictogrammes vectoriels élégants
/// et gère le fallback en cas d'absence ou d'échec de photo réelle.
class SpeciesAvatar extends StatelessWidget {
  final AnimalType type;
  final String? imageUrl;
  final double size;
  final double borderRadius;
  final String? heroTag;

  const SpeciesAvatar({
    super.key,
    required this.type,
    this.imageUrl,
    this.size = 48.0,
    this.borderRadius = 14.0,
    this.heroTag,
  });

  IconData _iconForSpecies(AnimalType type) {
    switch (type) {
      case AnimalType.bovin:
        return Icons.agriculture_rounded;
      case AnimalType.caprin:
        return Icons.terrain_rounded;
      case AnimalType.ovin:
        return Icons.filter_vintage_rounded;
      case AnimalType.volaille:
        return Icons.egg_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = AppColors.forSpecies(type);

    final avatarWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.40 : 0.25),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 1),
        child: _buildContent(color),
      ),
    );

    if (heroTag != null && heroTag!.isNotEmpty) {
      return Hero(
        tag: heroTag!,
        child: avatarWidget,
      );
    }

    return avatarWidget;
  }

  /// Chemin de l'image locale représentative de chaque espèce (libres de droits et optimisées)
  static String defaultAssetForSpecies(AnimalType type) {
    switch (type) {
      case AnimalType.bovin:
        return 'assets/images/bovin.jpg';
      case AnimalType.caprin:
        return 'assets/images/caprin.jpg';
      case AnimalType.ovin:
        return 'assets/images/ovin.jpg';
      case AnimalType.volaille:
        return 'assets/images/volaille.jpg';
    }
  }

  Widget _buildContent(Color color) {
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      final effectivePath = imageUrl!.trim();
      final isNetwork = effectivePath.startsWith('http://') ||
          effectivePath.startsWith('https://');

      if (isNetwork) {
        return Image.network(
          effectivePath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildVectorGlyph(color),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: SizedBox(
                width: size * 0.4,
                height: size * 0.4,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              ),
            );
          },
        );
      }

      return Image.asset(
        effectivePath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildVectorGlyph(color),
      );
    }

    return _buildVectorGlyph(color);
  }

  Widget _buildVectorGlyph(Color color) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Cercle décoratif en arrière-plan
        Positioned(
          bottom: -size * 0.15,
          right: -size * 0.15,
          child: Container(
            width: size * 0.7,
            height: size * 0.7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
            ),
          ),
        ),
        Icon(
          _iconForSpecies(type),
          size: size * 0.52,
          color: color,
        ),
      ],
    );
  }
}
