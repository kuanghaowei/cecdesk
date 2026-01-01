pub mod webrtc_engine;
pub mod signaling;
pub mod screen_capture;
pub mod input_control;
pub mod file_transfer;
pub mod session_manager;
pub mod security;
pub mod network;
pub mod access_control;
pub mod ffi;

#[cfg(test)]
mod signaling_test;

#[cfg(test)]
mod access_control_test;

pub use webrtc_engine::{WebRTCEngine, RTCConfiguration, IceServer, RTCPeerConnectionState, WebRTCEvent, MediaStream, MediaTrack, ConnectionStats};
pub use signaling::{SignalingClient, SignalingMessage, SignalingEvent, DeviceInfo, DeviceCapabilities, DeviceStatus, SignalingMetrics, generate_device_id};
pub use access_control::{AccessControlManager, AccessCode, Permission, AuthorizationType, DeviceAuthorization, ConnectionRequest, ConnectionResponse, DeviceRegistration, ACCESS_CODE_EXPIRATION_SECS};
pub use screen_capture::{ScreenCapturer, AudioCapturer, DisplayInfo, CaptureOptions, VideoCodecType, QualityPreset, VideoFrame, AudioFrame, AudioCaptureOptions, NetworkConditions, AdaptiveBitrateConfig};
pub use input_control::InputController;
pub use file_transfer::FileTransfer;
pub use session_manager::SessionManager;

// Re-export common types
pub use crate::ffi::*;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_library_initialization() {
        // Basic smoke test to ensure library loads
        assert!(true);
    }
}