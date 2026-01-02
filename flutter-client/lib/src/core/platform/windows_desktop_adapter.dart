part of 'desktop_adapter.dart';

/// Windows-specific desktop adapter implementation
/// Requirements: 1.1 (Windows 10/11 support)
class WindowsDesktopAdapter extends DesktopAdapter {
  bool _initialized = false;
  final StreamController<TrayEvent> _trayEventController =
      StreamController<TrayEvent>.broadcast();
  final StreamController<List<DisplayConfig>> _displayChangeController =
      StreamController<List<DisplayConfig>>.broadcast();

  // Cached display list
  List<DisplayConfig>? _cachedDisplays;
  Timer? _displayPollTimer;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    // Start polling for display changes (Windows doesn't have a native event)
    _displayPollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkDisplayChanges(),
    );

    _initialized = true;
    debugPrint('WindowsDesktopAdapter initialized');
  }

  @override
  Future<void> dispose() async {
    _displayPollTimer?.cancel();
    await _trayEventController.close();
    await _displayChangeController.close();
    _initialized = false;
  }

  // System Tray Implementation
  @override
  Future<void> initSystemTray({
    required String iconPath,
    required String tooltip,
    List<TrayMenuItem>? menuItems,
  }) async {
    // In production, this would use system_tray package
    // For now, we provide a working stub that can be enhanced
    debugPrint('Windows: Initializing system tray with icon: $iconPath');
    // SystemTray().initSystemTray(
    //   title: tooltip,
    //   iconPath: iconPath,
    // );
  }

  @override
  Future<void> updateTrayIcon(String iconPath) async {
    debugPrint('Windows: Updating tray icon to: $iconPath');
  }

  @override
  Future<void> updateTrayTooltip(String tooltip) async {
    debugPrint('Windows: Updating tray tooltip to: $tooltip');
  }

  @override
  Future<void> showTrayNotification({
    required String title,
    required String message,
  }) async {
    debugPrint('Windows: Showing tray notification - $title: $message');
    // In production, would use Windows toast notifications
  }

  @override
  Future<void> hideToTray() async {
    debugPrint('Windows: Hiding window to tray');
    // In production, would use window_manager to hide window
  }

  @override
  Future<void> showFromTray() async {
    debugPrint('Windows: Showing window from tray');
    // In production, would use window_manager to show and focus window
  }

  @override
  Future<void> destroyTray() async {
    debugPrint('Windows: Destroying system tray');
  }

  @override
  Stream<TrayEvent> get onTrayEvent => _trayEventController.stream;

  // Auto-start Implementation
  @override
  Future<bool> setAutoStart(bool enable) async {
    try {
      final executablePath = Platform.resolvedExecutable;
      final appName = 'CECRemote';

      if (enable) {
        // Add to Windows registry for auto-start
        // HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run
        final result = await Process.run('reg', [
          'add',
          r'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run',
          '/v',
          appName,
          '/t',
          'REG_SZ',
          '/d',
          '"$executablePath" --minimized',
          '/f',
        ]);
        return result.exitCode == 0;
      } else {
        // Remove from Windows registry
        final result = await Process.run('reg', [
          'delete',
          r'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run',
          '/v',
          appName,
          '/f',
        ]);
        return result.exitCode == 0;
      }
    } catch (e) {
      debugPrint('Windows: Failed to set auto-start: $e');
      return false;
    }
  }

  @override
  Future<bool> isAutoStartEnabled() async {
    try {
      final appName = 'CECRemote';
      final result = await Process.run('reg', [
        'query',
        r'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run',
        '/v',
        appName,
      ]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<AutoStartConfig> getAutoStartConfig() async {
    final enabled = await isAutoStartEnabled();
    return AutoStartConfig(
      enabled: enabled,
      executablePath: Platform.resolvedExecutable,
      arguments: enabled ? ['--minimized'] : null,
      minimized: enabled,
    );
  }

  // Multi-display Implementation
  @override
  Future<List<DisplayConfig>> getDisplays() async {
    try {
      // Use PowerShell to get display information
      final result = await Process.run('powershell', [
        '-Command',
        '''
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.Screen]::AllScreens | ForEach-Object {
          Write-Output ("\$(\$_.DeviceName)|\$(\$_.Bounds.X)|\$(\$_.Bounds.Y)|\$(\$_.Bounds.Width)|\$(\$_.Bounds.Height)|\$(\$_.Primary)")
        }
        '''
      ]);

      if (result.exitCode != 0) {
        return _getDefaultDisplays();
      }

      final lines = (result.stdout as String).trim().split('\n');
      final displays = <DisplayConfig>[];

      for (int i = 0; i < lines.length; i++) {
        final parts = lines[i].trim().split('|');
        if (parts.length >= 6) {
          displays.add(DisplayConfig(
            id: 'display_$i',
            name: parts[0].replaceAll(r'\\.\', ''),
            x: int.tryParse(parts[1]) ?? 0,
            y: int.tryParse(parts[2]) ?? 0,
            width: int.tryParse(parts[3]) ?? 1920,
            height: int.tryParse(parts[4]) ?? 1080,
            isPrimary: parts[5].toLowerCase() == 'true',
            scaleFactor: 1.0, // Would need additional API call for DPI
            refreshRate: 60, // Would need additional API call
          ));
        }
      }

      _cachedDisplays = displays;
      return displays.isEmpty ? _getDefaultDisplays() : displays;
    } catch (e) {
      debugPrint('Windows: Failed to get displays: $e');
      return _getDefaultDisplays();
    }
  }

  List<DisplayConfig> _getDefaultDisplays() {
    return [
      const DisplayConfig(
        id: 'display_0',
        name: 'Primary Display',
        x: 0,
        y: 0,
        width: 1920,
        height: 1080,
        isPrimary: true,
        scaleFactor: 1.0,
        refreshRate: 60,
      ),
    ];
  }

  @override
  Future<DisplayConfig?> getPrimaryDisplay() async {
    final displays = await getDisplays();
    return displays.firstWhere(
      (d) => d.isPrimary,
      orElse: () => displays.first,
    );
  }

  @override
  Future<DisplayConfig?> getDisplayAtPoint(int x, int y) async {
    final displays = await getDisplays();
    for (final display in displays) {
      if (display.bounds.contains(x, y)) {
        return display;
      }
    }
    return null;
  }

  @override
  Stream<List<DisplayConfig>> get onDisplaysChanged =>
      _displayChangeController.stream;

  Future<void> _checkDisplayChanges() async {
    final newDisplays = await getDisplays();
    if (_cachedDisplays != null && !_displaysEqual(_cachedDisplays!, newDisplays)) {
      _displayChangeController.add(newDisplays);
    }
    _cachedDisplays = newDisplays;
  }

  bool _displaysEqual(List<DisplayConfig> a, List<DisplayConfig> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].width != b[i].width ||
          a[i].height != b[i].height) {
        return false;
      }
    }
    return true;
  }

  // Window Management
  @override
  Future<void> setWindowPosition(int x, int y) async {
    debugPrint('Windows: Setting window position to ($x, $y)');
    // In production, would use window_manager
  }

  @override
  Future<void> setWindowSize(int width, int height) async {
    debugPrint('Windows: Setting window size to ${width}x$height');
  }

  @override
  Future<void> setWindowBounds(WindowBounds bounds) async {
    await setWindowPosition(bounds.x, bounds.y);
    await setWindowSize(bounds.width, bounds.height);
  }

  @override
  Future<WindowBounds> getWindowBounds() async {
    // In production, would use window_manager
    return const WindowBounds(x: 0, y: 0, width: 1280, height: 720);
  }

  @override
  Future<void> minimizeWindow() async {
    debugPrint('Windows: Minimizing window');
  }

  @override
  Future<void> maximizeWindow() async {
    debugPrint('Windows: Maximizing window');
  }

  @override
  Future<void> restoreWindow() async {
    debugPrint('Windows: Restoring window');
  }

  @override
  Future<void> closeWindow() async {
    debugPrint('Windows: Closing window');
    exit(0);
  }

  @override
  Future<void> setAlwaysOnTop(bool alwaysOnTop) async {
    debugPrint('Windows: Setting always on top: $alwaysOnTop');
  }

  @override
  Future<void> setWindowTitle(String title) async {
    debugPrint('Windows: Setting window title: $title');
  }

  @override
  Future<void> focusWindow() async {
    debugPrint('Windows: Focusing window');
  }

  @override
  Future<bool> isWindowFocused() async => true;

  @override
  Future<bool> isWindowVisible() async => true;

  @override
  Future<bool> isWindowMinimized() async => false;

  @override
  Future<bool> isWindowMaximized() async => false;
}
