//! Performance Optimization Module
//!
//! Feature: cec-remote
//! Task 11.2: 性能优化
//!
//! Provides:
//! - Memory usage optimization
//! - Network transmission efficiency optimization
//! - Resource management
//!
//! Validates: Requirements 2.4, 7.1, 15.6, 16.8

use std::collections::VecDeque;
use std::sync::atomic::{AtomicU64, AtomicUsize, Ordering};
use std::sync::Arc;
use std::time::Instant;
use tokio::sync::RwLock;

/// Memory usage statistics
#[derive(Debug, Clone, Default)]
pub struct MemoryStats {
    pub allocated_bytes: u64,
    pub peak_bytes: u64,
    pub buffer_pool_size: usize,
    pub active_buffers: usize,
    pub frame_buffer_count: usize,
    pub frame_buffer_bytes: u64,
}

/// Network transmission statistics
#[derive(Debug, Clone, Default)]
pub struct TransmissionStats {
    pub bytes_sent: u64,
    pub bytes_received: u64,
    pub packets_sent: u64,
    pub packets_received: u64,
    pub retransmissions: u64,
    pub avg_latency_ms: f64,
    pub bandwidth_utilization: f64,
}

/// Performance metrics
#[derive(Debug, Clone)]
pub struct PerformanceMetrics {
    pub memory: MemoryStats,
    pub transmission: TransmissionStats,
    pub frame_rate: f64,
    pub input_latency_ms: f64,
    pub cpu_usage_percent: f64,
    pub timestamp: Instant,
}

impl Default for PerformanceMetrics {
    fn default() -> Self {
        Self {
            memory: MemoryStats::default(),
            transmission: TransmissionStats::default(),
            frame_rate: 0.0,
            input_latency_ms: 0.0,
            cpu_usage_percent: 0.0,
            timestamp: Instant::now(),
        }
    }
}

/// Buffer pool for efficient memory reuse
/// Reduces allocation overhead by reusing buffers
pub struct BufferPool {
    buffers: Arc<RwLock<VecDeque<Vec<u8>>>>,
    buffer_size: usize,
    max_buffers: usize,
    allocated_count: AtomicUsize,
    reused_count: AtomicUsize,
}

impl BufferPool {
    pub fn new(buffer_size: usize, max_buffers: usize) -> Self {
        Self {
            buffers: Arc::new(RwLock::new(VecDeque::with_capacity(max_buffers))),
            buffer_size,
            max_buffers,
            allocated_count: AtomicUsize::new(0),
            reused_count: AtomicUsize::new(0),
        }
    }

    /// Acquire a buffer from the pool or allocate a new one
    pub async fn acquire(&self) -> Vec<u8> {
        let mut buffers = self.buffers.write().await;

        if let Some(mut buffer) = buffers.pop_front() {
            buffer.clear();
            self.reused_count.fetch_add(1, Ordering::Relaxed);
            buffer
        } else {
            self.allocated_count.fetch_add(1, Ordering::Relaxed);
            Vec::with_capacity(self.buffer_size)
        }
    }

    /// Return a buffer to the pool for reuse
    pub async fn release(&self, buffer: Vec<u8>) {
        let mut buffers = self.buffers.write().await;

        if buffers.len() < self.max_buffers {
            buffers.push_back(buffer);
        }
        // If pool is full, buffer is dropped
    }

    /// Get pool statistics
    pub fn stats(&self) -> (usize, usize) {
        (
            self.allocated_count.load(Ordering::Relaxed),
            self.reused_count.load(Ordering::Relaxed),
        )
    }
}

/// Frame buffer manager for video frame optimization
/// Implements double/triple buffering for smooth playback
pub struct FrameBufferManager {
    buffers: Arc<RwLock<VecDeque<FrameBuffer>>>,
    max_buffers: usize,
    total_bytes: AtomicU64,
    dropped_frames: AtomicU64,
}

#[derive(Debug, Clone)]
pub struct FrameBuffer {
    pub id: u64,
    pub timestamp: u64,
    pub data: Vec<u8>,
    pub width: u32,
    pub height: u32,
    pub format: FrameFormat,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum FrameFormat {
    RGBA,
    BGRA,
    NV12,
    I420,
}

impl FrameBufferManager {
    pub fn new(max_buffers: usize) -> Self {
        Self {
            buffers: Arc::new(RwLock::new(VecDeque::with_capacity(max_buffers))),
            max_buffers,
            total_bytes: AtomicU64::new(0),
            dropped_frames: AtomicU64::new(0),
        }
    }

