use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::{Arc, RwLock};
use uuid::Uuid;
use chrono::{DateTime, Utc, Duration};

/// 会话状态枚举
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum SessionStatus {
    Pending,
    Active,
    Paused,
    Ended,
    Failed,
}

/// 权限类型枚举
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum Permission {
    ScreenView,
    InputControl,
    FileTransfer,
    AudioCapture,
    SystemControl,
}

/// 连接质量等级
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum ConnectionQuality {
    Excellent,
    Good,
    Fair,
    Poor,
}

impl ConnectionQuality {
    /// 根据网络指标计算连接质量
    pub fn from_metrics(rtt: u32, packet_loss: f32, jitter: u32) -> Self {
        if rtt < 50 && packet_loss < 1.0 && jitter < 10 {
            ConnectionQuality::Excellent
        } else if rtt < 100 && packet_loss < 3.0 && jitter < 20 {
            ConnectionQuality::Good
        } else if rtt < 200 && packet_loss < 5.0 && jitter < 50 {
            ConnectionQuality::Fair
        } else {
            ConnectionQuality::Poor
        }
    }
}

/// 会话统计信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionStats {
    pub duration_secs: u64,
    pub bytes_sent: u64,
    pub bytes_received: u64,
    pub average_latency_ms: u32,
    pub max_latency_ms: u32,
    pub min_latency_ms: u32,
    pub packet_loss_percent: f32,
    pub jitter_ms: u32,
    pub frames_sent: u64,
    pub frames_received: u64,
    pub connection_quality: ConnectionQuality,
    pub connection_type: ConnectionType,
}

impl Default for SessionStats {
    fn default() -> Self {
        Self {
            duration_secs: 0,
            bytes_sent: 0,
            bytes_received: 0,
            average_latency_ms: 0,
            max_latency_ms: 0,
            min_latency_ms: u32::MAX,
            packet_loss_percent: 0.0,
            jitter_ms: 0,
            frames_sent: 0,
            frames_received: 0,
            connection_quality: ConnectionQuality::Good,
            connection_type: ConnectionType::Direct,
        }
    }
}

/// 连接类型
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum ConnectionType {
    Direct,      // P2P 直连
    Relay,       // TURN 中继
    Unknown,
}

/// 会话信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Session {
    pub session_id: String,
    pub controller_id: String,
    pub controlled_id: String,
    pub start_time: DateTime<Utc>,
    pub end_time: Option<DateTime<Utc>>,
    pub status: SessionStatus,
    pub permissions: Vec<Permission>,
    pub stats: SessionStats,
    pub metadata: HashMap<String, String>,
}

impl Session {
    /// 创建新会话
    pub fn new(controller_id: String, controlled_id: String, permissions: Vec<Permission>) -> Self {
        Self {
            session_id: Uuid::new_v4().to_string(),
            controller_id,
            controlled_id,
            start_time: Utc::now(),
            end_time: None,
            status: SessionStatus::Pending,
            permissions,
            stats: SessionStats::default(),
            metadata: HashMap::new(),
        }
    }

    /// 获取会话持续时间（秒）
    pub fn duration_secs(&self) -> u64 {
        let end = self.end_time.unwrap_or_else(Utc::now);
        (end - self.start_time).num_seconds().max(0) as u64
    }

    /// 更新会话统计
    pub fn update_stats(&mut self, latency: u32, packet_loss: f32, jitter: u32, bytes_delta: (u64, u64)) {
        self.stats.duration_secs = self.duration_secs();
        self.stats.bytes_sent += bytes_delta.0;
        self.stats.bytes_received += bytes_delta.1;
        
        // 更新延迟统计
        if latency > 0 {
            if self.stats.average_latency_ms == 0 {
                self.stats.average_latency_ms = latency;
            } else {
                // 移动平均
                self.stats.average_latency_ms = (self.stats.average_latency_ms * 9 + latency) / 10;
            }
            self.stats.max_latency_ms = self.stats.max_latency_ms.max(latency);
            self.stats.min_latency_ms = self.stats.min_latency_ms.min(latency);
        }
        
        self.stats.packet_loss_percent = packet_loss;
        self.stats.jitter_ms = jitter;
        self.stats.connection_quality = ConnectionQuality::from_metrics(latency, packet_loss, jitter);
    }
}

/// 会话创建选项
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionOptions {
    pub permissions: Vec<Permission>,
    pub auto_accept: bool,
    pub session_timeout_secs: u64,
    pub require_encryption: bool,
}

