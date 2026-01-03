//! Mock WebRTC implementation for testing
//!
//! This module provides a lightweight mock implementation of the WebRTC engine
//! that can be used in unit tests without requiring actual WebRTC initialization
//! or network operations. The mock uses simple HashMap-based storage and completes
//! all operations synchronously.

use crate::webrtc_engine::{RTCConfiguration, RTCPeerConnectionState};
use anyhow::Result;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::Mutex;
use uuid::Uuid;

/// Mock connection information stored in the mock engine
#[derive(Debug, Clone)]
struct MockConnectionInfo {
    id: String,
    state: RTCPeerConnectionState,
    remote_id: Option<String>,
}

/// Mock WebRTC engine for testing
///
/// This implementation provides the same interface as WebRTCEngine but without
/// any actual WebRTC or network operations. All operations complete immediately
/// and deterministically.
pub struct MockWebRTCEngine {
    connections: Arc<Mutex<HashMap<String, MockConnectionInfo>>>,
}

impl MockWebRTCEngine {
    /// Create a new mock WebRTC engine
    pub fn new() -> Self {
        Self {
            connections: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    /// Create a mock peer connection
    ///
    /// Returns a unique connection ID immediately without any network operations.
    /// The connection is initialized with state "New".
    pub async fn create_peer_connection(&self, _config: RTCConfiguration) -> Result<String> {
        let connection_id = Uuid::new_v4().to_string();

        let connection_info = MockConnectionInfo {
            id: connection_id.clone(),
            state: RTCPeerConnectionState::New,
            remote_id: None,
        };

        self.connections
            .lock()
            .await
            .insert(connection_id.clone(), connection_info);

        Ok(connection_id)
    }

    /// Get the state of a mock connection
    ///
    /// Returns None if the connection doesn't exist.
    pub async fn get_connection_state(
        &self,
        connection_id: &str,
    ) -> Option<RTCPeerConnectionState> {
        let connections = self.connections.lock().await;
        connections
            .get(connection_id)
            .map(|conn| conn.state.clone())
    }

    /// Close a mock connection
    ///
    /// Removes the connection from storage. This operation is idempotent -
    /// closing a non-existent connection succeeds without error.
    pub async fn close_connection(&self, connection_id: &str) -> Result<()> {
        let mut connections = self.connections.lock().await;
        connections.remove(connection_id);
        Ok(())
    }

    /// Establish a mock connection to a remote peer
    ///
    /// Returns an error if the connection doesn't exist.
    pub async fn establish_connection(&self, connection_id: &str, remote_id: String) -> Result<()> {
        let mut connections = self.connections.lock().await;

        let connection_info = connections
            .get_mut(connection_id)
            .ok_or_else(|| anyhow::anyhow!("Connection not found: {}", connection_id))?;

        connection_info.remote_id = Some(remote_id);
        connection_info.state = RTCPeerConnectionState::Connecting;

        Ok(())
    }
}

impl Default for MockWebRTCEngine {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_single_connection_creation() {
        let engine = MockWebRTCEngine::new();

        let config = RTCConfiguration {
            ice_servers: vec![],
            ice_transport_policy: "all".to_string(),
            bundle_policy: None,
            rtcp_mux_policy: None,
        };

        let connection_id = engine
            .create_peer_connection(config)
            .await
            .expect("Failed to create connection");

        assert!(
            !connection_id.is_empty(),
            "Connection ID should not be empty"
        );
    }

    #[tokio::test]
    async fn test_newly_created_connection_has_new_state() {
        let engine = MockWebRTCEngine::new();

        let config = RTCConfiguration {
            ice_servers: vec![],
            ice_transport_policy: "all".to_string(),
            bundle_policy: None,
            rtcp_mux_policy: None,
        };

        let connection_id = engine
            .create_peer_connection(config)
            .await
            .expect("Failed to create connection");

        let state = engine.get_connection_state(&connection_id).await;
        assert_eq!(
            state,
            Some(RTCPeerConnectionState::New),
            "Newly created connection should have 'New' state"
        );
    }

    #[tokio::test]
    async fn test_closing_connection_removes_state() {
        let engine = MockWebRTCEngine::new();

        let config = RTCConfiguration {
            ice_servers: vec![],
            ice_transport_policy: "all".to_string(),
            bundle_policy: None,
            rtcp_mux_policy: None,
        };

        let connection_id = engine
            .create_peer_connection(config)
            .await
            .expect("Failed to create connection");

        engine
            .close_connection(&connection_id)
            .await
            .expect("Failed to close connection");

        let state = engine.get_connection_state(&connection_id).await;
        assert_eq!(state, None, "State should be None after closing connection");
    }

    #[tokio::test]
    async fn test_querying_nonexistent_connection_returns_none() {
        let engine = MockWebRTCEngine::new();

        let state = engine.get_connection_state("non-existent-id").await;
        assert_eq!(
            state, None,
            "Querying non-existent connection should return None"
        );
    }

    #[tokio::test]
    async fn test_closing_nonexistent_connection_succeeds() {
        let engine = MockWebRTCEngine::new();

        let result = engine.close_connection("non-existent-id").await;
        assert!(
            result.is_ok(),
            "Closing non-existent connection should succeed (idempotence)"
        );
    }
}

#[cfg(test)]
mod property_tests {
    use super::*;
    use proptest::prelude::*;

    // Feature: webrtc-test-refactor, Property 1: Connection ID Uniqueness
    // Validates: Requirements 4.2
    proptest! {
        #![proptest_config(ProptestConfig::with_cases(100))]

        #[test]
        fn property_connection_id_uniqueness(num_connections in 2usize..=10) {
            let rt = tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
                .unwrap();

            rt.block_on(async {
                let engine = MockWebRTCEngine::new();

                let config = RTCConfiguration {
                    ice_servers: vec![],
                    ice_transport_policy: "all".to_string(),
                    bundle_policy: None,
                    rtcp_mux_policy: None,
                };

                let mut connection_ids = Vec::new();
                for _ in 0..num_connections {
                    let id = engine
                        .create_peer_connection(config.clone())
                        .await
                        .expect("Failed to create connection");
                    connection_ids.push(id);
                }

                // All IDs should be unique
                let unique_count = {
                    let mut sorted = connection_ids.clone();
                    sorted.sort();
                    sorted.dedup();
                    sorted.len()
                };

                prop_assert_eq!(
                    unique_count,
                    connection_ids.len(),
                    "All connection IDs should be unique"
                );

                // Cleanup
                for id in connection_ids {
                    let _ = engine.close_connection(&id).await;
                }

                Ok(())
            })?;
        }
    }

    // Feature: webrtc-test-refactor, Property 2: Initial State Consistency
    // Validates: Requirements 4.3
    proptest! {
        #![proptest_config(ProptestConfig::with_cases(100))]

        #[test]
        fn property_initial_state_consistency(num_connections in 1usize..=10) {
            let rt = tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
                .unwrap();

            rt.block_on(async {
                let engine = MockWebRTCEngine::new();

                let config = RTCConfiguration {
                    ice_servers: vec![],
                    ice_transport_policy: "all".to_string(),
                    bundle_policy: None,
                    rtcp_mux_policy: None,
                };

                let mut connection_ids = Vec::new();
                for _ in 0..num_connections {
                    let id = engine
                        .create_peer_connection(config.clone())
                        .await
                        .expect("Failed to create connection");

                    // Verify state is always "New" immediately after creation
                    let state = engine.get_connection_state(&id).await;
                    prop_assert_eq!(
                        state,
                        Some(RTCPeerConnectionState::New),
                        "Newly created connection should always have 'New' state"
                    );

                    connection_ids.push(id);
                }

                // Cleanup
                for id in connection_ids {
                    let _ = engine.close_connection(&id).await;
                }

                Ok(())
            })?;
        }
    }

    // Feature: webrtc-test-refactor, Property 4: State Removal After Close
    // Validates: Requirements 4.3
    proptest! {
        #![proptest_config(ProptestConfig::with_cases(100))]

        #[test]
        fn property_state_removal_after_close(num_connections in 1usize..=10) {
            let rt = tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
                .unwrap();

            rt.block_on(async {
                let engine = MockWebRTCEngine::new();

                let config = RTCConfiguration {
                    ice_servers: vec![],
                    ice_transport_policy: "all".to_string(),
                    bundle_policy: None,
                    rtcp_mux_policy: None,
                };

                let mut connection_ids = Vec::new();
                for _ in 0..num_connections {
                    let id = engine
                        .create_peer_connection(config.clone())
                        .await
                        .expect("Failed to create connection");
                    connection_ids.push(id);
                }

                // Close all connections and verify state is None
                for id in &connection_ids {
                    engine
                        .close_connection(id)
                        .await
                        .expect("Failed to close connection");

                    let state = engine.get_connection_state(id).await;
                    prop_assert_eq!(
                        state,
                        None,
                        "State should be None after closing connection"
                    );
                }

                Ok(())
            })?;
        }
    }
}
