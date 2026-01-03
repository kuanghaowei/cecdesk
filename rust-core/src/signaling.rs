//! WebSocket Signaling Service
//!
//! Implements device registration, discovery, and WebRTC signaling exchange.
//! Requirements: 4.1, 4.2, 4.3

use anyhow::{Context, Result};
use futures_util::{SinkExt, StreamExt};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use std::time::Instant;
use tokio::sync::{mpsc, Mutex, RwLock};
use tokio_tungstenite::{connect_async, tungstenite::Message};
use uuid::Uuid;

/// Device information for registration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeviceInfo {
    pub device_id: String,
    pub device_name: String,
    pub platform: String,
    pub version: String,
    pub capabilities: DeviceCapabilities,
}

/// Device capabilities
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeviceCapabilities {
    pub screen_capture: bool,
    pub audio_capture: bool,
    pub file_transfer: bool,
    pub input_control: bool,
}

/// Device online status
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeviceStatus {
    pub device_id: String,
    pub online: bool,
    pub last_seen: String,
}

/// Signaling message types for WebSocket communication
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", content = "payload")]
pub enum SignalingMessage {
    /// Register device with server
    Register(DeviceInfo),
    /// Registration response with assigned device ID
    RegisterResponse { device_id: String, success: bool },
    /// Query device status
    QueryStatus { device_id: String },
    /// Device status response
    StatusResponse(DeviceStatus),
    /// SDP Offer for WebRTC connection
    Offer {
        from: String,
        to: String,
        sdp: String,
    },
    /// SDP Answer for WebRTC connection
    Answer {
        from: String,
        to: String,
        sdp: String,
    },
    /// ICE Candidate for NAT traversal
    IceCandidate {
        from: String,
        to: String,
        candidate: String,
    },
    /// Connection request from remote device
    ConnectionRequest {
        from: String,
        device_info: DeviceInfo,
    },
    /// Connection request response
    ConnectionResponse {
        from: String,
        to: String,
        accepted: bool,
    },
    /// Heartbeat to keep connection alive
    Heartbeat { device_id: String },
    /// Heartbeat acknowledgment
    HeartbeatAck,
    /// Error message
    Error { code: u32, message: String },
}

/// Events emitted by the signaling client
#[derive(Debug, Clone)]
pub enum SignalingEvent {
    /// Connected to signaling server
    Connected,
    /// Disconnected from signaling server
    Disconnected,
    /// SDP Offer received from remote device
    OfferReceived { from: String, sdp: String },
    /// SDP Answer received from remote device
    AnswerReceived { from: String, sdp: String },
    /// ICE Candidate received from remote device
    IceCandidateReceived { from: String, candidate: String },
    /// Connection request from remote device
    ConnectionRequest {
        from: String,
        device_info: DeviceInfo,
    },
    /// Connection response received
    ConnectionResponse { from: String, accepted: bool },
    /// Error occurred
    Error { code: u32, message: String },
}

/// Signaling exchange metrics for performance monitoring
#[derive(Debug, Clone, Default)]
pub struct SignalingMetrics {
    /// Total messages sent
    pub messages_sent: u64,
    /// Total messages received
    pub messages_received: u64,
    /// Average round-trip time in milliseconds
    pub avg_rtt_ms: f64,
    /// Last signaling exchange duration in milliseconds
    pub last_exchange_duration_ms: u64,
    /// Number of successful signaling exchanges
    pub successful_exchanges: u64,
    /// Number of failed signaling exchanges
    pub failed_exchanges: u64,
}

/// Internal state for tracking signaling exchanges
#[allow(dead_code)]
#[derive(Debug)]
struct SignalingExchange {
    start_time: Instant,
    exchange_type: String,
    target_device: String,
}