impl Default for SessionOptions {
    fn default() -> Self {
        Self {
            permissions: vec![Permission::ScreenView, Permission::InputControl],
            auto_accept: false,
            session_timeout_secs: 3600, // 1 hour
            require_encryption: true,
        }
    }
}

/// 会话历史记录
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionRecord {
    pub session_id: String,
    pub controller_id: String,
    pub controlled_id: String,
    pub start_time: DateTime<Utc>,
    pub end_time: DateTime<Utc>,
    pub duration_secs: u64,
    pub end_reason: EndReason,
    pub final_stats: SessionStats,
}

/// 会话结束原因
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum EndReason {
    UserRequested,
    RemoteDisconnect,
    Timeout,
    NetworkError,
    AuthenticationFailed,
    PermissionDenied,
    SystemError(String),
}

impl std::fmt::Display for EndReason {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            EndReason::UserRequested => write!(f, "用户主动断开"),
            EndReason::RemoteDisconnect => write!(f, "远程设备断开"),
            EndReason::Timeout => write!(f, "会话超时"),
            EndReason::NetworkError => write!(f, "网络错误"),
            EndReason::AuthenticationFailed => write!(f, "认证失败"),
            EndReason::PermissionDenied => write!(f, "权限被拒绝"),
            EndReason::SystemError(msg) => write!(f, "系统错误: {}", msg),
        }
    }
}

/// 权限请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PermissionRequest {
    pub request_id: String,
    pub from_device_id: String,
    pub to_device_id: String,
    pub permissions: Vec<Permission>,
    pub message: Option<String>,
    pub created_at: DateTime<Utc>,
    pub expires_at: DateTime<Utc>,
}

impl PermissionRequest {
    pub fn new(from_device_id: String, to_device_id: String, permissions: Vec<Permission>) -> Self {
        let now = Utc::now();
        Self {
            request_id: Uuid::new_v4().to_string(),
            from_device_id,
            to_device_id,
            permissions,
            message: None,
            created_at: now,
            expires_at: now + Duration::minutes(5),
        }
    }

    pub fn is_expired(&self) -> bool {
        Utc::now() > self.expires_at
    }
}

/// 会话事件类型
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum SessionEvent {
    Created { session_id: String, controller_id: String, controlled_id: String },
    Started { session_id: String },
    Paused { session_id: String },
    Resumed { session_id: String },
    Ended { session_id: String, reason: EndReason },
    StatsUpdated { session_id: String, stats: SessionStats },
    PermissionRequested { request_id: String, permissions: Vec<Permission> },
    PermissionGranted { request_id: String },
    PermissionDenied { request_id: String },
}

/// 会话事件监听器
pub type SessionEventCallback = Box<dyn Fn(SessionEvent) + Send + Sync>;

/// 会话管理器
pub struct SessionManager {
    local_device_id: String,
    active_sessions: Arc<RwLock<HashMap<String, Session>>>,
    session_history: Arc<RwLock<Vec<SessionRecord>>>,
    pending_requests: Arc<RwLock<HashMap<String, PermissionRequest>>>,
    event_callbacks: Arc<RwLock<Vec<SessionEventCallback>>>,
    history_retention_days: u32,
}

impl SessionManager {
    /// 创建新的会话管理器
    pub fn new(local_device_id: String) -> Self {
        Self {
            local_device_id,
            active_sessions: Arc::new(RwLock::new(HashMap::new())),
            session_history: Arc::new(RwLock::new(Vec::new())),
            pending_requests: Arc::new(RwLock::new(HashMap::new())),
            event_callbacks: Arc::new(RwLock::new(Vec::new())),
            history_retention_days: 30,
        }
    }

    /// 设置历史记录保留天数
    pub fn set_history_retention_days(&mut self, days: u32) {
        self.history_retention_days = days;
    }

    /// 注册事件回调
    pub fn on_event(&self, callback: SessionEventCallback) {
        if let Ok(mut callbacks) = self.event_callbacks.write() {
            callbacks.push(callback);
        }
    }

    /// 触发事件
    fn emit_event(&self, event: SessionEvent) {
        if let Ok(callbacks) = self.event_callbacks.read() {
            for callback in callbacks.iter() {
                callback(event.clone());
            }
        }
        tracing::info!("Session event: {:?}", event);
    }

