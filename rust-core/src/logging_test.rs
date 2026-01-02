//! Property-based tests for logging module
//! 
//! Feature: cec-remote, Property 13: Connection Event Logging
//! Validates: Requirements 14.1

use crate::logging::{
    ConnectionEvent, ConnectionEventType, LogConfig, LogEntry, LogLevel, LogManager,
};
use proptest::prelude::*;

/// Generate arbitrary log levels
fn arb_log_level() -> impl Strategy<Value = LogLevel> {
    prop_oneof![
        Just(LogLevel::Debug),
        Just(LogLevel::Info),
        Just(LogLevel::Warn),
        Just(LogLevel::Error),
    ]
}

/// Generate arbitrary connection event types
fn arb_connection_event_type() -> impl Strategy<Value = ConnectionEventType> {
    prop_oneof![
        Just(ConnectionEventType::ConnectionAttempt),
        Just(ConnectionEventType::ConnectionEstablished),
        Just(ConnectionEventType::ConnectionFailed),
        Just(ConnectionEventType::ConnectionClosed),
        Just(ConnectionEventType::ReconnectAttempt),
        Just(ConnectionEventType::IceCandidateGathered),
        Just(ConnectionEventType::IceCandidateReceived),
        Just(ConnectionEventType::SignalingConnected),
        Just(ConnectionEventType::SignalingDisconnected),
        Just(ConnectionEventType::MediaStreamAdded),
        Just(ConnectionEventType::MediaStreamRemoved),
        Just(ConnectionEventType::DataChannelOpened),
        Just(ConnectionEventType::DataChannelClosed),
        Just(ConnectionEventType::QualityChanged),
    ]
}

/// Generate arbitrary session IDs
fn arb_session_id() -> impl Strategy<Value = String> {
    "[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}"
}

/// Generate arbitrary device IDs
fn arb_device_id() -> impl Strategy<Value = String> {
    "[0-9]{9}"
}

/// Generate arbitrary category names
fn arb_category() -> impl Strategy<Value = String> {
    prop_oneof![
        Just("Connection".to_string()),
        Just("Session".to_string()),
        Just("Network".to_string()),
        Just("Security".to_string()),
        Just("Media".to_string()),
    ]
}

/// Generate arbitrary log messages
fn arb_message() -> impl Strategy<Value = String> {
    "[a-zA-Z0-9 ]{1,100}"
}

