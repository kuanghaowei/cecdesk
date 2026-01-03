import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'src/app.dart';
import 'src/core/platform/platform_service.dart';
import 'src/core/rust_bridge/rust_bridge.dart';
import 'src/core/platform/desktop_initializer.dart'
    if (dart.library.html) 'src/core/platform/web_initializer.dart'
    as platform_init;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize platform-specific services (desktop only)
  if (!kIsWeb) {
    await platform_init.initializeDesktop();
  }
  
  // Initialize Rust core engine
  await RustBridge.initialize();
  
  // Initialize platform services
  await PlatformService.initialize();
  
  runApp(
    const ProviderScope(
      child: RemoteDesktopApp(),
    ),
  );
}
