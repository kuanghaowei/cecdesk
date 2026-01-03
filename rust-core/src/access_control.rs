//! Device Authentication and Access Control
//!
//! Implements device ID generation, temporary access codes, and permission management.
//! Requirements: 5.1, 5.2, 5.4, 5.5, 5.7

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::sync::RwLock;
use uuid::Uuid;

/// Access code expiration time in seconds (10 minutes as per requirement 5.7)
pub const ACCESS_CODE_EXPIRATION_SECS: u64 = 600;

/// Permission types for remote control
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum Permission {
    /// View remote screen
    ViewScreen,
    /// Control mouse and keyboard
    InputControl,
    /// Transfer files
    FileTransfer,
    /// Access clipboard
    Clipboard,
    /// Capture audio
    AudioCapture,
    /// Full control (all permissions)
    FullControl,
}

impl Permission {
    /// Get all permissions included in FullControl
    pub fn expand_full_control() -> Vec<Permission> {
        vec![
            Permission::ViewScreen,
            Permission::InputControl,
            Permission::FileTransfer,
            Permission::Clipboard,
            Permission::AudioCapture,
        ]
    }
}

/// Authorization type for device access
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum AuthorizationType {
    /// Temporary access via access code
    AccessCode,
    /// Persistent authorization via account binding
    AccountBinding,
    /// Pre-authorized unattended access
    UnattendedAccess,
}

/// Access code for temporary authorization
#[derive(Debug, Clone)]
pub struct AccessCode {
    /// The access code string
    pub code: String,
    /// Device ID that generated this code
    pub device_id: String,
    /// When the code was created
    pub created_at: Instant,
    /// Expiration duration
    pub expires_in: Duration,
    /// Permissions granted by this code
    pub permissions: Vec<Permission>,
    /// Whether the code has been used
    pub used: bool,
}

impl AccessCode {
    /// Check if the access code has expired
    pub fn is_expired(&self) -> bool {
        self.created_at.elapsed() > self.expires_in
    }

    /// Check if the access code is valid (not expired and not used)
    pub fn is_valid(&self) -> bool {
        !self.is_expired() && !self.used
    }

    /// Get remaining time in seconds
    pub fn remaining_seconds(&self) -> u64 {
        let elapsed = self.created_at.elapsed();
        if elapsed >= self.expires_in {
            0
        } else {
            (self.expires_in - elapsed).as_secs()
        }
    }
}

/// Device authorization record
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeviceAuthorization {
    /// Authorized device ID
    pub device_id: String,
    /// Device name for display
    pub device_name: String,
    /// Type of authorization
    pub auth_type: AuthorizationType,
    /// Granted permissions
    pub permissions: Vec<Permission>,
    /// When authorization was granted
    pub authorized_at: String,
    /// When authorization expires (None for permanent)
    pub expires_at: Option<String>,
    /// Whether this is an active authorization
    pub active: bool,
}

/// Connection request from a remote device
#[derive(Debug, Clone)]
pub struct ConnectionRequest {
    /// Request ID
    pub request_id: String,
    /// Requesting device ID
    pub from_device_id: String,
    /// Requesting device name
    pub from_device_name: String,
    /// Requested permissions
    pub requested_permissions: Vec<Permission>,
    /// Access code if provided
    pub access_code: Option<String>,
    /// When the request was made
    pub requested_at: Instant,
}

/// Connection request response
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConnectionResponse {
    /// Request ID being responded to
    pub request_id: String,
    /// Whether the request was accepted
    pub accepted: bool,
    /// Granted permissions (may be subset of requested)
    pub granted_permissions: Vec<Permission>,
    /// Reason for rejection if not accepted
    pub rejection_reason: Option<String>,
}

/// Device registration info
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeviceRegistration {
    /// Unique device ID
    pub device_id: String,
    /// Human-readable device name
    pub device_name: String,
    /// Platform (windows, macos, linux, etc.)
    pub platform: String,
    /// Application version
    pub version: String,
    /// When the device was first registered
    pub registered_at: String,
    /// Last seen timestamp
    pub last_seen: String,
    /// Whether unattended access is enabled
    pub unattended_access_enabled: bool,
    /// Unattended access password hash (if enabled)
    pub unattended_password_hash: Option<String>,
}

