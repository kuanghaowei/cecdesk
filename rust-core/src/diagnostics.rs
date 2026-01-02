use anyhow::Result;
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::net::{IpAddr, SocketAddr};
use std::time::Duration;

/// NAT 类型
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum NatType {
    Unknown,
    OpenInternet,
    FullCone,
    RestrictedCone,
    PortRestrictedCone,
    Symmetric,
    SymmetricUdpFirewall,
    Blocked,
}

impl std::fmt::Display for NatType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            NatType::Unknown => write!(f, "未知"),
            NatType::OpenInternet => write!(f, "开放网络"),
            NatType::FullCone => write!(f, "完全锥形NAT"),
            NatType::RestrictedCone => write!(f, "受限锥形NAT"),
            NatType::PortRestrictedCone => write!(f, "端口受限锥形NAT"),
            NatType::Symmetric => write!(f, "对称NAT"),
            NatType::SymmetricUdpFirewall => write!(f, "对称UDP防火墙"),
            NatType::Blocked => write!(f, "被阻止"),
        }
    }
}

/// 服务器状态
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerStatus {
    pub name: String,
    pub url: String,
    pub reachable: bool,
    pub latency_ms: Option<u32>,
    pub error: Option<String>,
    pub last_check: DateTime<Utc>,
}

impl ServerStatus {
    pub fn new(name: &str, url: &str) -> Self {
        Self {
            name: name.to_string(),
            url: url.to_string(),
            reachable: false,
            latency_ms: None,
            error: None,
            last_check: Utc::now(),
        }
    }

    pub fn success(mut self, latency_ms: u32) -> Self {
        self.reachable = true;
        self.latency_ms = Some(latency_ms);
        self.last_check = Utc::now();
        self
    }

    pub fn failure(mut self, error: &str) -> Self {
        self.reachable = false;
        self.error = Some(error.to_string());
        self.last_check = Utc::now();
        self
    }
}

/// 网络诊断结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NetworkDiagnostics {
    pub timestamp: DateTime<Utc>,
    pub internet_connected: bool,
    pub ipv4_available: bool,
    pub ipv6_available: bool,
    pub public_ipv4: Option<String>,
    pub public_ipv6: Option<String>,
    pub local_ipv4: Option<String>,
    pub local_ipv6: Option<String>,
    pub nat_type: NatType,
    pub signaling_server: ServerStatus,
    pub stun_servers: Vec<ServerStatus>,
    pub turn_servers: Vec<ServerStatus>,
    pub overall_status: DiagnosticStatus,
    pub recommendations: Vec<String>,
}

impl NetworkDiagnostics {
    pub fn new() -> Self {
        Self {
            timestamp: Utc::now(),
            internet_connected: false,
            ipv4_available: false,
            ipv6_available: false,
            public_ipv4: None,
            public_ipv6: None,
            local_ipv4: None,
            local_ipv6: None,
            nat_type: NatType::Unknown,
            signaling_server: ServerStatus::new("Signaling", ""),
            stun_servers: Vec::new(),
            turn_servers: Vec::new(),
            overall_status: DiagnosticStatus::Unknown,
            recommendations: Vec::new(),
        }
    }