    /// 创建新会话
    pub async fn create_session(&self, remote_id: String, options: SessionOptions) -> Result<Session> {
        let session = Session::new(
            self.local_device_id.clone(),
            remote_id.clone(),
            options.permissions,
        );

        let session_id = session.session_id.clone();
        
        if let Ok(mut sessions) = self.active_sessions.write() {
            sessions.insert(session_id.clone(), session.clone());
        }

        self.emit_event(SessionEvent::Created {
            session_id: session_id.clone(),
            controller_id: self.local_device_id.clone(),
            controlled_id: remote_id,
        });

        tracing::info!("Created session: {}", session_id);
        Ok(session)
    }

    /// 加入会话（被控端）
    pub async fn join_session(&self, session_id: String) -> Result<Session> {
        let mut sessions = self.active_sessions.write()
            .map_err(|_| anyhow::anyhow!("Failed to acquire lock"))?;
        
        if let Some(session) = sessions.get_mut(&session_id) {
            session.status = SessionStatus::Active;
            let session_clone = session.clone();
            
            drop(sessions);
            
            self.emit_event(SessionEvent::Started {
                session_id: session_id.clone(),
            });
            
            tracing::info!("Joined session: {}", session_id);
            Ok(session_clone)
        } else {
            Err(anyhow::anyhow!("Session not found: {}", session_id))
        }
    }

    /// 暂停会话
    pub fn pause_session(&self, session_id: &str) -> Result<()> {
        let mut sessions = self.active_sessions.write()
            .map_err(|_| anyhow::anyhow!("Failed to acquire lock"))?;
        
        if let Some(session) = sessions.get_mut(session_id) {
            session.status = SessionStatus::Paused;
            
            self.emit_event(SessionEvent::Paused {
                session_id: session_id.to_string(),
            });
            
            tracing::info!("Paused session: {}", session_id);
            Ok(())
        } else {
            Err(anyhow::anyhow!("Session not found: {}", session_id))
        }
    }

    /// 恢复会话
    pub fn resume_session(&self, session_id: &str) -> Result<()> {
        let mut sessions = self.active_sessions.write()
            .map_err(|_| anyhow::anyhow!("Failed to acquire lock"))?;
        
        if let Some(session) = sessions.get_mut(session_id) {
            session.status = SessionStatus::Active;
            
            self.emit_event(SessionEvent::Resumed {
                session_id: session_id.to_string(),
            });
            
            tracing::info!("Resumed session: {}", session_id);
            Ok(())
        } else {
            Err(anyhow::anyhow!("Session not found: {}", session_id))
        }
    }

    /// 结束会话
    pub fn end_session(&self, session_id: &str, reason: EndReason) -> Result<SessionRecord> {
        let mut sessions = self.active_sessions.write()
            .map_err(|_| anyhow::anyhow!("Failed to acquire lock"))?;
        
        if let Some(mut session) = sessions.remove(session_id) {
            session.status = SessionStatus::Ended;
            session.end_time = Some(Utc::now());
            session.stats.duration_secs = session.duration_secs();

            let record = SessionRecord {
                session_id: session.session_id.clone(),
                controller_id: session.controller_id.clone(),
                controlled_id: session.controlled_id.clone(),
                start_time: session.start_time,
                end_time: session.end_time.unwrap(),
                duration_secs: session.stats.duration_secs,
                end_reason: reason.clone(),
                final_stats: session.stats.clone(),
            };

            drop(sessions);

            // 添加到历史记录
            if let Ok(mut history) = self.session_history.write() {
                history.push(record.clone());
                // 清理过期记录
                self.cleanup_old_records(&mut history);
            }

            self.emit_event(SessionEvent::Ended {
                session_id: session_id.to_string(),
                reason,
            });

            tracing::info!("Ended session: {}", session_id);
            Ok(record)
        } else {
            Err(anyhow::anyhow!("Session not found: {}", session_id))
        }
    }

    /// 清理过期的历史记录
    fn cleanup_old_records(&self, history: &mut Vec<SessionRecord>) {
        let cutoff = Utc::now() - Duration::days(self.history_retention_days as i64);
        history.retain(|record| record.end_time > cutoff);
    }

    /// 更新会话统计
    pub fn update_session_stats(
        &self,
        session_id: &str,
        latency: u32,
        packet_loss: f32,
        jitter: u32,
        bytes_delta: (u64, u64),
    ) -> Result<SessionStats> {
        let mut sessions = self.active_sessions.write()
            .map_err(|_| anyhow::anyhow!("Failed to acquire lock"))?;
        
        if let Some(session) = sessions.get_mut(session_id) {
            session.update_stats(latency, packet_loss, jitter, bytes_delta);
            let stats = session.stats.clone();
            
            drop(sessions);
            
            self.emit_event(SessionEvent::StatsUpdated {
                session_id: session_id.to_string(),
                stats: stats.clone(),
            });
            
            Ok(stats)
        } else {
            Err(anyhow::anyhow!("Session not found: {}", session_id))
        }
    }

