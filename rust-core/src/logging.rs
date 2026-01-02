use anyhow::Result;
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::VecDeque;
use std::fs::{File, OpenOptions};
use std::io::{BufWriter, Write};
use std::path::PathBuf;
use std::sync::{Arc, RwLock};

/// 日志级别
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord)]
pub enum LogLevel {
    Debug = 0,
    Info = 1,
    Warn = 2,
    Error = 3,
}

impl std::fmt::Display for LogLevel {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            LogLevel::Debug => write!(f, "DEBUG"),
            LogLevel::Info => write!(f, "INFO"),
            LogLevel::Warn => write!(f, "WARN"),
            LogLevel::Error => write!(f, "ERROR"),
        }
    }
}

impl From<&str> for LogLevel {
    fn from(s: &str) -> Self {
        match s.to_uppercase().as_str() {
            "DEBUG" => LogLevel::Debug,
            "INFO" => LogLevel::Info,
            "WARN" => LogLevel::Warn,
            "ERROR" => LogLevel::Error,
            _ => LogLevel::Info,
        }
    }
}

/// 日志条目
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LogEntry {
    pub timestamp: DateTime<Utc>,
    pub level: LogLevel,
    pub category: String,
    pub message: String,
    pub metadata: Option<serde_json::Value>,
    pub session_id: Option<String>,
    pub device_id: Option<String>,
}

impl LogEntry {
    pub fn new(level: LogLevel, category: &str, message: &str) -> Self {
        Self {
            timestamp: Utc::now(),
            level,
            category: category.to_string(),
            message: message.to_string(),
            metadata: None,
            session_id: None,
            device_id: None,
        }
    }

    pub fn with_metadata(mut self, metadata: serde_json::Value) -> Self {
        self.metadata = Some(metadata);
        self
    }

    pub fn with_session(mut self, session_id: &str) -> Self {
        self.session_id = Some(session_id.to_string());
        self
    }

    pub fn with_device(mut self, device_id: &str) -> Self {
        self.device_id = Some(device_id.to_string());
        self
    }

    pub fn format(&self) -> String {
        let mut line = format!(
            "[{}] [{}] [{}] {}",
            self.timestamp.format("%Y-%m-%d %H:%M:%S%.3f"),
            self.level,
            self.category,
            self.message
        );

        if let Some(session_id) = &self.session_id {
            line.push_str(&format!(" [session:{}]", session_id));
        }

        if let Some(device_id) = &self.device_id {
            line.push_str(&format!(" [device:{}]", device_id));
        }

        if let Some(metadata) = &self.metadata {
            line.push_str(&format!(" {}", metadata));
        }

        line
    }
}

/// 连接事件类型
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ConnectionEventType {
    ConnectionAttempt,
    ConnectionEstablished,
    ConnectionFailed,
    ConnectionClosed,
    ReconnectAttempt,
    IceCandidateGathered,
    IceCandidateReceived,
    SignalingConnected,
    SignalingDisconnected,
    MediaStreamAdded,
    MediaStreamRemoved,
    DataChannelOpened,
    DataChannelClosed,
    QualityChanged,
}

impl std::fmt::Display for ConnectionEventType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ConnectionEventType::ConnectionAttempt => write!(f, "连接尝试"),
            ConnectionEventType::ConnectionEstablished => write!(f, "连接建立"),
            ConnectionEventType::ConnectionFailed => write!(f, "连接失败"),
            ConnectionEventType::ConnectionClosed => write!(f, "连接关闭"),
            ConnectionEventType::ReconnectAttempt => write!(f, "重连尝试"),
            ConnectionEventType::IceCandidateGathered => write!(f, "ICE候选收集"),
            ConnectionEventType::IceCandidateReceived => write!(f, "ICE候选接收"),
            ConnectionEventType::SignalingConnected => write!(f, "信令连接"),
            ConnectionEventType::SignalingDisconnected => write!(f, "信令断开"),
            ConnectionEventType::MediaStreamAdded => write!(f, "媒体流添加"),
            ConnectionEventType::MediaStreamRemoved => write!(f, "媒体流移除"),
            ConnectionEventType::DataChannelOpened => write!(f, "数据通道打开"),
            ConnectionEventType::DataChannelClosed => write!(f, "数据通道关闭"),
            ConnectionEventType::QualityChanged => write!(f, "质量变化"),
        }
    }
}

