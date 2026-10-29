// lib/screens/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/animals_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/agritrack_logo.dart';
import 'main_shell.dart';

/// Écran de démarrage officiel AgriTrack.
/// Offre une identité AgriTech Premium avec animation d'entrée fluide,
/// préchauffe la base de données locale Sembast et assure une transition douce.
class SplashScreen extends ConsumerStatefulWidget {
  final Duration minDuration;
  final Widget? nextScreen;

  const SplashScreen({
    super.key,
    this.minDuration = const Duration(milliseconds: 150),
    this.nextScreen,
  });

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
      ),
    );

    _animController.forward();
    _startPrewarmAndNavigate();
  }

  Future<void> _startPrewarmAndNavigate() async {
    final startTime = DateTime.now();

    // 1. Préchauffage asynchrone des données locales Sembast & SharedPreferences
    try {
      await ref.read(animalsProvider.future);
    } catch (e) {
      debugPrint('SplashScreen prewarm notice: $e');
    }

    // 2. Respect de la durée minimale (ultra-courte pour fluidité sans délai artificiel)
    final elapsed = DateTime.now().difference(startTime);
    final remaining = widget.minDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    if (!mounted || _navigated) return;
    _navigated = true;

    // 3. Transition fluide et rapide vers le shell principal
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            widget.nextScreen ?? const MainShell(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Couleur de fond rigoureusement identique au reste de l'application
    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final primaryColor =
        isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return Scaffold(
      backgroundColor: bgColor,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: bgColor,
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),

              // Logo & Identité visuelle animée — Source unique de vérité AgriTrackLogo
              FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: const AgriTrackLogo(
                    size: 76,
                    showText: true,
                    vertical: true,
                    subtitle: 'GESTION & SUIVI DE CHEPTEL',
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // Indicateur discret de préchauffage
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          primaryColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Chargement des données locales...',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 1),

              // Mention de localisation & version
              FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Côte d\'Ivoire • v1.0.0',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.5),
                      fontSize: 10,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
