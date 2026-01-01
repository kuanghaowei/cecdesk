use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::{mpsc, Mutex, RwLock};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DisplayInfo {
    pub id: String,
    pub name: String,
    pub width: u32,
    pub height: u32,
    pub is_primary: bool,
    pub refresh_rate: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CaptureOptions {
    pub frame_rate: u32,
    pub width: u32,
    pub height: u32,
    pub enable_hardware_acceleration: bool,
    pub codec: VideoCodecType,
    pub bitrate: u32, // in kbps
    pub quality_preset: QualityPreset,
}

impl Default for CaptureOptions {
    fn default() -> Self {
        Self {
            frame_rate: 30,
            width: 1920,
            height: 1080,
            enable_hardware_acceleration: true,
            codec: VideoCodecType::H264,
            bitrate: 4000,
            quality_preset: QualityPreset::Balanced,
        }
    }
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
pub enum VideoCodecType {
    H264,
    H265,
    VP9,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
pub enum QualityPreset {
    Low,      // 720p, 15fps, low bitrate
    Balanced, // 1080p, 30fps, medium bitrate
    High,     // 1080p, 60fps, high bitrate
    Ultra,    // Native resolution, 60fps, maximum bitrate
}

#[derive(Debug, Clone)]
pub struct VideoFrame {
    pub id: u64,
    pub timestamp: u64,
    pub width: u32,
    pub height: u32,
    pub data: Vec<u8>,
    pub format: FrameFormat,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum FrameFormat {
    RGBA,
    BGRA,
    NV12,
    I420,
}


#[derive(Debug, Clone)]
pub struct AudioFrame {
    pub id: u64,
    pub timestamp: u64,
    pub sample_rate: u32,
    pub channels: u8,
    pub data: Vec<i16>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AudioCaptureOptions {
    pub sample_rate: u32,
    pub channels: u8,
    pub enable_noise_suppression: bool,
    pub enable_echo_cancellation: bool,
}

impl Default for AudioCaptureOptions {
    fn default() -> Self {
        Self {
            sample_rate: 48000,
            channels: 2,
            enable_noise_suppression: true,
            enable_echo_cancellation: true,
        }
    }
}

#[derive(Debug, Clone)]
pub struct NetworkConditions {
    pub available_bandwidth: u32, // in kbps
    pub packet_loss: f32,         // percentage
    pub rtt: u32,                 // in ms
}

#[derive(Debug, Clone)]
pub struct AdaptiveBitrateConfig {
    pub min_bitrate: u32,
    pub max_bitrate: u32,
    pub target_bitrate: u32,
    pub min_frame_rate: u32,
    pub max_frame_rate: u32,
    pub target_frame_rate: u32,
}

impl Default for AdaptiveBitrateConfig {
    fn default() -> Self {
        Self {
            min_bitrate: 500,
            max_bitrate: 8000,
            target_bitrate: 4000,
            min_frame_rate: 15,
            max_frame_rate: 60,
            target_frame_rate: 30,
        }
    }
}

pub struct ScreenCapturer {
    id: String,
    current_display: Option<String>,
    capture_options: Arc<RwLock<CaptureOptions>>,
    hardware_acceleration_available: bool,
    is_capturing: Arc<RwLock<bool>>,
    frame_sender: Option<mpsc::UnboundedSender<VideoFrame>>,
    frame_counter: Arc<Mutex<u64>>,
    adaptive_config: Arc<RwLock<AdaptiveBitrateConfig>>,
}


impl ScreenCapturer {
    pub fn new() -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            current_display: None,
            capture_options: Arc::new(RwLock::new(CaptureOptions::default())),
            hardware_acceleration_available: Self::check_hardware_acceleration(),
            is_capturing: Arc::new(RwLock::new(false)),
            frame_sender: None,
            frame_counter: Arc::new(Mutex::new(0)),
            adaptive_config: Arc::new(RwLock::new(AdaptiveBitrateConfig::default())),
        }
    }

    pub async fn get_available_displays(&self) -> Result<Vec<DisplayInfo>> {
        // Platform-specific display enumeration
        #[cfg(target_os = "windows")]
        {
            self.get_windows_displays().await
        }
        #[cfg(target_os = "macos")]
        {
            self.get_macos_displays().await
        }
        #[cfg(target_os = "linux")]
        {
            self.get_linux_displays().await
        }
        #[cfg(not(any(target_os = "windows", target_os = "macos", target_os = "linux")))]
        {
            // Fallback for other platforms
            Ok(vec![DisplayInfo {
                id: "display_0".to_string(),
                name: "Primary Display".to_string(),
                width: 1920,
                height: 1080,
                is_primary: true,
                refresh_rate: 60,
            }])
        }
    }

    #[cfg(target_os = "windows")]
    async fn get_windows_displays(&self) -> Result<Vec<DisplayInfo>> {
        // Windows-specific implementation using Win32 API
        Ok(vec![DisplayInfo {
            id: "display_0".to_string(),
            name: "Primary Display".to_string(),
            width: 1920,
            height: 1080,
            is_primary: true,
            refresh_rate: 60,
        }])
    }

    #[cfg(target_os = "macos")]
    async fn get_macos_displays(&self) -> Result<Vec<DisplayInfo>> {
        // macOS-specific implementation using Core Graphics
        Ok(vec![DisplayInfo {
            id: "display_0".to_string(),
            name: "Primary Display".to_string(),
            width: 1920,
            height: 1080,
            is_primary: true,
            refresh_rate: 60,
        }])
    }

    #[cfg(target_os = "linux")]
    async fn get_linux_displays(&self) -> Result<Vec<DisplayInfo>> {
        // Linux-specific implementation using X11/Wayland
        Ok(vec![DisplayInfo {
            id: "display_0".to_string(),
            name: "Primary Display".to_string(),
            width: 1920,
            height: 1080,
            is_primary: true,
            refresh_rate: 60,
        }])
    }

    pub async fn start_capture(&mut self, display_id: String, options: CaptureOptions) -> Result<mpsc::UnboundedReceiver<VideoFrame>> {
        let (sender, receiver) = mpsc::unbounded_channel();
        
        self.current_display = Some(display_id.clone());
        *self.capture_options.write().await = options.clone();
        self.frame_sender = Some(sender);
        *self.is_capturing.write().await = true;
        
        tracing::info!(
            "Starting screen capture for display: {} at {}x{} {}fps",
            display_id,
            options.width,
            options.height,
            options.frame_rate
        );
        
        // Start capture loop in background
        self.start_capture_loop().await?;
        
        Ok(receiver)
    }

    async fn start_capture_loop(&self) -> Result<()> {
        let is_capturing = Arc::clone(&self.is_capturing);
        let capture_options = Arc::clone(&self.capture_options);
        let frame_counter = Arc::clone(&self.frame_counter);
        let frame_sender = self.frame_sender.clone();
        
        tokio::spawn(async move {
            while *is_capturing.read().await {
                let options = capture_options.read().await;
                let frame_interval = std::time::Duration::from_millis(1000 / options.frame_rate as u64);
                drop(options);
                
                // Capture frame (placeholder - actual implementation would use platform APIs)
                if let Some(sender) = &frame_sender {
                    let mut counter = frame_counter.lock().await;
                    *counter += 1;
                    
                    let frame = VideoFrame {
                        id: *counter,
                        timestamp: std::time::SystemTime::now()
                            .duration_since(std::time::UNIX_EPOCH)
                            .unwrap()
                            .as_millis() as u64,
                        width: 1920,
                        height: 1080,
                        data: vec![], // Placeholder - actual frame data
                        format: FrameFormat::RGBA,
                    };
                    
                    let _ = sender.send(frame);
                }
                
                tokio::time::sleep(frame_interval).await;
            }
        });
        
        Ok(())
    }

    pub async fn stop_capture(&mut self) {
        *self.is_capturing.write().await = false;
        
        if let Some(display_id) = &self.current_display {
            tracing::info!("Stopping screen capture for display: {}", display_id);
        }
        
        self.current_display = None;
        self.frame_sender = None;
    }

    pub async fn set_video_codec(&self, codec: VideoCodecType) {
        let mut options = self.capture_options.write().await;
        options.codec = codec;
        tracing::info!("Setting video codec: {:?}", codec);
    }

    pub async fn set_frame_rate(&self, fps: u32) {
        let mut options = self.capture_options.write().await;
        options.frame_rate = fps.clamp(15, 60);
        tracing::info!("Setting frame rate: {} FPS", options.frame_rate);
    }

    pub async fn set_resolution(&self, width: u32, height: u32) {
        let mut options = self.capture_options.write().await;
        options.width = width;
        options.height = height;
        tracing::info!("Setting resolution: {}x{}", width, height);
    }

    pub async fn set_bitrate(&self, bitrate: u32) {
        let mut options = self.capture_options.write().await;
        options.bitrate = bitrate;
        tracing::info!("Setting bitrate: {} kbps", bitrate);
    }

    pub fn is_hardware_acceleration_available(&self) -> bool {
        self.hardware_acceleration_available
    }

    pub async fn enable_hardware_acceleration(&self, enable: bool) {
        let mut options = self.capture_options.write().await;
        options.enable_hardware_acceleration = enable && self.hardware_acceleration_available;
        tracing::info!(
            "Hardware acceleration: {}",
            if options.enable_hardware_acceleration { "enabled" } else { "disabled" }
        );
    }

    fn check_hardware_acceleration() -> bool {
        // Check for hardware encoding support
        #[cfg(target_os = "windows")]
        {
            // Check for NVENC, AMD VCE, or Intel QuickSync
            true
        }
        #[cfg(target_os = "macos")]
        {
            // Check for VideoToolbox
            true
        }
        #[cfg(target_os = "linux")]
        {
            // Check for VAAPI or NVENC
            true
        }
        #[cfg(not(any(target_os = "windows", target_os = "macos", target_os = "linux")))]
        {
            false
        }
    }

    pub async fn get_current_options(&self) -> CaptureOptions {
        self.capture_options.read().await.clone()
    }

    pub async fn apply_quality_preset(&self, preset: QualityPreset) {
        let mut options = self.capture_options.write().await;
        options.quality_preset = preset;
        
        match preset {
            QualityPreset::Low => {
                options.width = 1280;
                options.height = 720;
                options.frame_rate = 15;
                options.bitrate = 1000;
            }
            QualityPreset::Balanced => {
                options.width = 1920;
                options.height = 1080;
                options.frame_rate = 30;
                options.bitrate = 4000;
            }
            QualityPreset::High => {
                options.width = 1920;
                options.height = 1080;
                options.frame_rate = 60;
                options.bitrate = 8000;
            }
            QualityPreset::Ultra => {
                // Keep native resolution
                options.frame_rate = 60;
                options.bitrate = 15000;
            }
        }
        
        tracing::info!("Applied quality preset: {:?}", preset);
    }

    // Adaptive bitrate adjustment based on network conditions
    pub async fn adapt_to_network_conditions(&self, conditions: NetworkConditions) {
        let mut options = self.capture_options.write().await;
        let config = self.adaptive_config.read().await;
        
        // Calculate target bitrate based on available bandwidth
        let target_bitrate = (conditions.available_bandwidth as f32 * 0.8) as u32;
        let new_bitrate = target_bitrate.clamp(config.min_bitrate, config.max_bitrate);
        
        // Adjust frame rate based on packet loss and RTT
        let frame_rate_factor = if conditions.packet_loss > 5.0 || conditions.rtt > 150 {
            0.7
        } else if conditions.packet_loss > 2.0 || conditions.rtt > 100 {
            0.85
        } else {
            1.0
        };
        
        let new_frame_rate = ((config.target_frame_rate as f32 * frame_rate_factor) as u32)
            .clamp(config.min_frame_rate, config.max_frame_rate);
        
        // Apply changes if significant
        if (options.bitrate as i32 - new_bitrate as i32).abs() > 200 {
            options.bitrate = new_bitrate;
            tracing::info!("Adaptive bitrate adjustment: {} kbps", new_bitrate);
        }
        
        if options.frame_rate != new_frame_rate {
            options.frame_rate = new_frame_rate;
            tracing::info!("Adaptive frame rate adjustment: {} fps", new_frame_rate);
        }
    }

    pub async fn set_adaptive_config(&self, config: AdaptiveBitrateConfig) {
        *self.adaptive_config.write().await = config;
    }

    pub async fn is_capturing(&self) -> bool {
        *self.is_capturing.read().await
    }
}


pub struct AudioCapturer {
    id: String,
    capture_options: Arc<RwLock<AudioCaptureOptions>>,
    is_capturing: Arc<RwLock<bool>>,
    frame_sender: Option<mpsc::UnboundedSender<AudioFrame>>,
    frame_counter: Arc<Mutex<u64>>,
}

impl AudioCapturer {
    pub fn new() -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            capture_options: Arc::new(RwLock::new(AudioCaptureOptions::default())),
            is_capturing: Arc::new(RwLock::new(false)),
            frame_sender: None,
            frame_counter: Arc::new(Mutex::new(0)),
        }
    }

    pub async fn start_capture(&mut self, options: AudioCaptureOptions) -> Result<mpsc::UnboundedReceiver<AudioFrame>> {
        let (sender, receiver) = mpsc::unbounded_channel();
        
        *self.capture_options.write().await = options.clone();
        self.frame_sender = Some(sender);
        *self.is_capturing.write().await = true;
        
        tracing::info!(
            "Starting audio capture at {} Hz, {} channels",
            options.sample_rate,
            options.channels
        );
        
        // Start capture loop in background
        self.start_capture_loop().await?;
        
        Ok(receiver)
    }

    async fn start_capture_loop(&self) -> Result<()> {
        let is_capturing = Arc::clone(&self.is_capturing);
        let capture_options = Arc::clone(&self.capture_options);
        let frame_counter = Arc::clone(&self.frame_counter);
        let frame_sender = self.frame_sender.clone();
        
        tokio::spawn(async move {
            while *is_capturing.read().await {
                let options = capture_options.read().await;
                // Audio frames typically at 20ms intervals
                let frame_interval = std::time::Duration::from_millis(20);
                let sample_rate = options.sample_rate;
                let channels = options.channels;
                drop(options);
                
                if let Some(sender) = &frame_sender {
                    let mut counter = frame_counter.lock().await;
                    *counter += 1;
                    
                    let frame = AudioFrame {
                        id: *counter,
                        timestamp: std::time::SystemTime::now()
                            .duration_since(std::time::UNIX_EPOCH)
                            .unwrap()
                            .as_millis() as u64,
                        sample_rate,
                        channels,
                        data: vec![], // Placeholder - actual audio data
                    };
                    
                    let _ = sender.send(frame);
                }
                
                tokio::time::sleep(frame_interval).await;
            }
        });
        
        Ok(())
    }

    pub async fn stop_capture(&mut self) {
        *self.is_capturing.write().await = false;
        self.frame_sender = None;
        tracing::info!("Stopping audio capture");
    }

    pub async fn set_sample_rate(&self, sample_rate: u32) {
        let mut options = self.capture_options.write().await;
        options.sample_rate = sample_rate;
        tracing::info!("Setting audio sample rate: {} Hz", sample_rate);
    }

    pub async fn enable_noise_suppression(&self, enable: bool) {
        let mut options = self.capture_options.write().await;
        options.enable_noise_suppression = enable;
        tracing::info!("Noise suppression: {}", if enable { "enabled" } else { "disabled" });
    }

    pub async fn enable_echo_cancellation(&self, enable: bool) {
        let mut options = self.capture_options.write().await;
        options.enable_echo_cancellation = enable;
        tracing::info!("Echo cancellation: {}", if enable { "enabled" } else { "disabled" });
    }

    pub async fn get_current_options(&self) -> AudioCaptureOptions {
        self.capture_options.read().await.clone()
    }

    pub async fn is_capturing(&self) -> bool {
        *self.is_capturing.read().await
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_screen_capturer_creation() {
        let capturer = ScreenCapturer::new();
        assert!(!capturer.is_capturing().await);
    }

    #[tokio::test]
    async fn test_quality_preset_application() {
        let capturer = ScreenCapturer::new();
        
        capturer.apply_quality_preset(QualityPreset::Low).await;
        let options = capturer.get_current_options().await;
        assert_eq!(options.width, 1280);
        assert_eq!(options.height, 720);
        assert_eq!(options.frame_rate, 15);
        
        capturer.apply_quality_preset(QualityPreset::High).await;
        let options = capturer.get_current_options().await;
        assert_eq!(options.width, 1920);
        assert_eq!(options.height, 1080);
        assert_eq!(options.frame_rate, 60);
    }

    #[tokio::test]
    async fn test_adaptive_bitrate() {
        let capturer = ScreenCapturer::new();
        
        // Simulate good network conditions
        let good_conditions = NetworkConditions {
            available_bandwidth: 10000,
            packet_loss: 0.5,
            rtt: 50,
        };
        capturer.adapt_to_network_conditions(good_conditions).await;
        
        // Simulate poor network conditions
        let poor_conditions = NetworkConditions {
            available_bandwidth: 2000,
            packet_loss: 8.0,
            rtt: 200,
        };
        capturer.adapt_to_network_conditions(poor_conditions).await;
        
        let options = capturer.get_current_options().await;
        assert!(options.bitrate <= 2000);
    }

    #[tokio::test]
    async fn test_audio_capturer_creation() {
        let capturer = AudioCapturer::new();
        assert!(!capturer.is_capturing().await);
    }
}
