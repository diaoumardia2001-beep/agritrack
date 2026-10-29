// lib/screens/main_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/active_farm_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/agritrack_logo.dart';
import 'dashboard_screen.dart';
import 'animal_list_screen.dart';
import 'add_animal_screen.dart';
import 'settings_screen.dart';
import 'farm/select_farm_dialog.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;
  static const double kResponsiveBreakpoint = 768.0;
  static const double kDesktopBreakpoint = 1024.0;

  void _onAddAnimal() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddAnimalScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width >= kDesktopBreakpoint) {
          return _buildDesktopLayout(context, isTablet: false);
        } else if (width >= kResponsiveBreakpoint) {
          return _buildDesktopLayout(context, isTablet: true);
        } else {
          return _buildMobileLayout(context);
        }
      },
    );
  }

  // ─── Disposition Écran Large (Web, Tablette, Desktop) ───────────────────
  Widget _buildDesktopLayout(BuildContext context, {bool isTablet = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sidebarWidth = isTablet ? 224.0 : 260.0;
    final farmState = ref.watch(activeFarmProvider);

    return Scaffold(
      body: Row(
        children: [
          // ── Sidebar de navigation ──
          Container(
            width: sidebarWidth,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              border: Border(
                right: BorderSide(
                  color: isDark
                      ? AppColors.darkCardBorder
                      : AppColors.lightCardBorder,
                  width: 1.0,
                ),
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo & Titre officiel AgriTrack
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      isTablet ? 12 : 16,
                      20,
                      isTablet ? 12 : 16,
                      16,
                    ),
                    child: AgriTrackLogo(
                      size: isTablet ? 36 : 38,
                      showText: true,
                      compact: isTablet,
                      subtitle: isTablet ? null : 'GESTION & SUIVI DE CHEPTEL',
                    ),
                  ),

                  // Carte d'exploitation active
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 10 : 16,
                      vertical: 8,
                    ),
                    child: InkWell(
                      onTap: farmState.hasRemoteFarms
                          ? () => SelectFarmDialog.show(context)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: EdgeInsets.all(isTablet ? 10 : 12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceSubtle
                              : AppColors.lightSurfaceSubtle,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkCardBorder
                                : AppColors.lightCardBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: isTablet ? 30 : 34,
                              height: isTablet ? 30 : 34,
                              decoration: BoxDecoration(
                                color: (isDark
                                        ? AppColors.darkPrimary
                                        : AppColors.lightPrimary)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.agriculture_rounded,
                                size: isTablet ? 16 : 18,
                                color: isDark
                                    ? AppColors.darkPrimary
                                    : AppColors.lightPrimary,
                              ),
                            ),
                            SizedBox(width: isTablet ? 8 : 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Exploitation active',
                                    style: (isTablet
                                            ? theme.textTheme.labelSmall
                                            : theme.textTheme.labelMedium)
                                        ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    farmState.activeFarm.name,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: isTablet ? 10 : 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: farmState.isRemote
                                    ? const Color(0xFF0284C7)
                                    : const Color(0xFF16A34A),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Divider(
                    height: 1,
                    indent: isTablet ? 10 : 16,
                    endIndent: isTablet ? 10 : 16,
                  ),
                  const SizedBox(height: 12),

                  // Liens de navigation
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 8 : 12,
                    ),
                    child: Column(
                      children: [
                        _SidebarNavItem(
                          icon: Icons.dashboard_outlined,
                          activeIcon: Icons.dashboard_rounded,
                          label: 'Tableau',
                          isSelected: _currentIndex == 0,
                          onTap: () => setState(() => _currentIndex = 0),
                        ),
                        const SizedBox(height: 6),
                        _SidebarNavItem(
                          icon: Icons.pets_outlined,
                          activeIcon: Icons.pets_rounded,
                          label: 'Cheptel',
                          isSelected: _currentIndex == 1,
                          onTap: () => setState(() => _currentIndex = 1),
                        ),
                        const SizedBox(height: 6),
                        _SidebarNavItem(
                          icon: Icons.settings_outlined,
                          activeIcon: Icons.settings_rounded,
                          label: 'Réglages',
                          isSelected: _currentIndex == 2,
                          onTap: () => setState(() => _currentIndex = 2),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Bouton Ajouter un animal
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 10 : 16,
                      vertical: 8,
                    ),
                    child: FilledButton.icon(
                      onPressed: _onAddAnimal,
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text(
                        'Ajouter',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),

                  // Bascule de thème rapide
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      isTablet ? 10 : 16,
                      8,
                      isTablet ? 10 : 16,
                      16,
                    ),
                    child: InkWell(
                      onTap: () =>
                          ref.read(themeModeProvider.notifier).toggle(),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 8 : 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkCardBorder
                                : AppColors.lightCardBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isDark
                                      ? Icons.dark_mode_outlined
                                      : Icons.light_mode_outlined,
                                  size: 18,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isDark ? 'Mode sombre' : 'Mode clair',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Icon(
                              Icons.sync_alt,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Contenu principal ──
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                DashboardScreen(
                  onNavigateToHerd: () => setState(() => _currentIndex = 1),
                  onNavigateToSettings: () => setState(() => _currentIndex = 2),
                ),
                const AnimalListScreen(),
                const SettingsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Disposition Écran Mobile ───────────────────────────────────────────
  Widget _buildMobileLayout(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DashboardScreen(
            onNavigateToHerd: () => setState(() => _currentIndex = 1),
            onNavigateToSettings: () => setState(() => _currentIndex = 2),
          ),
          const AnimalListScreen(),
          const SettingsScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onAddAnimal,
        tooltip: 'Ajouter un animal au cheptel',
        icon: const Icon(Icons.add),
        label: const Text(
          'Ajouter',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 4,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          border: Border(
            top: BorderSide(
              color:
                  isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
              width: 1.0,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomAppBar(
          color: Colors.transparent,
          elevation: 0,
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                // ─── Dashboard ─────────────────────────────────────────
                Expanded(
                  child: _MobileNavItem(
                    icon: Icons.dashboard_outlined,
                    activeIcon: Icons.dashboard_rounded,
                    label: 'Tableau',
                    selected: _currentIndex == 0,
                    onTap: () => setState(() => _currentIndex = 0),
                  ),
                ),
                // ─── Cheptel ───────────────────────────────────────────
                Expanded(
                  child: _MobileNavItem(
                    icon: Icons.pets_outlined,
                    activeIcon: Icons.pets_rounded,
                    label: 'Cheptel',
                    selected: _currentIndex == 1,
                    onTap: () => setState(() => _currentIndex = 1),
                  ),
                ),
                // ─── Espace pour le FAB central ───────────────────────
                const Expanded(child: SizedBox()),
                const Expanded(child: SizedBox()),
                // ─── Réglages ──────────────────────────────────────────
                Expanded(
                  child: _MobileNavItem(
                    icon: Icons.settings_outlined,
                    activeIcon: Icons.settings_rounded,
                    label: 'Réglages',
                    selected: _currentIndex == 2,
                    onTap: () => setState(() => _currentIndex = 2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Élément de navigation pour la Sidebar Desktop ─────────────────────────
class _SidebarNavItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor =
        isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    final bgColor = widget.isSelected
        ? (isDark
            ? AppColors.darkPrimaryContainer
            : AppColors.lightPrimaryContainer)
        : (_isHovered
            ? (isDark
                ? AppColors.darkSurfaceSubtle
                : AppColors.lightSurfaceSubtle)
            : Colors.transparent);

    final textColor = widget.isSelected
        ? (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
        : theme.colorScheme.onSurfaceVariant;

    return Semantics(
      label: 'Onglet ${widget.label}',
      selected: widget.isSelected,
      button: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isSelected
                  ? primaryColor.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      widget.isSelected ? widget.activeIcon : widget.icon,
                      color: textColor,
                      size: 22,
                    ),
                    const SizedBox(width: 14),
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: widget.isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Élément de navigation pour la barre Mobile ───────────────────────────
class _MobileNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MobileNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeColor = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return Semantics(
      label: 'Onglet $label',
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? (isDark
                          ? AppColors.darkPrimaryContainer
                          : AppColors.lightPrimaryContainer)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  selected ? activeIcon : icon,
                  color: selected
                      ? activeColor
                      : theme.colorScheme.onSurfaceVariant,
                  size: 22,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected
                      ? activeColor
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
