// lib/widgets/agri_icon_container.dart
import 'package:flutter/material.dart';

/// Conteneur d'icône stylisé avec fond coloré et bordure douce.
class AgriIconContainer extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color? backgroundColor;
  final double size;
  final double iconSize;
  final double borderRadius;

  const AgriIconContainer({
    super.key,
    required this.icon,
    required this.color,
    this.backgroundColor,
    this.size = 42.0,
    this.iconSize = 22.0,
    this.borderRadius = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? color.withValues(alpha: 0.12);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: color.withValues(alpha: 0.20),
          width: 1.0,
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: iconSize,
          color: color,
        ),
      ),
    );
  }
}
