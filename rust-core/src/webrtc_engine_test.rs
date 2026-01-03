//! Property-based tests for WebRTC Engine
//!
//! Note: These tests avoid real network calls to prevent CI timeouts.
//! Tests that require network connectivity are marked with #[ignore].

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

    /// Property: For any valid RTCConfiguration, creating a peer connection should succeed
    /// and return a non-empty connection ID with initial state "New".
    /// 
    /// Note: This test only validates connection creation, not network establishment,
    /// to avoid CI timeouts from unreachable STUN servers.
    #[test]
    fn property_peer_connection_creation(
        config in arb_rtc_configuration()
    ) {
        let rt = tokio::runtime::Runtime::new().unwrap();
        rt.block_on(async {
            let engine = WebRTCEngine::new().await.expect("Failed to create WebRTC engine");

            let connection_id = engine.create_peer_connection(config).await
                .expect("Failed to create peer connection");

            // Property 1: Connection ID should always be non-empty
            assert!(!connection_id.is_empty(), "Connection ID should not be empty");

            // Property 2: Initial state should always be New
            let state = engine.get_connection_state(&connection_id).await;
            assert_eq!(state, Some(RTCPeerConnectionState::New));

            // Property 3: Closing should always succeed
            let close_result = engine.close_connection(&connection_id).await;
            assert!(close_result.is_ok(), "Closing connection should succeed");

            // Property 4: After closing, state should be None
            let state_after_close = engine.get_connection_state(&connection_id).await;
            assert_eq!(state_after_close, None, "State should be None after closing");
        });
    }

    /// Property: Connection IDs should be unique across multiple creations
    #[test]
    fn property_connection_ids_unique(
        configs in prop::collection::vec(arb_rtc_configuration(), 2..5)
    ) {
        let rt = tokio::runtime::Runtime::new().unwrap();
        rt.block_on(async {
            let engine = WebRTCEngine::new().await.expect("Failed to create WebRTC engine");
            
            let mut connection_ids = Vec::new();
            for config in configs {
                let id = engine.create_peer_connection(config).await
                    .expect("Failed to create peer connection");
                connection_ids.push(id);
            }

            // All IDs should be unique
            let unique_count = {
                let mut sorted = connection_ids.clone();
                sorted.sort();
                sorted.dedup();
                sorted.len()
            };
            assert_eq!(unique_count, connection_ids.len(), "All connection IDs should be unique");

            // Cleanup
            for id in connection_ids {
                let _ = engine.close_connection(&id).await;
            }
        });
    }
}

// Network-dependent test - requires actual STUN server connectivity
// Run with: cargo test -- --ignored
#[cfg(test)]
mod network_tests {
    use super::*;

    #[tokio::test]
    #[ignore = "Requires network connectivity to STUN server"]
    async fn test_establish_connection_with_real_stun() {
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

        let result = engine
            .establish_connection(&connection_id, "remote123".to_string())
            .await;
        assert!(result.is_ok(), "Connection establishment should succeed");

        engine
            .close_connection(&connection_id)
            .await
            .expect("Failed to close connection");
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

    /// Test peer connection lifecycle without network calls
    /// Uses empty ICE servers to avoid network timeouts
    #[tokio::test]
    async fn test_peer_connection_lifecycle() {
        let engine = WebRTCEngine::new().await.expect("Failed to create engine");

        // Use empty ICE servers to avoid network calls
        let config = RTCConfiguration {
            ice_servers: vec![],
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

    #[tokio::test]
    async fn test_multiple_connections() {
        let engine = WebRTCEngine::new().await.expect("Failed to create engine");

        let config = RTCConfiguration {
            ice_servers: vec![],
            ice_transport_policy: "all".to_string(),
            bundle_policy: None,
            rtcp_mux_policy: None,
        };

        // Create multiple connections
        let id1 = engine.create_peer_connection(config.clone()).await.unwrap();
        let id2 = engine.create_peer_connection(config.clo
