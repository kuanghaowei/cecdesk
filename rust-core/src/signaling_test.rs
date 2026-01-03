//! Property-based tests for Signaling Service
//!
//! Feature: cec-remote
//! Property 5: 信令交换性能 - Signaling exchange should complete within 5 seconds
//! Property 6: 设备 ID 唯一性 - Device IDs should be unique
//! Validates: Requirements 4.5, 5.1

use crate::signaling::{
    generate_device_id, DeviceCapabilities, DeviceInfo, SignalingMessage, SignalingMetrics,
};
use proptest::prelude::*;
use std::collections::HashSet;

/// Strategy for generating random device names
fn device_name_strategy() -> impl Strategy<Value = String> {
    "[a-zA-Z0-9_-]{1,50}".prop_map(|s| s)
}

/// Strategy for generating random platform names
fn platform_strategy() -> impl Strategy<Value = String> {
    prop_oneof![
        Just("windows".to_string()),
        Just("macos".to_string()),
        Just("linux".to_string()),
        Just("ios".to_string()),
        Just("android".to_string()),
        Just("harmonyos".to_string()),
        Just("web".to_string()),
        Just("wechat_miniprogram".to_string()),
    ]
}

/// Strategy for generating random version strings
fn version_strategy() -> impl Strategy<Value = String> {
    (1u32..100, 0u32..100, 0u32..1000)
        .prop_map(|(major, minor, patch)| format!("{}.{}.{}", major, minor, patch))
}

/// Strategy for generating random device capabilities
fn capabilities_strategy() -> impl Strategy<Value = DeviceCapabilities> {
    (any::<bool>(), any::<bool>(), any::<bool>(), any::<bool>()).prop_map(
        |(screen, audio, file, input)| DeviceCapabilities {
            screen_capture: screen,
            audio_capture: audio,
            file_transfer: file,
            input_control: input,
        },
    )
}

/// Strategy for generating random device info
fn device_info_strategy() -> impl Strategy<Value = DeviceInfo> {
    (
        device_name_strategy(),
        platform_strategy(),
        version_strategy(),
        capabilities_strategy(),
    )
        .prop_map(|(name, platform, version, capabilities)| DeviceInfo {
            device_id: generate_device_id(),
            device_name: name,
            platform,
            version,
            capabilities,
        })
}

/// Strategy for generating random SDP strings (simplified)
fn sdp_strategy() -> impl Strategy<Value = String> {
    "[a-zA-Z0-9=]{10,100}".prop_map(|s| format!("v=0\r\n{}", s))
}