/// 连接事件
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConnectionEvent {
    pub timestamp: DateTime<Utc>,
    pub event_type: ConnectionEventType,
    pub session_id: Option<String>,
    pub remote_device_id: Option<String>,
    pub details: Option<serde_json::Value>,
    pub success: bool,
    pub error_message: Option<String>,
}

impl ConnectionEvent {
    pub fn new(event_type: ConnectionEventType) -> Self {
        Self {
            timestamp: Utc::now(),
            event_type,
            session_id: None,
            remote_device_id: None,
            details: None,
            success: true,
            error_message: None,
        }
    }

    pub fn with_session(mut self, session_id: &str) -> Self {
        self.session_id = Some(session_id.to_string());
        self
    }

    pub fn with_remote_device(mut self, device_id: &str) -> Self {
        self.remote_device_id = Some(device_id.to_string());
        self
    }

    pub fn with_details(mut self, details: serde_json::Value) -> Self {
        self.details = Some(details);
        self
    }

    pub fn with_error(mut self, error: &str) -> Self {
        self.success = false;
        self.error_message = Some(error.to_string());
        self
    }
}


/// 日志配置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LogConfig {
    pub min_level: LogLevel,
    pub max_entries: usize,
    pub log_to_file: bool,
    pub log_file_path: Option<PathBuf>,
    pub max_file_size_mb: u64,
    pub rotate_logs: bool,
    pub max_log_files: u32,
}

impl Default for LogConfig {
    fn default() -> Self {
        Self {
            min_level: LogLevel::Info,
            max_entries: 1000,
            log_to_file: false,
            log_file_path: None,
            max_file_size_mb: 10,
            rotate_logs: true,
            max_log_files: 5,
        }
    }
}

/// 日志管理器
pub struct LogManager {
    config: Arc<RwLock<LogConfig>>,
    logs: Arc<RwLock<VecDeque<LogEntry>>>,
    connection_events: Arc<RwLock<VecDeque<ConnectionEvent>>>,
    file_writer: Arc<RwLock<Option<BufWriter<File>>>>,
}

impl LogManager {
    /// 创建新的日志管理器
    pub fn new(config: LogConfig) -> Self {
        let file_writer = if config.log_to_file {
            config.log_file_path.as_ref().and_then(|path| {
                OpenOptions::new()
                    .create(true)
                    .append(true)
                    .open(path)
                    .ok()
                    .map(|f| BufWriter::new(f))
            })
        } else {
            None
        };

        Self {
            config: Arc::new(RwLock::new(config)),
            logs: Arc::new(RwLock::new(VecDeque::new())),
            connection_events: Arc::new(RwLock::new(VecDeque::new())),
            file_writer: Arc::new(RwLock::new(file_writer)),
        }
    }

    /// 记录日志
    pub fn log(&self, entry: LogEntry) {
        let config = self.config.read().unwrap();
        
        // 检查日志级别
        if entry.level < config.min_level {
            return;
        }

        // 写入文件
        if config.log_to_file {
            if let Ok(mut writer) = self.file_writer.write() {
                if let Some(ref mut w) = *writer {
                    let _ = writeln!(w, "{}", entry.format());
                    let _ = w.flush();
                }
            }
        }

        // 添加到内存日志
        if let Ok(mut logs) = self.logs.write() {
            logs.push_front(entry.clone());
            while logs.len() > config.max_entries {
                logs.pop_back();
            }
        }

        // 同时使用 tracing 输出
        match entry.level {
            LogLevel::Debug => tracing::debug!("[{}] {}", entry.category, entry.message),
            LogLevel::Info => tracing::info!("[{}] {}", entry.category, entry.message),
            LogLevel::Warn => tracing::warn!("[{}] {}", entry.category, entry.message),
            LogLevel::Error => tracing::error!("[{}] {}", entry.category, entry.message),
        }
    }

