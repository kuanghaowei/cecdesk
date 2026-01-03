part of 'desktop_adapter.dart';

/// Linux-specific desktop adapter implementation
/// Requirements: 1.3 (Ubuntu Desktop 20.04+ support)
class LinuxDesktopAdapter extends DesktopAdapter {
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
    debugPrint('LinuxDesktopAdapter initialized');
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
    debugPrint('Linux: Initializing system tray (AppIndicator)');
  }

  @override
  Future<void> updateTrayIcon(String iconPath) async {}

  @override
  Future<void> updateTrayTooltip(String tooltip) async {}

  @override
  Future<void> showTrayNotification({
    required String title,
    required String message,
  }) async {
    try {
      await Process.run('notify-send', [title, message]);
    } catch (e) {
      debugPrint('Linux: Failed to show notification: $e');
    }
  }

  @override
  Future<void> hideToTray() async {}

  @override
  Future<void> showFromTray() async {}

  @override
  Future<void> destroyTray() async {}

  @override
  Stream<TrayEvent> get onTrayEvent => _trayEventController.stream;

  @override
  Future<bool> setAutoStart(bool enable) async {
    try {
      final homeDir = Platform.environment['HOME'] ?? '';
      final autostartDir = '$homeDir/.config/autostart';
      final desktopFile = '$autostartDir/cec-remote.desktop';

      if (enable) {
        await Directory(autostartDir).create(recursive: true);
        final executablePath = Platform.resolvedExecutable;
        final content = '''
[Desktop Entry]
Type=Application
Name=CEC Remote
Exec=$executablePath --minimized
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
''';
        await File(desktopFile).writeAsString(content);
        return true;
      } else {
        final file = File(desktopFile);
        if (await file.exists()) {
          await file.delete();
        }
        return true;
      }
    } catch (e) {
      debugPrint('Linux: Failed to set auto-start: $e');
      return false;
    }
  }

  @override
  Future<bool> isAutoStartEnabled() async {
    try {
      final homeDir = Platform.environment['HOME'] ?? '';
      final desktopFile = '$homeDir/.config/autostart/cec-remote.desktop';
      return File(desktopFile).existsSync();
    } catch (e) {
      return false;
    }
  }

  @override
  Future<AutoStartConfig> getAutoStartConfig() async {
    return AutoStartConfig(
      enabled: await isAutoStartEnabled(),
      executablePath: Platform.resolvedExecutable,
    );
  }

  @override
  Future<List<DisplayConfig>> getDisplays() async {
    try {
      final result = await Process.run('xrandr', ['--query']);
      if (result.exitCode != 0) return _getDefaultDisplays();

      final output = result.stdout as String;
      final displays = <DisplayConfig>[];
      final lines = output.split('\n');

      int index = 0;
      // ignore: unused_local_variable
      int xOffset = 0;

      for (final line in lines) {
        if (line.contains(' connected')) {
          final parts = line.split(' ');
          final name = parts[0];
          final isPrimary = line.contains('primary');

          // Parse resolution from the connected line or next line
          final resMatch = RegExp(r'(\d+)x(\d+)\+(\d+)\+(\d+)').firstMatch(line);
          if (resMatch != null) {
            final width = int.parse(resMatch.group(1)!);
            final height = int.parse(resMatch.group(2)!);
            final x = int.parse(resMatch.group(3)!);
            final y = int.parse(resMatch.group(4)!);

            displays.add(DisplayConfig(
              id: 'display_$index',
              name: name,
              x: x,
              y: y,
              width: width,
              height: height,
              isPrimary: isPrimary,
              scaleFactor: 1.0,
              refreshRate: 60,
            ));
            xOffset = x + width;
            index++;
          }
        }
      }

      _cachedDisplays = displays;
      return displays.isEmpty ? _getDefaultDisplays() : displays;
    } catch (e) {
      debugPrint('Linux: Failed to get displays: $e');
      return _getDefaultDisplays();
    }
  }

  List<DisplayConfig> _getDefaultDisplays() {
    return [
      const DisplayConfig(
        id: 'display_0',
        name: 'Primary Display',
        x: 0, y: 0,
        width: 1920, height: 1080,
        isPrimary: true,
        scaleFactor: 1.0,
        refreshRate: 60,
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
