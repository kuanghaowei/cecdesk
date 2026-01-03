//! Property-based tests for WebRTC Engine

use crate::webrtc_engine::{IceServer, RTCConfiguration, RTCPeerConnectionState, WebRTCEngine};
use proptest::prelude::*;

prop_compose! {
    fn arb_ice_server()(
        urls in prop::collection::vec(
            "[a-zA-Z0-9.-]+:[0-9]+".prop_map(|s| format!("stun:{}", s)),
            1..4
        ),
        username in prop::option::of("[a-zA-Z0-9_-]{1,20}"),
        credential in prop::option::of("[a-zA-Z0-9_-]{1,20}")
    ) -> IceServer {
        IceServer {
            urls,
            username,
            credential,
        }
    }
}

prop_compose! {
    fn arb_rtc_configuration()(
        ice_servers in prop::collection::vec(arb_ice_server(), 1..3),
        ice_transport_policy in Just("all".to_string()),
        bundle_policy in prop::option::of(Just("balanced".to_string())),
        rtcp_mux_policy in prop::option::of(Just("require".to_string()))
    ) -> RTCConfiguration {
        RTCConfiguration {
            ice_servers,
            ice_transport_policy,
            bundle_policy,
            rtcp_mux_policy,
        }
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(100))]

    #[test]
    fn property_webrtc_protocol_usage(
        config in arb_rtc_configuration(),
        remote_id in "[a-zA-Z0-9_-]{8,32}"
    ) {
        let rt = tokio::runtime::Runtime::new().unwrap();
        rt.block_on(async {
            let engine = WebRTCEngine::new().await.expect("Failed to create WebRTC engine");

            let connection_id = engine.create_peer_connection(config).await
                .expect("Failed to create peer connection");

            assert!(!connection_id.is_empty(), "Connection ID should not be empty");

            let state = engine.get_connection_state(&connection_id).await;
            assert_eq!(state, Some(RTCPeerConnectionState::New));

            let result = engine.establish_connection(&connection_id, remote_id).await;
            assert!(result.is_ok(), "WebRTC connection establishment should succeed");

            let _ = engine.close_connection(&connection_id).await;
        });
    }
}

#[cfg(test)]
mod unit_tests {
    use super::*;

    #[tokio::test]
    async fn test_webrtc_engine_creation() {
        let engine = WebRTCEngine::new().await;
        assert!(
            engine.is_ok(),
            "WebRTC engine should be created successfully"
        );
    }

    #[tokio::test]
    async fn test_peer_connection_lifecycle() {
        let engine = WebRTCEngine::new().await.expect("Failed to create engine");

        let config = RTCConfiguration {
            ice_servers: vec![IceServer {
                urls: vec!["stun:stun.l.google.com:19302".to_string()],
                username: None,
                credential: None,
            }],
            ice_transport_policy: "all".to_string(),
            bundle_policy: None,
            rtcp_mux_policy: None,
        };

        let connection_id = engine
            .create_peer_connection(config)
            .await
            .expect("Failed to create peer connection");

        let state = engine.get_connection_state(&connection_id).await;
        assert_eq!(state, Some(RTCPeerConnectionState::New));

        engine
            .close_connection(&connection_id)
            .await
            .expect("Failed to close connection");

        let state = engine.get_connection_state(&connection_id).await;
        assert_eq!(state, None);
    }

    #[tokio::test]
    async fn test_connection_not_found_error() {
        let engine = WebRTCEngine::new().await.expect("Failed to create engine");

        let result = engine
            .establish_connection("non-existent", "remote123".to_string())
            .await;
        assert!(result.is_err(), "Should fail for non-existent connection");

        let result = engine.close_connection("non-existent").await;
        assert!(
            result.is_ok(),
            "Closing non-existent connection should not error"
        );
    }

    #[tokio::test]
    async fn test_empty_ice_servers_config() {
        let engine = WebRTCEngine::new().await.expect("Failed to create engine");

        let config = RTCConfiguration {
            ice_servers: vec![],
            ice_transport_policy: "all".to_string(),
            bundle_policy: None,
            rtcp_mux_policy: None,
        };

        let result = engine.create_peer_connection(config).await;
        assert!(result.is_ok(), "Should handle empty ICE servers gracefully");
    }
}