    /// 便捷日志方法
    pub fn debug(&self, category: &str, message: &str) {
        self.log(LogEntry::new(LogLevel::Debug, category, message));
    }

    pub fn info(&self, category: &str, message: &str) {
        self.log(LogEntry::new(LogLevel::Info, category, message));
    }

    pub fn warn(&self, category: &str, message: &str) {
        self.log(LogEntry::new(LogLevel::Warn, category, message));
    }

    pub fn error(&self, category: &str, message: &str) {
        self.log(LogEntry::new(LogLevel::Error, category, message));
    }

    /// 记录连接事件
    pub fn log_connection_event(&self, event: ConnectionEvent) {
        // 同时记录为普通日志
        let level = if event.success { LogLevel::Info } else { LogLevel::Error };
        let message = if let Some(ref err) = event.error_message {
            format!("{}: {}", event.event_type, err)
        } else {
            format!("{}", event.event_type)
        };

        let mut entry = LogEntry::new(level, "Connection", &message);
        if let Some(ref session_id) = event.session_id {
            entry = entry.with_session(session_id);
        }
        if let Some(ref device_id) = event.remote_device_id {
            entry = entry.with_device(device_id);
        }
        if let Some(ref details) = event.details {
            entry = entry.with_metadata(details.clone());
        }
        self.log(entry);

        // 添加到连接事件列表
        if let Ok(mut events) = self.connection_events.write() {
            events.push_front(event);
            while events.len() > 100 {
                events.pop_back();
            }
        }
    }

    /// 获取日志
    pub fn get_logs(&self, level: Option<LogLevel>, limit: Option<usize>) -> Vec<LogEntry> {
        let logs = self.logs.read().unwrap();
        let limit = limit.unwrap_or(logs.len());
        
        logs.iter()
            .filter(|log| level.map_or(true, |l| log.level >= l))
            .take(limit)
            .cloned()
            .collect()
    }

    /// 获取连接事件
    pub fn get_connection_events(&self, limit: Option<usize>) -> Vec<ConnectionEvent> {
        let events = self.connection_events.read().unwrap();
        let limit = limit.unwrap_or(events.len());
        
        events.iter()
            .take(limit)
            .cloned()
            .collect()
    }

    /// 清除日志
    pub fn clear_logs(&self) {
        if let Ok(mut logs) = self.logs.write() {
            logs.clear();
        }
    }

    /// 清除连接事件
    pub fn clear_connection_events(&self) {
        if let Ok(mut events) = self.connection_events.write() {
            events.clear();
        }
    }

    /// 设置日志级别
    pub fn set_log_level(&self, level: LogLevel) {
        if let Ok(mut config) = self.config.write() {
            config.min_level = level;
        }
    }

    /// 获取当前日志级别
    pub fn get_log_level(&self) -> LogLevel {
        self.config.read().unwrap().min_level
    }

    /// 导出日志
    pub fn export_logs(&self) -> String {
        let logs = self.logs.read().unwrap();
        let mut buffer = String::new();
        
        buffer.push_str("=== 远程桌面客户端日志导出 ===\n");
        buffer.push_str(&format!("导出时间: {}\n", Utc::now().format("%Y-%m-%d %H:%M:%S")));
        buffer.push_str(&format!("日志条目数: {}\n\n", logs.len()));

        for log in logs.iter().rev() {
            buffer.push_str(&log.format());
            buffer.push('\n');
        }

        buffer
    }