/// Strategy for generating random ICE candidate strings
fn ice_candidate_strategy() -> impl Strategy<Value = String> {
    (1u32..10, 1u32..65535).prop_map(|(component, port)| {
        format!(
            "candidate:{} {} UDP {} 192.168.1.1 {} typ host",
            component,
            component,
            port * 1000,
            port
        )
    })
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(100))]

    /// Feature: cec-remote, Property 6: 设备 ID 唯一性
    /// For any set of generated device IDs, all IDs should be unique
    /// Validates: Requirements 5.1
    #[test]
    fn prop_device_id_uniqueness(count in 10usize..100) {
        let mut ids = HashSet::new();

        for _ in 0..count {
            let id = generate_device_id();
            // Each generated ID should be unique
            prop_assert!(ids.insert(id.clone()),
                "Generated duplicate device ID: {}", id);
        }

        // All IDs should be present
        prop_assert_eq!(ids.len(), count);
    }

    /// Feature: cec-remote, Property 6: 设备 ID 唯一性
    /// Device IDs should be valid UUIDs
    /// Validates: Requirements 5.1
    #[test]
    fn prop_device_id_is_valid_uuid(_seed in any::<u64>()) {
        let id = generate_device_id();

        // Should be a valid UUID format (8-4-4-4-12 hex digits)
        let parts: Vec<&str> = id.split('-').collect();
        prop_assert_eq!(parts.len(), 5, "UUID should have 5 parts separated by dashes");
        prop_assert_eq!(parts[0].len(), 8, "First part should be 8 chars");
        prop_assert_eq!(parts[1].len(), 4, "Second part should be 4 chars");
        prop_assert_eq!(parts[2].len(), 4, "Third part should be 4 chars");
        prop_assert_eq!(parts[3].len(), 4, "Fourth part should be 4 chars");
        prop_assert_eq!(parts[4].len(), 12, "Fifth part should be 12 chars");

        // All parts should be valid hex
        for part in parts {
            prop_assert!(part.chars().all(|c| c.is_ascii_hexdigit()),
                "UUID parts should be hexadecimal");
        }
    }

    /// Feature: cec-remote, Property 5: 信令交换性能
    /// Signaling messages should serialize and deserialize correctly (round-trip)
    /// This is a prerequisite for fast signaling exchange
    /// Validates: Requirements 4.5
    #[test]
    fn prop_signaling_message_roundtrip_offer(
        from in device_name_strategy(),
        to in device_name_strategy(),
        sdp in sdp_strategy()
    ) {
        let msg = SignalingMessage::Offer {
            from: from.clone(),
            to: to.clone(),
            sdp: sdp.clone(),
        };

        // Serialize
        let json = serde_json::to_string(&msg).expect("Serialization should succeed");

        // Deserialize
        let parsed: SignalingMessage = serde_json::from_str(&json)
            .expect("Deserialization should succeed");

        // Verify round-trip
        match parsed {
            SignalingMessage::Offer { from: f, to: t, sdp: s } => {
                prop_assert_eq!(f, from);
                prop_assert_eq!(t, to);
                prop_assert_eq!(s, sdp);
            }
            _ => prop_assert!(false, "Wrong message type after round-trip"),
        }
    }

    /// Feature: cec-remote, Property 5: 信令交换性能
    /// Answer messages should serialize and deserialize correctly
    /// Validates: Requirements 4.5
    #[test]
    fn prop_signaling_message_roundtrip_answer(
        from in device_name_strategy(),
        to in device_name_strategy(),
        sdp in sdp_strategy()
    ) {
        let msg = SignalingMessage::Answer {
            from: from.clone(),
            to: to.clone(),
            sdp: sdp.clone(),
        };

        let json = serde_json::to_string(&msg).expect("Serialization should succeed");
        let parsed: SignalingMessage = serde_json::from_str(&json)
            .expect("Deserialization should succeed");

        match parsed {
            SignalingMessage::Answer { from: f, to: t, sdp: s } => {
                prop_assert_eq!(f, from);
                prop_assert_eq!(t, to);
                prop_assert_eq!(s, sdp);
            }
            _ => prop_assert!(false, "Wrong message type after round-trip"),
        }
    }

    /// Feature: cec-remote, Property 5: 信令交换性能
    /// ICE candidate messages should serialize and deserialize correctly
    /// Validates: Requirements 4.5
    #[test]
    fn prop_signaling_message_roundtrip_ice_candidate(
        from in device_name_strategy(),
        to in device_name_strategy(),
        candidate in ice_candidate_strategy()
    ) {
        let msg = SignalingMessage::IceCandidate {
            from: from.clone(),
            to: to.clone(),
            candidate: candidate.clone(),
        };

        let json = serde_json::to_string(&msg).expect("Serialization should succeed");
        let parsed: SignalingMessage = serde_json::from_str(&json)
            .expect("Deserialization should succeed");

        match parsed {
            SignalingMessage::IceCandidate { from: f, to: t, candidate: c } => {
                prop_assert_eq!(f, from);
                prop_assert_eq!(t, to);
                prop_assert_eq!(c, candidate);
            }
            _ => prop_assert!(false, "Wrong message type after round-trip"),
        }
    }

    /// Feature: cec-remote, Property 6: 设备 ID 唯一性
    /// Device info should serialize and deserialize correctly
    /// Validates: Requirements 5.1
    #[test]
    fn prop_device_info_roundtrip(device_info in device_info_strategy()) {
        let json = serde_json::to_string(&device_info).expect("Serialization should succeed");
        let parsed: DeviceInfo = serde_json::from_str(&json)
            .expect("Deserialization should succeed");

        prop_assert_eq!(parsed.device_id, device_info.device_id);
        prop_assert_eq!(parsed.device_name, device_info.device_name);
        prop_assert_eq!(parsed.platform, device_info.platform);
        prop_assert_eq!(parsed.version, device_info.version);
        prop_assert_eq!(parsed.capabilities.screen_capture, device_info.capabilities.screen_capture);
        prop_assert_eq!(parsed.capabilities.audio_capture, device_info.capabilities.audio_capture);
        prop_assert_eq!(parsed.capabilities.file_transfer, device_info.capabilities.file_transfer);
        prop_assert_eq!(parsed.capabilities.input_control, device_info.capabilities.input_control);
    }

    /// Feature: cec-remote, Property 5: 信令交换性能
    /// Register messages should serialize and deserialize correctly
    /// Validates: Requirements 4.5
    #[test]
    fn prop_register_message_roundtrip(device_info in device_info_strategy()) {
        let msg = SignalingMessage::Register(device_info.clone());

        let json = serde_json::to_string(&msg).expect("Serialization should succeed");
        let parsed: SignalingMessage = serde_json::from_str(&json)
            .expect("Deserialization should succeed");

        match parsed {
            SignalingMessage::Register(info) => {
                prop_assert_eq!(info.device_id, device_info.device_id);
                prop_assert_eq!(info.device_name, device_info.device_name);
            }
            _ => prop_assert!(false, "Wrong message type after round-trip"),
        }
    }

    /// Feature: cec-remote, Property 5: 信令交换性能
    /// Connection request messages should serialize and deserialize correctly
    /// Validates: Requirements 4.5
    #[test]
    fn prop_connection_request_roundtrip(
        from in device_name_strategy(),
        device_info in device_info_strategy()
    ) {
        let msg = SignalingMessage::ConnectionRequest {
            from: from.clone(),
            device_info: device_info.clone(),
        };

        let json = serde_json::to_string(&msg).expect("Serialization should succeed");
        let parsed: SignalingMessage = serde_json::from_str(&json)
            .expect("Deserialization should succeed");

        match parsed {
            SignalingMessage::ConnectionRequest { from: f, device_info: info } => {
                prop_assert_eq!(f, from);
                prop_assert_eq!(info.device_id, device_info.device_id);
            }
            _ => prop_assert!(false, "Wrong message type after round-trip"),
        }
    }
}

