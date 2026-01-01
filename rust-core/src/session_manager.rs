use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Session {
    pub session_id: String,
    pub controller_id: String,
    pub controlled_id: String,
    pub start_time: String,
    pub end_time: Option<String>,
    pub status: SessionStatus,
    pub permissions: Vec<Permission>,
    pub stats: SessionStats,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum SessionStatus {
    Pending,
    Active,
    Paused,
    Ended,
    Failed,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Permission {
    ScreenView,
    InputControl,
    FileTransfer,
    AudioCapture,
    SystemControl,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionStats {
    pub duration: u64, // seconds
    pub bytes_transferred: u64,
    pub average_latency: u32, // milliseconds
    pub packet_loss: f32, // percentage
    pub connection_quality: ConnectionQuality,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ConnectionQuality {
    Excellent,
    Good,
    Fair,
    Poor,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionOptions {
    pub permissions: Vec<Permission>,
    pub auto_accept: bool,
    pub session_timeout: u64, // seconds
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionRecord {
    pub session_id: String,
    pub controller_id: String,
    pub controlled_id: String,
    pub start_time: String,
    pub end_time: String,
    pub duration: u64,
    pub end_reason: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PermissionRequest {
    pub request_id: String,
    pub from_device_id: String,
    pub to_device_id: String,
    pub permissions: Vec<Permission>,
    pub message: Option<String>,
}

pub struct SessionManager {
    active_sessions: HashMap<String, Session>,
    session_history: Vec<SessionRecord>,
    pending_requests: HashMap<String, PermissionRequest>,
}

impl SessionManager {
    pub fn new() -> Self {
        Self {
            active_sessions: HashMap::new(),
            session_history: Vec::new(),
            pending_requests: HashMap::new(),
        }
    }

    pub async fn create_session(&mut self, remote_id: String, options: SessionOptions) -> Result<Session> {
        let session_id = Uuid::new_v4().to_string();
        let session = Session {
            session_id: session_id.clone(),
            controller_id: "local_device".to_string(), // Would be actual device ID
            controlled_id: remote_id,
            start_time: chrono::Utc::now().to_rfc3339(),
            end_time: None,
            status: SessionStatus::Pending,
            permissions: options.permissions,
            stats: SessionStats {
                duration: 0,
                bytes_transferred: 0,
                average_latency: 0,
                packet_loss: 0.0,
                connection_quality: ConnectionQuality::Good,
            },
        };

        self.active_sessions.insert(session_id.clone(), session.clone());
        tracing::info!("Created session: {}", session_id);
        Ok(session)
    }

    pub async fn join_session(&mut self, session_id: String) -> Result<Session> {
        if let Some(session) = self.active_sessions.get_mut(&session_id) {
            session.status = SessionStatus::Active;
            tracing::info!("Joined session: {}", session_id);
            Ok(session.clone())
        } else {
            Err(anyhow::anyhow!("Session not found: {}", session_id))
        }
    }

    pub fn end_session(&mut self, session_id: &str) -> Result<()> {
        if let Some(mut session) = self.active_sessions.remove(session_id) {
            session.status = SessionStatus::Ended;
            session.end_time = Some(chrono::Utc::now().to_rfc3339());

            let record = SessionRecord {
                session_id: session.session_id.clone(),
                controller_id: session.controller_id.clone(),
                controlled_id: session.controlled_id.clone(),
                start_time: session.start_time.clone(),
                end_time: session.end_time.clone().unwrap_or_default(),
                duration: session.stats.duration,
                end_reason: "User requested".to_string(),
            };

            self.session_history.push(record);
            tracing::info!("Ended session: {}", session_id);
            Ok(())
        } else {
            Err(anyhow::anyhow!("Session not found: {}", session_id))
        }
    }

    pub fn get_active_sessions(&self) -> Vec<&Session> {
        self.active_sessions.values().collect()
    }

    pub fn get_session_history(&self, days: u32) -> Vec<&SessionRecord> {
        // Placeholder - would filter by date
        self.session_history.iter().collect()
    }

    pub fn get_session_stats(&self, session_id: &str) -> Option<&SessionStats> {
        self.active_sessions.get(session_id).map(|s| &s.stats)
    }

    pub async fn request_permission(&mut self, remote_id: String, permissions: Vec<Permission>) -> Result<String> {
        let request_id = Uuid::new_v4().to_string();
        let request = PermissionRequest {
            request_id: request_id.clone(),
            from_device_id: "local_device".to_string(),
            to_device_id: remote_id,
            permissions,
            message: None,
        };

        self.pending_requests.insert(request_id.clone(), request);
        tracing::info!("Created permission request: {}", request_id);
        Ok(request_id)
    }

    pub fn grant_permission(&mut self, request_id: &str, grant: bool) -> Result<()> {
        if let Some(request) = self.pending_requests.remove(request_id) {
            tracing::info!("Permission request {} {}", request_id, 
                if grant { "granted" } else { "denied" });
            Ok(())
        } else {
            Err(anyhow::anyhow!("Permission request not found: {}", request_id))
        }
    }
}