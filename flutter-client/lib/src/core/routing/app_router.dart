import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/connection/presentation/pages/connection_page.dart';
import '../../features/remote_desktop/presentation/pages/remote_desktop_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/file_transfer/presentation/pages/file_transfer_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/connection',
    routes: [
      GoRoute(
        path: '/connection',
        name: 'connection',
        builder: (context, state) => const ConnectionPage(),
      ),
      GoRoute(
        path: '/remote-desktop/:sessionId',
        name: 'remote-desktop',
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId']!;
          return RemoteDesktopPage(sessionId: sessionId);
        },
      ),
      GoRoute(
        path: '/file-transfer',
        name: 'file-transfer',
        builder: (context, state) => const FileTransferPage(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
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
              'Page not found',
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
              onPressed: () => context.go('/connection'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});