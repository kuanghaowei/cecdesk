import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

part 'windows_desktop_adapter.dart';
part 'macos_desktop_adapter.dart';
part 'linux_desktop_adapter.dart';

/// Desktop platform adapter for Windows, macOS, and Linux
/// Implements system tray, auto-start, and multi-display support
/// Requirements: 1.1, 1.2, 1.3, 6.2
abstract class DesktopAdapter {
  static DesktopAdapter? _instance;

  static DesktopAdapter get instance {
    if (_instance == null) {
      if (kIsWeb) {
        throw UnsupportedError('DesktopAdapter is not supported on web');
      }
      if (Platform.isWindows) {
        _instance = WindowsDesktopAdapter();
      } else if (Platform.isMacOS) {
        _instance = MacOSDesktopAdapter();
      } else if (Platform.isLinux) {
        _instance = LinuxDesktopAdapter();
      } else {
        throw UnsupportedError('DesktopAdapter is not supported on this platform');
      }
    }
    return _instance!;
  }

  /// Check if running on a desktop platform
  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// Initialize the desktop adapter
  Future<void> initialize();

  /// Dispose resources
  Future<void> dispose();

  // System Tray functionality
  /// Initialize system tray with icon and menu
  Future<void> initSystemTray({
    required String iconPath,
    required String tooltip,
    List<TrayMenuItem>? menuItems,
  });

  /// Update system tray icon
  Future<void> updateTrayIcon(String iconPath);

  /// Update system tray tooltip
  Future<void> updateTrayTooltip(String tooltip);

  /// Show system tray notification
  Future<void> showTrayNotification({
    required String title,
    required String message,
  });

  /// Hide to system tray
  Future<void> hideToTray();

  /// Show window from system tray
  Future<void> showFromTray();

  /// Destroy system tray
  Future<void> destroyTray();

  /// Stream of tray events
  Stream<TrayEvent> get onTrayEvent;

  // Auto-start functionality
  /// Enable or disable auto-start on system boot
  Future<bool> setAutoStart(bool enable);

  /// Check if auto-start is enabled
  Future<bool> isAutoStartEnabled();

  /// Get auto-start configuration
  Future<AutoStartConfig> getAutoStartConfig();

  // Multi-display support
  /// Get list of all connected displays
  Future<List<DisplayConfig>> getDisplays();

  /// Get primary display
  Future<DisplayConfig?> getPrimaryDisplay();

  /// Get display at specific point
  Future<DisplayConfig?> getDisplayAtPoint(int x, int y);

  /// Stream of display configuration changes
  Stream<List<DisplayConfig>> get onDisplaysChanged;

  // Window management
  /// Set window position
  Future<void> setWindowPosition(int x, int y);

  /// Set window size
  Future<void> setWindowSize(int width, int height);

  /// Set window bounds
  Future<void> setWindowBounds(WindowBounds bounds);

  /// Get current window bounds
  Future<WindowBounds> getWindowBounds();

  /// Minimize window
  Future<void> minimizeWindow();

  /// Maximize window
  Future<void> maximizeWindow();

  /// Restore window
  Future<void> restoreWindow();

  /// Close window
  Future<void> closeWindow();

  /// Set window always on top
  Future<void> setAlwaysOnTop(bool alwaysOnTop);

  /// Set window title
  Future<void> setWindowTitle(String title);

  /// Focus window
  Future<void> focusWindow();

  /// Check if window is focused
  Future<bool> isWindowFocused();

  /// Check if window is visible
  Future<bool> isWindowVisible();

  /// Check if window is minimized
  Future<bool> isWindowMinimized();

  /// Check if window is maximized
  Future<bool> isWindowMaximized();
}

/// System tray menu item
class TrayMenuItem {
  final String label;
  final String? iconPath;
  final bool enabled;
  final bool checked;
  final VoidCallback? onTap;
  final List<TrayMenuItem>? submenu;

  const TrayMenuItem({
    required this.label,
    this.iconPath,
    this.enabled = true,
    this.checked = false,
    this.onTap,
    this.submenu,
  });

  /// Create a separator menu item
  static TrayMenuItem separator() => const TrayMenuItem(label: '---');

  bool get isSeparator => label == '---';
}

/// System tray event types
enum TrayEventType {
  leftClick,
  rightClick,
  doubleClick,
  menuItemClick,
}

/// System tray event
class TrayEvent {
  final TrayEventType type;
  final String? menuItemLabel;
  final DateTime timestamp;

  TrayEvent({
    required this.type,
    this.menuItemLabel,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Auto-start configuration
class AutoStartConfig {
  final bool enabled;
  final String? executablePath;
  final List<String>? arguments;
  final bool minimized;

  const AutoStartConfig({
    required this.enabled,
    this.executablePath,
    this.arguments,
    this.minimized = false,
  });

  AutoStartConfig copyWith({
    bool? enabled,
    String? executablePath,
    List<String>? arguments,
    bool? minimized,
  }) {
    return AutoStartConfig(
      enabled: enabled ?? this.enabled,
      executablePath: executablePath ?? this.executablePath,
      arguments: arguments ?? this.arguments,
      minimized: minimized ?? this.minimized,
    );
  }
}

/// Display configuration
class DisplayConfig {
  final String id;
  final String name;
  final int width;
  final int height;
  final int x;
  final int y;
  final double scaleFactor;
  final int refreshRate;
  final bool isPrimary;
  final bool isInternal;

  const DisplayConfig({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    required this.x,
    required this.y,
    this.scaleFactor = 1.0,
    this.refreshRate = 60,
    this.isPrimary = false,
    this.isInternal = false,
  });

  /// Get the display bounds
  WindowBounds get bounds => WindowBounds(
        x: x,
        y: y,
        width: width,
        height: height,
      );

  /// Get the scaled resolution
  int get scaledWidth => (width * scaleFactor).round();
  int get scaledHeight => (height * scaleFactor).round();

  @override
  String toString() {
    return 'DisplayConfig(id: $id, name: $name, ${width}x$height @ $refreshRate Hz, primary: $isPrimary)';
  }
}

/// Window bounds
class WindowBounds {
  final int x;
  final int y;
  final int width;
  final int height;

  const WindowBounds({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// Check if a point is within bounds
  bool contains(int px, int py) {
    return px >= x && px < x + width && py >= y && py < y + height;
  }

  /// Get center point
  (int, int) get center => (x + width ~/ 2, y + height ~/ 2);

  @override
  String toString() => 'WindowBounds($x, $y, $width, $height)';
}