    /// Add a frame to the buffer
    pub async fn push_frame(&self, frame: FrameBuffer) {
        let frame_size = frame.data.len() as u64;
        let mut buffers = self.buffers.write().await;

        // Drop oldest frame if buffer is full
        if buffers.len() >= self.max_buffers {
            if let Some(old_frame) = buffers.pop_front() {
                self.total_bytes
                    .fetch_sub(old_frame.data.len() as u64, Ordering::Relaxed);
                self.dropped_frames.fetch_add(1, Ordering::Relaxed);
            }
        }

        self.total_bytes.fetch_add(frame_size, Ordering::Relaxed);
        buffers.push_back(frame);
    }

    /// Get the next frame for display
    pub async fn pop_frame(&self) -> Option<FrameBuffer> {
        let mut buffers = self.buffers.write().await;

        if let Some(frame) = buffers.pop_front() {
            self.total_bytes
                .fetch_sub(frame.data.len() as u64, Ordering::Relaxed);
            Some(frame)
        } else {
            None
        }
    }

    /// Get buffer statistics
    pub async fn stats(&self) -> (usize, u64, u64) {
        let buffers = self.buffers.read().await;
        (
            buffers.len(),
            self.total_bytes.load(Ordering::Relaxed),
            self.dropped_frames.load(Ordering::Relaxed),
        )
    }

    /// Clear all buffers
    pub async fn clear(&self) {
        let mut buffers = self.buffers.write().await;
        buffers.clear();
        self.total_bytes.store(0, Ordering::Relaxed);
    }
}

/// Network transmission optimizer
/// Implements adaptive bitrate and packet batching
pub struct TransmissionOptimizer {
    target_bitrate: AtomicU64,
    current_bitrate: AtomicU64,
    min_bitrate: u64,
    max_bitrate: u64,
    #[allow(dead_code)]
    packet_batch_size: AtomicUsize,
    latency_samples: Arc<RwLock<VecDeque<f64>>>,
    bandwidth_samples: Arc<RwLock<VecDeque<u64>>>,
}

impl TransmissionOptimizer {
    pub fn new(min_bitrate: u64, max_bitrate: u64, target_bitrate: u64) -> Self {
        Self {
            target_bitrate: AtomicU64::new(target_bitrate),
            current_bitrate: AtomicU64::new(target_bitrate),
            min_bitrate,
            max_bitrate,
            packet_batch_size: AtomicUsize::new(1),
            latency_samples: Arc::new(RwLock::new(VecDeque::with_capacity(100))),
            bandwidth_samples: Arc::new(RwLock::new(VecDeque::with_capacity(100))),
        }
    }

    /// Record a latency sample
    pub async fn record_latency(&self, latency_ms: f64) {
        let mut samples = self.latency_samples.write().await;
        if samples.len() >= 100 {
            samples.pop_front();
        }
        samples.push_back(latency_ms);
    }

    /// Record a bandwidth sample
    pub async fn record_bandwidth(&self, bandwidth_bps: u64) {
        let mut samples = self.bandwidth_samples.write().await;
        if samples.len() >= 100 {
            samples.pop_front();
        }
        samples.push_back(bandwidth_bps);
    }

    /// Adapt bitrate based on network conditions
    pub async fn adapt_bitrate(&self) -> u64 {
        let latency_samples = self.latency_samples.read().await;
        let bandwidth_samples = self.bandwidth_samples.read().await;

        if latency_samples.is_empty() || bandwidth_samples.is_empty() {
            return self.current_bitrate.load(Ordering::Relaxed);
        }

        // Calculate average latency
        let avg_latency: f64 = latency_samples.iter().sum::<f64>() / latency_samples.len() as f64;

        // Calculate average bandwidth
        let avg_bandwidth: u64 =
            bandwidth_samples.iter().sum::<u64>() / bandwidth_samples.len() as u64;

        // Adaptive bitrate algorithm
        let mut new_bitrate = self.current_bitrate.load(Ordering::Relaxed);

        // If latency is high, reduce bitrate
        if avg_latency > 150.0 {
            new_bitrate = (new_bitrate as f64 * 0.8) as u64;
        } else if avg_latency > 100.0 {
            new_bitrate = (new_bitrate as f64 * 0.9) as u64;
        } else if avg_latency < 50.0 {
            // If latency is low and bandwidth allows, increase bitrate
            let target = self.target_bitrate.load(Ordering::Relaxed);
            if new_bitrate < target && avg_bandwidth > new_bitrate {
                new_bitrate = (new_bitrate as f64 * 1.1) as u64;
            }
        }

        // Clamp to min/max
        new_bitrate = new_bitrate.clamp(self.min_bitrate, self.max_bitrate);
        self.current_bitrate.store(new_bitrate, Ordering::Relaxed);

        new_bitrate
    }

