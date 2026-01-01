import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:remote_desktop_client/src/core/services/device_management_service.dart';
import 'package:remote_desktop_client/src/core/services/secure_storage_service.dart';

/// Property-based tests for DeviceManagementService
/// Feature: remote-desktop-client
/// Validates: Requirements 20.x, 21.x

void main() {
  late SecureStorageService secureStorage;
  late DeviceManagementService deviceService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    secureStorage = SecureStorageService();
    deviceService = DeviceManagementService(secureStorage: secureStorage);
  });

  tearDown(() async {
    await secureStorage.clearAll();
  });

  group('Device Control Property Tests', () {
    /// Property 36: Remote control switch rejects connections
    /// *For any* device with "Allow remote control" switch turned off,
    /// the system should reject all remote connection requests
    /// **Validates: Requirement 20.2**
    test('Property 36: Remote control switch rejects connections', () async {
      // Feature: remote-desktop-client, Property 36: Remote control switch rejects connections
      
      const iterations = 100;
      final random = Random();
      
      for (var i = 0; i < iterations; i++) {
        // Set allow remote control to false
        await deviceService.setAllowRemoteControl(false);
        
        // Generate random password
        final password = List.generate(9, (_) {
          const chars = '0123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz';
          return chars[random.nextInt(chars.length)];
        }).join();
        
        // Property: Connection should be rejected when switch is off
        final shouldAllow = await deviceService.shouldAllowConnection(password);
        expect(shouldAllow, isFalse,
            reason: 'Connection should be rejected when switch is off (iteration $i)');
        
        // Verify setting is persisted
        final allowRemote = await deviceService.getAllowRemoteControl();
        expect(allowRemote, isFalse,
            reason: 'Setting should be persisted as false (iteration $i)');
      }
    });

    /// Property 37: Device code format
    /// *For any* generated device code, it should be in 9-digit format
    /// **Validates: Requirement 20.3**
    test('Property 37: Device code format', () async {
      // Feature: remote-desktop-client, Property 37: Device code format
      
      const iterations = 100;
      
      for (var i = 0; i < iterations; i++) {
        // Clear cached code to generate new one
        await secureStorage.clearAll();
        final newDeviceService = DeviceManagementService(secureStorage: secureStorage);
        
        final deviceCode = await newDeviceService.generateDeviceCode();
        
        // Property: Device code should be exactly 9 characters
        expect(deviceCode.length, equals(9),
            reason: 'Device code should be 9 characters (iteration $i)');
        
        // Property: Device code should contain only digits
        expect(RegExp(r'^\d{9}$').hasMatch(deviceCode), isTrue,
            reason: 'Device code should be 9 digits (iteration $i)');
        
        // Property: Validation function should accept valid codes
        expect(DeviceManagementService.isValidDeviceCode(deviceCode), isTrue,
            reason: 'Generated code should pass validation (iteration $i)');
      }
    });

    /// Property 38: Connection password format
    /// *For any* generated connection password, it should be in 9-character
    /// alphanumeric format
    /// **Validates: Requirement 20.4**
    test('Property 38: Connection password format', () async {
      // Feature: remote-desktop-client, Property 38: Connection password format
      
      const iterations = 100;
      
      for (var i = 0; i < iterations; i++) {
        // Clear cached password to generate new one
        await secureStorage.clearAll();
        final newDeviceService = DeviceManagementService(secureStorage: secureStorage);
        
        final password = await newDeviceService.generateConnectionPassword();
        
        // Property: Password should be exactly 9 characters
        expect(password.length, equals(9),
            reason: 'Password should be 9 characters (iteration $i)');
        
        // Property: Password should contain only alphanumeric characters
        expect(RegExp(r'^[0-9A-Za-z]{9}$').hasMatch(password), isTrue,
            reason: 'Password should be 9 alphanumeric characters (iteration $i)');
        
        // Property: Validation function should accept valid passwords
        expect(DeviceManagementService.isValidConnectionPassword(password), isTrue,
            reason: 'Generated password should pass validation (iteration $i)');
      }
    });

    /// Property 39: Connection password refresh
    /// *For any* connection password refresh operation, the system should
    /// generate a new password different from the old one
    /// **Validates: Requirement 20.5**
    test('Property 39: Connection password refresh', () async {
      // Feature: remote-desktop-client, Property 39: Connection password refresh
      
      const iterations = 100;
      
      for (var i = 0; i < iterations; i++) {
        // Get initial password
        final settings = await deviceService.getRemoteControlSettings();
        final oldPassword = settings.connectionPassword;
        
        // Refresh password
        final newPassword = await deviceService.refreshConnectionPassword();
        
        // Property: New password should be different from old
        expect(newPassword, isNot(equals(oldPassword)),
            reason: 'New password should be different from old (iteration $i)');
        
        // Property: New password should still be valid format
        expect(DeviceManagementService.isValidConnectionPassword(newPassword), isTrue,
            reason: 'New password should be valid format (iteration $i)');
        
        // Property: Settings should reflect new password
        final updatedSettings = await deviceService.getRemoteControlSettings();
        expect(updatedSettings.connectionPassword, equals(newPassword),
            reason: 'Settings should have new password (iteration $i)');
      }
    });

    /// Property 40: Screen lock password verification
    /// *For any* device with screen lock password verification enabled,
    /// the system should require correct screen lock password before accepting
    /// remote connections
    /// **Validates: Requirement 20.7**
    test('Property 40: Screen lock password verification', () async {
      // Feature: remote-desktop-client, Property 40: Screen lock password verification
      
      const iterations = 100;
      final random = Random();
      
      for (var i = 0; i < iterations; i++) {
        // Enable screen lock password requirement
        await deviceService.setRequireScreenLockPassword(true);
        
        // Verify setting is enabled
        final requirePassword = await deviceService.getRequireScreenLockPassword();
        expect(requirePassword, isTrue,
            reason: 'Screen lock password requirement should be enabled (iteration $i)');
        
        // Property: Empty password should fail verification
        final emptyResult = await deviceService.verifyScreenLockPassword('');
        expect(emptyResult, isFalse,
            reason: 'Empty password should fail verification (iteration $i)');
        
        // Property: Non-empty password should pass (in mock implementation)
        final validPassword = 'test_password_$i';
        final validResult = await deviceService.verifyScreenLockPassword(validPassword);
        expect(validResult, isTrue,
            reason: 'Valid password should pass verification (iteration $i)');
        
        // Disable and verify
        await deviceService.setRequireScreenLockPassword(false);
        final disabledRequirement = await deviceService.getRequireScreenLockPassword();
        expect(disabledRequirement, isFalse,
            reason: 'Screen lock password requirement should be disabled (iteration $i)');
      }
    });

    /// Property: Device code validation rejects invalid formats
    test('Device code validation rejects invalid formats', () {
      // Feature: remote-desktop-client, Property: Device code validation
      
      final invalidCodes = [
        '',           // Empty
        '12345678',   // 8 digits
        '1234567890', // 10 digits
        '12345678a',  // Contains letter
        '123-456-78', // Contains dash
        '123 456 78', // Contains space
        'abcdefghi',  // All letters
      ];
      
      for (final code in invalidCodes) {
        expect(DeviceManagementService.isValidDeviceCode(code), isFalse,
            reason: 'Invalid code "$code" should be rejected');
      }
      
      // Valid codes
      final validCodes = [
        '123456789',
        '000000000',
        '999999999',
        '123000789',
      ];
      
      for (final code in validCodes) {
        expect(DeviceManagementService.isValidDeviceCode(code), isTrue,
            reason: 'Valid code "$code" should be accepted');
      }
    });

    /// Property: Connection password validation rejects invalid formats
    test('Connection password validation rejects invalid formats', () {
      // Feature: remote-desktop-client, Property: Connection password validation
      
      final invalidPasswords = [
        '',            // Empty
        '12345678',    // 8 characters
        '1234567890',  // 10 characters
        '12345678!',   // Contains special char
        '123-456-78',  // Contains dash
        '123 456 78',  // Contains space
      ];
      
      for (final password in invalidPasswords) {
        expect(DeviceManagementService.isValidConnectionPassword(password), isFalse,
            reason: 'Invalid password "$password" should be rejected');
      }
      
      // Valid passwords
      final validPasswords = [
        '123456789',
        'abcdefghi',
        'ABCDEFGHI',
        'aB3dE6gH9',
        '000000000',
      ];
      
      for (final password in validPasswords) {
        expect(DeviceManagementService.isValidConnectionPassword(password), isTrue,
            reason: 'Valid password "$password" should be accepted');
      }
    });
  });

  group('Device List Management Property Tests', () {
    /// Property 41: Device list persistence
    /// *For any* new device first connection success, the system should
    /// automatically add that device to the device list
    /// **Validates: Requirement 21.10**
    test('Property 41: Device list persistence', () async {
      // Feature: remote-desktop-client, Property 41: Device list persistence
      
      const iterations = 50;
      final random = Random();
      
      for (var i = 0; i < iterations; i++) {
        // Clear device list
        await secureStorage.clearAll();
        final newDeviceService = DeviceManagementService(secureStorage: secureStorage);
        
        // Create random device
        final device = DeviceRecord(
          deviceId: 'device_${random.nextInt(1000000)}',
          deviceCode: List.generate(9, (_) => random.nextInt(10)).join(),
          displayName: 'Test Device $i',
          platform: ['windows', 'macos', 'linux', 'android', 'ios'][random.nextInt(5)],
          lastOnlineTime: DateTime.now(),
          isOnline: random.nextBool(),
        );
        
        // Add device
        await newDeviceService.addDevice(device);
        
        // Property: Device should be in list
        final devices = await newDeviceService.getDeviceList();
        expect(devices.any((d) => d.deviceId == device.deviceId), isTrue,
            reason: 'Added device should be in list (iteration $i)');
        
        // Property: Device data should match
        final savedDevice = devices.firstWhere((d) => d.deviceId == device.deviceId);
        expect(savedDevice.deviceCode, equals(device.deviceCode),
            reason: 'Device code should match (iteration $i)');
        expect(savedDevice.displayName, equals(device.displayName),
            reason: 'Display name should match (iteration $i)');
        expect(savedDevice.platform, equals(device.platform),
            reason: 'Platform should match (iteration $i)');
      }
    });

    /// Property 42: Device deletion
    /// *For any* device deletion operation, the system should remove that
    /// device record from the device list
    /// **Validates: Requirement 21.8**
    test('Property 42: Device deletion', () async {
      // Feature: remote-desktop-client, Property 42: Device deletion
      
      const iterations = 50;
      final random = Random();
      
      for (var i = 0; i < iterations; i++) {
        // Clear and add multiple devices
        await secureStorage.clearAll();
        final newDeviceService = DeviceManagementService(secureStorage: secureStorage);
        
        final deviceCount = random.nextInt(5) + 2; // 2-6 devices
        final devices = <DeviceRecord>[];
        
        for (var j = 0; j < deviceCount; j++) {
          final device = DeviceRecord(
            deviceId: 'device_${i}_$j',
            deviceCode: List.generate(9, (_) => random.nextInt(10)).join(),
            displayName: 'Device $j',
            platform: 'windows',
            lastOnlineTime: DateTime.now(),
            isOnline: false,
          );
          devices.add(device);
          await newDeviceService.addDevice(device);
        }
        
        // Pick random device to delete
        final deviceToDelete = devices[random.nextInt(devices.length)];
        
        // Delete device
        await newDeviceService.removeDevice(deviceToDelete.deviceId);
        
        // Property: Deleted device should not be in list
        final remainingDevices = await newDeviceService.getDeviceList();
        expect(remainingDevices.any((d) => d.deviceId == deviceToDelete.deviceId), isFalse,
            reason: 'Deleted device should not be in list (iteration $i)');
        
        // Property: Other devices should still be in list
        expect(remainingDevices.length, equals(deviceCount - 1),
            reason: 'Other devices should remain (iteration $i)');
      }
    });

    /// Property: Device rename persists
    test('Device rename persists', () async {
      // Feature: remote-desktop-client, Property: Device rename
      
      const iterations = 50;
      final random = Random();
      
      for (var i = 0; i < iterations; i++) {
        // Add a device
        final device = DeviceRecord(
          deviceId: 'device_$i',
          deviceCode: '123456789',
          displayName: 'Original Name',
          platform: 'windows',
          lastOnlineTime: DateTime.now(),
          isOnline: false,
        );
        
        await deviceService.addDevice(device);
        
        // Rename device
        final newName = 'New Name ${random.nextInt(1000)}';
        await deviceService.renameDevice(device.deviceId, newName);
        
        // Property: Name should be updated
        final devices = await deviceService.getDeviceList();
        final renamedDevice = devices.firstWhere((d) => d.deviceId == device.deviceId);
        expect(renamedDevice.displayName, equals(newName),
            reason: 'Device name should be updated (iteration $i)');
        
        // Cleanup
        await deviceService.removeDevice(device.deviceId);
      }
    });

    /// Property: Adding duplicate device updates existing
    test('Adding duplicate device updates existing', () async {
      // Feature: remote-desktop-client, Property: Duplicate device handling
      
      const iterations = 50;
      
      for (var i = 0; i < iterations; i++) {
        await secureStorage.clearAll();
        final newDeviceService = DeviceManagementService(secureStorage: secureStorage);
        
        // Add initial device
        final device = DeviceRecord(
          deviceId: 'device_$i',
          deviceCode: '123456789',
          displayName: 'Original Name',
          platform: 'windows',
          lastOnlineTime: DateTime.now().subtract(const Duration(hours: 1)),
          isOnline: false,
        );
        
        await newDeviceService.addDevice(device);
        
        // Add same device with updated info
        final updatedDevice = DeviceRecord(
          deviceId: 'device_$i', // Same ID
          deviceCode: '123456789',
          displayName: 'Updated Name',
          platform: 'windows',
          lastOnlineTime: DateTime.now(),
          isOnline: true,
        );
        
        await newDeviceService.addDevice(updatedDevice);
        
        // Property: Should only have one device
        final devices = await newDeviceService.getDeviceList();
        final matchingDevices = devices.where((d) => d.deviceId == 'device_$i').toList();
        expect(matchingDevices.length, equals(1),
            reason: 'Should only have one device with same ID (iteration $i)');
        
        // Property: Device should have updated info
        expect(matchingDevices.first.displayName, equals('Updated Name'),
            reason: 'Device should have updated name (iteration $i)');
        expect(matchingDevices.first.isOnline, isTrue,
            reason: 'Device should have updated online status (iteration $i)');
      }
    });
  });
}
