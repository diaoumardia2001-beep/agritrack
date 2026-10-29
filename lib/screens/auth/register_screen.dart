// lib/screens/auth/register_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/agri_card.dart';
import '../../widgets/agritrack_logo.dart';
import 'login_screen.dart';

/// Écran d'inscription d'AgriTrack.
/// Prise en charge explicite du flux avec confirmation par email ou session immédiate.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;
  bool _registrationCompletedNeedsConfirmation = false;
  String _confirmedEmail = '';

  // État du renvoi d'e-mail de confirmation
  bool _isResending = false;
  int _resendCooldownSeconds = 0;
  Timer? _cooldownTimer;
  String? _resendSuccessMessage;
  String? _resendErrorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).clearError();
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Déclenche le renvoi de l'e-mail de confirmation avec protection anti-spam et retours visuels
  Future<void> _handleResendConfirmation() async {
    if (_isResending || _resendCooldownSeconds > 0) return;
    if (_confirmedEmail.isEmpty) return;

    setState(() {
      _isResending = true;
      _resendSuccessMessage = null;
      _resendErrorMessage = null;
    });

    final success = await ref
        .read(authProvider.notifier)
        .resendConfirmationEmail(_confirmedEmail);

    if (!mounted) return;

    setState(() {
      _isResending = false;
      if (success) {
        _resendSuccessMessage =
            'Un nouvel e-mail de confirmation a été envoyé à $_confirmedEmail.';
        _resendErrorMessage = null;
        _startCooldown(60);
      } else {
        final authErr = ref.read(authProvider).errorMessage;
        _resendErrorMessage = authErr ??
            'Impossible de renvoyer l\'e-mail. Veuillez réessayer plus tard.';
        _resendSuccessMessage = null;
      }
    });
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldownSeconds = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _resendCooldownSeconds = 0);
      } else {
        setState(() => _resendCooldownSeconds--);
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    final success = await ref.read(authProvider.notifier).signUp(
          email: email,
          password: password,
          fullName: fullName,
          phoneNumber: phone.isNotEmpty ? phone : null,
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      final authState = ref.read(authProvider);

      if (authState.needsEmailConfirmation) {
        // Cas 1 : Inscription réussie mais email non confirmé par Supabase
        setState(() {
          _registrationCompletedNeedsConfirmation = true;
          _confirmedEmail = email;
        });
      } else if (authState.isAuthenticated) {
        // Cas 2 : Inscription réussie avec session active immédiate
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Compte créé avec succès ! Bienvenue sur AgriTrack.'),
            backgroundColor: Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authProvider);

    final isLoading = _isSubmitting || authState.isLoading;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AgriCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                borderRadius: 20,
                child: _registrationCompletedNeedsConfirmation
                    ? _buildEmailConfirmationView(context, isDark)
                    : _buildRegisterForm(context, isDark, authState, isLoading),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Vue affichée lorsque l'inscription nécessite une confirmation par e-mail
  Widget _buildEmailConfirmationView(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    return Column(
      key: const ValueKey('email_confirmation_view'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color:
                const Color(0xFF0284C7).withValues(alpha: isDark ? 0.25 : 0.12),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(
              Icons.mark_email_read_outlined,
              size: 36,
              color: Color(0xFF0284C7),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Vérifiez votre boîte e-mail',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Un lien de confirmation vient d\'être envoyé à l\'adresse :',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          _confirmedEmail,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceSubtle
                : AppColors.lightSurfaceSubtle,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline,
                  size: 20, color: Color(0xFF0284C7)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cliquez sur le lien reçu pour valider votre compte, puis connectez-vous avec vos identifiants.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ─── Retours visuels du renvoi ───
        if (_resendSuccessMessage != null) ...[
          const SizedBox(height: 14),
          Container(
            key: const ValueKey('resend_confirmation_success_message'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A)
                  .withValues(alpha: isDark ? 0.25 : 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF16A34A)
                    .withValues(alpha: isDark ? 0.5 : 0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 18, color: Color(0xFF16A34A)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _resendSuccessMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? const Color(0xFF86EFAC)
                          : const Color(0xFF15803D),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (_resendErrorMessage != null) ...[
          const SizedBox(height: 14),
          Container(
            key: const ValueKey('resend_confirmation_error_message'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626)
                  .withValues(alpha: isDark ? 0.25 : 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFDC2626)
                    .withValues(alpha: isDark ? 0.5 : 0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    size: 18, color: Color(0xFFDC2626)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _resendErrorMessage!,
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

        const SizedBox(height: 18),

        // Bouton de renvoi d'email
        OutlinedButton.icon(
          key: const ValueKey('resend_confirmation_email_button'),
          onPressed: (_isResending || _resendCooldownSeconds > 0)
              ? null
              : _handleResendConfirmation,
          icon: _isResending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                  ),
                )
              : const Icon(Icons.send_rounded, size: 16),
          label: Text(
            _isResending
                ? 'Envoi en cours...'
                : (_resendCooldownSeconds > 0
                    ? 'Renvoyer l\'e-mail (${_resendCooldownSeconds}s)'
                    : 'Renvoyer l\'e-mail de confirmation'),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        const SizedBox(height: 8),
        Text(
          'Si vous ne recevez rien, pensez à vérifier votre dossier de courriers indésirables (spams).',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('goto_login_after_signup_button'),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
          icon: const Icon(Icons.login_rounded, size: 18),
          label: const Text('Aller à la connexion'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  /// Formulaire complet d'inscription
  Widget _buildRegisterForm(
    BuildContext context,
    bool isDark,
    AppAuthState authState,
    bool isLoading,
  ) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête
          const Center(
            child: AgriTrackLogo(
              size: 44,
              showText: true,
              subtitle: 'NOUVEAU COMPTE ÉLEVEUR',
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Créer un compte',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Rejoignez la plateforme de gestion d\'élevage moderne.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Bannière hors-ligne
          if (!authState.isClientAvailable)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706)
                    .withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFD97706)
                      .withValues(alpha: isDark ? 0.5 : 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      size: 20, color: Color(0xFFD97706)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Service d\'inscription distant non accessible. L\'application reste pleinement fonctionnelle en mode local.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? const Color(0xFFFDE68A)
                            : const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Bannière d'erreur
          if (authState.hasError && authState.errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626)
                    .withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFDC2626)
                      .withValues(alpha: isDark ? 0.5 : 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 20, color: Color(0xFFDC2626)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      authState.errorMessage!,
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

          // Nom complet
          Text(
            'Nom complet *',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: const ValueKey('register_fullname_field'),
            controller: _fullNameController,
            textInputAction: TextInputAction.next,
            enabled: !isLoading,
            decoration: _inputDecoration(
              isDark: isDark,
              hint: 'ex: Ousmane Konan',
              prefixIcon: Icons.person_outline,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Veuillez saisir votre nom complet';
              }
              if (value.trim().length < 2) {
                return 'Le nom doit comporter au moins 2 caractères';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // E-mail
          Text(
            'Adresse e-mail *',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: const ValueKey('register_email_field'),
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            enabled: !isLoading,
            decoration: _inputDecoration(
              isDark: isDark,
              hint: 'exemple@agritrack.ci',
              prefixIcon: Icons.email_outlined,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Veuillez saisir votre adresse e-mail';
              }
              final trimmed = value.trim();
              if (!trimmed.contains('@') || !trimmed.contains('.')) {
                return 'Format d\'adresse e-mail invalide';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Téléphone facultatif
          Text(
            'Numéro de téléphone (facultatif)',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: const ValueKey('register_phone_field'),
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            enabled: !isLoading,
            decoration: _inputDecoration(
              isDark: isDark,
              hint: 'ex: +225 07 00 00 00 00',
              prefixIcon: Icons.phone_outlined,
            ),
          ),
          const SizedBox(height: 14),

          // Mot de passe
          Text(
            'Mot de passe *',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: const ValueKey('register_password_field'),
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            enabled: !isLoading,
            decoration: _inputDecoration(
              isDark: isDark,
              hint: 'Au moins 6 caractères',
              prefixIcon: Icons.lock_outline,
              suffixIcon: IconButton(
                key: const ValueKey('register_password_toggle'),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
                tooltip: _obscurePassword
                    ? 'Afficher le mot de passe'
                    : 'Masquer le mot de passe',
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez définir un mot de passe';
              }
              if (value.length < 6) {
                return 'Le mot de passe doit comporter au moins 6 caractères';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Confirmation mot de passe
          Text(
            'Confirmer le mot de passe *',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: const ValueKey('register_confirm_password_field'),
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            enabled: !isLoading,
            onFieldSubmitted: (_) => _handleSubmit(),
            decoration: _inputDecoration(
              isDark: isDark,
              hint: 'Répétez le mot de passe',
              prefixIcon: Icons.lock_clock_outlined,
              suffixIcon: IconButton(
                key: const ValueKey('register_confirm_password_toggle'),
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
                tooltip: _obscureConfirm
                    ? 'Afficher le mot de passe'
                    : 'Masquer le mot de passe',
                onPressed: () {
                  setState(() => _obscureConfirm = !_obscureConfirm);
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez confirmer votre mot de passe';
              }
              if (value != _passwordController.text) {
                return 'Les deux mots de passe ne correspondent pas';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Bouton d'inscription
          FilledButton(
            key: const ValueKey('register_submit_button'),
            onPressed: isLoading ? null : _handleSubmit,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Créer mon compte',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          const SizedBox(height: 18),

          // Lien retour vers connexion
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Vous avez déjà un compte ?',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              TextButton(
                key: const ValueKey('register_goto_login_button'),
                onPressed: isLoading
                    ? null
                    : () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                child: const Text(
                  'Se connecter',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required bool isDark,
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(prefixIcon, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor:
          isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
        ),
      ),
    );
  }
}