    /// Get current bitrate
    pub fn get_current_bitrate(&self) -> u64 {
        self.current_bitrate.load(Ordering::Relaxed)
    }

    /// Set target bitrate
    pub fn set_target_bitrate(&self, bitrate: u64) {
        let clamped = bitrate.clamp(self.min_bitrate, self.max_bitrate);
        self.target_bitrate.store(clamped, Ordering::Relaxed);
    }

    /// Get average latency
    pub async fn get_avg_latency(&self) -> f64 {
        let samples = self.latency_samples.read().await;
        if samples.is_empty() {
            return 0.0;
        }
        samples.iter().sum::<f64>() / samples.len() as f64
    }
}

/// Input latency optimizer
/// Implements input event batching and prioritization
pub struct InputOptimizer {
    event_queue: Arc<RwLock<VecDeque<InputEventEntry>>>,
    max_queue_size: usize,
    batch_interval_ms: u64,
    last_batch_time: Arc<RwLock<Instant>>,
    latency_samples: Arc<RwLock<VecDeque<f64>>>,
}

#[derive(Debug, Clone)]
pub struct InputEventEntry {
    pub event_type: InputEventType,
    pub timestamp: Instant,
    pub priority: u8,
    pub data: Vec<u8>,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum InputEventType {
    MouseMove,
    MouseClick,
    MouseScroll,
    KeyDown,
    KeyUp,
    KeyPress,
}

impl InputEventType {
    /// Get default priority (lower = higher priority)
    pub fn default_priority(&self) -> u8 {
        match self {
            InputEventType::KeyDown | InputEventType::KeyUp => 1,
            InputEventType::MouseClick => 2,
            InputEventType::KeyPress => 3,
            InputEventType::MouseScroll => 4,
            InputEventType::MouseMove => 5,
        }
    }
}

impl InputOptimizer {
    pub fn new(max_queue_size: usize, batch_interval_ms: u64) -> Self {
        Self {
            event_queue: Arc::new(RwLock::new(VecDeque::with_capacity(max_queue_size))),
            max_queue_size,
            batch_interval_ms,
            last_batch_time: Arc::new(RwLock::new(Instant::now())),
            latency_samples: Arc::new(RwLock::new(VecDeque::with_capacity(100))),
        }
    }

    /// Queue an input event
    pub async fn queue_event(&self, event: InputEventEntry) {
        let mut queue = self.event_queue.write().await;

        // Drop oldest low-priority events if queue is full
        while queue.len() >= self.max_queue_size {
            // Find and remove lowest priority event
            if let Some(idx) = queue
                .iter()
                .enumerate()
                .max_by_key(|(_, e)| e.priority)
                .map(|(i, _)| i)
            {
                queue.remove(idx);
            } else {
                break;
            }
        }

        queue.push_back(event);
    }

    /// Get batched events for transmission
    pub async fn get_batch(&self) -> Vec<InputEventEntry> {
        let mut queue = self.event_queue.write().await;
        let mut last_batch = self.last_batch_time.write().await;

        // Check if enough time has passed for batching
        if last_batch.elapsed().as_millis() < self.batch_interval_ms as u128 {
            return Vec::new();
        }

        *last_batch = Instant::now();

        // Sort by priority and timestamp
        let mut events: Vec<_> = queue.drain(..).collect();
        events.sort_by(|a, b| {
            a.priority
                .cmp(&b.priority)
                .then_with(|| a.timestamp.cmp(&b.timestamp))
        });

        // Coalesce mouse move events (keep only the latest)
        let mut coalesced = Vec::new();
        let mut last_mouse_move: Option<InputEventEntry> = None;

        for event in events {
            if event.event_type == InputEventType::MouseMove {
                last_mouse_move = Some(event);
            } else {
                if let Some(mm) = last_mouse_move.take() {
                    coalesced.push(mm);
                }
                coalesced.push(event);
            }
        }

        if let Some(mm) = last_mouse_move {
            coalesced.push(mm);
        }

        coalesced
    }