    /// 计算总体状态
    pub fn calculate_overall_status(&mut self) {
        if !self.internet_connected {
            self.overall_status = DiagnosticStatus::Critical;
            self.recommendations.push("请检查网络连接".to_string());
            return;
        }

        if !self.signaling_server.reachable {
            self.overall_status = DiagnosticStatus::Critical;
            self.recommendations.push("无法连接信令服务器，请检查网络设置".to_string());
            return;
        }

        let stun_reachable = self.stun_servers.iter().any(|s| s.reachable);
        let turn_reachable = self.turn_servers.iter().any(|s| s.reachable);

        if !stun_reachable && !turn_reachable {
            self.overall_status = DiagnosticStatus::Critical;
            self.recommendations.push("无法连接STUN/TURN服务器，可能无法建立P2P连接".to_string());
            return;
        }

        match self.nat_type {
            NatType::Symmetric | NatType::SymmetricUdpFirewall => {
                if !turn_reachable {
                    self.overall_status = DiagnosticStatus::Warning;
                    self.recommendations.push("检测到对称NAT，建议确保TURN服务器可用".to_string());
                } else {
                    self.overall_status = DiagnosticStatus::Good;
                    self.recommendations.push("检测到对称NAT，将使用TURN中继".to_string());
                }
            }
            NatType::Blocked => {
                self.overall_status = DiagnosticStatus::Critical;
                self.recommendations.push("UDP被阻止，请检查防火墙设置".to_string());
            }
            _ => {
                self.overall_status = DiagnosticStatus::Good;
            }
        }

        // 检查延迟
        if let Some(latency) = self.signaling_server.latency_ms {
            if latency > 200 {
                self.recommendations.push(format!("信令服务器延迟较高 ({}ms)，可能影响连接建立速度", latency));
            }
        }
    }
}

impl Default for NetworkDiagnostics {
    fn default() -> Self {
        Self::new()
    }
}

/// 诊断状态
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum DiagnosticStatus {
    Unknown,
    Good,
    Warning,
    Critical,
}

impl std::fmt::Display for DiagnosticStatus {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            DiagnosticStatus::Unknown => write!(f, "未知"),
            DiagnosticStatus::Good => write!(f, "良好"),
            DiagnosticStatus::Warning => write!(f, "警告"),
            DiagnosticStatus::Critical => write!(f, "严重"),
        }
    }
}

/// 系统诊断结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SystemDiagnostics {
    pub timestamp: DateTime<Utc>,
    pub os_name: String,
    pub os_version: String,
    pub cpu_usage_percent: f32,
    pub memory_usage_percent: f32,
    pub available_memory_mb: u64,
    pub disk_usage_percent: f32,
    pub screen_capture_available: bool,
    pub audio_capture_available: bool,
    pub hardware_acceleration_available: bool,
    pub supported_codecs: Vec<String>,
}

impl SystemDiagnostics {
    pub fn new() -> Self {
        Self {
            timestamp: Utc::now(),
            os_name: std::env::consts::OS.to_string(),
            os_version: "Unknown".to_string(),
            cpu_usage_percent: 0.0,
            memory_usage_percent: 0.0,
            available_memory_mb: 0,
            disk_usage_percent: 0.0,
            screen_capture_available: true,
            audio_capture_available: true,
            hardware_acceleration_available: false,
            supported_codecs: vec!["H.264".to_string(), "VP8".to_string(), "VP9".to_string()],
        }
    }
}

impl Default for SystemDiagnostics {
    fn default() -> Self {
        Self::new()
    }
}

/// 诊断管理器
pub struct DiagnosticsManager {
    signaling_url: String,
    stun_urls: Vec<String>,
    turn_urls: Vec<String>,
}

impl DiagnosticsManager {
    pub fn new() -> Self {
        Self {
            signaling_url: String::new(),
            stun_urls: Vec::new(),
            turn_urls: Vec::new(),
        }
    }

    /// 配置服务器URL
    pub fn configure(&mut self, signaling_url: &str, stun_urls: Vec<String>, turn_urls: Vec<String>) {
        self.signaling_url = signaling_url.to_string();
        self.stun_urls = stun_urls;
        self.turn_urls = turn_urls;
    }

