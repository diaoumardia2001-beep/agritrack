// lib/widgets/health_status_badge.dart
import 'package:flutter/material.dart';
import '../models/animal.dart';

class HealthStatusBadge extends StatelessWidget {
  final HealthStatus status;
  final bool compact;

  const HealthStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  Color _bgColor(BuildContext context) {
    switch (status) {
      case HealthStatus.sain:
        return const Color(0xFF1B5E20);
      case HealthStatus.aSurveiller:
        return const Color(0xFFE65100);
      case HealthStatus.malade:
        return const Color(0xFFB71C1C);
    }
  }

  Color _fgColor() => Colors.white;

  IconData _icon() {
    switch (status) {
      case HealthStatus.sain:
        return Icons.check_circle_outline;
      case HealthStatus.aSurveiller:
        return Icons.warning_amber_rounded;
      case HealthStatus.malade:
        return Icons.sick_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: _bgColor(context),
          shape: BoxShape.circle,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _bgColor(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(), size: 14, color: _fgColor()),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              color: _fgColor(),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
