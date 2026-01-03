//! Property-based tests for Screen Capture module

use crate::screen_capture::{
    AdaptiveBitrateConfig, NetworkConditions, QualityPreset, ScreenCapturer,
};
use proptest::prelude::*;

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
            capturer.set_adaptive_config(config.clone()).await;
            capturer.adapt_to_network_conditions(conditions.clone()).await;
            let options = capturer.get_current_options().await;

            assert!(options.bitrate >= config.min_bitrate && options.bitrate <= config.max_bitrate);
            assert!(options.frame_rate >= config.min_frame_rate && options.frame_rate <= config.max_frame_rate);
        });
    }

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

            capturer.apply_quality_preset(preset).await;
            let options = capturer.get_current_options().await;
            assert!(options.frame_rate >= 15 && options.frame_rate <= 60);

            capturer.set_frame_rate(manual_fps).await;
            let options = capturer.get_current_options().await;
            assert!(options.frame_rate >= 15 && options.frame_rate <= 60);
        });
    }
}

#[cfg(test)]
mod unit_tests {
    use super::*;

    #[tokio::test]
    async fn test_quality_preset_frame_rates() {
        let capturer = ScreenCapturer::new();

        capturer.apply_quality_preset(QualityPreset::Low).await;
        assert_eq!(capturer.get_current_options().await.frame_rate, 15);

        capturer.apply_quality_preset(QualityPreset::Balanced).await;
        assert_eq!(capturer.get_current_options().await.frame_rate, 30);

        capturer.apply_quality_preset(QualityPreset::High).await;
        assert_eq!(capturer.get_current_options().await.frame_rate, 60);
    }
}
