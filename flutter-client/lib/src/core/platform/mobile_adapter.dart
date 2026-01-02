import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

part 'android_mobile_adapter.dart';
part 'ios_mobile_adapter.dart';

/// Mobile platform adapter for iOS and Android
/// Implements touch input, background management, and push notifications
/// Requirements: 1.4, 1.5
abstract class MobileAdapter {
  static MobileAdapter? _instance;

  static MobileAdapter get instance {
    if (_instance == null) {
      if (kIsWeb) {
        throw UnsupportedError('MobileAdapter is not supported on web');
      }
      if (Platform.isAndroid) {
        _instance = AndroidMobileAdapter();
      } else if (Platform.isIOS) {
        _instance = IOSMobileAdapter();
      } else {
        throw UnsupportedError('MobileAdapter is not supported on this platform');
      }
    }
    return _instance!;
  }

  /// Check if running on a mobile platform
  static bool get isMobile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Initialize the mobile adapter
  Future<void> initialize();

  /// Dispose resources
  Future<void> dispose();

  // Touch Input Adaptation
  /// Convert touch event to mouse event
  MouseEvent touchToMouseEvent(TouchEvent touch);

  /// Convert multi-touch gesture to input events
  List<InputEvent> gestureToInputEvents(GestureEvent gesture);

  /// Get touch sensitivity settings
  TouchSettings getTouchSettings();

  /// Update touch sensitivity settings
  Future<void> updateTouchSettings(TouchSettings settings);

  /// Enable/disable touch-to-mouse emulation
  Future<void> setTouchEmulation(bool enabled);

  /// Stream of processed input events
  Stream<InputEvent> get onInputEvent;

  // Background Management
  /// Request background execution permission
  Future<bool> requestBackgroundPermission();

  /// Check if background execution is allowed
  Future<bool> isBackgroundAllowed();

  /// Start background service for maintaining connection
  Future<bool> startBackgroundService();

  /// Stop background service
  Future<void> stopBackgroundService();

  /// Check if background service is running
  Future<bool> isBackgroundServiceRunning();

  /// Get background execution state
  Future<BackgroundState> getBackgroundState();

  /// Stream of background state changes
  Stream<BackgroundState> get onBackgroundStateChanged;

  // Push Notifications
  /// Request push notification permission
  Future<bool> requestNotificationPermission();

  /// Check if notifications are allowed
  Future<bool> areNotificationsAllowed();

  /// Get push notification token
  Future<String?> getNotificationToken();

  /// Register for push notifications
  Future<void> registerForNotifications();

  /// Unregister from push notifications
  Future<void> unregisterFromNotifications();

  /// Show local notification
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
    NotificationPriority priority = NotificationPriority.normal,
  });

  /// Cancel notification by ID
  Future<void> cancelNotification(int id);

  /// Cancel all notifications
  Future<void> cancelAllNotifications();

  /// Stream of notification events
  Stream<NotificationEvent> get onNotificationEvent;

  // Screen and Display
  /// Keep screen awake during remote session
  Future<void> setKeepScreenAwake(bool awake);

  /// Get screen orientation
  Future<ScreenOrientation> getScreenOrientation();

  /// Lock screen orientation
  Future<void> lockOrientation(ScreenOrientation orientation);

  /// Unlock screen orientation
  Future<void> unlockOrientation();

  /// Get safe area insets
  Future<EdgeInsets> getSafeAreaInsets();

  // Haptic Feedback
  /// Trigger haptic feedback
  Future<void> triggerHapticFeedback(HapticFeedbackType type);

  // Battery and Performance
  /// Get battery level
  Future<int> getBatteryLevel();

  /// Check if device is charging
  Future<bool> isCharging();

  /// Get thermal state
  Future<ThermalState> getThermalState();

  /// Stream of thermal state changes
  Stream<ThermalState> get onThermalStateChanged;
}

/// Touch event data
class TouchEvent {
  final TouchPhase phase;
  final double x;
  final double y;
  final double pressure;
  final double radius;
  final int pointerId;
  final DateTime timestamp;

  const TouchEvent({
    required this.phase,
    required this.x,
    required this.y,
    this.pressure = 1.0,
    this.radius = 1.0,
    this.pointerId = 0,
    required this.timestamp,
  });
}

