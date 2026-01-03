//! Rust bridge for Flutter client
//!
//! This crate provides FFI bindings between the Rust core engine
//! and the Flutter client application.

pub use remote_desktop_core::*;

#[cfg(test)]
mod tests {
    #[test]
    fn test_bridge_exports_core() {
        // Verify that core types are re-exported
        // This ensures the bridge properly exposes the core library
        let _ = std::any::type_name::<super::SignalingClient>();
    }
}
