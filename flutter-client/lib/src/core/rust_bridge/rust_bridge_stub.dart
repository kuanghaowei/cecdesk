/// Stub implementation for web platform (no FFI support)
class RustBridge {
  static bool _initialized = false;

  /// Initialize the Rust bridge (no-op on web)
  static Future<void> initialize() async {
    _initialized = true;
    print('RustBridge: Running in web mode (no native FFI)');
  }

  /// Create a WebRTC engine instance (not supported on web)
  static dynamic createWebRTCEngine() => null;

  /// Destroy a WebRTC engine instance (no-op on web)
  static void destroyWebRTCEngine(dynamic handle) {}

  /// Create a peer connection (not supported on web)
  static String? createPeerConnection(dynamic engineHandle, String configJson) => null;

  /// Send data through WebRTC data channel (not supported on web)
  static bool sendData(dynamic engineHandle, String connectionId, List<int> data) => false;

  /// Create a signaling client (not supported on web)
  static dynamic createSignalingClient(String serverUrl) => null;

  /// Destroy a signaling client (no-op on web)
  static void destroySignalingClient(dynamic handle) {}

  /// Connect to signaling server (not supported on web)
  static bool connectSignalingClient(dynamic handle) => false;

  /// Check if the bridge is initialized
  static bool get isInitialized => _initialized;
}
