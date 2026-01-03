// Conditional import for platform-specific implementations
export 'rust_bridge_stub.dart'
    if (dart.library.io) 'rust_bridge_native.dart';
