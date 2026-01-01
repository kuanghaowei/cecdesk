use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::{mpsc, Mutex};
use uuid::Uuid;
use webrtc::api::interceptor_registry::register_default_interceptors;
use webrtc::api::media_engine::MediaEngine;
use webrtc::api::APIBuilder;
use webrtc::ice_transport::ice_candidate::RTCIceCandidate;
use webrtc::ice_transport::ice_server::RTCIceServer;
use webrtc::peer_connection::configuration::RTCConfiguration as WebRTCConfig;
use webrtc::peer_connection::peer_connection_state::RTCPeerConnectionState as WebRTCState;
use webrtc::peer_connection::RTCPeerConnection;
use webrtc::peer_connection::sdp::session_description::RTCSessionDescription;
use webrtc::interceptor::registry::Registry;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RTCConfiguration {
    pub ice_servers: Vec<IceServer>,
    pub ice_transport_policy: String,
    pub bundle_policy: Option<String>,
    pub rtcp_mux_policy: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IceServer {
    pub urls: Vec<String>,
    pub username: Option<String>,
    pub credential: Option<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub enum RTCPeerConnectionState {
    New,
    Connecting,
    Connected,
    Disconnected,
    Failed,
    Closed,
}

impl From<WebRTCState> for RTCPeerConnectionState {
    fn from(state: WebRTCState) -> Self {
        match state {
            WebRTCState::New => RTCPeerConnectionState::New,
            WebRTCState::Connecting => RTCPeerConnectionState::Connecting,
            WebRTCState::Connected => RTCPeerConnectionState::Connected,
            WebRTCState::Disconnected => RTCPeerConnectionState::Disconnected,
            WebRTCState::Failed => RTCPeerConnectionState::Failed,
            WebRTCState::Closed => RTCPeerConnectionState::Closed,
            _ => RTCPeerConnectionState::New,
        }
    }
}

pub struct WebRTCEngine {
    connections: Arc<Mutex<HashMap<String, ConnectionInfo>>>,
    event_sender: mpsc::UnboundedSender<WebRTCEvent>,
    event_receiver: Arc<Mutex<mpsc::UnboundedReceiver<WebRTCEvent>>>,
    api: webrtc::api::API,
}

#[derive(Debug)]
pub enum WebRTCEvent {
    ConnectionStateChanged(String, RTCPeerConnectionState),
    DataReceived(String, Vec<u8>),
    RemoteStreamAdded(String, MediaStream),
    IceCandidateReceived(String, RTCIceCandidate),
    OfferReceived(String, RTCSessionDescription),
    AnswerReceived(String, RTCSessionDescription),
}

#[derive(Debug)]
pub struct ConnectionInfo {
    id: String,
    peer_connection: Arc<RTCPeerConnection>,
    state: RTCPeerConnectionState,
    remote_id: Option<String>,
}

#[derive(Debug, Clone)]
pub struct MediaStream {
    id: String,
    tracks: Vec<MediaTrack>,
}

#[derive(Debug, Clone)]
pub struct MediaTrack {
    id: String,
    kind: String, // "audio" or "video"
    enabled: bool,
}

impl WebRTCEngine {
    pub async fn new() -> Result<Self> {
        let (event_sender, event_receiver) = mpsc::unbounded_channel();
        
        // Create a MediaEngine object to configure the supported codec
        let mut media_engine = MediaEngine::default();
        media_engine.register_default_codecs()?;

        // Create a InterceptorRegistry. This is the user configurable RTP/RTCP Pipeline.
        // This provides NACKs, RTCP-RR, SRTP, SRTCP
        let mut registry = Registry::new();
        registry = register_default_interceptors(registry, &mut media_engine)?;

        // Create the API object with the MediaEngine
        let api = APIBuilder::new()
            .with_media_engine(media_engine)
            .with_interceptor_registry(registry)
            .build();
        
        Ok(Self {
            connections: Arc::new(Mutex::new(HashMap::new())),
            event_sender,
            event_receiver: Arc::new(Mutex::new(event_receiver)),
            api,
        })
    }

    pub async fn create_peer_connection(&self, config: RTCConfiguration) -> Result<String> {
        let connection_id = Uuid::new_v4().to_string();
        
        // Convert our config to webrtc crate config
        let webrtc_config = self.convert_config(config)?;
        
        // Create the PeerConnection
        let peer_connection = Arc::new(self.api.new_peer_connection(webrtc_config).await?);
        
        // Set up connection state change handler
        let connection_id_clone = connection_id.clone();
        let event_sender = self.event_sender.clone();
        let connections = Arc::clone(&self.connections);
        
        peer_connection.on_peer_connection_state_change(Box::new(move |state| {
            let connection_id = connection_id_clone.clone();
            let event_sender = event_sender.clone();
            let connections = Arc::clone(&connections);
            
            Box::pin(async move {
                let new_state = RTCPeerConnectionState::from(state);
                
                // Update connection state
                if let Ok(mut conns) = connections.lock().await {
                    if let Some(conn_info) = conns.get_mut(&connection_id) {
                        conn_info.state = new_state.clone();
                    }
                }
                
                // Send event
                let _ = event_sender.send(WebRTCEvent::ConnectionStateChanged(
                    connection_id,
                    new_state,
                ));
            })
        }));

        // Set up ICE candidate handler
        let connection_id_clone = connection_id.clone();
        let event_sender_clone = self.event_sender.clone();
        
        peer_connection.on_ice_candidate(Box::new(move |candidate| {
            let connection_id = connection_id_clone.clone();
            let event_sender = event_sender_clone.clone();
            
            Box::pin(async move {
                if let Some(candidate) = candidate {
                    let _ = event_sender.send(WebRTCEvent::IceCandidateReceived(
                        connection_id,
                        candidate,
                    ));
                }
            })
        }));

        // Store connection info
        let connection_info = ConnectionInfo {
            id: connection_id.clone(),
            peer_connection: Arc::clone(&peer_connection),
            state: RTCPeerConnectionState::New,
            remote_id: None,
        };
        
        self.connections.lock().await.insert(connection_id.clone(), connection_info);
        
        tracing::info!("Created peer connection: {}", connection_id);
        Ok(connection_id)
    }

    pub async fn establish_connection(&self, connection_id: &str, remote_id: String) -> Result<()> {
        let connections = self.connections.lock().await;
        let connection_info = connections.get(connection_id)
            .ok_or_else(|| anyhow::anyhow!("Connection not found: {}", connection_id))?;
        
        // Create offer
        let offer = connection_info.peer_connection.create_offer(None).await?;
        connection_info.peer_connection.set_local_description(offer.clone()).await?;
        
        tracing::info!("Created offer for connection {} to remote {}", connection_id, remote_id);
        
        // In a real implementation, this offer would be sent via signaling server
        // For now, we'll emit an event
        let _ = self.event_sender.send(WebRTCEvent::OfferReceived(remote_id.clone(), offer));
        
        Ok(())
    }

    pub async fn handle_remote_offer(&self, connection_id: &str, offer: RTCSessionDescription) -> Result<RTCSessionDescription> {
        let connections = self.connections.lock().await;
        let connection_info = connections.get(connection_id)
            .ok_or_else(|| anyhow::anyhow!("Connection not found: {}", connection_id))?;
        
        // Set remote description
        connection_info.peer_connection.set_remote_description(offer).await?;
        
        // Create answer
        let answer = connection_info.peer_connection.create_answer(None).await?;
        connection_info.peer_connection.set_local_description(answer.clone()).await?;
        
        tracing::info!("Created answer for connection {}", connection_id);
        Ok(answer)
    }

    pub async fn handle_remote_answer(&self, connection_id: &str, answer: RTCSessionDescription) -> Result<()> {
        let connections = self.connections.lock().await;
        let connection_info = connections.get(connection_id)
            .ok_or_else(|| anyhow::anyhow!("Connection not found: {}", connection_id))?;
        
        connection_info.peer_connection.set_remote_description(answer).await?;
        tracing::info!("Set remote answer for connection {}", connection_id);
        Ok(())
    }

    pub async fn add_ice_candidate(&self, connection_id: &str, candidate: RTCIceCandidate) -> Result<()> {
        let connections = self.connections.lock().await;
        let connection_info = connections.get(connection_id)
            .ok_or_else(|| anyhow::anyhow!("Connection not found: {}", connection_id))?;
        
        connection_info.peer_connection.add_ice_candidate(candidate).await?;
        tracing::info!("Added ICE candidate for connection {}", connection_id);
        Ok(())
    }

    pub async fn close_connection(&self, connection_id: &str) -> Result<()> {
        let mut connections = self.connections.lock().await;
        
        if let Some(connection_info) = connections.remove(connection_id) {
            connection_info.peer_connection.close().await?;
            tracing::info!("Connection {} closed", connection_id);
        }
        Ok(())
    }

    pub async fn get_connection_state(&self, connection_id: &str) -> Option<RTCPeerConnectionState> {
        let connections = self.connections.lock().await;
        connections.get(connection_id).map(|conn| conn.state.clone())
    }

    pub async fn get_connection_stats(&self, connection_id: &str) -> Result<ConnectionStats> {
        let connections = self.connections.lock().await;
        let connection_info = connections.get(connection_id)
            .ok_or_else(|| anyhow::anyhow!("Connection not found: {}", connection_id))?;
        
        let stats = connection_info.peer_connection.get_stats().await;
        
        // Convert webrtc stats to our format
        Ok(ConnectionStats {
            connection_id: connection_id.to_string(),
            state: connection_info.state.clone(),
            bytes_sent: 0, // TODO: Extract from stats
            bytes_received: 0, // TODO: Extract from stats
            packets_sent: 0, // TODO: Extract from stats
            packets_received: 0, // TODO: Extract from stats
            rtt: 0.0, // TODO: Extract from stats
        })
    }

    pub async fn get_event_receiver(&self) -> Arc<Mutex<mpsc::UnboundedReceiver<WebRTCEvent>>> {
        Arc::clone(&self.event_receiver)
    }

    fn convert_config(&self, config: RTCConfiguration) -> Result<WebRTCConfig> {
        let ice_servers: Result<Vec<RTCIceServer>, _> = config.ice_servers
            .into_iter()
            .map(|server| {
                RTCIceServer {
                    urls: server.urls,
                    username: server.username.unwrap_or_default(),
                    credential: server.credential.unwrap_or_default(),
                    credential_type: Default::default(),
                }
            })
            .collect::<Result<Vec<_>, _>>();

        Ok(WebRTCConfig {
            ice_servers: ice_servers?,
            ..Default::default()
        })
    }

    // Media stream methods (placeholder implementations)
    pub async fn start_screen_capture(&self) -> Result<MediaStream> {
        // Placeholder for screen capture - will be implemented in media processing task
        Ok(MediaStream {
            id: Uuid::new_v4().to_string(),
            tracks: vec![MediaTrack {
                id: Uuid::new_v4().to_string(),
                kind: "video".to_string(),
                enabled: true,
            }],
        })
    }

    pub async fn start_audio_capture(&self) -> Result<MediaStream> {
        // Placeholder for audio capture - will be implemented in media processing task
        Ok(MediaStream {
            id: Uuid::new_v4().to_string(),
            tracks: vec![MediaTrack {
                id: Uuid::new_v4().to_string(),
                kind: "audio".to_string(),
                enabled: true,
            }],
        })
    }

    pub async fn send_data(&self, connection_id: &str, data: Vec<u8>) -> Result<()> {
        tracing::debug!("Sending {} bytes to connection {}", data.len(), connection_id);
        // TODO: Implement data channel sending
        Ok(())
    }
}

#[derive(Debug, Clone)]
pub struct ConnectionStats {
    pub connection_id: String,
    pub state: RTCPeerConnectionState,
    pub bytes_sent: u64,
    pub bytes_received: u64,
    pub packets_sent: u64,
    pub packets_received: u64,
    pub rtt: f64, // Round trip time in milliseconds
}

#[cfg(test)]
mod webrtc_engine_test;