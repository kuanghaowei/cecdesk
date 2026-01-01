#[cfg(test)]
mod tests {
    use super::*;
    use proptest::prelude::*;
    use std::time::Duration;
    use tokio::time::timeout;

    // Property test generators
    prop_compose! {
        fn arb_ice_server()(
            urls in prop::collection::vec(
                prop::string::string_regex(r"(stun|turn):[a-zA-Z0-9.-]+:[0-9]+").unwrap(),
                1..4
            ),
            username in prop::option::of(prop::string::string_regex(r"[a-zA-Z0-9_-]{1,20}").unwrap()),
            credential in prop::option::of(prop::string::string_regex(r"[a-zA-Z0-9_-]{1,20}").unwrap())
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
            ice_transport_policy in prop::option::of(Just("all".to_string())).prop_map(|x| x.unwrap_or_else(|| "all".to_string())),
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

    // Feature: remote-desktop-client, Property 2: WebRTC 协议使用
    // *对于任何*远程桌面连接建立，系统应该使用 WebRTC 协议传输音视频数据
    // **验证: 需求 2.1**
    proptest! {
        #[test]
        fn property_webrtc_protocol_usage(
            config in arb_rtc_configuration(),
            remote_id in prop::string::string_regex(r"[a-zA-Z0-9_-]{8,32}").unwrap()
        ) {
            let rt = tokio::runtime::Runtime::new().unwrap();
            rt.block_on(async {
                // Create WebRTC engine
                let engine = WebRTCEngine::new().await.expect("Failed to create WebRTC engine");
                
                // Create peer connection - this should always use WebRTC protocol
                let connection_id = engine.create_peer_connection(config).await
                    .expect("Failed to create peer connection");
                
                // Verify connection was created with WebRTC protocol
                prop_assert!(connection_id.len() > 0, "Connection ID should not be empty");
                
                // Verify initial state is New (WebRTC standard)
                let state = engine.get_connection_state(&connection_id).await;
                prop_assert_eq!(state, Some(RTCPeerConnectionState::New));
                
                // Attempt to establish connection - should use WebRTC offer/answer
                let result = engine.establish_connection(&connection_id, remote_id).await;
                prop_assert!(result.is_ok(), "WebRTC connection establishment should succeed");
                
                // Clean up
                let _ = engine.close_connection(&connection_id).await;
            });
        }
    }

    // Unit tests for specific examples and edge cases
    #[tokio::test]
    async fn test_webrtc_engine_creation() {
        let engine = WebRTCEngine::new().await;
        assert!(engine.is_ok(), "WebRTC engine should be created successfully");
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
        
        // Create connection
        let connection_id = engine.create_peer_connection(config).await
            .expect("Failed to create peer connection");
        
        // Verify initial state
        let state = engine.get_connection_state(&connection_id).await;
        assert_eq!(state, Some(RTCPeerConnectionState::New));
        
        // Close connection
        engine.close_connection(&connection_id).await
            .expect("Failed to close connection");
        
        // Verify connection is removed
        let state = engine.get_connection_state(&connection_id).await;
        assert_eq!(state, None);
    }

    #[tokio::test]
    async fn test_connection_not_found_error() {
        let engine = WebRTCEngine::new().await.expect("Failed to create engine");
        
        // Try to establish connection with non-existent connection ID
        let result = engine.establish_connection("non-existent", "remote123".to_string()).await;
        assert!(result.is_err(), "Should fail for non-existent connection");
        
        // Try to close non-existent connection (should not error)
        let result = engine.close_connection("non-existent").await;
        assert!(result.is_ok(), "Closing non-existent connection should not error");
    }

    #[tokio::test]
    async fn test_empty_ice_servers_config() {
        let engine = WebRTCEngine::new().await.expect("Failed to create engine");
        
        let config = RTCConfiguration {
            ice_servers: vec![], // Empty ICE servers
            ice_transport_policy: "all".to_string(),
            bundle_policy: None,
            rtcp_mux_policy: None,
        };
        
        // Should still be able to create connection even with empty ICE servers
        let result = engine.create_peer_connection(config).await;
        assert!(result.is_ok(), "Should handle empty ICE servers gracefully");
    }

    #[tokio::test]
    async fn test_connection_stats() {
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
        
        let connection_id = engine.create_peer_connection(config).await
            .expect("Failed to create peer connection");
        
        // Get connection stats
        let stats = engine.get_connection_stats(&connection_id).await;
        assert!(stats.is_ok(), "Should be able to get connection stats");
        
        let stats = stats.unwrap();
        assert_eq!(stats.connection_id, connection_id);
        assert_eq!(stats.state, RTCPeerConnectionState::New);
    }
}