/// Access control manager
pub struct AccessControlManager {
    /// Current device ID
    device_id: Arc<RwLock<Option<String>>>,
    /// Generated access codes
    access_codes: Arc<RwLock<HashMap<String, AccessCode>>>,
    /// Authorized devices
    authorized_devices: Arc<RwLock<HashMap<String, DeviceAuthorization>>>,
    /// Pending connection requests
    pending_requests: Arc<RwLock<HashMap<String, ConnectionRequest>>>,
    /// Device registration info
    device_registration: Arc<RwLock<Option<DeviceRegistration>>>,
}

impl AccessControlManager {
    /// Create a new access control manager
    pub fn new() -> Self {
        Self {
            device_id: Arc::new(RwLock::new(None)),
            access_codes: Arc::new(RwLock::new(HashMap::new())),
            authorized_devices: Arc::new(RwLock::new(HashMap::new())),
            pending_requests: Arc::new(RwLock::new(HashMap::new())),
            device_registration: Arc::new(RwLock::new(None)),
        }
    }

    /// Generate a unique device ID
    /// Requirement 5.1: Generate unique Device_ID for each device
    pub fn generate_device_id() -> String {
        Uuid::new_v4().to_string()
    }

    /// Register this device and generate a device ID
    /// Requirement 5.1: Generate unique Device_ID for first-time registration
    pub async fn register_device(
        &self,
        device_name: String,
        platform: String,
        version: String,
    ) -> Result<String> {
        let device_id = Self::generate_device_id();
        let now = chrono::Utc::now().to_rfc3339();

        let registration = DeviceRegistration {
            device_id: device_id.clone(),
            device_name,
            platform,
            version,
            registered_at: now.clone(),
            last_seen: now,
            unattended_access_enabled: false,
            unattended_password_hash: None,
        };

        {
            let mut reg = self.device_registration.write().await;
            *reg = Some(registration);
        }

        {
            let mut did = self.device_id.write().await;
            *did = Some(device_id.clone());
        }

        tracing::info!("Device registered with ID: {}", device_id);
        Ok(device_id)
    }

    /// Get the current device ID
    pub async fn get_device_id(&self) -> Option<String> {
        self.device_id.read().await.clone()
    }

    /// Generate a temporary access code
    /// Requirement 5.2: Support Access_Code based temporary access authorization
    pub async fn generate_access_code(&self, permissions: Vec<Permission>) -> Result<AccessCode> {
        let device_id = self
            .device_id
            .read()
            .await
            .clone()
            .ok_or_else(|| anyhow::anyhow!("Device not registered"))?;

        // Generate a 6-digit numeric code for easy sharing
        let code = format!("{:06}", rand_code());

        let access_code = AccessCode {
            code: code.clone(),
            device_id,
            created_at: Instant::now(),
            expires_in: Duration::from_secs(ACCESS_CODE_EXPIRATION_SECS),
            permissions,
            used: false,
        };

        {
            let mut codes = self.access_codes.write().await;
            codes.insert(code.clone(), access_code.clone());
        }

        tracing::info!(
            "Generated access code: {} (expires in {} seconds)",
            code,
            ACCESS_CODE_EXPIRATION_SECS
        );
        Ok(access_code)
    }

    /// Validate an access code
    /// Requirement 5.7: Access code expires after 10 minutes
    pub async fn validate_access_code(&self, code: &str) -> Result<Option<AccessCode>> {
        let codes = self.access_codes.read().await;

        if let Some(access_code) = codes.get(code) {
            if access_code.is_valid() {
                Ok(Some(access_code.clone()))
            } else if access_code.is_expired() {
                tracing::warn!("Access code {} has expired", code);
                Ok(None)
            } else {
                tracing::warn!("Access code {} has already been used", code);
                Ok(None)
            }
        } else {
            tracing::warn!("Access code {} not found", code);
            Ok(None)
        }
    }

    /// Use an access code (marks it as used)
    pub async fn use_access_code(&self, code: &str) -> Result<Option<Vec<Permission>>> {
        let mut codes = self.access_codes.write().await;

        if let Some(access_code) = codes.get_mut(code) {
            if access_code.is_valid() {
                access_code.used = true;
                let permissions = access_code.permissions.clone();
                tracing::info!("Access code {} used successfully", code);
                Ok(Some(permissions))
            } else {
                Ok(None)
            }
        } else {
            Ok(None)
        }
    }