enum TouchPhase { began, moved, stationary, ended, cancelled }

/// Mouse event data (converted from touch)
class MouseEvent {
  final MouseEventType type;
  final double x;
  final double y;
  final MouseButton button;
  final DateTime timestamp;

  const MouseEvent({
    required this.type,
    required this.x,
    required this.y,
    this.button = MouseButton.left,
    required this.timestamp,
  });
}

enum MouseEventType { move, down, up, click, doubleClick, scroll }
enum MouseButton { left, right, middle }

/// Gesture event data
class GestureEvent {
  final GestureType type;
  final double x;
  final double y;
  final double scale;
  final double rotation;
  final double velocityX;
  final double velocityY;
  final int touchCount;
  final DateTime timestamp;

  const GestureEvent({
    required this.type,
    required this.x,
    required this.y,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.velocityX = 0.0,
    this.velocityY = 0.0,
    this.touchCount = 1,
    required this.timestamp,
  });
}

enum GestureType {
  tap,
  doubleTap,
  longPress,
  pan,
  pinch,
  rotate,
  swipe,
  twoFingerTap,
  threeFingerTap,
}

/// Generic input event
class InputEvent {
  final InputEventType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  const InputEvent({
    required this.type,
    required this.data,
    required this.timestamp,
  });
}

enum InputEventType { mouse, keyboard, scroll, gesture }

/// Touch sensitivity settings
class TouchSettings {
  final double sensitivity;
  final double scrollSpeed;
  final bool tapToClick;
  final bool twoFingerRightClick;
  final bool threeFingerMiddleClick;
  final int longPressDuration;
  final bool hapticFeedback;

  const TouchSettings({
    this.sensitivity = 1.0,
    this.scrollSpeed = 1.0,
    this.tapToClick = true,
    this.twoFingerRightClick = true,
    this.threeFingerMiddleClick = true,
    this.longPressDuration = 500,
    this.hapticFeedback = true,
  });

  TouchSettings copyWith({
    double? sensitivity,
    double? scrollSpeed,
    bool? tapToClick,
    bool? twoFingerRightClick,
    bool? threeFingerMiddleClick,
    int? longPressDuration,
    bool? hapticFeedback,
  }) {
    return TouchSettings(
      sensitivity: sensitivity ?? this.sensitivity,
      scrollSpeed: scrollSpeed ?? this.scrollSpeed,
      tapToClick: tapToClick ?? this.tapToClick,
      twoFingerRightClick: twoFingerRightClick ?? this.twoFingerRightClick,
      threeFingerMiddleClick: threeFingerMiddleClick ?? this.threeFingerMiddleClick,
      longPressDuration: longPressDuration ?? this.longPressDuration,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
    );
  }
}

/// Background execution state
class BackgroundState {
  final bool isInBackground;
  final bool serviceRunning;
  final DateTime? backgroundSince;
  final Duration? remainingTime;

  const BackgroundState({
    required this.isInBackground,
    required this.serviceRunning,
    this.backgroundSince,
    this.remainingTime,
  });
}

/// Notification event
class NotificationEvent {
  final NotificationEventType type;
  final String? payload;
  final DateTime timestamp;

  const NotificationEvent({
    required this.type,
    this.payload,
    required this.timestamp,
  });
}

enum NotificationEventType { received, tapped, dismissed }
enum NotificationPriority { low, normal, high, urgent }

/// Screen orientation
enum ScreenOrientation {
  portrait,
  portraitUpsideDown,
  landscapeLeft,
  landscapeRight,
}

/// Edge insets for safe area
class EdgeInsets {
  final double top;
  final double bottom;
  final double left;
  final double right;

  const EdgeInsets({
    this.top = 0,
    this.bottom = 0,
    this.left = 0,
    this.right = 0,
  });

  static const EdgeInsets zero = EdgeInsets();
}

/// Haptic feedback types
enum HapticFeedbackType {
  light,
  medium,
  heavy,
  selection,
  success,
  warning,
  error,
}

/// Thermal state
enum ThermalState { nominal, fair, serious, critical }