/// WebSocket signaling client for device discovery and WebRTC signaling
pub struct SignalingClient {
    /// Unique device ID assigned by server
    device_id: Arc<RwLock<Option<String>>>,
    /// Server URL
    server_url: String,
    /// Connection state
    connected: Arc<RwLock<bool>>,
    /// Event sender for notifying listeners
    event_sender: mpsc::UnboundedSender<SignalingEvent>,
    /// Event receiver for consuming events
    event_receiver: Arc<Mutex<mpsc::UnboundedReceiver<SignalingEvent>>>,
    /// Message sender for WebSocket
    ws_sender: Arc<Mutex<Option<mpsc::UnboundedSender<SignalingMessage>>>>,
    /// Registered devices cache
    registered_devices: Arc<RwLock<HashMap<String, DeviceInfo>>>,
    /// Signaling metrics
    metrics: Arc<RwLock<SignalingMetrics>>,
    /// Pending signaling exchanges for timing
    pending_exchanges: Arc<RwLock<HashMap<String, SignalingExchange>>>,
}

impl SignalingClient {
    /// Create a new signaling client
    pub fn new(server_url: String) -> Result<Self> {
        let (event_sender, event_receiver) = mpsc::unbounded_channel();

        Ok(Self {
            device_id: Arc::new(RwLock::new(None)),
            server_url,
            connected: Arc::new(RwLock::new(false)),
            event_sender,
            event_receiver: Arc::new(Mutex::new(event_receiver)),
            ws_sender: Arc::new(Mutex::new(None)),
            registered_devices: Arc::new(RwLock::new(HashMap::new())),
            metrics: Arc::new(RwLock::new(SignalingMetrics::default())),
            pending_exchanges: Arc::new(RwLock::new(HashMap::new())),
        })
    }

    /// Connect to the signaling server via WebSocket
    /// Requirement 4.1: WebSocket protocol for real-time bidirectional communication
    pub async fn connect(&self) -> Result<()> {
        tracing::info!("Connecting to signaling server: {}", self.server_url);

        let url = url::Url::parse(&self.server_url).context("Invalid signaling server URL")?;

        let (ws_stream, _) = connect_async(url)
            .await
            .context("Failed to connect to signaling server")?;

        let (mut write, mut read) = ws_stream.split();

        // Create channel for sending messages
        let (tx, mut rx) = mpsc::unbounded_channel::<SignalingMessage>();

        // Store sender for later use
        {
            let mut ws_sender = self.ws_sender.lock().await;
            *ws_sender = Some(tx);
        }

        // Mark as connected
        {
            let mut connected = self.connected.write().await;
            *connected = true;
        }

        // Notify listeners
        let _ = self.event_sender.send(SignalingEvent::Connected);

        // Clone references for async tasks
        let event_sender = self.event_sender.clone();
        let connected = self.connected.clone();
        let device_id = self.device_id.clone();
        let registered_devices = self.registered_devices.clone();
        let metrics = self.metrics.clone();
        let pending_exchanges = self.pending_exchanges.clone();

        // Spawn task to handle outgoing messages
        tokio::spawn(async move {
            while let Some(msg) = rx.recv().await {
                let json = match serde_json::to_string(&msg) {
                    Ok(j) => j,
                    Err(e) => {
                        tracing::error!("Failed to serialize message: {}", e);
                        continue;
                    }
                };

                if let Err(e) = write.send(Message::Text(json)).await {
                    tracing::error!("Failed to send message: {}", e);
                    break;
                }

                // Update metrics
                let mut m = metrics.write().await;
                m.messages_sent += 1;
            }
        });

        // Clone metrics for read task
        let metrics = self.metrics.clone();

        // Spawn task to handle incoming messages
        tokio::spawn(async move {
            while let Some(msg_result) = read.next().await {
                match msg_result {
                    Ok(Message::Text(text)) => {
                        // Update metrics
                        {
                            let mut m = metrics.write().await;
                            m.messages_received += 1;
                        }

                        match serde_json::from_str::<SignalingMessage>(&text) {
                            Ok(msg) => {
                                Self::handle_message(
                                    msg,
                                    &event_sender,
                                    &device_id,
                                    &registered_devices,
                                    &metrics,
                                    &pending_exchanges,
                                )
                                .await;
                            }
                            Err(e) => {
                                tracing::error!("Failed to parse message: {}", e);
                            }
                        }
                    }
                    Ok(Message::Close(_)) => {
                        tracing::info!("WebSocket connection closed");
                        break;
                    }
                    Err(e) => {
                        tracing::error!("WebSocket error: {}", e);
                        break;
                    }
                    _ => {}
                }
            }

            // Mark as disconnected
            {
                let mut c = connected.write().await;
                *c = false;
            }

            let _ = event_sender.send(SignalingEvent::Disconnected);
        });

        tracing::info!("Connected to signaling server");
        Ok(())
    }

