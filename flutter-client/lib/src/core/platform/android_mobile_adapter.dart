part of 'mobile_adapter.dart';

/// Android-specific mobile adapter implementation
/// Requirements: 1.5 (Android 8.0+ support)
class AndroidMobileAdapter extends MobileAdapter {
  bool _initialized = false;
  TouchSettings _touchSettings = const TouchSettings();

  final StreamController<InputEvent> _inputEventController =
      StreamController<InputEvent>.broadcast();
  final StreamController<BackgroundState> _backgroundStateController =
      StreamController<BackgroundState>.broadcast();
  final StreamController<NotificationEvent> _notificationEventController =
      StreamController<NotificationEvent>.broadcast();
  final StreamController<ThermalState> _thermalStateController =
      StreamController<ThermalState>.broadcast();

  bool _isInBackground = false;
  bool _backgroundServiceRunning = false;
  String? _notificationToken;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    debugPrint('AndroidMobileAdapter initialized');
  }

  @override
  Future<void> dispose() async {
    await _inputEventController.close();
    await _backgroundStateController.close();
    await _notificationEventController.close();
    await _thermalStateController.close();
    _initialized = false;
  }

  // Touch Input Adaptation
  @override
  MouseEvent touchToMouseEvent(TouchEvent touch) {
    final type = switch (touch.phase) {
      TouchPhase.began => MouseEventType.down,
      TouchPhase.moved => MouseEventType.move,
      TouchPhase.ended => MouseEventType.up,
      TouchPhase.cancelled => MouseEventType.up,
      TouchPhase.stationary => MouseEventType.move,
    };

    return MouseEvent(
      type: type,
      x: touch.x * _touchSettings.sensitivity,
      y: touch.y * _touchSettings.sensitivity,
      button: MouseButton.left,
      timestamp: touch.timestamp,
    );
  }

  @override
  List<InputEvent> gestureToInputEvents(GestureEvent gesture) {
    final events = <InputEvent>[];
    final now = DateTime.now();

    switch (gesture.type) {
      case GestureType.tap:
        if (_touchSettings.tapToClick) {
          events.add(InputEvent(
            type: InputEventType.mouse,
            data: {'action': 'click', 'button': 'left', 'x': gesture.x, 'y': gesture.y},
            timestamp: now,
          ));
        }
        break;

      case GestureType.doubleTap:
        events.add(InputEvent(
          type: InputEventType.mouse,
          data: {'action': 'doubleClick', 'button': 'left', 'x': gesture.x, 'y': gesture.y},
          timestamp: now,
        ));
        break;

      case GestureType.longPress:
        if (_touchSettings.twoFingerRightClick) {
          events.add(InputEvent(
            type: InputEventType.mouse,
            data: {'action': 'click', 'button': 'right', 'x': gesture.x, 'y': gesture.y},
            timestamp: now,
          ));
        }
        break;

      case GestureType.twoFingerTap:
        if (_touchSettings.twoFingerRightClick) {
          events.add(InputEvent(
            type: InputEventType.mouse,
            data: {'action': 'click', 'button': 'right', 'x': gesture.x, 'y': gesture.y},
            timestamp: now,
          ));
        }
        break;

      case GestureType.threeFingerTap:
        if (_touchSettings.threeFingerMiddleClick) {
          events.add(InputEvent(
            type: InputEventType.mouse,
            data: {'action': 'click', 'button': 'middle', 'x': gesture.x, 'y': gesture.y},
            timestamp: now,
          ));
        }
        break;

      case GestureType.pinch:
        events.add(InputEvent(
          type: InputEventType.scroll,
          data: {
            'deltaY': (gesture.scale - 1.0) * 100 * _touchSettings.scrollSpeed,
            'x': gesture.x,
            'y': gesture.y,
          },
          timestamp: now,
        ));
        break;

      case GestureType.pan:
        events.add(InputEvent(
          type: InputEventType.scroll,
          data: {
            'deltaX': gesture.velocityX * _touchSettings.scrollSpeed,
            'deltaY': gesture.velocityY * _touchSettings.scrollSpeed,
            'x': gesture.x,
            'y': gesture.y,
          },
          timestamp: now,
        ));
        break;

      default:
        break;
    }

    if (_touchSettings.hapticFeedback && events.isNotEmpty) {
      triggerHapticFeedback(HapticFeedbackType.light);
    }

    return events;
  }

  @override
  TouchSettings getTouchSettings() => _touchSettings;

  @override
  Future<void> updateTouchSettings(TouchSettings settings) async {
    _touchSettings = settings;
  }

  @override
  Future<void> setTouchEmulation(bool enabled) async {
    debugPrint('Android: Touch emulation ${enabled ? 'enabled' : 'disabled'}');
  }

  @override
  Stream<InputEvent> get onInputEvent => _inputEventController.stream;

  // Background Management
  @override
  Future<bool> requestBackgroundPermission() async {
    // Android requires FOREGROUND_SERVICE permission in manifest
    // and potentially IGNORE_BATTERY_OPTIMIZATIONS
    return true;
  }

  @override
  Future<bool> isBackgroundAllowed() async {
    return true;
  }

  @override
  Future<bool> startBackgroundService() async {
    // In production, would start a foreground service
    _backgroundServiceRunning = true;
    _emitBackgroundState();
    debugPrint('Android: Background service started');
    return true;
  }

  @override
  Future<void> stopBackgroundService() async {
    _backgroundServiceRunning = false;
    _emitBackgroundState();
    debugPrint('Android: Background service stopped');
  }

  @override
  Future<bool> isBackgroundServiceRunning() async => _backgroundServiceRunning;

  @override
  Future<BackgroundState> getBackgroundState() async {
    return BackgroundState(
      isInBackground: _isInBackground,
      serviceRunning: _backgroundServiceRunning,
    );
  }

  @override
  Stream<BackgroundState> get onBackgroundStateChanged =>
      _backgroundStateController.stream;

  void _emitBackgroundState() {
    _backgroundStateController.add(BackgroundState(
      isInBackground: _isInBackground,
      serviceRunning: _backgroundServiceRunning,
    ));
  }

  // Push Notifications
  @override
  Future<bool> requestNotificationPermission() async {
    // Android 13+ requires POST_NOTIFICATIONS permission
    return true;
  }

  @override
  Future<bool> areNotificationsAllowed() async => true;

  @override
  Future<String?> getNotificationToken() async => _notificationToken;

  @override
  Future<void> registerForNotifications() async {
    // In production, would use Firebase Cloud Messaging
    _notificationToken = 'android_fcm_token_placeholder';
    debugPrint('Android: Registered for notifications');
  }

  @override
  Future<void> unregisterFromNotifications() async {
    _notificationToken = null;
    debugPrint('Android: Unregistered from notifications');
  }

  @override
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
    NotificationPriority priority = NotificationPriority.normal,
  }) async {
    debugPrint('Android: Showing notification - $title: $body');
    // In production, would use flutter_local_notifications
  }

  @override
  Future<void> cancelNotification(int id) async {}

  @override
  Future<void> cancelAllNotifications() async {}

  @override
  Stream<NotificationEvent> get onNotificationEvent =>
      _notificationEventController.stream;

  // Screen and Display
  @override
  Future<void> setKeepScreenAwake(bool awake) async {
    // In production, would use wakelock package
    debugPrint('Android: Keep screen awake: $awake');
  }

  @override
  Future<ScreenOrientation> getScreenOrientation() async {
    return ScreenOrientation.portrait;
  }

  @override
  Future<void> lockOrientation(ScreenOrientation orientation) async {
    final orientations = switch (orientation) {
      ScreenOrientation.portrait => [DeviceOrientation.portraitUp],
      ScreenOrientation.portraitUpsideDown => [DeviceOrientation.portraitDown],
      ScreenOrientation.landscapeLeft => [DeviceOrientation.landscapeLeft],
      ScreenOrientation.landscapeRight => [DeviceOrientation.landscapeRight],
    };
    await SystemChrome.setPreferredOrientations(orientations);
  }

  @override
  Future<void> unlockOrientation() async {
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  @override
  Future<EdgeInsets> getSafeAreaInsets() async {
    return const EdgeInsets(top: 24, bottom: 0, left: 0, right: 0);
  }

  // Haptic Feedback
  @override
  Future<void> triggerHapticFeedback(HapticFeedbackType type) async {
    switch (type) {
      case HapticFeedbackType.light:
        await HapticFeedback.lightImpact();
        break;
      case HapticFeedbackType.medium:
        await HapticFeedback.mediumImpact();
        break;
      case HapticFeedbackType.heavy:
        await HapticFeedback.heavyImpact();
        break;
      case HapticFeedbackType.selection:
        await HapticFeedback.selectionClick();
        break;
      default:
        await HapticFeedback.vibrate();
    }
  }

  // Battery and Performance
  @override
  Future<int> getBatteryLevel() async => 100;

  @override
  Future<bool> isCharging() async => false;

  @override
  Future<ThermalState> getThermalState() async => ThermalState.nominal;

  @override
  Stream<ThermalState> get onThermalStateChanged => _thermalStateController.stream;
}
