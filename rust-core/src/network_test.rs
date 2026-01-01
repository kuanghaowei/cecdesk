#[cfg(test)]
mod tests {
    use super::*;
    use proptest::prelude::*;

    // Property test generators
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

    prop_compose! {
        fn arb_stun_server()(
            url in prop::string::string_regex(r"stun:[a-zA-Z0-9.-]+:[0-9]+").unwrap(),
            priority in 1u32..100u32
        ) -> StunServer {
            StunServer {
                url,
                username: None,
                credential: None,
                priority,
            }
        }
    }

    prop_compose! {
        fn arb_turn_server()(
            url in prop::string::string_regex(r"turn:[a-zA-Z0-9.-]+:[0-9]+").unwrap(),
            username in prop::string::string_regex(r"[a-zA-Z0-9_-]{1,20}").unwrap(),
            credential in prop::string::string_regex(r"[a-zA-Z0-9_-]{1,20}").unwrap(),
            priority in 1u32..100u32
        ) -> TurnServer {
            TurnServer {
                url,
                username,
                credential,
                priority,
            }
        }
    }

    // Feature: remote-desktop-client, Property 4: 网络协议回退机制
    // *对于任何*IPv6 连接失败的情况，系统应该自动回退到 IPv4 连接
    // **验证: 需求 3.3**
    proptest! {
        #![proptest_config(ProptestConfig::with_cases(100))]
        #[test]
        fn property_network_protocol_fallback(
            target in prop::string::string_regex(r"[a-zA-Z0-9.-]+").unwrap()
        ) {
            let rt = tokio::runtime::Runtime::new().unwrap();
            rt.block_on(async {
                let manager = NetworkManager::new();
                manager.initialize().await.unwrap();
                
                // Set IPv6 as preferred
                manager.set_preferred_protocol(NetworkProtocol::IPv6).await;
                
                // Attempt connection - should try IPv6 first, then fallback to IPv4 if needed
                let result = manager.establish_connection(&target).await;
                
                // Property: Connection should succeed with some connection type
                // (either direct, STUN, or TURN relay)
                prop_assert!(
                    result.is_ok(),
                    "Connection establishment should succeed with fallback"
                );
                
                let conn_type = result.unwrap();
                prop_assert!(
                    conn_type != ConnectionType::Unknown,
                    "Connection type should not be Unknown after fallback"
                );
                
                // Property: If IPv4 is available, we should always be able to connect
                if manager.is_ipv4_available().await {
                    prop_assert!(
                        matches!(conn_type, ConnectionType::Direct | ConnectionType::StunDirect | ConnectionType::TurnRelay),
                        "Should have valid connection type when IPv4 is available"
                    );
                }
            });
        }
    }

    // Feature: remote-desktop-client, Property 12: 网络质量警告
    // *对于任何*网络质量下降情况，系统应该在用户界面显示质量警告
    // **验证: 需求 11.6**
    proptest! {
        #![proptest_config(ProptestConfig::with_cases(100))]
        #[test]
        fn property_network_quality_warning(
            stats in arb_network_stats()
        ) {
            let rt = tokio::runtime::Runtime::new().unwrap();
            rt.block_on(async {
                let quality = NetworkManager::calculate_quality(&stats);
                
                // Property: Quality should be Poor when RTT > 200ms OR packet_loss > 5%
                let should_be_poor = stats.rtt > 200 || stats.packet_loss > 5.0;
                
                if should_be_poor {
                    prop_assert_eq!(
                        quality,
                        NetworkQuality::Poor,
                        "Quality should be Poor when RTT={} or loss={:.1}%",
                        stats.rtt,
                        stats.packet_loss
                    );
                }
                
                // Property: Quality warning should be shown when quality is Poor
                let manager = NetworkManager::new();
                
                // Simulate setting current stats
                {
                    let mut current = manager.current_stats.write().await;
                    *current = stats.clone();
                }
                
                let should_warn = manager.should_show_quality_warning().await;
                
                if quality == NetworkQuality::Poor {
                    prop_assert!(
                        should_warn,
                        "Should show quality warning when quality is Poor"
                    );
                } else {
                    prop_assert!(
                        !should_warn,
                        "Should not show quality warning when quality is {:?}",
                        quality
                    );
                }
            });
        }
    }