    /// Clean up expired access codes
    pub async fn cleanup_expired_codes(&self) {
        let mut codes = self.access_codes.write().await;
        let before_count = codes.len();
        codes.retain(|_, code| !code.is_expired());
        let removed = before_count - codes.len();
        if removed > 0 {
            tracing::debug!("Cleaned up {} expired access codes", removed);
        }
    }

    /// Handle incoming connection request
    /// Requirement 5.4: Display connection request notification to user
    pub async fn handle_connection_request(
        &self,
        from_device_id: String,
        from_device_name: String,
        requested_permissions: Vec<Permission>,
        access_code: Option<String>,
    ) -> Result<ConnectionRequest> {
        let request_id = Uuid::new_v4().to_string();

        let request = ConnectionRequest {
            request_id: request_id.clone(),
            from_device_id,
            from_device_name,
            requested_permissions,
            access_code,
            requested_at: Instant::now(),
        };

        {
            let mut requests = self.pending_requests.write().await;
            requests.insert(request_id.clone(), request.clone());
        }

        tracing::info!("Connection request received: {}", request_id);
        Ok(request)
    }

    /// Respond to a connection request
    /// Requirement 5.5: Allow user to accept or reject connection request
    pub async fn respond_to_request(
        &self,
        request_id: &str,
        accepted: bool,
        granted_permissions: Option<Vec<Permission>>,
        rejection_reason: Option<String>,
    ) -> Result<ConnectionResponse> {
        let mut requests = self.pending_requests.write().await;

        let request = requests
            .remove(request_id)
            .ok_or_else(|| anyhow::anyhow!("Request not found: {}", request_id))?;

        let response = if accepted {
            let permissions =
                granted_permissions.unwrap_or_else(|| request.requested_permissions.clone());

            // Add to authorized devices
            let auth = DeviceAuthorization {
                device_id: request.from_device_id.clone(),
                device_name: request.from_device_name.clone(),
                auth_type: AuthorizationType::AccessCode,
                permissions: permissions.clone(),
                authorized_at: chrono::Utc::now().to_rfc3339(),
                expires_at: None,
                active: true,
            };

            {
                let mut authorized = self.authorized_devices.write().await;
                authorized.insert(request.from_device_id.clone(), auth);
            }

            ConnectionResponse {
                request_id: request_id.to_string(),
                accepted: true,
                granted_permissions: permissions,
                rejection_reason: None,
            }
        } else {
            ConnectionResponse {
                request_id: request_id.to_string(),
                accepted: false,
                granted_permissions: vec![],
                rejection_reason,
            }
        };

        tracing::info!(
            "Connection request {} {}",
            request_id,
            if accepted { "accepted" } else { "rejected" }
        );
        Ok(response)
    }

    /// Check if a device is authorized
    pub async fn is_device_authorized(&self, device_id: &str) -> bool {
        let authorized = self.authorized_devices.read().await;
        authorized
            .get(device_id)
            .map(|auth| auth.active)
            .unwrap_or(false)
    }

    /// Get permissions for an authorized device
    pub async fn get_device_permissions(&self, device_id: &str) -> Option<Vec<Permission>> {
        let authorized = self.authorized_devices.read().await;
        authorized
            .get(device_id)
            .filter(|auth| auth.active)
            .map(|auth| auth.permissions.clone())
    }

    /// Revoke device authorization
    pub async fn revoke_authorization(&self, device_id: &str) -> Result<()> {
        let mut authorized = self.authorized_devices.write().await;

        if let Some(auth) = authorized.get_mut(device_id) {
            auth.active = false;
            tracing::info!("Authorization revoked for device: {}", device_id);
            Ok(())
        } else {
            Err(anyhow::anyhow!("Device not found: {}", device_id))
        }
    }

    /// Enable unattended access
    /// Requirement 5.6: Support unattended access mode with pre-authorization
    pub async fn enable_unattended_access(&self, password: &str) -> Result<()> {
        let mut reg = self.device_registration.write().await;

        if let Some(registration) = reg.as_mut() {
            // In production, use proper password hashing (bcrypt, argon2, etc.)
            let hash = simple_hash(password);
            registration.unattended_access_enabled = true;
            registration.unattended_password_hash = Some(hash);
            tracing::info!("Unattended access enabled");
            Ok(())
        } else {
            Err(anyhow::anyhow!("Device not registered"))
        }
    }

