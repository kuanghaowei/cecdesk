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
pub mod logging;
pub mod diagnostics;
pub mod performance;

#[cfg(test)]
mod signaling_test;

#[cfg(test)]
mod access_control_test;

#[cfg(test)]
mod network_test;

#[cfg(test)]
mod screen_capture_test;

#[cfg(test)]
mod webrtc_engine_test;

#[cfg(test)]
mod security_test;

#[cfg(test)]
mod logging_test;

#[cfg(test)]
mod integration_test;

pub use webrtc_engine::{WebRTCEngine, RTCConfiguration, IceServer, RTCPeerConnectionState, WebRTCEvent, MediaStream, MediaTrack, ConnectionStats};
pub use signaling::{SignalingClient, SignalingMessage, SignalingEvent, DeviceInfo, DeviceCapabilities, DeviceStatus, SignalingMetrics, generate_device_id};
pub use access_control::{AccessControlManager, AccessCode, Permission, AuthorizationType, DeviceAuthorization, ConnectionRequest, ConnectionResponse, DeviceRegistration, ACCESS_CODE_EXPIRATION_SECS};
pub use screen_capture::{ScreenCapturer, AudioCapturer, DisplayInfo, CaptureOptions, VideoCodecType, QualityPreset, VideoFrame, AudioFrame, AudioCaptureOptions, NetworkConditions, AdaptiveBitrateConfig};
pub use input_control::InputController;
pub use file_transfer::FileTransfer;
pub use session_manager::{SessionManager, Session, SessionStatus, SessionStats, SessionOptions, SessionRecord, Permission as SessionPermission, ConnectionQuality, ConnectionType, EndReason, PermissionRequest, SessionEvent, SessionSummaryStats};
pub use logging::{LogManager, LogEntry, LogLevel, LogConfig, ConnectionEvent, ConnectionEventType};
pub use diagnostics::{DiagnosticsManager, NetworkDiagnostics, SystemDiagnostics, NatType, ServerStatus, DiagnosticStatus};
pub use security::{SecurityManager, SecurityConfig, DeviceCertificate, SecurityThreat, EncryptedData, EncryptionAlgorithm, DtlsSrtpConfig, TlsConfig, SessionKey, SecurityEvent, SecurityEventType, CertificateValidationResult, CertificateValidationError, KeyRotationConfig, ThreatDetectionConfig, ReplayDetectionState, FailedAttemptTracker};

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