import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/service_locator.dart';

/// Main shell with bottom navigation bar
/// Validates: Requirement 19.1 - Main menu structure with login, remote control, device list, settings
class MainShell extends ConsumerWidget {
  final Widget child;

  const MainShell({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final currentLocation = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _getSelectedIndex(currentLocation),
        onDestinationSelected: (index) => _onDestinationSelected(context, index, authState.isLoggedIn),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.desktop_windows_outlined),
            selectedIcon: Icon(Icons.desktop_windows),
            label: '远程控制',
          ),
          const NavigationDestination(
            icon: Icon(Icons.devices_outlined),
            selectedIcon: Icon(Icons.devices),
            label: '设备列表',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }

  int _getSelectedIndex(String location) {
    if (location.startsWith('/remote-control')) return 0;
    if (location.startsWith('/device-list')) return 1;
    if (location.startsWith('/settings')) return 2;
    return 0;
  }

  void _onDestinationSelected(BuildContext context, int index, bool isLoggedIn) {
    switch (index) {
      case 0:
        // Remote control - requires login
        if (!isLoggedIn) {
          _showLoginRequired(context, '/remote-control');
        } else {
          context.go('/remote-control');
        }
        break;
      case 1:
        // Device list - requires login
        if (!isLoggedIn) {
          _showLoginRequired(context, '/device-list');
        } else {
          context.go('/device-list');
        }
        break;
      case 2:
        // Settings - no login required
        context.go('/settings');
        break;
    }
  }

  /// Show login required dialog
  /// Validates: Requirement 19.2 - Guide user to login when accessing protected features
  void _showLoginRequired(BuildContext context, String targetRoute) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要登录'),
        content: const Text('请先登录后再使用此功能'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/login');
            },
            child: const Text('去登录'),
          ),
        ],
      ),
    );
  }
}
