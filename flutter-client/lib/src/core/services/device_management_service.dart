import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'secure_storage_service.dart';

/// Device record for device list management
class DeviceRecord {
  final String deviceId;
  final String deviceCode;
  String displayName;
  final String platform;
  final DateTime lastOnlineTime;
  final bool isOnline;

  DeviceRecord({
    required this.deviceId,
    required this.deviceCode,
    required this.displayName,
    required this.platform,
    required this.lastOnlineTime,
    required this.isOnline,
  });

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'deviceCode': deviceCode,
    'displayName': displayName,
    'platform': platform,
    'lastOnlineTime': lastOnlineTime.toIso8601String(),
    'isOnline': isOnline,
  };

  factory DeviceRecord.fromJson(Map<String, dynamic> json) => DeviceRecord(
    deviceId: json['deviceId'] as String,
    deviceCode: json['deviceCode'] as String,
    displayName: json['displayName'] as String,
    platform: json['platform'] as String,
    lastOnlineTime: DateTime.parse(json['lastOnlineTime'] as String),
    isOnline: json['isOnline'] as bool? ?? false,
  );

  DeviceRecord copyWith({
    String? deviceId,
    String? deviceCode,
    String? displayName,
    String? platform,
    DateTime? lastOnlineTime,
    bool? isOnline,
  }) => DeviceRecord(
    deviceId: deviceId ?? this.deviceId,
    deviceCode: deviceCode ?? this.deviceCode,
    displayName: displayName ?? this.displayName,
    platform: platform ?? this.platform,
    lastOnlineTime: lastOnlineTime ?? this.lastOnlineTime,
    isOnline: isOnline ?? this.isOnline,
  );
}

/// Device status information
class DeviceStatus {
  final String deviceId;
  final bool isOnline;
  final bool allowRemoteControl;
  final DateTime lastSeen;

  const DeviceStatus({
    required this.deviceId,
    required this.isOnline,
    required this.allowRemoteControl,
    required this.lastSeen,
  });
}

/// Remote control settings for this device
class RemoteControlSettings {
  final bool allowRemoteControl;
  final String deviceCode;
  final String connectionPassword;
  final bool requireScreenLockPassword;

  const RemoteControlSettings({
    required this.allowRemoteControl,
    required this.deviceCode,
    required this.connectionPassword,
    required this.requireScreenLockPassword,
  });

  Map<String, dynamic> toJson() => {
    'allowRemoteControl': allowRemoteControl,
    'deviceCode': deviceCode,
    'connectionPassword': connectionPassword,
    'requireScreenLockPassword': requireScreenLockPassword,
  };

  factory RemoteControlSettings.fromJson(Map<String, dynamic> json) => RemoteControlSettings(
    allowRemoteControl: json['allowRemoteControl'] as bool? ?? false,
    deviceCode: json['deviceCode'] as String? ?? '',
    connectionPassword: json['connectionPassword'] as String? ?? '',
    requireScreenLockPassword: json['requireScreenLockPassword'] as bool? ?? false,
  );

  RemoteControlSettings copyWith({
    bool? allowRemoteControl,
    String? deviceCode,
    String? connectionPassword,
    bool? requireScreenLockPassword,
  }) => RemoteControlSettings(
    allowRemoteControl: allowRemoteControl ?? this.allowRemoteControl,
    deviceCode: deviceCode ?? this.deviceCode,
    connectionPassword: connectionPassword ?? this.connectionPassword,
    requireScreenLockPassword: requireScreenLockPassword ?? this.requireScreenLockPassword,
  );
}

/// Device management service
/// Validates: Requirements 20.x, 21.x
class DeviceManagementService {
  static const String _deviceListKey = 'device_list';
  static const String _settingsKey = 'remote_control_settings';
  // ignore: unused_field
  static const String _thisDeviceKey = 'this_device';

  final SecureStorageService _secureStorage;
  RemoteControlSettings? _cachedSettings;
  String? _cachedDeviceCode;
  String? _cachedConnectionPassword;

  DeviceManagementService({required SecureStorageService secureStorage})
      : _secureStorage = secureStorage;

  // ============ Device Code and Password Generation ============

  /// Generate 9-digit device code
  /// Validates: Requirement 20.3
  Future<String> generateDeviceCode() async {
    if (_cachedDeviceCode != null) {
      return _cachedDeviceCode!;
    }
    
    final random = Random.secure();
    final code = List.generate(9, (_) => random.nextInt(10)).join();
    _cachedDeviceCode = code;
    
    // Save to storage
    await _saveThisDeviceInfo();
    
    return code;
  }

