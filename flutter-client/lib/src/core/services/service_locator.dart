import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'authentication_service.dart';
import 'device_management_service.dart';
import 'consent_service.dart';
import 'secure_storage_service.dart';
import 'session_management_service.dart';
import 'performance_service.dart';

/// Service locator for dependency injection using Riverpod
/// Provides centralized access to all core services

// Secure storage service provider
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

// Consent service provider
final consentServiceProvider = Provider<ConsentService>((ref) {
  final secureStorage = ref.watch(secureStorageServiceProvider);
  return ConsentService(secureStorage: secureStorage);
});

// Authentication service provider
final authenticationServiceProvider = Provider<AuthenticationService>((ref) {
  final secureStorage = ref.watch(secureStorageServiceProvider);
  return AuthenticationService(secureStorage: secureStorage);
});

// Device management service provider
final deviceManagementServiceProvider = Provider<DeviceManagementService>((ref) {
  final secureStorage = ref.watch(secureStorageServiceProvider);
  return DeviceManagementService(secureStorage: secureStorage);
});

// Authentication state provider
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  final authService = ref.watch(authenticationServiceProvider);
  return AuthStateNotifier(authService);
});

// Consent state provider
final consentStateProvider = StateNotifierProvider<ConsentStateNotifier, ConsentState>((ref) {
  final consentService = ref.watch(consentServiceProvider);
  return ConsentStateNotifier(consentService);
});

// Session management service provider (re-exported from session_management_service.dart)
// Use sessionManagementServiceProvider from session_management_service.dart directly

// Performance service provider (re-exported from performance_service.dart)
// Use performanceServiceProvider from performance_service.dart directly