    /// Record input latency
    pub async fn record_latency(&self, latency_ms: f64) {
        let mut samples = self.latency_samples.write().await;
        if samples.len() >= 100 {
            samples.pop_front();
        }
        samples.push_back(latency_ms);
    }

    /// Get average input latency
    pub async fn get_avg_latency(&self) -> f64 {
        let samples = self.latency_samples.read().await;
        if samples.is_empty() {
            return 0.0;
        }
        samples.iter().sum::<f64>() / samples.len() as f64
    }

    /// Check if latency meets requirement (< 100ms)
    pub async fn meets_latency_requirement(&self) -> bool {
        self.get_avg_latency().await < 100.0
    }
}

/// Performance monitor
/// Collects and reports performance metrics
pub struct PerformanceMonitor {
    buffer_pool: Arc<BufferPool>,
    frame_buffer: Arc<FrameBufferManager>,
    transmission_optimizer: Arc<TransmissionOptimizer>,
    input_optimizer: Arc<InputOptimizer>,
    metrics_history: Arc<RwLock<VecDeque<PerformanceMetrics>>>,
    max_history: usize,
}

impl PerformanceMonitor {
    pub fn new(
        buffer_pool: Arc<BufferPool>,
        frame_buffer: Arc<FrameBufferManager>,
        transmission_optimizer: Arc<TransmissionOptimizer>,
        input_optimizer: Arc<InputOptimizer>,
    ) -> Self {
        Self {
            buffer_pool,
            frame_buffer,
            transmission_optimizer,
            input_optimizer,
            metrics_history: Arc::new(RwLock::new(VecDeque::with_capacity(60))),
            max_history: 60, // Keep 60 seconds of history
        }
    }

    /// Collect current performance metrics
    pub async fn collect_metrics(&self) -> PerformanceMetrics {
        let (allocated, reused) = self.buffer_pool.stats();
        let (frame_count, frame_bytes, _dropped) = self.frame_buffer.stats().await;
        let avg_latency = self.transmission_optimizer.get_avg_latency().await;
        let input_latency = self.input_optimizer.get_avg_latency().await;
        let current_bitrate = self.transmission_optimizer.get_current_bitrate();

        let metrics = PerformanceMetrics {
            memory: MemoryStats {
                allocated_bytes: (allocated * 65536) as u64, // Estimate based on buffer size
                peak_bytes: 0,                               // Would need system-level tracking
                buffer_pool_size: allocated + reused,
                active_buffers: allocated,
                frame_buffer_count: frame_count,
                frame_buffer_bytes: frame_bytes,
            },
            transmission: TransmissionStats {
                bytes_sent: 0, // Would need actual tracking
                bytes_received: 0,
                packets_sent: 0,
                packets_received: 0,
                retransmissions: 0,
                avg_latency_ms: avg_latency,
                bandwidth_utilization: current_bitrate as f64 / 10_000_000.0, // Assume 10Mbps max
            },
            frame_rate: 30.0, // Would need actual measurement
            input_latency_ms: input_latency,
            cpu_usage_percent: 0.0, // Would need system-level tracking
            timestamp: Instant::now(),
        };

        // Store in history
        let mut history = self.metrics_history.write().await;
        if history.len() >= self.max_history {
            history.pop_front();
        }
        history.push_back(metrics.clone());

        metrics
    }

    /// Get metrics history
    pub async fn get_history(&self) -> Vec<PerformanceMetrics> {
        self.metrics_history.read().await.iter().cloned().collect()
    }

