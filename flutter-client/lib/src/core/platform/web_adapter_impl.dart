part of 'web_adapter.dart';

/// Web adapter implementation for Flutter Web
/// Requirements: 1.8, 12.1-12.8
class WebAdapterImpl extends WebAdapter {
  bool _initialized = false;
  final StreamController<bool> _fullscreenController = StreamController<bool>.broadcast();
  final StreamController<ViewportSize> _viewportController = StreamController<ViewportSize>.broadcast();

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    debugPrint('WebAdapter initialized');
  }

  @override
  Future<void> dispose() async {
    await _fullscreenController.close();
    await _viewportController.close();
    _initialized = false;
  }

  // Browser Compatibility
  @override
  Future<bool> isWebRTCSupported() async {
    // In production, would check window.RTCPeerConnection
    return true;
  }

  @override
  Future<bool> isCodecSupported(String codec) async {
    // In production, would use RTCRtpSender.getCapabilities
    final supportedCodecs = ['h264', 'vp8', 'vp9', 'opus'];
    return supportedCodecs.contains(codec.toLowerCase());
  }

  @override
  Future<BrowserInfo> getBrowserInfo() async {
    // In production, would parse navigator.userAgent
    return const BrowserInfo(
      name: 'Chrome',
      version: '120.0',
      platform: 'Web',
      userAgent: 'Mozilla/5.0 (Web)',
      isMobile: false,
      isSecureContext: true,
    );
  }

  @override
  Future<CompatibilityResult> checkCompatibility() async {
    final features = await getSupportedFeatures();
    final missingFeatures = <String>[];
    final warnings = <String>[];

    if (!features.webRTC) {
      missingFeatures.add('WebRTC');
    }
    if (!features.webSocket) {
      missingFeatures.add('WebSocket');
    }
    if (!features.mediaDevices) {
      warnings.add('Media devices access may be limited');
    }
    if (!features.screenCapture) {
      warnings.add('Screen capture may not be available');
    }

    return CompatibilityResult(
      isCompatible: missingFeatures.isEmpty,
      missingFeatures: missingFeatures,
      warnings: warnings,
      errorMessage: missingFeatures.isNotEmpty
          ? 'Your browser does not support required features: ${missingFeatures.join(", ")}'
          : null,
    );
  }

  @override
  Future<WebFeatures> getSupportedFeatures() async {
    // In production, would check actual browser capabilities
    return const WebFeatures(
      webRTC: true,
      webSocket: true,
      localStorage: true,
      sessionStorage: true,
      notifications: true,
      clipboard: true,
      fullscreen: true,
      fileSystem: true,
      mediaDevices: true,
      screenCapture: true,
    );
  }

  // File Operations
  @override
  Future<WebFile?> selectFile({
    List<String>? allowedExtensions,
    bool multiple = false,
  }) async {
    // In production, would use html.FileUploadInputElement
    debugPrint('Web: Selecting file with extensions: $allowedExtensions');
    return null;
  }

  @override
  Future<List<WebFile>> selectFiles({List<String>? allowedExtensions}) async {
    debugPrint('Web: Selecting multiple files');
    return [];
  }

  @override
  Future<void> downloadFile({
    required List<int> data,
    required String filename,
    String? mimeType,
  }) async {
    // In production, would create blob and trigger download
    debugPrint('Web: Downloading file: $filename (${data.length} bytes)');
  }

  @override
  Future<void> downloadFromUrl({
    required String url,
    required String filename,
  }) async {
    debugPrint('Web: Downloading from URL: $url');
  }

  @override
  Future<List<int>> readFileAsBytes(WebFile file) async {
    // In production, would use FileReader
    return [];
  }

  @override
  Future<String> readFileAsText(WebFile file) async {
    return '';
  }

  // Display and Fullscreen
  @override
  Future<bool> enterFullscreen() async {
    // In production, would use document.documentElement.requestFullscreen()
    debugPrint('Web: Entering fullscreen');
    _fullscreenController.add(true);
    return true;
  }

  @override
  Future<void> exitFullscreen() async {
    debugPrint('Web: Exiting fullscreen');
    _fullscreenController.add(false);
  }

  @override
  Future<bool> isFullscreen() async {
    return false;
  }

  @override
  Stream<bool> get onFullscreenChanged => _fullscreenController.stream;

  @override
  Future<ViewportSize> getViewportSize() async {
    // In production, would use window.innerWidth/innerHeight
    return const ViewportSize(
      width: 1920,
      height: 1080,
      devicePixelRatio: 1.0,
    );
  }

  @override
  Stream<ViewportSize> get onViewportSizeChanged => _viewportController.stream;

  // Local Storage
  @override
  Future<void> saveToLocalStorage(String key, String value) async {
    // In production, would use window.localStorage
    debugPrint('Web: Saving to localStorage: $key');
  }

  @override
  Future<String?> loadFromLocalStorage(String key) async {
    return null;
  }

  @override
  Future<void> removeFromLocalStorage(String key) async {
    debugPrint('Web: Removing from localStorage: $key');
  }

  @override
  Future<void> clearLocalStorage() async {
    debugPrint('Web: Clearing localStorage');
  }

  // Session Storage
  @override
  Future<void> saveToSessionStorage(String key, String value) async {
    debugPrint('Web: Saving to sessionStorage: $key');
  }

  @override
  Future<String?> loadFromSessionStorage(String key) async {
    return null;
  }

  // Clipboard
  @override
  Future<bool> copyToClipboard(String text) async {
    // In production, would use navigator.clipboard.writeText
    debugPrint('Web: Copying to clipboard');
    return true;
  }

  @override
  Future<String?> readFromClipboard() async {
    return null;
  }

  // Notifications
  @override
  Future<bool> requestNotificationPermission() async {
    // In production, would use Notification.requestPermission()
    return true;
  }

  @override
  Future<void> showNotification({
    required String title,
    required String body,
    String? icon,
  }) async {
    debugPrint('Web: Showing notification - $title: $body');
  }

  // URL and Navigation
  @override
  String getCurrentUrl() {
    // In production, would use window.location.href
    return 'https://localhost/';
  }

  @override
  void updateUrl(String path) {
    // In production, would use window.history.pushState
    debugPrint('Web: Updating URL to: $path');
  }

  @override
  Future<void> openInNewTab(String url) async {
    // In production, would use window.open
    debugPrint('Web: Opening in new tab: $url');
  }

  // Performance
  @override
  Future<MemoryInfo?> getMemoryInfo() async {
    // In production, would use performance.memory (Chrome only)
    return null;
  }

  @override
  Future<ConnectionInfo?> getConnectionInfo() async {
    // In production, would use navigator.connection
    return const ConnectionInfo(
      effectiveType: '4g',
      downlink: 10.0,
      rtt: 50,
      saveData: false,
    );
  }
}
