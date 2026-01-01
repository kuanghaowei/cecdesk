import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/connection/presentation/pages/connection_page.dart';
import '../../features/remote_desktop/presentation/pages/remote_desktop_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/file_transfer/presentation/pages/file_transfer_page.dart';
import '../../features/auth/presentation/pages/consent_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/device_list/presentation/pages/device_list_page.dart';
import '../../features/remote_control/presentation/pages/remote_control_page.dart';
import '../services/service_locator.dart';
import 'main_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final consentState = ref.watch(consentStateProvider);
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/remote-control',
    redirect: (context, state) {
      final isConsentPage = state.matchedLocation == '/consent';
      final isLoginPage = state.matchedLocation == '/login';
      
      // Check consent first
      if (!consentState.hasConsented && !isConsentPage) {
        return '/consent';
      }
      
      // Protected routes that require login
      final protectedRoutes = ['/remote-control', '/device-list'];
      final isProtectedRoute = protectedRoutes.any(
        (route) => state.matchedLocation.startsWith(route),
      );
      
      // Redirect to login if accessing protected route without auth
      if (isProtectedRoute && !authState.isLoggedIn && !isLoginPage) {
        return '/login';
      }
      
      return null;
    },
    routes: [
      // Consent page (shown on first launch)
      GoRoute(
        path: '/consent',
        name: 'consent',
        builder: (context, state) => ConsentPage(
          onConsentAccepted: () {
            context.go('/login');
          },
        ),
      ),
      
      // Login page
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      
      // Main app shell with bottom navigation
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          // Remote control main page
          GoRoute(
            path: '/remote-control',
            name: 'remote-control',
            builder: (context, state) => const RemoteControlPage(),
          ),
          
          // Device list page
          GoRoute(
            path: '/device-list',
            name: 'device-list',
            builder: (context, state) => const DeviceListPage(),
          ),
          
          // Settings page
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
      
      // Connection management page
      GoRoute(
        path: '/connection',
        name: 'connection',
        builder: (context, state) => const ConnectionPage(),
      ),
      
      // Remote desktop session page
      GoRoute(
        path: '/remote-desktop/:sessionId',
        name: 'remote-desktop',
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId']!;
          return RemoteDesktopPage(sessionId: sessionId);
        },
      ),
      
      // File transfer page
      GoRoute(
        path: '/file-transfer',
        name: 'file-transfer',
        builder: (context, state) => const FileTransferPage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              '页面未找到',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              state.error.toString(),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/remote-control'),
              child: const Text('返回首页'),
            ),
          ],
        ),
      ),
    ),
  );
});