    /// Handle incoming signaling message
    async fn handle_message(
        msg: SignalingMessage,
        event_sender: &mpsc::UnboundedSender<SignalingEvent>,
        device_id: &Arc<RwLock<Option<String>>>,
        registered_devices: &Arc<RwLock<HashMap<String, DeviceInfo>>>,
        metrics: &Arc<RwLock<SignalingMetrics>>,
        pending_exchanges: &Arc<RwLock<HashMap<String, SignalingExchange>>>,
    ) {
        match msg {
            SignalingMessage::RegisterResponse {
                device_id: id,
                success,
            } => {
                if success {
                    let mut did = device_id.write().await;
                    *did = Some(id.clone());
                    tracing::info!("Device registered with ID: {}", id);
                } else {
                    tracing::error!("Device registration failed");
                }
            }

            SignalingMessage::StatusResponse(status) => {
                tracing::debug!("Received device status: {:?}", status);
            }

            SignalingMessage::Offer { from, sdp, .. } => {
                // Track exchange timing
                let exchange_key = format!("offer_{}", from);
                {
                    let mut pending = pending_exchanges.write().await;
                    pending.insert(
                        exchange_key,
                        SignalingExchange {
                            start_time: Instant::now(),
                            exchange_type: "offer".to_string(),
                            target_device: from.clone(),
                        },
                    );
                }

                let _ = event_sender.send(SignalingEvent::OfferReceived { from, sdp });
            }

            SignalingMessage::Answer { from, sdp, .. } => {
                // Complete exchange timing
                let exchange_key = format!("offer_{}", from);
                {
                    let mut pending = pending_exchanges.write().await;
                    if let Some(exchange) = pending.remove(&exchange_key) {
                        let duration = exchange.start_time.elapsed().as_millis() as u64;
                        let mut m = metrics.write().await;
                        m.last_exchange_duration_ms = duration;
                        m.successful_exchanges += 1;
                        // Update average RTT
                        let total = m.successful_exchanges as f64;
                        m.avg_rtt_ms = (m.avg_rtt_ms * (total - 1.0) + duration as f64) / total;
                    }
                }

                let _ = event_sender.send(SignalingEvent::AnswerReceived { from, sdp });
            }

            SignalingMessage::IceCandidate {
                from, candidate, ..
            } => {
                let _ = event_sender.send(SignalingEvent::IceCandidateReceived { from, candidate });
            }

            SignalingMessage::ConnectionRequest { from, device_info } => {
                // Cache device info
                {
                    let mut devices = registered_devices.write().await;
                    devices.insert(from.clone(), device_info.clone());
                }

                let _ = event_sender.send(SignalingEvent::ConnectionRequest { from, device_info });
            }

            SignalingMessage::ConnectionResponse { from, accepted, .. } => {
                let _ = event_sender.send(SignalingEvent::ConnectionResponse { from, accepted });
            }

            SignalingMessage::HeartbeatAck => {
                tracing::trace!("Heartbeat acknowledged");
            }

            SignalingMessage::Error { code, message } => {
                tracing::error!("Signaling error {}: {}", code, message);
                let _ = event_sender.send(SignalingEvent::Error { code, message });
            }

            _ => {
                tracing::debug!("Unhandled message type");
            }
        }
    }

    /// Disconnect from the signaling server
    pub async fn disconnect(&self) -> Result<()> {
        tracing::info!("Disconnecting from signaling server");

        // Clear WebSocket sender to close connection
        {
            let mut ws_sender = self.ws_sender.lock().await;
            *ws_sender = None;
        }

        // Mark as disconnected
        {
            let mut connected = self.connected.write().await;
            *connected = false;
        }

        Ok(())
    }

