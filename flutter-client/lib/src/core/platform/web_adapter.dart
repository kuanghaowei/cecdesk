import 'dart:async';
import 'package:flutter/foundation.dart';

part 'web_adapter_impl.dart';

/// Web platform adapter for Flutter Web deployment
/// Implements browser compatibility, file upload/download
/// Requirements: 1.8, 12.1-12.8
abstract class WebAdapter {
  static WebAdapter? _instance;

  static WebAdapter get instance {
    _instance ??= WebAdapterImpl();
    return _instance!;
  }

  /// Check if running on web platform
  static bool get isWeb => kIsWeb;

  /// Initialize the web adapter
  Future<void> initialize();

  /// Dispose resources
  Future<void> dispose();

  // Browser Compatibility
  /// Check if WebRTC is supported
  Future<bool> isWebRTCSupported();

  /// Check if specific codec is supported
  Future<bool> isCodecSupported(String codec);

  /// Get browser information
  Future<BrowserInfo> getBrowserInfo();

  /// Check browser compatibility
  Future<CompatibilityResult> checkCompatibility();

  /// Get supported features
  Future<WebFeatures> getSupportedFeatures();

  // File Operations
  /// Select file for upload
  Future<WebFile?> selectFile({
    List<String>? allowedExtensions,
    bool multiple = false,
  });

  /// Select multiple files
  Future<List<WebFile>> selectFiles({List<String>? allowedExtensions});

  /// Download file to user's device
  Future<void> downloadFile({
    required List<int> data,
    required String filename,
    String? mimeType,
  });

  /// Download file from URL
  Future<void> downloadFromUrl({
    required String url,
    required String filename,
  });

  /// Read file as bytes
  Future<List<int>> readFileAsBytes(WebFile file);

  /// Read file as text
  Future<String> readFileAsText(WebFile file);

  // Display and Fullscreen
  /// Enter fullscreen mode
  Future<bool> enterFullscreen();

  /// Exit fullscreen mode
  Future<void> exitFullscreen();

  /// Check if in fullscreen mode
  Future<bool> isFullscreen();

  /// Stream of fullscreen state changes
  Stream<bool> get onFullscreenChanged;

  /// Get viewport size
  Future<ViewportSize> getViewportSize();

  /// Stream of viewport size changes
  Stream<ViewportSize> get onViewportSizeChanged;

  // Local Storage
  /// Save data to local storage
  Future<void> saveToLocalStorage(String key, String value);

  /// Load data from local storage
  Future<String?> loadFromLocalStorage(String key);

  /// Remove data from local storage
  Future<void> removeFromLocalStorage(String key);

  /// Clear all local storage
  Future<void> clearLocalStorage();

  // Session Storage
  /// Save data to session storage
  Future<void> saveToSessionStorage(String key, String value);

  /// Load data from session storage
  Future<String?> loadFromSessionStorage(String key);

  // Clipboard
  /// Copy text to clipboard
  Future<bool> copyToClipboard(String text);

  /// Read text from clipboard
  Future<String?> readFromClipboard();

  // Notifications
  /// Request notification permission
  Future<bool> requestNotificationPermission();

  /// Show browser notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? icon,
  });

  // URL and Navigation
  /// Get current URL
  String getCurrentUrl();

  /// Update URL without navigation
  void updateUrl(String path);

  /// Open URL in new tab
  Future<void> openInNewTab(String url);

  // Performance
  /// Get memory usage info
  Future<MemoryInfo?> getMemoryInfo();

  /// Get connection info
  Future<ConnectionInfo?> getConnectionInfo();
}

/// Browser information
class BrowserInfo {
  final String name;
  final String version;
  final String platform;
  final String userAgent;
  final bool isMobile;
  final bool isSecureContext;

  const BrowserInfo({
    required this.name,
    required this.version,
    required this.platform,
    required this.userAgent,
    this.isMobile = false,
    this.isSecureContext = true,
  });
}

/// Compatibility check result
class CompatibilityResult {
  final bool isCompatible;
  final List<String> missingFeatures;
  final List<String> warnings;
  final String? errorMessage;

  const CompatibilityResult({
    required this.isCompatible,
    this.missingFeatures = const [],
    this.warnings = const [],
    this.errorMessage,
  });
}

/// Web features support
class WebFeatures {
  final bool webRTC;
  final bool webSocket;
  final bool localStorage;
  final bool sessionStorage;
  final bool notifications;
  final bool clipboard;
  final bool fullscreen;
  final bool fileSystem;
  final bool mediaDevices;
  final bool screenCapture;

  const WebFeatures({
    this.webRTC = false,
    this.webSocket = false,
    this.localStorage = false,
    this.sessionStorage = false,
    this.notifications = false,
    this.clipboard = false,
    this.fullscreen = false,
    this.fileSystem = false,
    this.mediaDevices = false,
    this.screenCapture = false,
  });
}

/// Web file representation
class WebFile {
  final String name;
  final int size;
  final String type;
  final DateTime lastModified;
  final dynamic nativeFile; // Platform-specific file object

  const WebFile({
    required this.name,
    required this.size,
    required this.type,
    required this.lastModified,
    this.nativeFile,
  });
}

/// Viewport size
class ViewportSize {
  final int width;
  final int height;
  final double devicePixelRatio;

  const ViewportSize({
    required this.width,
    required this.height,
    this.devicePixelRatio = 1.0,
  });

  bool get isPortrait => height > width;
  bool get isLandscape => width > height;
}

/// Memory information
class MemoryInfo {
  final int? usedJSHeapSize;
  final int? totalJSHeapSize;
  final int? jsHeapSizeLimit;

  const MemoryInfo({
    this.usedJSHeapSize,
    this.totalJSHeapSize,
    this.jsHeapSizeLimit,
  });
}

/// Connection information
class ConnectionInfo {
  final String? effectiveType; // 4g, 3g, 2g, slow-2g
  final double? downlink; // Mbps
  final int? rtt; // ms
  final bool? saveData;

  const ConnectionInfo({
    this.effectiveType,
    this.downlink,
    this.rtt,
    this.saveData,
  });
}
