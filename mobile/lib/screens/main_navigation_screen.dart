import 'package:flutter/material.dart';
import 'package:app/l10n/app_localizations.dart';
import '../services/global_context_engine.dart';
import '../widgets/nature_background.dart';
import 'help_desk/help_desk_screen.dart';
import 'map/map_screen.dart';
import 'profile/profile_screen.dart';
import 'scan/scan_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // AI Assistant tab removed from bottom nav; its offline functionality is preserved
  // and accessible globally via the floating AI Mascot.
  final List<Widget> _screens = const [
    ScanScreen(),
    MapScreen(),
    HelpDeskScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Allow Agent tools and context engine to switch tabs programmatically
    GlobalContextEngine.instance.registerTabSwitchCallback((index) {
      if (mounted && index != _currentIndex && index >= 0 && index < _screens.length) {
        setState(() {
          _currentIndex = index;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: NatureBackground(
        child: IndexedStack(index: _currentIndex, children: _screens),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF3F5EA),
          border: Border(top: BorderSide(color: Color(0xFFE2E9D4), width: 1)),
        ),
        child: NavigationBar(
          height: 68,
          selectedIndex: _currentIndex,
          onDestinationSelected: (int index) {
            setState(() {
              _currentIndex = index;
            });
            GlobalContextEngine.instance.switchTab(index);
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.qr_code_scanner_outlined),
              selectedIcon: const Icon(Icons.qr_code_scanner),
              label: l10n?.navScan ?? 'Scan',
            ),
            NavigationDestination(
              icon: const Icon(Icons.map_outlined),
              selectedIcon: const Icon(Icons.map),
              label: l10n?.navMap ?? 'Map',
            ),
            NavigationDestination(
              icon: const Icon(Icons.support_agent_outlined),
              selectedIcon: const Icon(Icons.support_agent),
              label: l10n?.navHelpDesk ?? 'Help Desk',
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
              label: l10n?.navProfile ?? 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