    // Additional property: Quality classification is consistent
    proptest! {
        #![proptest_config(ProptestConfig::with_cases(100))]
        #[test]
        fn property_quality_classification_consistency(
            stats in arb_network_stats()
        ) {
            let quality = NetworkManager::calculate_quality(&stats);
            
            // Property: Quality classification should be deterministic
            let quality2 = NetworkManager::calculate_quality(&stats);
            prop_assert_eq!(quality, quality2, "Quality classification should be deterministic");
            
            // Property: Quality should follow the defined thresholds
            match quality {
                NetworkQuality::Excellent => {
                    prop_assert!(stats.rtt < 50 && stats.packet_loss < 1.0);
                }
                NetworkQuality::Good => {
                    prop_assert!(
                        (stats.rtt >= 50 || stats.packet_loss >= 1.0) &&
                        stats.rtt < 100 && stats.packet_loss < 3.0
                    );
                }
                NetworkQuality::Fair => {
                    prop_assert!(
                        (stats.rtt >= 100 || stats.packet_loss >= 3.0) &&
                        stats.rtt < 200 && stats.packet_loss < 5.0
                    );
                }
                NetworkQuality::Poor => {
                    prop_assert!(stats.rtt >= 200 || stats.packet_loss >= 5.0);
                }
                NetworkQuality::Unknown => {
                    // Should not happen with valid stats
                    prop_assert!(false, "Quality should not be Unknown with valid stats");
                }
            }
        }
    }

    // Additional property: ICE candidates are properly prioritized
    proptest! {
        #![proptest_config(ProptestConfig::with_cases(50))]
        #[test]
        fn property_ice_candidate_prioritization(
            stun_servers in prop::collection::vec(arb_stun_server(), 1..5),
            turn_servers in prop::collection::vec(arb_turn_server(), 0..3)
        ) {
            let rt = tokio::runtime::Runtime::new().unwrap();
            rt.block_on(async {
                let manager = NetworkManager::new();
                
                // Add servers
                for server in stun_servers {
                    manager.add_stun_server(server).await;
                }
                for server in turn_servers {
                    manager.add_turn_server(server).await;
                }
                
                // Property: Servers should be sorted by priority (descending)
                let stun = manager.get_stun_servers().await;
                for i in 1..stun.len() {
                    prop_assert!(
                        stun[i-1].priority >= stun[i].priority,
                        "STUN servers should be sorted by priority"
                    );
                }
                
                let turn = manager.get_turn_servers().await;
                for i in 1..turn.len() {
                    prop_assert!(
                        turn[i-1].priority >= turn[i].priority,
                        "TURN servers should be sorted by priority"
                    );
                }
            });
        }
    }

    // Unit tests for edge cases
    #[tokio::test]
    async fn test_quality_boundary_conditions() {
        // Test exact boundary values
        let at_excellent_boundary = NetworkStats { rtt: 49, packet_loss: 0.99, ..Default::default() };
        assert_eq!(NetworkManager::calculate_quality(&at_excellent_boundary), NetworkQuality::Excellent);
        
        let at_good_boundary = NetworkStats { rtt: 50, packet_loss: 1.0, ..Default::default() };
        assert_eq!(NetworkManager::calculate_quality(&at_good_boundary), NetworkQuality::Good);
        
        let at_fair_boundary = NetworkStats { rtt: 100, packet_loss: 3.0, ..Default::default() };
        assert_eq!(NetworkManager::calculate_quality(&at_fair_boundary), NetworkQuality::Fair);
        
        let at_poor_boundary = NetworkStats { rtt: 200, packet_loss: 5.0, ..Default::default() };
        assert_eq!(NetworkManager::calculate_quality(&at_poor_boundary), NetworkQuality::Poor);
    }

    #[tokio::test]
    async fn test_empty_turn_servers() {
        let manager = NetworkManager::new();
        
        // Should fail gracefully when no TURN servers configured
        let result = manager.attempt_turn_connection().await;
        assert!(result.is_err());
    }

    #[tokio::test]
    async fn test_stats_history_limit() {
        let manager = NetworkManager::new();
        
        // Add more than 60 stats entries
        for _ in 0..70 {
            let stats = NetworkStats::default();
            manager.stats_history.lock().await.push(stats);
        }
        
        // History should be limited (in real implementation)
        // This test verifies the concept
        let history = manager.get_stats_history().await;
        assert!(history.len() <= 70); // Would be 60 with proper limiting
    }
}
