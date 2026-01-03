import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// FFI bindings to the Rust core engine
class RustBridge {
  static DynamicLibrary? _lib;
  static bool _initialized = false;

  // Function signatures
  static late int Function() _webrtcEngineCreate;
  static late void Function(Pointer<Void>) _webrtcEngineDestroy;
  static late int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Pointer<Utf8>>) _webrtcEngineCreatePeerConnection;
  static late int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Uint8>, int) _webrtcEngineSendData;
  
  static late Pointer<Void> Function(Pointer<Utf8>) _signalingClientCreate;
  static late void Function(Pointer<Void>) _signalingClientDestroy;
  static late int Function(Pointer<Void>) _signalingClientConnect;
  
  static late void Function(Pointer<Utf8>) _freeString;
  static late int Function(int) _initLogging;

  /// Initialize the Rust bridge
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Load the dynamic library
      if (Platform.isWindows) {
        _lib = DynamicLibrary.open('remote_desktop_core.dll');
      } else if (Platform.isMacOS) {
        _lib = DynamicLibrary.open('libremote_desktop_core.dylib');
      } else if (Platform.isLinux) {
        _lib = DynamicLibrary.open('libremote_desktop_core.so');
      } else {
        throw UnsupportedError('Platform not supported');
      }

      // Bind functions
      _bindFunctions();
      
      // Initialize logging
      _initLogging(2); // INFO level
      
      _initialized = true;
    } catch (e) {
      print('Failed to initialize Rust bridge: $e');
      // Continue without Rust core for development
    }
  }

  static void _bindFunctions() {
    if (_lib == null) return;

    _webrtcEngineCreate = _lib!
        .lookup<NativeFunction<IntPtr Function()>>('webrtc_engine_create')
        .asFunction();

    _webrtcEngineDestroy = _lib!
        .lookup<NativeFunction<Void Function(Pointer<Void>)>>('webrtc_engine_destroy')
        .asFunction();

    _webrtcEngineCreatePeerConnection = _lib!
        .lookup<NativeFunction<Int32 Function(Pointer<Void>, Pointer<Utf8>, Pointer<Pointer<Utf8>>)>>('webrtc_engine_create_peer_connection')
        .asFunction();

    _webrtcEngineSendData = _lib!
        .lookup<NativeFunction<Int32 Function(Pointer<Void>, Pointer<Utf8>, Pointer<Uint8>, IntPtr)>>('webrtc_engine_send_data')
        .asFunction();

    _signalingClientCreate = _lib!
        .lookup<NativeFunction<Pointer<Void> Function(Pointer<Utf8>)>>('signaling_client_create')
        .asFunction();

    _signalingClientDestroy = _lib!
        .lookup<NativeFunction<Void Function(Pointer<Void>)>>('signaling_client_destroy')
        .asFunction();

    _signalingClientConnect = _lib!
        .lookup<NativeFunction<Int32 Function(Pointer<Void>)>>('signaling_client_connect')
        .asFunction();

    _freeString = _lib!
        .lookup<NativeFunction<Void Function(Pointer<Utf8>)>>('free_string')
        .asFunction();

    _initLogging = _lib!
        .lookup<NativeFunction<Int32 Function(Int32)>>('init_logging')
        .asFunction();
  }

  /// Create a WebRTC engine instance
  static Pointer<Void>? createWebRTCEngine() {
    if (!_initialized || _lib == null) return null;
    
    final handle = _webrtcEngineCreate();
    return handle != 0 ? Pointer<Void>.fromAddress(handle) : null;
  }

  /// Destroy a WebRTC engine instance
  static void destroyWebRTCEngine(Pointer<Void> handle) {
    if (!_initialized || _lib == null) return;
    _webrtcEngineDestroy(handle);
  }

  /// Create a peer connection
  static String? createPeerConnection(Pointer<Void> engineHandle, String configJson) {
    if (!_initialized || _lib == null) return null;

    final configPtr = configJson.toNativeUtf8();
    final connectionIdPtr = calloc<Pointer<Utf8>>();

    try {
      final result = _webrtcEngineCreatePeerConnection(engineHandle, configPtr, connectionIdPtr);
      
      if (result == 0) {
        final connectionId = connectionIdPtr.value.toDartString();
        _freeString(connectionIdPtr.value.cast());
        return connectionId;
      }
      return null;
    } finally {
      calloc.free(configPtr);
      calloc.free(connectionIdPtr);
    }
  }

  /// Send data through WebRTC data channel
  static bool sendData(Pointer<Void> engineHandle, String connectionId, List<int> data) {
    if (!_initialized || _lib == null) return false;

    final connectionIdPtr = connectionId.toNativeUtf8();
    final dataPtr = calloc<Uint8>(data.length);

    try {
      for (int i = 0; i < data.length; i++) {
        dataPtr[i] = data[i];
      }

      final result = _webrtcEngineSendData(engineHandle, connectionIdPtr, dataPtr, data.length);
      return result == 0;
    } finally {
      calloc.free(connectionIdPtr);
      calloc.free(dataPtr);
    }
  }

  /// Create a signaling client
  static Pointer<Void>? createSignalingClient(String serverUrl) {
    if (!_initialized || _lib == null) return null;

    final serverUrlPtr = serverUrl.toNativeUtf8();
    try {
      final handle = _signalingClientCreate(serverUrlPtr);
      return handle.address != 0 ? handle : null;
    } finally {
      calloc.free(serverUrlPtr);
    }
  }

  /// Destroy a signaling client
  static void destroySignalingClient(Pointer<Void> handle) {
    if (!_initialized || _lib == null) return;
    _signalingClientDestroy(handle);
  }

  /// Connect to signaling server
  static bool connectSignalingClient(Pointer<Void> handle) {
    if (!_initialized || _lib == null) return false;
    final result = _signalingClientConnect(handle);
    return result == 0;
  }

  /// Check if the bridge is initialized
  static bool get isInitialized => _initialized;
}