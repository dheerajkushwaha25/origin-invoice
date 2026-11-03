// lib/screens/app_scaffold.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:ezinvoice/screens/home/home_screen.dart';
import 'package:ezinvoice/screens/bills/all_bills_screen.dart';
import 'package:ezinvoice/screens/clients/clients_screen.dart';
import 'package:ezinvoice/screens/settings/settings_screen.dart' as settings;
import 'package:ezinvoice/screens/settings/sync_google_drive_screen.dart';
import 'package:ezinvoice/providers/invoice_provider.dart';
import 'package:ezinvoice/providers/client_provider.dart';

class AppScaffold extends ConsumerStatefulWidget {
  const AppScaffold({super.key});

  static final GlobalKey<_AppScaffoldState> navigatorKey =
  GlobalKey<_AppScaffoldState>();

  @override
  ConsumerState<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends ConsumerState<AppScaffold> {
  int _selectedIndex = 0;

  // ── Double-tap detection ─────────────────────────────────────────────────
  DateTime? _lastTapTime;
  int? _lastTapIndex;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  void _onItemTapped(int index) {
    final now = DateTime.now();

    if (_selectedIndex == index) {
      // Always fire instant haptic on every tap of current tab
      HapticFeedback.selectionClick();

      // Double-tap within 400ms → refresh
      if (_lastTapIndex == index &&
          _lastTapTime != null &&
          now.difference(_lastTapTime!) < const Duration(milliseconds: 400)) {
        _refreshTab(index);
        _lastTapTime = null;
        _lastTapIndex = null;
        return;
      }

      // Single tap → pop to root
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() => _selectedIndex = index);
      if (index == 1) {
        ref.invalidate(invoiceListProvider);
      }
    }

    _lastTapTime = now;
    _lastTapIndex = index;
  }

  void _refreshTab(int index) {
    // Pop to root first
    _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);

    // Invalidate providers based on tab
    switch (index) {
      case 0: // Home
        ref.invalidate(invoiceListProvider);
        ref.invalidate(clientListProvider);
        break;
      case 1: // All Bills
        ref.invalidate(invoiceListProvider);
        break;
      case 2: // Clients
        ref.invalidate(clientListProvider);
        break;
      case 3: // More — no refresh needed
        break;
    }


  }

  void switchToTab(int index) => setState(() => _selectedIndex = index);

  void goToSyncDrive() {
    setState(() => _selectedIndex = 3);
    Future.delayed(const Duration(milliseconds: 100), () {
      _navigatorKeys[3].currentState?.push(
        MaterialPageRoute(builder: (_) => const SyncGoogleDriveScreen()),
      );
    });
  }

  Widget _buildTabNavigator(int index, Widget child) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (_) => child,
      ),
    );
  }

  // Returns true if we should allow the app to exit
  bool _handlePop() {
    final currentNavigator = _navigatorKeys[_selectedIndex].currentState;

    // If current tab has pages on its stack, pop within the tab
    if (currentNavigator != null && currentNavigator.canPop()) {
      currentNavigator.pop();
      return false; // don't exit
    }

    // If not on home tab, go to home tab
    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
      return false; // don't exit
    }

    // On home tab with nothing to pop → exit app
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final currentNavigator = _navigatorKeys[_selectedIndex].currentState;

        // 1. Pop within current tab's stack first
        if (currentNavigator != null && currentNavigator.canPop()) {
          currentNavigator.pop();
          return;
        }

        // 2. Not on home tab → go to home
        if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
          return;
        }

        // 3. On home with nothing to pop → exit app
        await SystemNavigator.pop();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildTabNavigator(0, const HomeScreen()),
            _buildTabNavigator(1, const BillsScreen()),
            _buildTabNavigator(2, const ClientsScreen()),
            _buildTabNavigator(3, const settings.SettingsScreen()),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.house),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.fileInvoice),
              label: 'All Bills',
            ),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.user),
              label: 'Clients',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.widgets_rounded),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}