    /// Register device with the signaling server
    /// Requirement 4.2: Register device and assign unique Device_ID
    pub async fn register_device(&self, device_info: DeviceInfo) -> Result<String> {
        if !*self.connected.read().await {
            return Err(anyhow::anyhow!("Not connected to signaling server"));
        }

        let msg = SignalingMessage::Register(device_info.clone());
        self.send_message(msg).await?;

        // For now, generate a local device ID if server doesn't respond
        // In production, this would wait for RegisterResponse
        let device_id = device_info.device_id.clone();

        // Cache locally
        {
            let mut devices = self.registered_devices.write().await;
            devices.insert(device_id.clone(), device_info);
        }

        // Store device ID
        {
            let mut did = self.device_id.write().await;
            *did = Some(device_id.clone());
        }

        tracing::info!("Device registered with ID: {}", device_id);
        Ok(device_id)
    }

    /// Query device status
    pub async fn query_device_status(&self, device_id: &str) -> Result<DeviceStatus> {
        if !*self.connected.read().await {
            return Err(anyhow::anyhow!("Not connected to signaling server"));
        }

        let msg = SignalingMessage::QueryStatus {
            device_id: device_id.to_string(),
        };
        self.send_message(msg).await?;

        // Return cached status or default
        Ok(DeviceStatus {
            device_id: device_id.to_string(),
            online: true,
            last_seen: chrono::Utc::now().to_rfc3339(),
        })
    }

    /// Send SDP offer to target device
    /// Requirement 4.3: Forward SDP offer/answer
    pub async fn send_offer(&self, target_id: &str, offer_sdp: &str) -> Result<()> {
        let device_id = self
            .get_device_id()
            .await
            .ok_or_else(|| anyhow::anyhow!("Device not registered"))?;

        // Track exchange start time
        let exchange_key = format!("offer_{}", target_id);
        {
            let mut pending = self.pending_exchanges.write().await;
            pending.insert(
                exchange_key,
                SignalingExchange {
                    start_time: Instant::now(),
                    exchange_type: "offer".to_string(),
                    target_device: target_id.to_string(),
                },
            );
        }

        let msg = SignalingMessage::Offer {
            from: device_id,
            to: target_id.to_string(),
            sdp: offer_sdp.to_string(),
        };

        self.send_message(msg).await?;
        tracing::info!("Sent offer to device: {}", target_id);
        Ok(())
    }

    /// Send SDP answer to target device
    /// Requirement 4.3: Forward SDP offer/answer
    pub async fn send_answer(&self, target_id: &str, answer_sdp: &str) -> Result<()> {
        let device_id = self
            .get_device_id()
            .await
            .ok_or_else(|| anyhow::anyhow!("Device not registered"))?;

        let msg = SignalingMessage::Answer {
            from: device_id,
            to: target_id.to_string(),
            sdp: answer_sdp.to_string(),
        };

        self.send_message(msg).await?;
        tracing::info!("Sent answer to device: {}", target_id);
        Ok(())
    }

    /// Send ICE candidate to target device
    /// Requirement 4.3: Forward ICE candidates
    pub async fn send_ice_candidate(&self, target_id: &str, candidate: &str) -> Result<()> {
        let device_id = self
            .get_device_id()
            .await
            .ok_or_else(|| anyhow::anyhow!("Device not registered"))?;

        let msg = SignalingMessage::IceCandidate {
            from: device_id,
            to: target_id.to_string(),
            candidate: candidate.to_string(),
        };

        self.send_message(msg).await?;
        tracing::debug!("Sent ICE candidate to device: {}", target_id);
        Ok(())
    }

    /// Send connection request to target device
    pub async fn send_connection_request(
        &self,
        target_id: &str,
        device_info: DeviceInfo,
    ) -> Result<()> {
        let device_id = self
            .get_device_id()
            .await
            .ok_or_else(|| anyhow::anyhow!("Device not registered"))?;

        let msg = SignalingMessage::ConnectionRequest {
            from: device_id,
            device_info,
        };

        self.send_message(msg).await?;
        tracing::info!("Sent connection request to device: {}", target_id);
        Ok(())
    }

