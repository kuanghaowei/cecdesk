use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::net::{IpAddr, Ipv4Addr, Ipv6Addr, SocketAddr};
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::sync::{mpsc, Mutex, RwLock};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NetworkStats {
    pub rtt: u32,         // milliseconds
    pub packet_loss: f32, // percentage
    pub jitter: u32,      // milliseconds
    pub bandwidth: u64,   // bits per second
    pub connection_type: ConnectionType,
    pub local_address: Option<String>,
    pub remote_address: Option<String>,
    pub protocol: NetworkProtocol,
}

impl Default for NetworkStats {
    fn default() -> Self {
        Self {
            rtt: 0,
            packet_loss: 0.0,
            jitter: 0,
            bandwidth: 0,
            connection_type: ConnectionType::Unknown,
            local_address: None,
            remote_address: None,
            protocol: NetworkProtocol::IPv4,
        }
    }
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
pub enum ConnectionType {
    Direct,
    StunDirect,
    TurnRelay,
    Unknown,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
pub enum NetworkProtocol {
    IPv4,
    IPv6,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StunServer {
    pub url: String,
    pub username: Option<String>,
    pub credential: Option<String>,
    pub priority: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TurnServer {
    pub url: String,
    pub username: String,
    pub credential: String,
    pub priority: u32,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
pub enum NetworkQuality {
    Excellent, // < 50ms RTT, < 1% loss
    Good,      // < 100ms RTT, < 3% loss
    Fair,      // < 200ms RTT, < 5% loss
    Poor,      // > 200ms RTT, > 5% loss
    Unknown,
}

#[derive(Debug, Clone)]
pub enum NetworkEvent {
    QualityChanged(NetworkQuality),
    ConnectionTypeChanged(ConnectionType),
    ProtocolFallback(NetworkProtocol, NetworkProtocol), // from, to
    StatsUpdated(NetworkStats),
    QualityWarning(String),
}

#[derive(Debug, Clone)]
pub struct IceCandidate {
    pub candidate: String,
    pub sdp_mid: Option<String>,
    pub sdp_mline_index: Option<u16>,
    pub foundation: String,
    pub priority: u32,
    pub ip: IpAddr,
    pub port: u16,
    pub candidate_type: IceCandidateType,
    pub protocol: IceProtocol,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum IceCandidateType {
    Host,
    ServerReflexive,
    PeerReflexive,
    Relay,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum IceProtocol {
    Udp,
    Tcp,
}

pub struct NetworkManager {
    id: String,
    preferred_protocol: Arc<RwLock<NetworkProtocol>>,
    stun_servers: Arc<RwLock<Vec<StunServer>>>,
    turn_servers: Arc<RwLock<Vec<TurnServer>>>,
    pub current_stats: Arc<RwLock<NetworkStats>>,
    pub stats_history: Arc<Mutex<Vec<NetworkStats>>>,
    event_sender: mpsc::UnboundedSender<NetworkEvent>,
    event_receiver: Arc<Mutex<mpsc::UnboundedReceiver<NetworkEvent>>>,
    ice_candidates: Arc<Mutex<Vec<IceCandidate>>>,
    is_monitoring: Arc<RwLock<bool>>,
    ipv6_available: Arc<RwLock<bool>>,
    ipv4_available: Arc<RwLock<bool>>,
}

impl NetworkManager {
    pub fn new() -> Self {
        let (event_sender, event_receiver) = mpsc::unbounded_channel();

        Self {
            id: Uuid::new_v4().to_string(),
            preferred_protocol: Arc::new(RwLock::new(NetworkProtocol::IPv6)),
            stun_servers: Arc::new(RwLock::new(vec![
                StunServer {
                    url: "stun:stun.l.google.com:19302".to_string(),
                    username: None,
                    credential: None,
                    priority: 100,
                },
                StunServer {
                    url: "stun:stun1.l.google.com:19302".to_string(),
                    username: None,
                    credential: None,
                    priority: 90,
                },
            ])),
            turn_servers: Arc::new(RwLock::new(Vec::new())),
            current_stats: Arc::new(RwLock::new(NetworkStats::default())),
            stats_history: Arc::new(Mutex::new(Vec::new())),
            event_sender,
            event_receiver: Arc::new(Mutex::new(event_receiver)),
            ice_candidates: Arc::new(Mutex::new(Vec::new())),
            is_monitoring: Arc::new(RwLock::new(false)),
            ipv6_available: Arc::new(RwLock::new(false)),
            ipv4_available: Arc::new(RwLock::new(true)),
        }
    }

    pub async fn initialize(&self) -> Result<()> {
        // Check network availability
        self.check_ipv6_availability().await;
        self.check_ipv4_availability().await;

        tracing::info!(
            "Network initialized - IPv4: {}, IPv6: {}",
            *self.ipv4_available.read().await,
            *self.ipv6_available.read().await
        );

        Ok(())
    }

    async fn check_ipv6_availability(&self) {
        // Check if IPv6 is available on this system
        // In a real implementation, this would test actual connectivity
        let available = self.test_ipv6_connectivity().await;
        *self.ipv6_available.write().await = available;
    }

    async fn check_ipv4_availability(&self) {
        // Check if IPv4 is available on this system
        let available = self.test_ipv4_connectivity().await;
        *self.ipv4_available.write().await = available;
    }

    async fn test_ipv6_connectivity(&self) -> bool {
        // Placeholder - would test actual IPv6 connectivity
        // Try to connect to a known IPv6 address
        true
    }

    async fn test_ipv4_connectivity(&self) -> bool {
        // Placeholder - would test actual IPv4 connectivity
        true
    }

    pub async fn set_preferred_protocol(&self, protocol: NetworkProtocol) {
        let old_protocol = *self.preferred_protocol.read().await;
        *self.preferred_protocol.write().await = protocol;

        if old_protocol != protocol {
            tracing::info!("Set preferred network protocol: {:?}", protocol);
        }
    }

    pub async fn get_preferred_protocol(&self) -> NetworkProtocol {
        *self.preferred_protocol.read().await
    }

    pub async fn add_stun_server(&self, server: StunServer) {
        let mut servers = self.stun_servers.write().await;
        servers.push(server);
        servers.sort_by(|a, b| b.priority.cmp(&a.priority));
        tracing::info!("Added STUN server, total: {}", servers.len());
    }

    pub async fn add_turn_server(&self, server: TurnServer) {
        let mut servers = self.turn_servers.write().await;
        servers.push(server);
        servers.sort_by(|a, b| b.priority.cmp(&a.priority));
        tracing::info!("Added TURN server, total: {}", servers.len());
    }

    pub async fn get_stun_servers(&self) -> Vec<StunServer> {
        self.stun_servers.read().await.clone()
    }

    pub async fn get_turn_servers(&self) -> Vec<TurnServer> {
        self.turn_servers.read().await.clone()
    }

    // NAT Traversal and Connection Establishment
    pub async fn establish_connection(&self, target: &str) -> Result<ConnectionType> {
        let preferred = *self.preferred_protocol.read().await;

        // Try IPv6 first if preferred and available
        if preferred == NetworkProtocol::IPv6 && *self.ipv6_available.read().await {
            match self.try_ipv6_connection(target).await {
                Ok(conn_type) if conn_type != ConnectionType::Unknown => {
                    return Ok(conn_type);
                }
                _ => {
                    // Fallback to IPv4
                    let _ = self.event_sender.send(NetworkEvent::ProtocolFallback(
                        NetworkProtocol::IPv6,
                        NetworkProtocol::IPv4,
                    ));
                    tracing::info!("IPv6 connection failed, falling back to IPv4");
                }
            }
        }

        // Try IPv4
        if *self.ipv4_available.read().await {
            match self.try_ipv4_connection(target).await {
                Ok(conn_type) if conn_type != ConnectionType::Unknown => {
                    return Ok(conn_type);
                }
                _ => {}
            }
        }

        // Try STUN
        match self.attempt_stun_connection().await {
            Ok(conn_type) if conn_type != ConnectionType::Unknown => {
                return Ok(conn_type);
            }
            _ => {}
        }

        // Fallback to TURN relay
        self.attempt_turn_connection().await
    }

    async fn try_ipv6_connection(&self, target: &str) -> Result<ConnectionType> {
        tracing::debug!("Attempting IPv6 direct connection to {}", target);
        // Placeholder - would attempt actual IPv6 connection
        Ok(ConnectionType::Direct)
    }

    async fn try_ipv4_connection(&self, target: &str) -> Result<ConnectionType> {
        tracing::debug!("Attempting IPv4 direct connection to {}", target);
        // Placeholder - would attempt actual IPv4 connection
        Ok(ConnectionType::Direct)
    }

    pub async fn attempt_stun_connection(&self) -> Result<ConnectionType> {
        let servers = self.stun_servers.read().await;

        for server in servers.iter() {
            tracing::debug!("Trying STUN server: {}", server.url);

            match self.stun_binding_request(&server).await {
                Ok(reflexive_addr) => {
                    tracing::info!(
                        "STUN binding successful, reflexive address: {:?}",
                        reflexive_addr
                    );
                    return Ok(ConnectionType::StunDirect);
                }
                Err(e) => {
                    tracing::warn!("STUN server {} failed: {}", server.url, e);
                    continue;
                }
            }
        }

        Ok(ConnectionType::Unknown)
    }

    async fn stun_binding_request(&self, server: &StunServer) -> Result<SocketAddr> {
        // Placeholder - would perform actual STUN binding request
        // Returns the server-reflexive address
        Ok(SocketAddr::new(
            IpAddr::V4(Ipv4Addr::new(203, 0, 113, 1)),
            12345,
        ))
    }

    pub async fn attempt_turn_connection(&self) -> Result<ConnectionType> {
        let servers = self.turn_servers.read().await;

        if servers.is_empty() {
            return Err(anyhow::anyhow!("No TURN servers configured"));
        }

        for server in servers.iter() {
            tracing::debug!("Trying TURN server: {}", server.url);

            match self.turn_allocate_request(&server).await {
                Ok(relay_addr) => {
                    tracing::info!(
                        "TURN allocation successful, relay address: {:?}",
                        relay_addr
                    );
                    return Ok(ConnectionType::TurnRelay);
                }
                Err(e) => {
                    tracing::warn!("TURN server {} failed: {}", server.url, e);
                    continue;
                }
            }
        }

        Err(anyhow::anyhow!("All TURN servers failed"))
    }

    async fn turn_allocate_request(&self, server: &TurnServer) -> Result<SocketAddr> {
        // Placeholder - would perform actual TURN allocation
        Ok(SocketAddr::new(
            IpAddr::V4(Ipv4Addr::new(198, 51, 100, 1)),
            54321,
        ))
    }

    // ICE Candidate Management
    pub async fn gather_ice_candidates(&self) -> Result<Vec<IceCandidate>> {
        let mut candidates = Vec::new();

        // Gather host candidates
        candidates.extend(self.gather_host_candidates().await?);

        // Gather server-reflexive candidates via STUN
        candidates.extend(self.gather_srflx_candidates().await?);

        // Gather relay candidates via TURN
        candidates.extend(self.gather_relay_candidates().await?);

        // Store candidates
        *self.ice_candidates.lock().await = candidates.clone();

        tracing::info!("Gathered {} ICE candidates", candidates.len());
        Ok(candidates)
    }

    async fn gather_host_candidates(&self) -> Result<Vec<IceCandidate>> {
        let mut candidates = Vec::new();

        // Get local network interfaces
        // Placeholder - would enumerate actual network interfaces
        if *self.ipv4_available.read().await {
            candidates.push(IceCandidate {
                candidate: "candidate:1 1 UDP 2130706431 192.168.1.100 54321 typ host".to_string(),
                sdp_mid: Some("0".to_string()),
                sdp_mline_index: Some(0),
                foundation: "1".to_string(),
                priority: 2130706431,
                ip: IpAddr::V4(Ipv4Addr::new(192, 168, 1, 100)),
                port: 54321,
                candidate_type: IceCandidateType::Host,
                protocol: IceProtocol::Udp,
            });
        }

        if *self.ipv6_available.read().await {
            candidates.push(IceCandidate {
                candidate: "candidate:2 1 UDP 2130706430 ::1 54322 typ host".to_string(),
                sdp_mid: Some("0".to_string()),
                sdp_mline_index: Some(0),
                foundation: "2".to_string(),
                priority: 2130706430,
                ip: IpAddr::V6(Ipv6Addr::LOCALHOST),
                port: 54322,
                candidate_type: IceCandidateType::Host,
                protocol: IceProtocol::Udp,
            });
        }

        Ok(candidates)
    }

    async fn gather_srflx_candidates(&self) -> Result<Vec<IceCandidate>> {
        let mut candidates = Vec::new();
        let servers = self.stun_servers.read().await;

        for server in servers.iter() {
            if let Ok(reflexive_addr) = self.stun_binding_request(server).await {
                candidates.push(IceCandidate {
                    candidate: format!(
                        "candidate:3 1 UDP 1694498815 {} {} typ srflx raddr 192.168.1.100 rport 54321",
                        reflexive_addr.ip(),
                        reflexive_addr.port()
                    ),
                    sdp_mid: Some("0".to_string()),
                    sdp_mline_index: Some(0),
                    foundation: "3".to_string(),
                    priority: 1694498815,
                    ip: reflexive_addr.ip(),
                    port: reflexive_addr.port(),
                    candidate_type: IceCandidateType::ServerReflexive,
                    protocol: IceProtocol::Udp,
                });
                break; // Use first successful STUN server
            }
        }

        Ok(candidates)
    }

    async fn gather_relay_candidates(&self) -> Result<Vec<IceCandidate>> {
        let mut candidates = Vec::new();
        let servers = self.turn_servers.read().await;

        for server in servers.iter() {
            if let Ok(relay_addr) = self.turn_allocate_request(server).await {
                candidates.push(IceCandidate {
                    candidate: format!(
                        "candidate:4 1 UDP 16777215 {} {} typ relay raddr 192.168.1.100 rport 54321",
                        relay_addr.ip(),
                        relay_addr.port()
                    ),
                    sdp_mid: Some("0".to_string()),
                    sdp_mline_index: Some(0),
                    foundation: "4".to_string(),
                    priority: 16777215,
                    ip: relay_addr.ip(),
                    port: relay_addr.port(),
                    candidate_type: IceCandidateType::Relay,
                    protocol: IceProtocol::Udp,
                });
                break; // Use first successful TURN server
            }
        }

        Ok(candidates)
    }

    pub async fn get_ice_candidates(&self) -> Vec<IceCandidate> {
        self.ice_candidates.lock().await.clone()
    }

    // Network Quality Monitoring
    pub async fn start_monitoring(&self) -> Result<()> {
        if *self.is_monitoring.read().await {
            return Ok(());
        }

        *self.is_monitoring.write().await = true;

        let is_monitoring = Arc::clone(&self.is_monitoring);
        let current_stats = Arc::clone(&self.current_stats);
        let stats_history = Arc::clone(&self.stats_history);
        let event_sender = self.event_sender.clone();

        tokio::spawn(async move {
            let mut last_quality = NetworkQuality::Unknown;

            while *is_monitoring.read().await {
                // Measure network stats
                let stats = Self::measure_stats_internal().await;

                // Update current stats
                *current_stats.write().await = stats.clone();

                // Add to history (keep last 60 samples)
                {
                    let mut history = stats_history.lock().await;
                    history.push(stats.clone());
                    if history.len() > 60 {
                        history.remove(0);
                    }
                }

                // Calculate quality
                let quality = Self::calculate_quality(&stats);

                // Send events if quality changed
                if quality != last_quality {
                    let _ = event_sender.send(NetworkEvent::QualityChanged(quality));

                    if quality == NetworkQuality::Poor {
                        let _ = event_sender.send(NetworkEvent::QualityWarning(format!(
                            "Network quality degraded: RTT={}ms, Loss={:.1}%",
                            stats.rtt, stats.packet_loss
                        )));
                    }

                    last_quality = quality;
                }

                let _ = event_sender.send(NetworkEvent::StatsUpdated(stats));

                // Monitor every second
                tokio::time::sleep(Duration::from_secs(1)).await;
            }
        });

        tracing::info!("Network monitoring started");
        Ok(())
    }

    pub async fn stop_monitoring(&self) {
        *self.is_monitoring.write().await = false;
        tracing::info!("Network monitoring stopped");
    }

    async fn measure_stats_internal() -> NetworkStats {
        // Placeholder - would measure actual network stats
        // In real implementation, this would:
        // 1. Send STUN binding requests to measure RTT
        // 2. Track packet loss from RTP statistics
        // 3. Calculate jitter from packet arrival times
        // 4. Estimate bandwidth from throughput measurements

        NetworkStats {
            rtt: 50,
            packet_loss: 0.5,
            jitter: 10,
            bandwidth: 10_000_000, // 10 Mbps
            connection_type: ConnectionType::Direct,
            local_address: Some("192.168.1.100:54321".to_string()),
            remote_address: Some("203.0.113.1:12345".to_string()),
            protocol: NetworkProtocol::IPv4,
        }
    }

    pub async fn measure_network_stats(&self) -> Result<NetworkStats> {
        let stats = Self::measure_stats_internal().await;
        *self.current_stats.write().await = stats.clone();
        Ok(stats)
    }

    pub fn calculate_quality(stats: &NetworkStats) -> NetworkQuality {
        if stats.rtt < 50 && stats.packet_loss < 1.0 {
            NetworkQuality::Excellent
        } else if stats.rtt < 100 && stats.packet_loss < 3.0 {
            NetworkQuality::Good
        } else if stats.rtt < 200 && stats.packet_loss < 5.0 {
            NetworkQuality::Fair
        } else {
            NetworkQuality::Poor
        }
    }

    pub async fn get_network_quality(&self) -> NetworkQuality {
        let stats = self.current_stats.read().await;
        Self::calculate_quality(&stats)
    }

    pub async fn should_show_quality_warning(&self) -> bool {
        self.get_network_quality().await == NetworkQuality::Poor
    }

    pub async fn get_current_stats(&self) -> NetworkStats {
        self.current_stats.read().await.clone()
    }

    pub async fn get_stats_history(&self) -> Vec<NetworkStats> {
        self.stats_history.lock().await.clone()
    }

    pub async fn get_average_stats(&self) -> NetworkStats {
        let history = self.stats_history.lock().await;

        if history.is_empty() {
            return NetworkStats::default();
        }

        let count = history.len() as u32;
        let total_rtt: u32 = history.iter().map(|s| s.rtt).sum();
        let total_loss: f32 = history.iter().map(|s| s.packet_loss).sum();
        let total_jitter: u32 = history.iter().map(|s| s.jitter).sum();
        let total_bandwidth: u64 = history.iter().map(|s| s.bandwidth).sum();

        NetworkStats {
            rtt: total_rtt / count,
            packet_loss: total_loss / count as f32,
            jitter: total_jitter / count,
            bandwidth: total_bandwidth / count as u64,
            ..history.last().cloned().unwrap_or_default()
        }
    }

    pub async fn get_event_receiver(&self) -> Arc<Mutex<mpsc::UnboundedReceiver<NetworkEvent>>> {
        Arc::clone(&self.event_receiver)
    }

    pub async fn is_ipv6_available(&self) -> bool {
        *self.ipv6_available.read().await
    }

    pub async fn is_ipv4_available(&self) -> bool {
        *self.ipv4_available.read().await
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_network_manager_creation() {
        let manager = NetworkManager::new();
        assert!(manager.get_stun_servers().await.len() > 0);
    }

    #[tokio::test]
    async fn test_protocol_preference() {
        let manager = NetworkManager::new();

        // Default should be IPv6
        assert_eq!(
            manager.get_preferred_protocol().await,
            NetworkProtocol::IPv6
        );

        // Change to IPv4
        manager.set_preferred_protocol(NetworkProtocol::IPv4).await;
        assert_eq!(
            manager.get_preferred_protocol().await,
            NetworkProtocol::IPv4
        );
    }

    #[tokio::test]
    async fn test_network_quality_calculation() {
        let excellent = NetworkStats {
            rtt: 30,
            packet_loss: 0.5,
            ..Default::default()
        };
        assert_eq!(
            NetworkManager::calculate_quality(&excellent),
            NetworkQuality::Excellent
        );

        let good = NetworkStats {
            rtt: 80,
            packet_loss: 2.0,
            ..Default::default()
        };
        assert_eq!(
            NetworkManager::calculate_quality(&good),
            NetworkQuality::Good
        );

        let fair = NetworkStats {
            rtt: 150,
            packet_loss: 4.0,
            ..Default::default()
        };
        assert_eq!(
            NetworkManager::calculate_quality(&fair),
            NetworkQuality::Fair
        );

        let poor = NetworkStats {
            rtt: 300,
            packet_loss: 10.0,
            ..Default::default()
        };
        assert_eq!(
            NetworkManager::calculate_quality(&poor),
            NetworkQuality::Poor
        );
    }

    #[tokio::test]
    async fn test_ice_candidate_gathering() {
        let manager = NetworkManager::new();
        manager.initialize().await.unwrap();

        let candidates = manager.gather_ice_candidates().await.unwrap();
        assert!(!candidates.is_empty());

        // Should have at least host candidates
        let host_candidates: Vec<_> = candidates
            .iter()
            .filter(|c| c.candidate_type == IceCandidateType::Host)
            .collect();
        assert!(!host_candidates.is_empty());
    }
}
