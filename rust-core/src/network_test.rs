//! Property-based tests for Network module
//!
//! Feature: cec-remote
//! Property       - Network protocol fallback mechanism
//! Property 12: 网络质量警告 - Network quality warning
//! Validates: Requirements 3.3, 11.6

use crate::network::{
    ConnectionType, NetworkManager, NetworkProtocol, NetworkQuality, NetworkStats,
};
use proptest::prelude::*;

prop_compose! {
    fn arb_network_stats()(
        rtt in 0u32..1000u32,
        packet_loss in 0.0f32..100.0f32,
        jitter in 0u32..500u32,
        bandwidth in 100000u64..100000000u64
    ) -> NetworkStats {
        NetworkStats {
            rtt,
            packet_loss,
            jitter,
            bandwidth,
            connection_type: ConnectionType::Direct,
            local_address: Some("192.168.1.100:54321".to_string()),
            remote_address: Some("203.0.113.1:12345".to_string()),
            protocol: NetworkProtocol::IPv4,
        }
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(100))]

    #[test]
    fn property_network_quality_warning(stats in arb_network_stats()) {
        let quality = NetworkManager::calculate_quality(&stats);
        let should_be_poor = stats.rtt >= 200 || stats.packet_loss >= 5.0;
        if should_be_poor {
            prop_assert_eq!(quality, NetworkQuality::Poor);
        }
    }

    #[test]
    fn property_quality_classification_consistency(stats in arb_network_stats()) {
        let quality = NetworkManager::calculate_quality(&stats);
        let quality2 = NetworkManager::calculate_quality(&stats);
        prop_assert_eq!(quality, quality2);
    }
}

#[cfg(test)]
mod unit_tests {
    use super::*;

    #[tokio::test]
    async fn test_quality_boundary_conditions() {
        let at_excellent = NetworkStats {
            rtt: 49,
            packet_loss: 0.99,
            jitter: 0,
            bandwidth: 1000000,
            connection_type: ConnectionType::Direct,
            local_address: None,
            remote_address: None,
            protocol: NetworkProtocol::IPv4,
        };
        assert_eq!(
            NetworkManager::calculate_quality(&at_excellent),
            NetworkQuality::Excellent
        );

        let at_poor = NetworkStats {
            rtt: 200,
            packet_loss: 5.0,
            jitter: 0,
            bandwidth: 1000000,
            connection_type: ConnectionType::Direct,
            local_address: None,
            remote_address: None,
            protocol: NetworkProtocol::IPv4,
        };
        assert_eq!(
            NetworkManager::calculate_quality(&at_poor),
            NetworkQuality::Poor
        );
    }

    #[tokio::test]
    async fn test_empty_turn_servers() {
        let manager = NetworkManager::new();
        let result = manager.attempt_turn_connection().await;
        assert!(result.is_err());
    }

    #[tokio::test]
    async fn test_network_manager_creation() {
        let manager = NetworkManager::new();
        let stats = manager.current_stats.read().await;
        assert_eq!(stats.rtt, 0);
    }
}
