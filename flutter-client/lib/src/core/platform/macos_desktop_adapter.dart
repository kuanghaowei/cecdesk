part of 'desktop_adapter.dart';

/// macOS-specific desktop adapter implementation
/// Requirements: 1.2 (macOS 11+ support)
class MacOSDesktopAdapter extends DesktopAdapter {
  bool _initialized = false;
  final StreamController<TrayEvent> _trayEventController =
      StreamController<TrayEvent>.broadcast();
  final StreamController<List<DisplayConfig>> _displayChangeController =
      StreamController<List<DisplayConfig>>.broadcast();

  List<DisplayConfig>? _cachedDisplays;
  Timer? _displayPollTimer;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _displayPollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkDisplayChanges(),
    );
    _initialized = true;
    debugPrint('MacOSDesktopAdapter initialized');
  }

  @override
  Future<void> dispose() async {
    _displayPollTimer?.cancel();
    await _trayEventController.close();
    await _displayChangeController.close();
    _initialized = false;
  }

  @override
  Future<void> initSystemTray({
    required String iconPath,
    required String tooltip,
    List<TrayMenuItem>? menuItems,
  }) async {
    debugPrint('macOS: Initializing menu bar item');
  }

  @override
  Future<void> updateTrayIcon(String iconPath) async {}

  @override
  Future<void> updateTrayTooltip(String tooltip) async {}

  @override
  Future<void> showTrayNotification({
    required String title,
    required String message,
  }) async {}

  @override
  Future<void> hideToTray() async {}

  @override
  Future<void> showFromTray() async {}

  @override
  Future<void> destroyTray() async {}

  @override
  Stream<TrayEvent> get onTrayEvent => _trayEventController.stream;

  @override
  Future<bool> setAutoStart(bool enable) async => false;

  @override
  Future<bool> isAutoStartEnabled() async => false;

  @override
  Future<AutoStartConfig> getAutoStartConfig() async {
    return AutoStartConfig(enabled: false, executablePath: Platform.resolvedExecutable);
  }

  @override
  Future<List<DisplayConfig>> getDisplays() async {
    return [
      const DisplayConfig(
        id: 'display_0', name: 'Built-in Display',
        x: 0, y: 0, width: 2560, height: 1600,
        isPrimary: true, scaleFactor: 2.0, refreshRate: 60, isInternal: true,
      ),
    ];
  }

  @override
  Future<DisplayConfig?> getPrimaryDisplay() async {
    final displays = await getDisplays();
    return displays.firstWhere((d) => d.isPrimary, orElse: () => displays.first);
  }

  @override
  Future<DisplayConfig?> getDisplayAtPoint(int x, int y) async {
    final displays = await getDisplays();
    for (final display in displays) {
      if (display.bounds.contains(x, y)) return display;
    }
    return null;
  }

  @override
  Stream<List<DisplayConfig>> get onDisplaysChanged => _displayChangeController.stream;

  Future<void> _checkDisplayChanges() async {
    final newDisplays = await getDisplays();
    if (_cachedDisplays != null && _cachedDisplays!.length != newDisplays.length) {
      _displayChangeController.add(newDisplays);
    }
    _cachedDisplays = newDisplays;
  }

  @override
  Future<void> setWindowPosition(int x, int y) async {}
  @override
  Future<void> setWindowSize(int width, int height) async {}
  @override
  Future<void> setWindowBounds(WindowBounds bounds) async {}
  @override
  Future<WindowBounds> getWindowBounds() async => const WindowBounds(x: 0, y: 0, width: 1280, height: 720);
  @override
  Future<void> minimizeWindow() async {}
  @override
  Future<void> maximizeWindow() async {}
  @override
  Future<void> restoreWindow() async {}
  @override
  Future<void> closeWindow() async => exit(0);
  @override
  Future<void> setAlwaysOnTop(bool alwaysOnTop) async {}
  @override
  Future<void> setWindowTitle(String title) async {}
  @override
  Future<void> focusWindow() async {}
  @override
  Future<bool> isWindowFocused() async => true;
  @override
  Future<bool> isWindowVisible() async => true;
  @override
  Future<bool> isWindowMinimized() async => false;
  @override
  Future<bool> isWindowMaximized() async => false;
}