  /// Generate 9-character connection password (alphanumeric)
  /// Validates: Requirement 20.4
  Future<String> generateConnectionPassword() async {
    const chars = '0123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz';
    final random = Random.secure();
    final password = List.generate(9, (_) => chars[random.nextInt(chars.length)]).join();
    _cachedConnectionPassword = password;
    
    // Save to storage
    await _saveThisDeviceInfo();
    
    return password;
  }

  /// Refresh connection password
  /// Validates: Requirement 20.5
  Future<String> refreshConnectionPassword() async {
    final oldPassword = _cachedConnectionPassword;
    String newPassword;
    
    // Ensure new password is different from old
    do {
      newPassword = await generateConnectionPassword();
    } while (newPassword == oldPassword);
    
    return newPassword;
  }

  /// Validate device code format (9 digits)
  /// Validates: Requirement 20.3
  static bool isValidDeviceCode(String code) {
    return RegExp(r'^\d{9}$').hasMatch(code);
  }

  /// Validate connection password format (9 alphanumeric characters)
  /// Validates: Requirement 20.4
  static bool isValidConnectionPassword(String password) {
    return RegExp(r'^[0-9A-Za-z]{9}$').hasMatch(password);
  }

  // ============ Device List Management ============

  /// Get device list
  /// Validates: Requirement 21.1
  Future<List<DeviceRecord>> getDeviceList() async {
    final json = await _secureStorage.readJson(_deviceListKey);
    if (json == null) return [];
    
    final list = json['devices'] as List<dynamic>?;
    if (list == null) return [];
    
    return list
        .map((e) => DeviceRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Add device to list
  /// Validates: Requirement 21.10
  Future<void> addDevice(DeviceRecord device) async {
    final devices = await getDeviceList();
    
    // Check if device already exists
    final existingIndex = devices.indexWhere((d) => d.deviceId == device.deviceId);
    if (existingIndex >= 0) {
      devices[existingIndex] = device;
    } else {
      devices.add(device);
    }
    
    await _saveDeviceList(devices);
  }

  /// Remove device from list
  /// Validates: Requirement 21.8
  Future<void> removeDevice(String deviceId) async {
    final devices = await getDeviceList();
    devices.removeWhere((d) => d.deviceId == deviceId);
    await _saveDeviceList(devices);
  }

  /// Rename device
  /// Validates: Requirement 21.9
  Future<void> renameDevice(String deviceId, String newName) async {
    final devices = await getDeviceList();
    final index = devices.indexWhere((d) => d.deviceId == deviceId);
    if (index >= 0) {
      devices[index].displayName = newName;
      await _saveDeviceList(devices);
    }
  }

  Future<void> _saveDeviceList(List<DeviceRecord> devices) async {
    await _secureStorage.writeJson(_deviceListKey, {
      'devices': devices.map((d) => d.toJson()).toList(),
    });
  }

  // ============ Device Status ============

  /// Get device status
  /// Validates: Requirement 21.2, 21.3, 21.4
  Future<DeviceStatus> getDeviceStatus(String deviceId) async {
    // In real implementation, query server for device status
    return DeviceStatus(
      deviceId: deviceId,
      isOnline: false,
      allowRemoteControl: false,
      lastSeen: DateTime.now(),
    );
  }

  /// Watch device status changes
  Stream<DeviceStatus> watchDeviceStatus(String deviceId) async* {
    // In real implementation, use WebSocket for real-time updates
    while (true) {
      await Future.delayed(const Duration(seconds: 5));
      yield await getDeviceStatus(deviceId);
    }
  }

  // ============ This Device Control Settings ============

  /// Set allow remote control
  /// Validates: Requirement 20.1, 20.2
  Future<void> setAllowRemoteControl(bool allow) async {
    final settings = await _getSettings();
    final newSettings = settings.copyWith(allowRemoteControl: allow);
    await _saveSettings(newSettings);
  }

  /// Get allow remote control setting
  Future<bool> getAllowRemoteControl() async {
    final settings = await _getSettings();
    return settings.allowRemoteControl;
  }

  /// Set require screen lock password
  /// Validates: Requirement 20.6
  Future<void> setRequireScreenLockPassword(bool require) async {
    final settings = await _getSettings();
    final newSettings = settings.copyWith(requireScreenLockPassword: require);
    await _saveSettings(newSettings);
  }

  /// Get require screen lock password setting
  Future<bool> getRequireScreenLockPassword() async {
    final settings = await _getSettings();
    return settings.requireScreenLockPassword;
  }

  /// Verify screen lock password
  /// Validates: Requirement 20.7
  Future<bool> verifyScreenLockPassword(String password) async {
    // In real implementation, use platform-specific API to verify
    // For now, simulate verification
    return password.isNotEmpty;
  }

  /// Get current remote control settings
  Future<RemoteControlSettings> getRemoteControlSettings() async {
    return _getSettings();
  }

  Future<RemoteControlSettings> _getSettings() async {
    if (_cachedSettings != null) {
      return _cachedSettings!;
    }
    
    final json = await _secureStorage.readJson(_settingsKey);
    if (json != null) {
      _cachedSettings = RemoteControlSettings.fromJson(json);
      return _cachedSettings!;
    }
    
    // Create default settings
    final deviceCode = await generateDeviceCode();
    final connectionPassword = await generateConnectionPassword();
    
    _cachedSettings = RemoteControlSettings(
      allowRemoteControl: false,
      deviceCode: deviceCode,
      connectionPassword: connectionPassword,
      requireScreenLockPassword: false,
    );
    
    await _saveSettings(_cachedSettings!);
    return _cachedSettings!;
  }

  Future<void> _saveSettings(RemoteControlSettings settings) async {
    _cachedSettings = settings;
    await _secureStorage.writeJson(_settingsKey, settings.toJson());
  }

  Future<void> _saveThisDeviceInfo() async {
    if (_cachedDeviceCode == null || _cachedConnectionPassword == null) return;
    
    final settings = await _getSettings();
    final newSettings = settings.copyWith(
      deviceCode: _cachedDeviceCode,
      connectionPassword: _cachedConnectionPassword,
    );
    await _saveSettings(newSettings);
  }

  // ============ Connection Management ============

  /// Check if remote connection should be allowed
  /// Validates: Requirement 20.2
  Future<bool> shouldAllowConnection(String password) async {
    final settings = await _getSettings();
    
    if (!settings.allowRemoteControl) {
      return false;
    }
    
    return password == settings.connectionPassword;
  }
}

/// Device management state for UI
class DeviceManagementState {
  final bool isLoading;
  final List<DeviceRecord> devices;
  final RemoteControlSettings? settings;
  final String? error;

  const DeviceManagementState({
    this.isLoading = false,
    this.devices = const [],
    this.settings,
    this.error,
  });

  DeviceManagementState copyWith({
    bool? isLoading,
    List<DeviceRecord>? devices,
    RemoteControlSettings? settings,
    String? error,
  }) => DeviceManagementState(
    isLoading: isLoading ?? this.isLoading,
    devices: devices ?? this.devices,
    settings: settings ?? this.settings,
    error: error,
  );
}

/// State notifier for device management
class DeviceManagementStateNotifier extends StateNotifier<DeviceManagementState> {
  final DeviceManagementService _deviceService;

  DeviceManagementStateNotifier(this._deviceService) 
      : super(const DeviceManagementState()) {
    _loadData();
  }

  Future<void> _loadData() async {
    state = state.copyWith(isLoading: true);
    try {
      final devices = await _deviceService.getDeviceList();
      final settings = await _deviceService.getRemoteControlSettings();
      
      state = state.copyWith(
        isLoading: false,
        devices: devices,
        settings: settings,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> setAllowRemoteControl(bool allow) async {
    try {
      await _deviceService.setAllowRemoteControl(allow);
      final settings = await _deviceService.getRemoteControlSettings();
      state = state.copyWith(settings: settings);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> refreshConnectionPassword() async {
    try {
      await _deviceService.refreshConnectionPassword();
      final settings = await _deviceService.getRemoteControlSettings();
      state = state.copyWith(settings: settings);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> removeDevice(String deviceId) async {
    try {
      await _deviceService.removeDevice(deviceId);
      final devices = await _deviceService.getDeviceList();
      state = state.copyWith(devices: devices);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> renameDevice(String deviceId, String newName) async {
    try {
      await _deviceService.renameDevice(deviceId, newName);
      final devices = await _deviceService.getDeviceList();
      state = state.copyWith(devices: devices);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> refresh() async {
    await _loadData();
  }
}