    /// Disable unattended access
    pub async fn disable_unattended_access(&self) -> Result<()> {
        let mut reg = self.device_registration.write().await;

        if let Some(registration) = reg.as_mut() {
            registration.unattended_access_enabled = false;
            registration.unattended_password_hash = None;
            tracing::info!("Unattended access disabled");
            Ok(())
        } else {
            Err(anyhow::anyhow!("Device not registered"))
        }
    }

    /// Validate unattended access password
    pub async fn validate_unattended_password(&self, password: &str) -> bool {
        let reg = self.device_registration.read().await;

        if let Some(registration) = reg.as_ref() {
            if registration.unattended_access_enabled {
                if let Some(hash) = &registration.unattended_password_hash {
                    return simple_hash(password) == *hash;
                }
            }
        }
        false
    }

    /// Get list of authorized devices
    pub async fn get_authorized_devices(&self) -> Vec<DeviceAuthorization> {
        let authorized = self.authorized_devices.read().await;
        authorized.values().cloned().collect()
    }

    /// Get pending connection requests
    pub async fn get_pending_requests(&self) -> Vec<ConnectionRequest> {
        let requests = self.pending_requests.read().await;
        requests.values().cloned().collect()
    }

    /// Get device registration info
    pub async fn get_device_registration(&self) -> Option<DeviceRegistration> {
        self.device_registration.read().await.clone()
    }
}

impl Default for AccessControlManager {
    fn default() -> Self {
        Self::new()
    }
}

/// Generate a random 6-digit code
fn rand_code() -> u32 {
    use std::time::{SystemTime, UNIX_EPOCH};
    let seed = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos() as u64;
    // Simple PRNG for demo - use proper random in production
    ((seed ^ (seed >> 17)) % 1_000_000) as u32
}

/// Simple hash function for demo - use proper crypto in production
fn simple_hash(input: &str) -> String {
    use std::collections::hash_map::DefaultHasher;
    use std::hash::{Hash, Hasher};
    let mut hasher = DefaultHasher::new();
    input.hash(&mut hasher);
    format!("{:016x}", hasher.finish())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_device_id() {
        let id1 = AccessControlManager::generate_device_id();
        let id2 = AccessControlManager::generate_device_id();
        assert_ne!(id1, id2);
        assert_eq!(id1.len(), 36); // UUID format
    }

    #[test]
    fn test_permission_expand_full_control() {
        let permissions = Permission::expand_full_control();
        assert!(permissions.contains(&Permission::ViewScreen));
        assert!(permissions.contains(&Permission::InputControl));
        assert!(permissions.contains(&Permission::FileTransfer));
        assert!(permissions.contains(&Permission::Clipboard));
        assert!(permissions.contains(&Permission::AudioCapture));
    }

    #[tokio::test]
    async fn test_access_code_expiration() {
        let code = AccessCode {
            code: "123456".to_string(),
            device_id: "test-device".to_string(),
            created_at: Instant::now() - Duration::from_secs(700), // 700 seconds ago
            expires_in: Duration::from_secs(600),                  // 10 minutes
            permissions: vec![Permission::ViewScreen],
            used: false,
        };

        assert!(code.is_expired());
        assert!(!code.is_valid());
    }

    #[tokio::test]
    async fn test_access_code_valid() {
        let code = AccessCode {
            code: "123456".to_string(),
            device_id: "test-device".to_string(),
            created_at: Instant::now(),
            expires_in: Duration::from_secs(600),
            permissions: vec![Permission::ViewScreen],
            used: false,
        };

        assert!(!code.is_expired());
        assert!(code.is_valid());
    }

    #[tokio::test]
    async fn test_access_code_used() {
        let code = AccessCode {
            code: "123456".to_string(),
            device_id: "test-device".to_string(),
            created_at: Instant::now(),
            expires_in: Duration::from_secs(600),
            permissions: vec![Permission::ViewScreen],
            used: true,
        };

        assert!(!code.is_expired());
        assert!(!code.is_valid()); // Used codes are not valid
    }
}