    /// 导出连接事件
    pub fn export_connection_events(&self) -> String {
        let events = self.connection_events.read().unwrap();
        let mut buffer = String::new();
        
        buffer.push_str("=== 连接事件导出 ===\n");
        buffer.push_str(&format!("导出时间: {}\n", Utc::now().format("%Y-%m-%d %H:%M:%S")));
        buffer.push_str(&format!("事件数: {}\n\n", events.len()));

        for event in events.iter().rev() {
            buffer.push_str(&format!(
                "[{}] {} - {}\n",
                event.timestamp.format("%Y-%m-%d %H:%M:%S"),
                event.event_type,
                if event.success { "成功" } else { "失败" }
            ));
            if let Some(ref session_id) = event.session_id {
                buffer.push_str(&format!("  会话: {}\n", session_id));
            }
            if let Some(ref device_id) = event.remote_device_id {
                buffer.push_str(&format!("  设备: {}\n", device_id));
            }
            if let Some(ref err) = event.error_message {
                buffer.push_str(&format!("  错误: {}\n", err));
            }
            if let Some(ref details) = event.details {
                buffer.push_str(&format!("  详情: {}\n", details));
            }
        }

        buffer
    }

    /// 启用文件日志
    pub fn enable_file_logging(&self, path: PathBuf) -> Result<()> {
        let file = OpenOptions::new()
            .create(true)
            .append(true)
            .open(&path)?;
        
        if let Ok(mut writer) = self.file_writer.write() {
            *writer = Some(BufWriter::new(file));
        }

        if let Ok(mut config) = self.config.write() {
            config.log_to_file = true;
            config.log_file_path = Some(path);
        }

        Ok(())
    }

    /// 禁用文件日志
    pub fn disable_file_logging(&self) {
        if let Ok(mut writer) = self.file_writer.write() {
            *writer = None;
        }

        if let Ok(mut config) = self.config.write() {
            config.log_to_file = false;
        }
    }
}

impl Default for LogManager {
    fn default() -> Self {
        Self::new(LogConfig::default())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_log_entry_creation() {
        let entry = LogEntry::new(LogLevel::Info, "Test", "Test message");
        assert_eq!(entry.level, LogLevel::Info);
        assert_eq!(entry.category, "Test");
        assert_eq!(entry.message, "Test message");
    }

    #[test]
    fn test_log_manager_basic() {
        let manager = LogManager::default();
        
        manager.info("Test", "Info message");
        manager.warn("Test", "Warn message");
        manager.error("Test", "Error message");
        
        let logs = manager.get_logs(None, None);
        assert_eq!(logs.len(), 3);
    }

    #[test]
    fn test_log_level_filtering() {
        let config = LogConfig {
            min_level: LogLevel::Warn,
            ..Default::default()
        };
        let manager = LogManager::new(config);
        
        manager.debug("Test", "Debug message");
        manager.info("Test", "Info message");
        manager.warn("Test", "Warn message");
        manager.error("Test", "Error message");
        
        let logs = manager.get_logs(None, None);
        assert_eq!(logs.len(), 2); // Only warn and error
    }

    #[test]
    fn test_connection_event_logging() {
        let manager = LogManager::default();
        
        let event = ConnectionEvent::new(ConnectionEventType::ConnectionEstablished)
            .with_session("session-123")
            .with_remote_device("device-456");
        
        manager.log_connection_event(event);
        
        let events = manager.get_connection_events(None);
        assert_eq!(events.len(), 1);
        assert_eq!(events[0].session_id, Some("session-123".to_string()));
    }

    #[test]
    fn test_log_export() {
        let manager = LogManager::default();
        
        manager.info("Test", "Test message 1");
        manager.warn("Test", "Test message 2");
        
        let export = manager.export_logs();
        assert!(export.contains("Test message 1"));
        assert!(export.contains("Test message 2"));
    }
}