    /// 获取活动会话列表
    pub fn get_active_sessions(&self) -> Vec<Session> {
        self.active_sessions.read()
            .map(|sessions| sessions.values().cloned().collect())
            .unwrap_or_default()
    }

    /// 获取指定会话
    pub fn get_session(&self, session_id: &str) -> Option<Session> {
        self.active_sessions.read()
            .ok()
            .and_then(|sessions| sessions.get(session_id).cloned())
    }

    /// 获取会话历史记录
    pub fn get_session_history(&self, days: Option<u32>) -> Vec<SessionRecord> {
        let days = days.unwrap_or(self.history_retention_days);
        let cutoff = Utc::now() - Duration::days(days as i64);
        
        self.session_history.read()
            .map(|history| {
                history.iter()
                    .filter(|record| record.end_time > cutoff)
                    .cloned()
                    .collect()
            })
            .unwrap_or_default()
    }

    /// 获取会话统计
    pub fn get_session_stats(&self, session_id: &str) -> Option<SessionStats> {
        self.active_sessions.read()
            .ok()
            .and_then(|sessions| sessions.get(session_id).map(|s| s.stats.clone()))
    }

    /// 请求权限
    pub async fn request_permission(&self, remote_id: String, permissions: Vec<Permission>) -> Result<String> {
        let request = PermissionRequest::new(
            self.local_device_id.clone(),
            remote_id,
            permissions.clone(),
        );
        
        let request_id = request.request_id.clone();
        
        if let Ok(mut requests) = self.pending_requests.write() {
            requests.insert(request_id.clone(), request);
        }

        self.emit_event(SessionEvent::PermissionRequested {
            request_id: request_id.clone(),
            permissions,
        });

        tracing::info!("Created permission request: {}", request_id);
        Ok(request_id)
    }

    /// 授予或拒绝权限
    pub fn grant_permission(&self, request_id: &str, grant: bool) -> Result<()> {
        let mut requests = self.pending_requests.write()
            .map_err(|_| anyhow::anyhow!("Failed to acquire lock"))?;
        
        if let Some(request) = requests.remove(request_id) {
            if request.is_expired() {
                return Err(anyhow::anyhow!("Permission request expired: {}", request_id));
            }

            if grant {
                self.emit_event(SessionEvent::PermissionGranted {
                    request_id: request_id.to_string(),
                });
                tracing::info!("Permission request {} granted", request_id);
            } else {
                self.emit_event(SessionEvent::PermissionDenied {
                    request_id: request_id.to_string(),
                });
                tracing::info!("Permission request {} denied", request_id);
            }
            
            Ok(())
        } else {
            Err(anyhow::anyhow!("Permission request not found: {}", request_id))
        }
    }

    /// 获取待处理的权限请求
    pub fn get_pending_requests(&self) -> Vec<PermissionRequest> {
        self.pending_requests.read()
            .map(|requests| {
                requests.values()
                    .filter(|r| !r.is_expired())
                    .cloned()
                    .collect()
            })
            .unwrap_or_default()
    }

    /// 清理过期的权限请求
    pub fn cleanup_expired_requests(&self) {
        if let Ok(mut requests) = self.pending_requests.write() {
            requests.retain(|_, request| !request.is_expired());
        }
    }

    /// 获取会话摘要统计
    pub fn get_summary_stats(&self) -> SessionSummaryStats {
        let history = self.session_history.read()
            .map(|h| h.clone())
            .unwrap_or_default();
        
        let active_count = self.active_sessions.read()
            .map(|s| s.len())
            .unwrap_or(0);
        
        let total_sessions = history.len();
        let total_duration: u64 = history.iter().map(|r| r.duration_secs).sum();
        let avg_duration = if total_sessions > 0 {
            total_duration / total_sessions as u64
        } else {
            0
        };
        
        SessionSummaryStats {
            active_sessions: active_count,
            total_sessions_30_days: total_sessions,
            total_duration_secs: total_duration,
            average_duration_secs: avg_duration,
        }
    }
}

/// 会话摘要统计
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionSummaryStats {
    pub active_sessions: usize,
    pub total_sessions_30_days: usize,
    pub total_duration_secs: u64,
    pub average_duration_secs: u64,
}

impl Default for SessionManager {
    fn default() -> Self {
        Self::new("default_device".to_string())
    }
}