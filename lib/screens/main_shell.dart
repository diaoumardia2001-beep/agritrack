// lib/screens/main_shell.dart
import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'animal_list_screen.dart';
import 'add_animal_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    AnimalListScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddAnimalScreen()),
          );
        },
        tooltip: 'Ajouter un animal au cheptel',
        icon: const Icon(Icons.add),
        label: const Text(
          'Ajouter',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 4,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          children: [
            // ─── Dashboard ─────────────────────────────────────────
            Expanded(
              child: _NavItem(
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard,
                label: 'Tableau',
                selected: _currentIndex == 0,
                onTap: () => setState(() => _currentIndex = 0),
              ),
            ),
            // ─── Cheptel ───────────────────────────────────────────
            Expanded(
              child: _NavItem(
                icon: Icons.pets_outlined,
                activeIcon: Icons.pets,
                label: 'Cheptel',
                selected: _currentIndex == 1,
                onTap: () => setState(() => _currentIndex = 1),
              ),
            ),
            // ─── Spacer for FAB ───────────────────────────────────
            const Expanded(child: SizedBox()),
            const Expanded(child: SizedBox()),
            // ─── Réglages ──────────────────────────────────────────
            Expanded(
              child: _NavItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings,
                label: 'Réglages',
                selected: _currentIndex == 2,
                onTap: () => setState(() => _currentIndex = 2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  selected ? activeIcon : icon,
                  key: ValueKey(selected),
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected
                      ? theme.colorScheme.primary
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
