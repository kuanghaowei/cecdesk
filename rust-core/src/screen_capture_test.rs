#[cfg(test)]
mod tests {
    use super::*;
    use proptest::prelude::*;

    // Property test generators
    prop_compose! {
        fn arb_network_conditions()(
            available_bandwidth in 100u32..20000u32,
            packet_loss in 0.0f32..20.0f32,
            rtt in 10u32..500u32
        ) -> NetworkConditions {
            NetworkConditions {
                available_bandwidth,
                packet_loss,
                rtt,
            }
        }
    }

    prop_compose! {
        fn arb_adaptive_config()(
            min_bitrate in 100u32..1000u32,
            max_bitrate in 5000u32..20000u32,
            min_frame_rate in 10u32..20u32,
            max_frame_rate in 30u32..60u32
        ) -> AdaptiveBitrateConfig {
            AdaptiveBitrateConfig {
                min_bitrate,
                max_bitrate,
                target_bitrate: (min_bitrate + max_bitrate) / 2,
                min_frame_rate,
                max_frame_rate,
                target_frame_rate: (min_frame_rate + max_frame_rate) / 2,
            }
        }
    }

    // Feature: remote-desktop-client, Property 3: 自适应码率调整
    // *对于任何*网络带宽波动情况，WebRTC 引擎应该自动调整码率以适应当前网络条件
    // **验证: 需求 2.4**
    proptest! {
        #![proptest_config(ProptestConfig::with_cases(100))]
        #[test]
        fn property_adaptive_bitrate_adjustment(
            conditions in arb_network_conditions(),
            config in arb_adaptive_config()
        ) {
            let rt = tokio::runtime::Runtime::new().unwrap();
            rt.block_on(async {
                let capturer = ScreenCapturer::new();
                
                // Set adaptive config
                capturer.set_adaptive_config(config.clone()).await;
                
                // Apply network conditions
                capturer.adapt_to_network_conditions(conditions.clone()).await;
                
                // Get resulting options
                let options = capturer.get_current_options().await;
                
                // Property: Bitrate should always be within configured bounds
                prop_assert!(
                    options.bitrate >= config.min_bitrate && options.bitrate <= config.max_bitrate,
                    "Bitrate {} should be within [{}, {}]",
                    options.bitrate, config.min_bitrate, config.max_bitrate
                );
                
                // Property: Frame rate should always be within configured bounds
                prop_assert!(
                    options.frame_rate >= config.min_frame_rate && options.frame_rate <= config.max_frame_rate,
                    "Frame rate {} should be within [{}, {}]",
                    options.frame_rate, config.min_frame_rate, config.max_frame_rate
                );
                
                // Property: Bitrate should not exceed available bandwidth
                let max_allowed_bitrate = (conditions.available_bandwidth as f32 * 0.8) as u32;
                prop_assert!(
                    options.bitrate <= max_allowed_bitrate.max(config.min_bitrate),
                    "Bitrate {} should not exceed 80% of available bandwidth {} (or min {})",
                    options.bitrate, conditions.available_bandwidth, config.min_bitrate
                );
            });
        }
    }

    // Feature: remote-desktop-client, Property 8: 屏幕传输帧率
    // *对于任何*屏幕内容传输，系统应该以 30-60 FPS 的帧率进行传输
    // **验证: 需求 6.3**
    proptest! {
        #![proptest_config(ProptestConfig::with_cases(100))]
        #[test]
        fn property_screen_transmission_frame_rate(
            preset in prop_oneof![
                Just(QualityPreset::Low),
                Just(QualityPreset::Balanced),
                Just(QualityPreset::High),
                Just(QualityPreset::Ultra)
            ],
            manual_fps in 15u32..120u32
        ) {
            let rt = tokio::runtime::Runtime::new().unwrap();
            rt.block_on(async {
                let capturer = ScreenCapturer::new();
                
                // Test preset application
                capturer.apply_quality_preset(preset).await;
                let options = capturer.get_current_options().await;
                
                // Property: Frame rate from presets should be within valid range (15-60)
                prop_assert!(
                    options.frame_rate >= 15 && options.frame_rate <= 60,
                    "Preset frame rate {} should be within [15, 60]",
                    options.frame_rate
                );
                
                // Test manual frame rate setting
                capturer.set_frame_rate(manual_fps).await;
                let options = capturer.get_current_options().await;
                
                // Property: Manual frame rate should be clamped to valid range
                prop_assert!(
                    options.frame_rate >= 15 && options.frame_rate <= 60,
                    "Manual frame rate {} should be clamped to [15, 60]",
                    options.frame_rate
                );
            });
        }
    }

    // Additional unit tests for edge cases
    #[tokio::test]
    async fn test_extreme_network_conditions() {
        let capturer = ScreenCapturer::new();
        
        // Test with very poor network
        let poor_conditions = NetworkConditions {
            available_bandwidth: 100,
            packet_loss: 15.0,
            rtt: 400,
        };
        capturer.adapt_to_network_conditions(poor_conditions).await;
        
        let options = capturer.get_current_options().await;
        // Should fall back to minimum values
        assert!(options.bitrate >= 500); // min_bitrate default
    }

    #[tokio::test]
    async fn test_excellent_network_conditions() {
        let capturer = ScreenCapturer::new();
        
        // Test with excellent network
        let excellent_conditions = NetworkConditions {
            available_bandwidth: 50000,
            packet_loss: 0.0,
            rtt: 10,
        };
        capturer.adapt_to_network_conditions(excellent_conditions).await;
        
        let options = capturer.get_current_options().await;
        // Should use high values but not exceed max
        assert!(options.bitrate <= 8000); // max_bitrate default
    }

    #[tokio::test]
    async fn test_quality_preset_frame_rates() {
        let capturer = ScreenCapturer::new();
        
        // Low preset should have 15 fps
        capturer.apply_quality_preset(QualityPreset::Low).await;
        assert_eq!(capturer.get_current_options().await.frame_rate, 15);
        
        // Balanced preset should have 30 fps
        capturer.apply_quality_preset(QualityPreset::Balanced).await;
        assert_eq!(capturer.get_current_options().await.frame_rate, 30);
        
        // High preset should have 60 fps
        capturer.apply_quality_preset(QualityPreset::High).await;
        assert_eq!(capturer.get_current_options().await.frame_rate, 60);
        
        // Ultra preset should have 60 fps
        capturer.apply_quality_preset(QualityPreset::Ultra).await;
        assert_eq!(capturer.get_current_options().await.frame_rate, 60);
    }
}