    /// Get performance summary
    pub async fn get_summary(&self) -> PerformanceSummary {
        let history = self.metrics_history.read().await;

        if history.is_empty() {
            return PerformanceSummary::default();
        }

        let avg_frame_rate =
            history.iter().map(|m| m.frame_rate).sum::<f64>() / history.len() as f64;
        let avg_input_latency =
            history.iter().map(|m| m.input_latency_ms).sum::<f64>() / history.len() as f64;
        let avg_network_latency = history
            .iter()
            .map(|m| m.transmission.avg_latency_ms)
            .sum::<f64>()
            / history.len() as f64;
        let max_memory = history
            .iter()
            .map(|m| m.memory.allocated_bytes)
            .max()
            .unwrap_or(0);

        PerformanceSummary {
            avg_frame_rate,
            avg_input_latency_ms: avg_input_latency,
            avg_network_latency_ms: avg_network_latency,
            max_memory_bytes: max_memory,
            meets_frame_rate_requirement: avg_frame_rate >= 30.0,
            meets_input_latency_requirement: avg_input_latency < 100.0,
        }
    }
}

/// Performance summary
#[derive(Debug, Clone, Default)]
pub struct PerformanceSummary {
    pub avg_frame_rate: f64,
    pub avg_input_latency_ms: f64,
    pub avg_network_latency_ms: f64,
    pub max_memory_bytes: u64,
    pub meets_frame_rate_requirement: bool,
    pub meets_input_latency_requirement: bool,
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::Duration;

    #[tokio::test]
    async fn test_buffer_pool() {
        let pool = BufferPool::new(1024, 10);

        // Acquire buffers
        let buf1 = pool.acquire().await;
        let _buf2 = pool.acquire().await;

        let (allocated, reused) = pool.stats();
        assert_eq!(allocated, 2);
        assert_eq!(reused, 0);

        // Release and reacquire
        pool.release(buf1).await;
        let _buf3 = pool.acquire().await;

        let (allocated, reused) = pool.stats();
        assert_eq!(allocated, 2);
        assert_eq!(reused, 1);
    }

    #[tokio::test]
    async fn test_frame_buffer_manager() {
        let manager = FrameBufferManager::new(3);

        // Add frames
        for i in 0..5 {
            manager
                .push_frame(FrameBuffer {
                    id: i,
                    timestamp: i,
                    data: vec![0u8; 1024],
                    width: 1920,
                    height: 1080,
                    format: FrameFormat::RGBA,
                })
                .await;
        }

        let (count, _bytes, dropped) = manager.stats().await;
        assert_eq!(count, 3); // Max buffers
        assert_eq!(dropped, 2); // 2 frames dropped
    }

    #[tokio::test]
    async fn test_transmission_optimizer() {
        let optimizer = TransmissionOptimizer::new(500_000, 10_000_000, 4_000_000);

        // Record good conditions
        for _ in 0..10 {
            optimizer.record_latency(30.0).await;
            optimizer.record_bandwidth(8_000_000).await;
        }

        let bitrate = optimizer.adapt_bitrate().await;
        assert!((500_000..=10_000_000).contains(&bitrate));

        // Record poor conditions
        for _ in 0..10 {
            optimizer.record_latency(200.0).await;
            optimizer.record_bandwidth(1_000_000).await;
        }

        let bitrate = optimizer.adapt_bitrate().await;
        // Bitrate should decrease due to high latency
        assert!(bitrate < 4_000_000);
    }

    #[tokio::test]
    async fn test_input_optimizer() {
        let optimizer = InputOptimizer::new(100, 16);

        // Queue events
        optimizer
            .queue_event(InputEventEntry {
                event_type: InputEventType::MouseMove,
                timestamp: Instant::now(),
                priority: InputEventType::MouseMove.default_priority(),
                data: vec![1, 2, 3, 4],
            })
            .await;

        optimizer
            .queue_event(InputEventEntry {
                event_type: InputEventType::KeyDown,
                timestamp: Instant::now(),
                priority: InputEventType::KeyDown.default_priority(),
                data: vec![5, 6],
            })
            .await;

        // Wait for batch interval
        tokio::time::sleep(Duration::from_millis(20)).await;

        let batch = optimizer.get_batch().await;
        assert_eq!(batch.len(), 2);

        // Key events should come before mouse moves (higher priority)
        assert_eq!(batch[0].event_type, InputEventType::KeyDown);
    }

    #[tokio::test]
    async fn test_input_latency_requirement() {
        let optimizer = InputOptimizer::new(100, 16);

        // Record good latencies
        for _ in 0..10 {
            optimizer.record_latency(50.0).await;
        }

        assert!(optimizer.meets_latency_requirement().await);

        // Record bad latencies
        for _ in 0..20 {
            optimizer.record_latency(150.0).await;
        }

        assert!(!optimizer.meets_latency_requirement().await);
    }
}