    /// 运行网络诊断
    pub async fn run_network_diagnostics(&self) -> NetworkDiagnostics {
        let mut diagnostics = NetworkDiagnostics::new();

        // 检查互联网连接
        diagnostics.internet_connected = self.check_internet_connection().await;

        if diagnostics.internet_connected {
            // 获取本地IP
            diagnostics.local_ipv4 = self.get_local_ipv4();
            diagnostics.local_ipv6 = self.get_local_ipv6();
            diagnostics.ipv4_available = diagnostics.local_ipv4.is_some();
            diagnostics.ipv6_available = diagnostics.local_ipv6.is_some();

            // 检查信令服务器
            diagnostics.signaling_server = self.check_server("Signaling", &self.signaling_url).await;

            // 检查STUN服务器
            for url in &self.stun_urls {
                let status = self.check_server("STUN", url).await;
                if status.reachable {
                    // 尝试获取公网IP
                    if diagnostics.public_ipv4.is_none() {
                        diagnostics.public_ipv4 = self.get_public_ip_via_stun(url).await;
                    }
                }
                diagnostics.stun_servers.push(status);
            }

            // 检查TURN服务器
            for url in &self.turn_urls {
                let status = self.check_server("TURN", url).await;
                diagnostics.turn_servers.push(status);
            }

            // 检测NAT类型
            diagnostics.nat_type = self.detect_nat_type().await;
        }

        // 计算总体状态
        diagnostics.calculate_overall_status();

        diagnostics
    }

    /// 运行系统诊断
    pub fn run_system_diagnostics(&self) -> SystemDiagnostics {
        let mut diagnostics = SystemDiagnostics::new();

        // 这里应该调用系统API获取实际信息
        // 目前使用模拟数据
        diagnostics.cpu_usage_percent = 25.0;
        diagnostics.memory_usage_percent = 60.0;
        diagnostics.available_memory_mb = 8192;
        diagnostics.disk_usage_percent = 45.0;

        diagnostics
    }

    /// 检查互联网连接
    async fn check_internet_connection(&self) -> bool {
        // 模拟检查 - 实际应该尝试连接已知服务器
        true
    }

    /// 检查服务器
    async fn check_server(&self, name: &str, url: &str) -> ServerStatus {
        let mut status = ServerStatus::new(name, url);
        
        if url.is_empty() {
            return status.failure("URL未配置");
        }

        // 模拟检查 - 实际应该尝试连接
        // 这里返回模拟成功结果
        let latency = 30 + (rand::random::<u32>() % 50);
        status.success(latency)
    }

    /// 获取本地IPv4
    fn get_local_ipv4(&self) -> Option<String> {
        // 模拟 - 实际应该获取真实IP
        Some("192.168.1.100".to_string())
    }

    /// 获取本地IPv6
    fn get_local_ipv6(&self) -> Option<String> {
        // 模拟 - 实际应该获取真实IP
        Some("fe80::1".to_string())
    }

    /// 通过STUN获取公网IP
    async fn get_public_ip_via_stun(&self, _stun_url: &str) -> Option<String> {
        // 模拟 - 实际应该通过STUN协议获取
        Some("203.0.113.1".to_string())
    }

    /// 检测NAT类型
    async fn detect_nat_type(&self) -> NatType {
        // 模拟 - 实际应该通过STUN协议检测
        NatType::FullCone
    }
}

impl Default for DiagnosticsManager {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_server_status() {
        let status = ServerStatus::new("Test", "http://test.com")
            .success(50);
        
        assert!(status.reachable);
        assert_eq!(status.latency_ms, Some(50));
    }

    #[test]
    fn test_network_diagnostics_status() {
        let mut diagnostics = NetworkDiagnostics::new();
        diagnostics.internet_connected = true;
        diagnostics.signaling_server = ServerStatus::new("Signaling", "ws://test.com").success(30);
        diagnostics.stun_servers.push(ServerStatus::new("STUN", "stun:test.com").success(20));
        diagnostics.nat_type = NatType::FullCone;
        
        diagnostics.calculate_overall_status();
        
        assert_eq!(diagnostics.overall_status, DiagnosticStatus::Good);
    }

    #[test]
    fn test_nat_type_display() {
        assert_eq!(format!("{}", NatType::FullCone), "完全锥形NAT");
        assert_eq!(format!("{}", NatType::Symmetric), "对称NAT");
    }
}
