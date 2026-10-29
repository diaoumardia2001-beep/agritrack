// lib/widgets/agritrack_logo.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Logo vectoriel officiel AgriTrack.
/// Associe l'agriculture (feuille/épi), l'élevage (arc protecteur)
/// et la traçabilité numérique (pulsations connectées).
class AgriTrackLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final String? subtitle;
  final Color? color;
  final bool compact;

  final bool vertical;

  const AgriTrackLogo({
    super.key,
    this.size = 40,
    this.showText = false,
    this.subtitle,
    this.color,
    this.compact = false,
    this.vertical = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor =
        color ?? (isDark ? AppColors.darkPrimary : AppColors.lightPrimary);
    final accentColor = isDark ? AppColors.darkAccent : AppColors.lightAccent;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final subtextColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final emblem = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFC4F75C),
            Color(0xFFA9E82C),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA9E82C).withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Center(
        child: SizedBox(
          width: size * 0.58,
          height: size * 0.58,
          child: const CustomPaint(
            painter: _AgriTrackLeafPainter(
              color: Color(0xFF0B1405),
            ),
          ),
        ),
      ),
    );

    if (!showText) {
      return emblem;
    }

    final brandFontSize =
        compact ? math.max(13.0, size * 0.55) : math.max(14.0, size * 0.44);

    final textBrand = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: vertical ? Alignment.center : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Agri',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: brandFontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: primaryColor,
              height: 1.1,
            ),
          ),
          Text(
            'Track',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: brandFontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: textColor,
              height: 1.1,
            ),
          ),
          Text(
            '.',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: brandFontSize,
              fontWeight: FontWeight.w800,
              color: accentColor,
              height: 1.1,
            ),
          ),
        ],
      ),
    );

    final effectiveSubtitle = subtitle ??
        (showText && !compact ? 'GESTION & SUIVI DE CHEPTEL' : null);

    final subtitleWidget = effectiveSubtitle != null
        ? FittedBox(
            fit: BoxFit.scaleDown,
            alignment: vertical ? Alignment.center : Alignment.centerLeft,
            child: Text(
              effectiveSubtitle,
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: math.max(8.5, size * 0.20),
                fontWeight: FontWeight.w600,
                color: subtextColor,
                letterSpacing: 0.8,
              ),
            ),
          )
        : null;

    if (vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          emblem,
          SizedBox(height: size * 0.22),
          textBrand,
          if (subtitleWidget != null) ...[
            const SizedBox(height: 4),
            subtitleWidget,
          ],
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        emblem,
        SizedBox(width: size * 0.25),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              textBrand,
              if (subtitleWidget != null) ...[
                const SizedBox(height: 2),
                subtitleWidget,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AgriTrackLeafPainter extends CustomPainter {
  final Color color;

  const _AgriTrackLeafPainter({
    this.color = const Color(0xFF0B1405),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * (size.width / 24.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.scale(size.width / 24.0, size.height / 24.0);

    // ── 1. Feuille principale Lucide (d="M11 20A7 7 0 0 1 9.8 6.1C15.5 5 17 4.48 19 2c1 2 2 4.18 2 8 0 5.5-4.78 10-10 10Z") ──
    final leafPath = Path();
    leafPath.moveTo(11, 20);
    leafPath.arcToPoint(
      const Offset(9.8, 6.1),
      radius: const Radius.circular(7.0),
      clockwise: true,
      largeArc: false,
    );
    leafPath.cubicTo(15.5, 5.0, 17.0, 4.48, 19.0, 2.0);
    leafPath.cubicTo(20.0, 4.0, 21.0, 6.18, 21.0, 10.0);
    leafPath.cubicTo(21.0, 15.5, 16.22, 20.0, 11.0, 20.0);
    leafPath.close();
    canvas.drawPath(leafPath, paint);

    // ── 2. Nervure / Tige centrale (d="M2 21c0-3 1.85-5.36 5.08-6C9.5 14.52 12 13 13 12") ──
    final stemPath = Path();
    stemPath.moveTo(2, 21);
    stemPath.cubicTo(2.0, 18.0, 3.85, 15.64, 7.08, 15.0);
    stemPath.cubicTo(9.5, 14.52, 12.0, 13.0, 13.0, 12.0);
    canvas.drawPath(stemPath, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AgriTrackLeafPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
