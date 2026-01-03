//! Rust bridge for Flutter client
//!
//! This crate provides FFI bindings between the Rust core engine
//! and the Flutter client application.

pub use remote_desktop_core::*;

#[cfg(test)]
mod tests {
    #[test]
    fn test_bridge_initialization() {
        // Basic smoke test
        assert!(true);
    }
}
