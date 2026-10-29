// lib/widgets/agri_card.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Carte universelle du design system AgriTrack.
/// Offre une bordure précise, un rayon de 18px et un retour tactile élégant.
class AgriCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final bool elevated;

  const AgriCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 18.0,
    this.elevated = false,
  });

  @override
  State<AgriCard> createState() => _AgriCardState();
}

class _AgriCardState extends State<AgriCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final defaultBorder =
        isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder;
    final hoverBorder = isDark
        ? AppColors.darkPrimary.withValues(alpha: 0.5)
        : AppColors.lightPrimary.withValues(alpha: 0.4);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: widget.backgroundColor ?? defaultBg,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: widget.borderColor ??
                (_isHovered && widget.onTap != null
                    ? hoverBorder
                    : defaultBorder),
            width: 1.0,
          ),
          boxShadow: [
            if (widget.elevated || (_isHovered && widget.onTap != null))
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.35)
                    : AppColors.lightPrimary.withValues(alpha: 0.06),
                blurRadius: _isHovered ? 12 : 6,
                offset: Offset(0, _isHovered ? 4 : 2),
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            splashColor:
                (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                    .withValues(alpha: 0.08),
            highlightColor:
                (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                    .withValues(alpha: 0.04),
            child: Padding(
              padding: widget.padding,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