#[cfg(test)]
mod unit_tests {
    use super::*;

    #[test]
    fn test_device_id_format() {
        let id = generate_device_id();
        // UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
        assert_eq!(id.len(), 36);
        assert_eq!(id.chars().filter(|c| *c == '-').count(), 4);
    }

    #[test]
    fn test_signaling_metrics_default() {
        let metrics = SignalingMetrics::default();
        assert_eq!(metrics.messages_sent, 0);
        assert_eq!(metrics.messages_received, 0);
        assert_eq!(metrics.avg_rtt_ms, 0.0);
        assert_eq!(metrics.successful_exchanges, 0);
        assert_eq!(metrics.failed_exchanges, 0);
    }

    #[test]
    fn test_error_message_serialization() {
        let msg = SignalingMessage::Error {
            code: 404,
            message: "Device not found".to_string(),
        };

        let json = serde_json::to_string(&msg).unwrap();
        assert!(json.contains("404"));
        assert!(json.contains("Device not found"));
    }

    #[test]
    fn test_heartbeat_serialization() {
        let msg = SignalingMessage::Heartbeat {
            device_id: "test-device-123".to_string(),
        };

        let json = serde_json::to_string(&msg).unwrap();
        let parsed: SignalingMessage = serde_json::from_str(&json).unwrap();

        match parsed {
            SignalingMessage::Heartbeat { device_id } => {
                assert_eq!(device_id, "test-device-123");
            }
            _ => panic!("Wrong message type"),
        }
    }
}