proptest! {
    /// **Feature: cec-remote, Property 13: Connection Event Logging**
    /// **Validates: Requirements 14.1**
    /// 
    /// For any connection establishment or disconnection event,
    /// the system should record the connection event and related information.
    #[test]
    fn prop_connection_events_are_logged(
        event_type in arb_connection_event_type(),
        session_id in proptest::option::of(arb_session_id()),
        device_id in proptest::option::of(arb_device_id()),
        success in any::<bool>(),
    ) {
        let manager = LogManager::default();
        
        // Create a connection event
        let mut event = ConnectionEvent::new(event_type.clone());
        if let Some(ref sid) = session_id {
            event = event.with_session(sid);
        }
        if let Some(ref did) = device_id {
            event = event.with_remote_device(did);
        }
        if !success {
            event = event.with_error("Test error");
        }
        
        // Log the connection event
        manager.log_connection_event(event.clone());
        
        // Verify the event was recorded
        let events = manager.get_connection_events(None);
        prop_assert!(!events.is_empty(), "Connection event should be recorded");
        
        let recorded_event = &events[0];
        
        // Verify event type matches
        prop_assert_eq!(
            std::mem::discriminant(&recorded_event.event_type),
            std::mem::discriminant(&event_type),
            "Event type should match"
        );
        
        // Verify session ID matches
        prop_assert_eq!(
            &recorded_event.session_id,
            &session_id,
            "Session ID should match"
        );
        
        // Verify device ID matches
        prop_assert_eq!(
            &recorded_event.remote_device_id,
            &device_id,
            "Device ID should match"
        );
        
        // Verify success status matches
        prop_assert_eq!(
            recorded_event.success,
            success,
            "Success status should match"
        );
        
        // Verify the event was also logged as a regular log entry
        let logs = manager.get_logs(None, None);
        prop_assert!(!logs.is_empty(), "Connection event should also create a log entry");
        
        // Verify the log entry contains the event information
        let log_entry = &logs[0];
        prop_assert_eq!(&log_entry.category, "Connection", "Log category should be 'Connection'");
        
        // Verify session ID is in log entry if provided
        if session_id.is_some() {
            prop_assert_eq!(
                &log_entry.session_id,
                &session_id,
                "Log entry should contain session ID"
            );
        }
        
        // Verify device ID is in log entry if provided
        if device_id.is_some() {
            prop_assert_eq!(
                &log_entry.device_id,
                &device_id,
                "Log entry should contain device ID"
            );
        }
    }

    /// Property: Log entries preserve all information
    /// For any log entry, all provided information should be preserved.
    #[test]
    fn prop_log_entries_preserve_information(
        level in arb_log_level(),
        category in arb_category(),
        message in arb_message(),
        session_id in proptest::option::of(arb_session_id()),
        device_id in proptest::option::of(arb_device_id()),
    ) {
        let config = LogConfig {
            min_level: LogLevel::Debug, // Accept all levels
            ..Default::default()
        };
        let manager = LogManager::new(config);
        
        // Create and log an entry
        let mut entry = LogEntry::new(level, &category, &message);
        if let Some(ref sid) = session_id {
            entry = entry.with_session(sid);
        }
        if let Some(ref did) = device_id {
            entry = entry.with_device(did);
        }
        
        manager.log(entry);
        
        // Retrieve and verify
        let logs = manager.get_logs(None, None);
        prop_assert!(!logs.is_empty(), "Log entry should be recorded");
        
        let recorded = &logs[0];
        prop_assert_eq!(recorded.level, level, "Level should be preserved");
        prop_assert_eq!(&recorded.category, &category, "Category should be preserved");
        prop_assert_eq!(&recorded.message, &message, "Message should be preserved");
        prop_assert_eq!(&recorded.session_id, &session_id, "Session ID should be preserved");
        prop_assert_eq!(&recorded.device_id, &device_id, "Device ID should be preserved");
    }

    /// Property: Log level filtering works correctly
    /// For any minimum log level, only logs at or above that level should be returned.
    #[test]
    fn prop_log_level_filtering(
        min_level in arb_log_level(),
        log_level in arb_log_level(),
        message in arb_message(),
    ) {
        let config = LogConfig {
            min_level: LogLevel::Debug, // Accept all for recording
            ..Default::default()
        };
        let manager = LogManager::new(config);
        
        // Log an entry
        let entry = LogEntry::new(log_level, "Test", &message);
        manager.log(entry);
        
        // Get logs filtered by level
        let logs = manager.get_logs(Some(min_level), None);
        
        // If log level is below min level, it should not appear in filtered results
        if log_level < min_level {
            prop_assert!(
                logs.is_empty() || logs.iter().all(|l| l.level >= min_level),
                "Logs below minimum level should be filtered out"
            );
        } else {
            // Log should appear in results
            prop_assert!(
                logs.iter().any(|l| l.message == message),
                "Logs at or above minimum level should be included"
            );
        }
    }

    /// Property: Connection events are ordered by time (most recent first)
    /// For any sequence of connection events, they should be stored in reverse chronological order.
    #[test]
    fn prop_connection_events_ordered_by_time(
        event_types in prop::collection::vec(arb_connection_event_type(), 2..10),
    ) {
        let manager = LogManager::default();
        
        // Log multiple events
        for event_type in &event_types {
            let event = ConnectionEvent::new(event_type.clone());
            manager.log_connection_event(event);
            // Small delay to ensure different timestamps
            std::thread::sleep(std::time::Duration::from_millis(1));
        }
        
        // Get all events
        let events = manager.get_connection_events(None);
        
        // Verify count
        prop_assert_eq!(
            events.len(),
            event_types.len(),
            "All events should be recorded"
        );
        
        // Verify ordering (most recent first)
        for i in 0..events.len() - 1 {
            prop_assert!(
                events[i].timestamp >= events[i + 1].timestamp,
                "Events should be ordered by timestamp (most recent first)"
            );
        }
    }

    /// Property: Log export contains all logged entries
    /// For any set of log entries, the export should contain all of them.
    #[test]
    fn prop_log_export_contains_all_entries(
        messages in prop::collection::vec(arb_message(), 1..20),
    ) {
        let manager = LogManager::default();
        
        // Log multiple entries
        for message in &messages {
            manager.info("Test", message);
        }
        
        // Export logs
        let export = manager.export_logs();
        
        // Verify all messages are in the export
        for message in &messages {
            prop_assert!(
                export.contains(message),
                "Export should contain message: {}", message
            );
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Unit test: Connection established event is logged correctly
    #[test]
    fn test_connection_established_event_logged() {
        let manager = LogManager::default();
        
        let event = ConnectionEvent::new(ConnectionEventType::ConnectionEstablished)
            .with_session("session-123")
            .with_remote_device("device-456");
        
        manager.log_connection_event(event);
        
        let events = manager.get_connection_events(None);
        assert_eq!(events.len(), 1);
        assert!(matches!(events[0].event_type, ConnectionEventType::ConnectionEstablished));
        assert_eq!(events[0].session_id, Some("session-123".to_string()));
        assert_eq!(events[0].remote_device_id, Some("device-456".to_string()));
        assert!(events[0].success);
    }

    /// Unit test: Connection failed event is logged correctly
    #[test]
    fn test_connection_failed_event_logged() {
        let manager = LogManager::default();
        
        let event = ConnectionEvent::new(ConnectionEventType::ConnectionFailed)
            .with_session("session-123")
            .with_error("Connection timeout");
        
        manager.log_connection_event(event);
        
        let events = manager.get_connection_events(None);
        assert_eq!(events.len(), 1);
        assert!(matches!(events[0].event_type, ConnectionEventType::ConnectionFailed));
        assert!(!events[0].success);
        assert_eq!(events[0].error_message, Some("Connection timeout".to_string()));
    }

    /// Unit test: Connection closed event is logged correctly
    #[test]
    fn test_connection_closed_event_logged() {
        let manager = LogManager::default();
        
        let event = ConnectionEvent::new(ConnectionEventType::ConnectionClosed)
            .with_session("session-123")
            .with_remote_device("device-456");
        
        manager.log_connection_event(event);
        
        let events = manager.get_connection_events(None);
        assert_eq!(events.len(), 1);
        assert!(matches!(events[0].event_type, ConnectionEventType::ConnectionClosed));
    }

    /// Unit test: Multiple connection events are recorded
    #[test]
    fn test_multiple_connection_events() {
        let manager = LogManager::default();
        
        manager.log_connection_event(
            ConnectionEvent::new(ConnectionEventType::ConnectionAttempt)
                .with_session("session-1")
        );
        manager.log_connection_event(
            ConnectionEvent::new(ConnectionEventType::ConnectionEstablished)
                .with_session("session-1")
        );
        manager.log_connection_event(
            ConnectionEvent::new(ConnectionEventType::ConnectionClosed)
                .with_session("session-1")
        );
        
        let events = manager.get_connection_events(None);
        assert_eq!(events.len(), 3);
    }

    /// Unit test: Connection events create corresponding log entries
    #[test]
    fn test_connection_events_create_log_entries() {
        let manager = LogManager::default();
        
        let event = ConnectionEvent::new(ConnectionEventType::ConnectionEstablished)
            .with_session("session-123");
        
        manager.log_connection_event(event);
        
        let logs = manager.get_logs(None, None);
        assert!(!logs.is_empty());
        assert_eq!(logs[0].category, "Connection");
        assert_eq!(logs[0].session_id, Some("session-123".to_string()));
    }
}
