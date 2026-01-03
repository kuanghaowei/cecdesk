pub mod access_control;
pub mod diagnostics;
pub mod ffi;
pub mod file_transfer;
pub mod input_control;
pub mod logging;
pub mod network;
pub mod performance;
pub mod screen_capture;
pub mod security;
pub mod session_manager;
pub mod signaling;
pub mod webrtc_engine;

#[cfg(test)]
pub mod webrtc_mock;

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

pub use access_control::{
    AccessCode, AccessControlManager, AuthorizationType, ConnectionRequest, ConnectionResponse,
    DeviceAuthorization, DeviceRegistration, Permission, ACCESS_CODE_EXPIRATION_SECS,
};
pub use diagnostics::{
    DiagnosticStatus, DiagnosticsManager, NatType, NetworkDiagnostics, ServerStatus,
    SystemDiagnostics,
};
pub use file_transfer::FileTransfer;
pub use input_control::InputController;
pub use logging::{
    ConnectionEvent, ConnectionEventType, LogConfig, LogEntry, LogLevel, LogManager,
};
pub use screen_capture::{
    AdaptiveBitrateConfig, AudioCaptureOptions, AudioCapturer, AudioFrame, CaptureOptions,
    DisplayInfo, NetworkConditions, QualityPreset, ScreenCapturer, VideoCodecType, VideoFrame,
};
pub use security::{
    CertificateValidationError, CertificateValidationResult, DeviceCertificate, DtlsSrtpConfig,
    EncryptedData, EncryptionAlgorithm, FailedAttemptTracker, KeyRotationConfig,
    ReplayDetectionState, SecurityConfig, SecurityEvent, SecurityEventType, SecurityManager,
    SecurityThreat, SessionKey, ThreatDetectionConfig, TlsConfig,
};
pub use session_manager::{
    ConnectionQuality, ConnectionType, EndReason, Permission as SessionPermission,
    PermissionRequest, Session, SessionEvent, SessionManager, SessionOptions, SessionRecord,
    SessionStats, SessionStatus, SessionSummaryStats,
};
pub use signaling::{
    generate_device_id, DeviceCapabilities, DeviceInfo, DeviceStatus, SignalingClient,
    SignalingEvent, SignalingMessage, SignalingMetrics,
};
pub use webrtc_engine::{
    ConnectionStats, IceServer, MediaStream, MediaTrack, RTCConfiguration, RTCPeerConnectionState,
    WebRTCEngine, WebRTCEvent,
};

// Re-export common types
pub use crate::ffi::*;

#[cfg(test)]
mod tests {
    #[test]
    fn test_library_initialization() {
        // Basic smoke test to ensure library loads
    }
}
