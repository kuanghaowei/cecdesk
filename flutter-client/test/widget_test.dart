// Basic Flutter widget test for CEC Remote app
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:remote_desktop_client/src/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Set a larger screen size to avoid overflow issues
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: RemoteDesktopApp(),
      ),
    );

    // Allow the app to settle
    await tester.pumpAndSettle();

    // Verify that the app renders without errors
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