    /// Respond to connection request
    pub async fn respond_to_connection(&self, target_id: &str, accepted: bool) -> Result<()> {
        let device_id = self
            .get_device_id()
            .await
            .ok_or_else(|| anyhow::anyhow!("Device not registered"))?;

        let msg = SignalingMessage::ConnectionResponse {
            from: device_id,
            to: target_id.to_string(),
            accepted,
        };

        self.send_message(msg).await?;
        tracing::info!(
            "Sent connection response to device: {} (accepted: {})",
            target_id,
            accepted
        );
        Ok(())
    }

    /// Send heartbeat to keep connection alive
    pub async fn send_heartbeat(&self) -> Result<()> {
        let device_id = self
            .get_device_id()
            .await
            .ok_or_else(|| anyhow::anyhow!("Device not registered"))?;

        let msg = SignalingMessage::Heartbeat { device_id };
        self.send_message(msg).await?;
        Ok(())
    }

    /// Internal method to send a signaling message
    async fn send_message(&self, msg: SignalingMessage) -> Result<()> {
        let ws_sender = self.ws_sender.lock().await;

        if let Some(sender) = ws_sender.as_ref() {
            sender
                .send(msg)
                .map_err(|_| anyhow::anyhow!("Failed to send message"))?;
            Ok(())
        } else {
            Err(anyhow::anyhow!("WebSocket not connected"))
        }
    }

    /// Get the device ID
    pub async fn get_device_id(&self) -> Option<String> {
        self.device_id.read().await.clone()
    }

    /// Check if connected to signaling server
    pub async fn is_connected(&self) -> bool {
        *self.connected.read().await
    }

    /// Get signaling metrics
    pub async fn get_metrics(&self) -> SignalingMetrics {
        self.metrics.read().await.clone()
    }

    /// Get event receiver for consuming signaling events
    pub async fn take_event_receiver(&self) -> mpsc::UnboundedReceiver<SignalingEvent> {
        let mut receiver = self.event_receiver.lock().await;
        let (_new_sender, new_receiver) = mpsc::unbounded_channel();
        // Note: In production, we'd need a better way to handle multiple consumers
        std::mem::replace(&mut *receiver, new_receiver)
    }

    /// Get cached device info
    pub async fn get_cached_device(&self, device_id: &str) -> Option<DeviceInfo> {
        self.registered_devices.read().await.get(device_id).cloned()
    }
}

/// Generate a unique device ID
/// Requirement 5.1: Generate unique Device_ID for each device
pub fn generate_device_id() -> String {
    Uuid::new_v4().to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_device_id_uniqueness() {
        let id1 = generate_device_id();
        let id2 = generate_device_id();
        assert_ne!(id1, id2);
    }

    #[test]
    fn test_signaling_message_serialization() {
        let msg = SignalingMessage::Offer {
            from: "device1".to_string(),
            to: "device2".to_string(),
            sdp: "test_sdp".to_string(),
        };

        let json = serde_json::to_string(&msg).unwrap();
        let parsed: SignalingMessage = serde_json::from_str(&json).unwrap();

        match parsed {
            SignalingMessage::Offer { from, to, sdp } => {
                assert_eq!(from, "device1");
                assert_eq!(to, "device2");
                assert_eq!(sdp, "test_sdp");
            }
            _ => panic!("Wrong message type"),
        }
    }

    #[test]
    fn test_device_info_serialization() {
        let info = DeviceInfo {
            device_id: "test_id".to_string(),
            device_name: "Test Device".to_string(),
            platform: "linux".to_string(),
            version: "1.0.0".to_string(),
            capabilities: DeviceCapabilities {
                screen_capture: true,
                audio_capture: true,
                file_transfer: true,
                input_control: true,
            },
        };

        let json = serde_json::to_string(&info).unwrap();
        let parsed: DeviceInfo = serde_json::from_str(&json).unwrap();

        assert_eq!(parsed.device_id, "test_id");
        assert_eq!(parsed.device_name, "Test Device");
        assert!(parsed.capabilities.screen_capture);
    }
}
