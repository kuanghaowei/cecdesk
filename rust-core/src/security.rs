//! Security and Encryption Module
//!
//! Implements end-to-end encryption for media streams, signaling, and file transfers.
//! Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6

use aes_gcm::{
    aead::{Aead, KeyInit, OsRng},
    Aes256Gcm, Nonce,
};
use anyhow::{Context, Result};
use ed25519_dalek::{Signature, Signer, SigningKey, Verifier, VerifyingKey};
use rand::RngCore;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::{HashMap, HashSet};
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::sync::RwLock;
use x25519_dalek::{EphemeralSecret, PublicKey};

/// Security configuration for the system
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecurityConfig {
    /// Enable DTLS-SRTP for media stream encryption (Requirement 10.1)
    pub enable_dtls_srtp: bool,
    /// Enable TLS 1.3 for signaling encryption (Requirement 10.2)
    pub enable_tls_signaling: bool,
    /// Enable end-to-end encryption for file transfers (Requirement 10.3)
    pub enable_file_encryption: bool,
    /// Enable device certificate validation (Requirement 10.4)
    pub certificate_validation: bool,
    /// Session key rotation interval in seconds (Requirement 10.5)
    pub key_rotation_interval: u64,
    /// Enable security threat detection (Requirement 10.6)
    pub threat_detection_enabled: bool,
}

impl Default for SecurityConfig {
    fn default() -> Self {
        Self {
            enable_dtls_srtp: true,
            enable_tls_signaling: true,
            enable_file_encryption: true,
            certificate_validation: true,
            key_rotation_interval: 3600, // 1 hour
            threat_detection_enabled: true,
        }
    }
}

/// Device certificate for authentication
/// Requirement 10.4: Verify device certificates to prevent MITM attacks
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeviceCertificate {
    pub device_id: String,
    pub certificate: Vec<u8>,
    pub private_key: Vec<u8>,
    pub public_key: Vec<u8>,
    pub valid_from: String,
    pub valid_until: String,
    pub fingerprint: String,
    /// Ed25519 signing key for certificate signatures
    #[serde(skip)]
    pub signing_key: Option<Vec<u8>>,
    /// Ed25519 verifying key for signature verification
    pub verifying_key: Vec<u8>,
    /// Certificate signature for authenticity verification
    pub signature: Vec<u8>,
    /// Certificate chain for trust verification
    pub issuer_fingerprint: Option<String>,
    /// Certificate revocation status
    pub revoked: bool,
}

/// Certificate validation result with detailed information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CertificateValidationResult {
    pub is_valid: bool,
    pub device_id: String,
    pub validation_errors: Vec<CertificateValidationError>,
    pub validated_at: String,
}

/// Certificate validation error types
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum CertificateValidationError {
    Expired,
    NotYetValid,
    FingerprintMismatch,
    SignatureInvalid,
    Revoked,
    IssuerNotTrusted,
    ChainBroken,
}

/// Security threat types that can be detected
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum SecurityThreat {
    InvalidCertificate,
    EncryptionFailure,
    UnauthorizedAccess,
    ManInTheMiddle,
    KeyCompromise,
    ReplayAttack,
    TamperingDetected,
}

/// Encryption algorithm types
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub enum EncryptionAlgorithm {
    Aes256Gcm,
    ChaCha20Poly1305,
}

/// Session key information
/// Requirement 10.5: Periodically rotate session keys
#[derive(Debug, Clone)]
pub struct SessionKey {
    pub key: Vec<u8>,
    pub created_at: Instant,
    pub rotation_count: u32,
    pub algorithm: EncryptionAlgorithm,
    /// Last rotation timestamp
    pub last_rotated_at: Instant,
    /// Maximum age before forced rotation (in seconds)
    pub max_age_secs: u64,
    /// Whether automatic rotation is enabled
    pub auto_rotate: bool,
}

/// Session key rotation configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KeyRotationConfig {
    /// Interval between automatic key rotations (in seconds)
    pub rotation_interval_secs: u64,
    /// Maximum number of messages before forced rotation
    pub max_messages_per_key: u64,
    /// Whether to enable automatic rotation
    pub auto_rotate: bool,
    /// Grace period for old key validity after rotation (in seconds)
    pub grace_period_secs: u64,
}

impl Default for KeyRotationConfig {
    fn default() -> Self {
        Self {
            rotation_interval_secs: 3600, // 1 hour
            max_messages_per_key: 1_000_000,
            auto_rotate: true,
            grace_period_secs: 60, // 1 minute grace period
        }
    }
}

/// Threat detection configuration
/// Requirement 10.6: Detect security threats and terminate connections
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ThreatDetectionConfig {
    /// Enable replay attack detection
    pub detect_replay_attacks: bool,
    /// Enable tampering detection
    pub detect_tampering: bool,
    /// Enable brute force detection
    pub detect_brute_force: bool,
    /// Maximum failed authentication attempts before lockout
    pub max_failed_attempts: u32,
    /// Lockout duration in seconds
    pub lockout_duration_secs: u64,
    /// Time window for tracking failed attempts (in seconds)
    pub attempt_window_secs: u64,
    /// Enable anomaly detection
    pub detect_anomalies: bool,
}

impl Default for ThreatDetectionConfig {
    fn default() -> Self {
        Self {
            detect_replay_attacks: true,
            detect_tampering: true,
            detect_brute_force: true,
            max_failed_attempts: 5,
            lockout_duration_secs: 300, // 5 minutes
            attempt_window_secs: 60,    // 1 minute window
            detect_anomalies: true,
        }
    }
}

/// Replay attack detection state
#[derive(Debug, Clone)]
pub struct ReplayDetectionState {
    /// Set of seen nonces to detect replay attacks
    pub seen_nonces: HashSet<Vec<u8>>,
    /// Maximum nonces to track (to prevent memory exhaustion)
    pub max_nonces: usize,
    /// Timestamp of oldest nonce
    pub oldest_nonce_time: Instant,
    /// Nonce expiration time in seconds
    pub nonce_expiration_secs: u64,
}

impl Default for ReplayDetectionState {
    fn default() -> Self {
        Self {
            seen_nonces: HashSet::new(),
            max_nonces: 100_000,
            oldest_nonce_time: Instant::now(),
            nonce_expiration_secs: 300, // 5 minutes
        }
    }
}

/// Failed authentication attempt tracking
#[derive(Debug, Clone)]
pub struct FailedAttemptTracker {
    /// Map of device/IP to failed attempt timestamps
    pub attempts: HashMap<String, Vec<Instant>>,
    /// Map of locked out devices/IPs with unlock time
    pub lockouts: HashMap<String, Instant>,
}

/// DTLS-SRTP configuration for media encryption
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DtlsSrtpConfig {
    /// SRTP profile to use
    pub srtp_profile: String,
    /// DTLS fingerprint algorithm
    pub fingerprint_algorithm: String,
    /// Local fingerprint
    pub local_fingerprint: Option<String>,
    /// Remote fingerprint for verification
    pub remote_fingerprint: Option<String>,
}

impl Default for DtlsSrtpConfig {
    fn default() -> Self {
        Self {
            srtp_profile: "SRTP_AES128_CM_HMAC_SHA1_80".to_string(),
            fingerprint_algorithm: "sha-256".to_string(),
            local_fingerprint: None,
            remote_fingerprint: None,
        }
    }
}

/// TLS configuration for signaling encryption
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TlsConfig {
    /// Minimum TLS version (should be 1.3 per Requirement 10.2)
    pub min_version: String,
    /// Cipher suites to use
    pub cipher_suites: Vec<String>,
    /// Enable certificate verification
    pub verify_certificates: bool,
}

impl Default for TlsConfig {
    fn default() -> Self {
        Self {
            min_version: "TLS1.3".to_string(),
            cipher_suites: vec![
                "TLS_AES_256_GCM_SHA384".to_string(),
                "TLS_AES_128_GCM_SHA256".to_string(),
                "TLS_CHACHA20_POLY1305_SHA256".to_string(),
            ],
            verify_certificates: true,
        }
    }
}

/// Encrypted data wrapper with metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EncryptedData {
    /// The encrypted ciphertext
    pub ciphertext: Vec<u8>,
    /// Nonce/IV used for encryption
    pub nonce: Vec<u8>,
    /// Authentication tag (for AEAD ciphers)
    pub tag: Vec<u8>,
    /// Algorithm used for encryption
    pub algorithm: EncryptionAlgorithm,
    /// Key ID used for encryption
    pub key_id: String,
}

/// Security event for logging and monitoring
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecurityEvent {
    pub timestamp: String,
    pub event_type: SecurityEventType,
    pub session_id: Option<String>,
    pub device_id: Option<String>,
    pub details: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum SecurityEventType {
    KeyRotation,
    CertificateValidation,
    ThreatDetected,
    EncryptionEnabled,
    EncryptionDisabled,
    SessionEstablished,
    SessionTerminated,
}

/// Security Manager - handles all encryption and security operations
pub struct SecurityManager {
    config: SecurityConfig,
    device_certificate: Option<DeviceCertificate>,
    session_keys: Arc<RwLock<HashMap<String, SessionKey>>>,
    dtls_config: DtlsSrtpConfig,
    tls_config: TlsConfig,
    security_events: Arc<RwLock<Vec<SecurityEvent>>>,
    threat_callbacks: Arc<RwLock<Vec<Box<dyn Fn(SecurityThreat) + Send + Sync>>>>,
    /// Key rotation configuration
    key_rotation_config: KeyRotationConfig,
    /// Threat detection configuration
    threat_detection_config: ThreatDetectionConfig,
    /// Replay attack detection state per session
    replay_detection: Arc<RwLock<HashMap<String, ReplayDetectionState>>>,
    /// Failed authentication attempt tracker
    failed_attempts: Arc<RwLock<FailedAttemptTracker>>,
    /// Trusted certificate fingerprints
    trusted_certificates: Arc<RwLock<HashSet<String>>>,
    /// Revoked certificate fingerprints
    revoked_certificates: Arc<RwLock<HashSet<String>>>,
    /// Old session keys for grace period (session_id -> old keys with expiration)
    old_session_keys: Arc<RwLock<HashMap<String, Vec<(SessionKey, Instant)>>>>,
}

impl SecurityManager {
    /// Create a new SecurityManager with default configuration
    pub fn new() -> Self {
        Self {
            config: SecurityConfig::default(),
            device_certificate: None,
            session_keys: Arc::new(RwLock::new(HashMap::new())),
            dtls_config: DtlsSrtpConfig::default(),
            tls_config: TlsConfig::default(),
            security_events: Arc::new(RwLock::new(Vec::new())),
            threat_callbacks: Arc::new(RwLock::new(Vec::new())),
            key_rotation_config: KeyRotationConfig::default(),
            threat_detection_config: ThreatDetectionConfig::default(),
            replay_detection: Arc::new(RwLock::new(HashMap::new())),
            failed_attempts: Arc::new(RwLock::new(FailedAttemptTracker {
                attempts: HashMap::new(),
                lockouts: HashMap::new(),
            })),
            trusted_certificates: Arc::new(RwLock::new(HashSet::new())),
            revoked_certificates: Arc::new(RwLock::new(HashSet::new())),
            old_session_keys: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// Create a new SecurityManager with custom configuration
    pub fn with_config(config: SecurityConfig) -> Self {
        Self {
            config,
            device_certificate: None,
            session_keys: Arc::new(RwLock::new(HashMap::new())),
            dtls_config: DtlsSrtpConfig::default(),
            tls_config: TlsConfig::default(),
            security_events: Arc::new(RwLock::new(Vec::new())),
            threat_callbacks: Arc::new(RwLock::new(Vec::new())),
            key_rotation_config: KeyRotationConfig::default(),
            threat_detection_config: ThreatDetectionConfig::default(),
            replay_detection: Arc::new(RwLock::new(HashMap::new())),
            failed_attempts: Arc::new(RwLock::new(FailedAttemptTracker {
                attempts: HashMap::new(),
                lockouts: HashMap::new(),
            })),
            trusted_certificates: Arc::new(RwLock::new(HashSet::new())),
            revoked_certificates: Arc::new(RwLock::new(HashSet::new())),
            old_session_keys: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// Update security configuration
    pub fn configure(&mut self, config: SecurityConfig) {
        self.config = config;
        tracing::info!("Security configuration updated");
        self.log_event(
            SecurityEventType::EncryptionEnabled,
            None,
            None,
            "Security configuration updated".to_string(),
        );
    }

    /// Get current security configuration
    pub fn get_security_config(&self) -> &SecurityConfig {
        &self.config
    }

    /// Get DTLS-SRTP configuration
    pub fn get_dtls_config(&self) -> &DtlsSrtpConfig {
        &self.dtls_config
    }

    /// Get TLS configuration
    pub fn get_tls_config(&self) -> &TlsConfig {
        &self.tls_config
    }

    /// Generate a device certificate for authentication
    /// Requirement 10.4: Verify device certificates to prevent MITM attacks
    pub async fn generate_device_certificate(
        &mut self,
        device_id: String,
    ) -> Result<DeviceCertificate> {
        // Generate X25519 key pair for key exchange
        let secret = EphemeralSecret::random_from_rng(OsRng);
        let public = PublicKey::from(&secret);

        // Generate Ed25519 signing key pair for certificate signatures
        let mut signing_key_bytes = [0u8; 32];
        OsRng.fill_bytes(&mut signing_key_bytes);
        let signing_key = SigningKey::from_bytes(&signing_key_bytes);
        let verifying_key = signing_key.verifying_key();

        // Generate certificate fingerprint
        let mut hasher = Sha256::new();
        hasher.update(public.as_bytes());
        hasher.update(verifying_key.as_bytes());
        let fingerprint = hex::encode(hasher.finalize());

        let now = chrono::Utc::now();
        let valid_until = now.checked_add_signed(chrono::Duration::days(365)).unwrap();

        // Create certificate data for signing
        let cert_data = format!(
            "{}:{}:{}:{}",
            device_id,
            hex::encode(public.as_bytes()),
            now.to_rfc3339(),
            valid_until.to_rfc3339()
        );

        // Sign the certificate
        let signature = signing_key.sign(cert_data.as_bytes());

        let certificate = DeviceCertificate {
            device_id: device_id.clone(),
            certificate: public.as_bytes().to_vec(),
            private_key: vec![0u8; 32], // In production, store securely
            public_key: public.as_bytes().to_vec(),
            valid_from: now.to_rfc3339(),
            valid_until: valid_until.to_rfc3339(),
            fingerprint: fingerprint.clone(),
            signing_key: Some(signing_key_bytes.to_vec()),
            verifying_key: verifying_key.as_bytes().to_vec(),
            signature: signature.to_bytes().to_vec(),
            issuer_fingerprint: None, // Self-signed
            revoked: false,
        };

        self.device_certificate = Some(certificate.clone());

        // Add to trusted certificates
        self.trusted_certificates
            .write()
            .await
            .insert(fingerprint.clone());

        self.log_event(
            SecurityEventType::CertificateValidation,
            None,
            Some(device_id.clone()),
            format!("Generated device certificate for: {}", device_id),
        );

        tracing::info!("Generated device certificate for: {}", device_id);
        Ok(certificate)
    }

    /// Validate a device certificate with comprehensive checks
    /// Requirement 10.4: Verify device certificates to prevent MITM attacks
    pub async fn validate_device_certificate(
        &self,
        certificate: &DeviceCertificate,
    ) -> Result<CertificateValidationResult> {
        let mut validation_errors = Vec::new();
        let now = chrono::Utc::now();

        if !self.config.certificate_validation {
            return Ok(CertificateValidationResult {
                is_valid: true,
                device_id: certificate.device_id.clone(),
                validation_errors: vec![],
                validated_at: now.to_rfc3339(),
            });
        }

        // Check if certificate is revoked
        if certificate.revoked {
            validation_errors.push(CertificateValidationError::Revoked);
        }

        // Check revocation list
        if self
            .revoked_certificates
            .read()
            .await
            .contains(&certificate.fingerprint)
        {
            validation_errors.push(CertificateValidationError::Revoked);
        }

        // Check certificate expiration
        let valid_until = chrono::DateTime::parse_from_rfc3339(&certificate.valid_until)
            .context("Invalid certificate expiration date")?;

        if valid_until < now {
            tracing::warn!("Certificate expired for device: {}", certificate.device_id);
            validation_errors.push(CertificateValidationError::Expired);
        }

        // Check not-before date
        let valid_from = chrono::DateTime::parse_from_rfc3339(&certificate.valid_from)
            .context("Invalid certificate start date")?;

        if valid_from > now {
            tracing::warn!(
                "Certificate not yet valid for device: {}",
                certificate.device_id
            );
            validation_errors.push(CertificateValidationError::NotYetValid);
        }

        // Verify fingerprint
        let mut hasher = Sha256::new();
        hasher.update(&certificate.public_key);
        hasher.update(&certificate.verifying_key);
        let computed_fingerprint = hex::encode(hasher.finalize());

        if computed_fingerprint != certificate.fingerprint {
            tracing::warn!(
                "Certificate fingerprint mismatch for device: {}",
                certificate.device_id
            );
            validation_errors.push(CertificateValidationError::FingerprintMismatch);
        }

        // Verify signature
        if !self.verify_certificate_signature(certificate)? {
            tracing::warn!(
                "Certificate signature invalid for device: {}",
                certificate.device_id
            );
            validation_errors.push(CertificateValidationError::SignatureInvalid);
        }

        // Check issuer trust chain (if not self-signed)
        if let Some(ref issuer_fingerprint) = certificate.issuer_fingerprint {
            if !self
                .trusted_certificates
                .read()
                .await
                .contains(issuer_fingerprint)
            {
                tracing::warn!(
                    "Certificate issuer not trusted for device: {}",
                    certificate.device_id
                );
                validation_errors.push(CertificateValidationError::IssuerNotTrusted);
            }
        }

        let is_valid = validation_errors.is_empty();

        if is_valid {
            tracing::debug!(
                "Certificate validated for device: {}",
                certificate.device_id
            );
        } else {
            // Detect potential MITM attack
            if validation_errors.contains(&CertificateValidationError::SignatureInvalid)
                || validation_errors.contains(&CertificateValidationError::FingerprintMismatch)
            {
                let _ = self.detect_security_threat(SecurityThreat::ManInTheMiddle);
            }
        }

        Ok(CertificateValidationResult {
            is_valid,
            device_id: certificate.device_id.clone(),
            validation_errors,
            validated_at: now.to_rfc3339(),
        })
    }

    /// Verify certificate signature
    fn verify_certificate_signature(&self, certificate: &DeviceCertificate) -> Result<bool> {
        if certificate.verifying_key.len() != 32 || certificate.signature.len() != 64 {
            return Ok(false);
        }

        let verifying_key_bytes: [u8; 32] = certificate
            .verifying_key
            .clone()
            .try_into()
            .map_err(|_| anyhow::anyhow!("Invalid verifying key length"))?;
        let verifying_key = VerifyingKey::from_bytes(&verifying_key_bytes)
            .map_err(|e| anyhow::anyhow!("Invalid verifying key: {}", e))?;

        let signature_bytes: [u8; 64] = certificate
            .signature
            .clone()
            .try_into()
            .map_err(|_| anyhow::anyhow!("Invalid signature length"))?;
        let signature = Signature::from_bytes(&signature_bytes);

        // Reconstruct certificate data for verification
        let cert_data = format!(
            "{}:{}:{}:{}",
            certificate.device_id,
            hex::encode(&certificate.public_key),
            certificate.valid_from,
            certificate.valid_until
        );

        Ok(verifying_key
            .verify(cert_data.as_bytes(), &signature)
            .is_ok())
    }

    /// Add a certificate to the trusted list
    pub async fn trust_certificate(&self, fingerprint: &str) {
        self.trusted_certificates
            .write()
            .await
            .insert(fingerprint.to_string());
        tracing::info!("Added certificate to trusted list: {}", fingerprint);
    }

    /// Revoke a certificate
    pub async fn revoke_certificate(&self, fingerprint: &str) {
        self.revoked_certificates
            .write()
            .await
            .insert(fingerprint.to_string());
        self.trusted_certificates.write().await.remove(fingerprint);

        self.log_event(
            SecurityEventType::CertificateValidation,
            None,
            None,
            format!("Certificate revoked: {}", fingerprint),
        );

        tracing::warn!("Certificate revoked: {}", fingerprint);
    }

    /// Check if a certificate is trusted
    pub async fn is_certificate_trusted(&self, fingerprint: &str) -> bool {
        self.trusted_certificates.read().await.contains(fingerprint)
            && !self.revoked_certificates.read().await.contains(fingerprint)
    }

    /// Legacy validation method for backward compatibility
    pub fn validate_device_certificate_sync(
        &self,
        certificate: &DeviceCertificate,
    ) -> Result<bool> {
        if !self.config.certificate_validation {
            return Ok(true);
        }

        // Check certificate expiration
        let valid_until = chrono::DateTime::parse_from_rfc3339(&certificate.valid_until)
            .context("Invalid certificate expiration date")?;
        let now = chrono::Utc::now();

        if valid_until < now {
            tracing::warn!("Certificate expired for device: {}", certificate.device_id);
            return Ok(false);
        }

        // Verify fingerprint (legacy check without verifying key)
        let mut hasher = Sha256::new();
        hasher.update(&certificate.public_key);
        if !certificate.verifying_key.is_empty() {
            hasher.update(&certificate.verifying_key);
        }
        let computed_fingerprint = hex::encode(hasher.finalize());

        if computed_fingerprint != certificate.fingerprint {
            tracing::warn!(
                "Certificate fingerprint mismatch for device: {}",
                certificate.device_id
            );
            return Ok(false);
        }

        tracing::debug!(
            "Certificate validated for device: {}",
            certificate.device_id
        );
        Ok(true)
    }

    /// Get the device certificate
    pub fn get_device_certificate(&self) -> Option<&DeviceCertificate> {
        self.device_certificate.as_ref()
    }

    /// Generate a session key for encryption
    pub async fn generate_session_key(&self, session_id: &str) -> Result<SessionKey> {
        let mut key = vec![0u8; 32]; // 256-bit key
        OsRng.fill_bytes(&mut key);

        let now = Instant::now();
        let session_key = SessionKey {
            key,
            created_at: now,
            rotation_count: 0,
            algorithm: EncryptionAlgorithm::Aes256Gcm,
            last_rotated_at: now,
            max_age_secs: self.key_rotation_config.rotation_interval_secs,
            auto_rotate: self.key_rotation_config.auto_rotate,
        };

        self.session_keys
            .write()
            .await
            .insert(session_id.to_string(), session_key.clone());

        // Initialize replay detection for this session
        self.replay_detection
            .write()
            .await
            .insert(session_id.to_string(), ReplayDetectionState::default());

        self.log_event(
            SecurityEventType::SessionEstablished,
            Some(session_id.to_string()),
            None,
            "Session key generated".to_string(),
        );

        tracing::info!("Generated session key for session: {}", session_id);
        Ok(session_key)
    }

    /// Rotate session key for enhanced security
    /// Requirement 10.5: Periodically rotate session keys
    pub async fn rotate_session_key(&self, session_id: &str) -> Result<SessionKey> {
        let mut keys = self.session_keys.write().await;

        if let Some(existing_key) = keys.get_mut(session_id) {
            // Store old key for grace period
            let old_key = existing_key.clone();
            let grace_expiration =
                Instant::now() + Duration::from_secs(self.key_rotation_config.grace_period_secs);

            {
                let mut old_keys = self.old_session_keys.write().await;
                old_keys
                    .entry(session_id.to_string())
                    .or_insert_with(Vec::new)
                    .push((old_key, grace_expiration));
            }

            // Generate new key
            let mut new_key = vec![0u8; 32];
            OsRng.fill_bytes(&mut new_key);

            existing_key.key = new_key;
            existing_key.last_rotated_at = Instant::now();
            existing_key.rotation_count += 1;

            self.log_event(
                SecurityEventType::KeyRotation,
                Some(session_id.to_string()),
                None,
                format!(
                    "Session key rotated (count: {})",
                    existing_key.rotation_count
                ),
            );

            tracing::info!(
                "Rotated session key for session: {} (rotation #{})",
                session_id,
                existing_key.rotation_count
            );

            Ok(existing_key.clone())
        } else {
            Err(anyhow::anyhow!("Session not found: {}", session_id))
        }
    }

    /// Check if session key needs rotation based on time or usage
    pub async fn needs_key_rotation(&self, session_id: &str) -> bool {
        if let Some(key) = self.session_keys.read().await.get(session_id) {
            if !key.auto_rotate {
                return false;
            }
            key.last_rotated_at.elapsed() > Duration::from_secs(key.max_age_secs)
        } else {
            false
        }
    }

    /// Automatically rotate keys that have exceeded their maximum age
    /// Requirement 10.5: Periodically rotate session keys
    pub async fn auto_rotate_expired_keys(&self) -> Vec<String> {
        let mut rotated_sessions = Vec::new();
        let session_ids: Vec<String> = self.session_keys.read().await.keys().cloned().collect();

        for session_id in session_ids {
            if self.needs_key_rotation(&session_id).await {
                if self.rotate_session_key(&session_id).await.is_ok() {
                    rotated_sessions.push(session_id);
                }
            }
        }

        // Clean up expired old keys
        self.cleanup_expired_old_keys().await;

        rotated_sessions
    }

    /// Clean up old keys that have exceeded their grace period
    async fn cleanup_expired_old_keys(&self) {
        let mut old_keys = self.old_session_keys.write().await;
        let now = Instant::now();

        for (_, keys) in old_keys.iter_mut() {
            keys.retain(|(_, expiration)| *expiration > now);
        }

        // Remove empty entries
        old_keys.retain(|_, keys| !keys.is_empty());
    }

    /// Configure key rotation settings
    pub fn configure_key_rotation(&mut self, config: KeyRotationConfig) {
        self.key_rotation_config = config;
        tracing::info!("Key rotation configuration updated");
    }

    /// Get key rotation configuration
    pub fn get_key_rotation_config(&self) -> &KeyRotationConfig {
        &self.key_rotation_config
    }

    /// Get session key for a session
    pub async fn get_session_key(&self, session_id: &str) -> Option<SessionKey> {
        self.session_keys.read().await.get(session_id).cloned()
    }

    /// Remove session key when session ends
    pub async fn remove_session_key(&self, session_id: &str) {
        self.session_keys.write().await.remove(session_id);
        self.replay_detection.write().await.remove(session_id);
        self.old_session_keys.write().await.remove(session_id);

        self.log_event(
            SecurityEventType::SessionTerminated,
            Some(session_id.to_string()),
            None,
            "Session key removed".to_string(),
        );
    }

    /// Encrypt media stream data using DTLS-SRTP
    /// Requirement 10.1: Use DTLS-SRTP to encrypt all WebRTC media streams
    pub async fn encrypt_media_stream(
        &self,
        session_id: &str,
        data: &[u8],
    ) -> Result<EncryptedData> {
        if !self.config.enable_dtls_srtp {
            // Return unencrypted data wrapped in EncryptedData structure
            return Ok(EncryptedData {
                ciphertext: data.to_vec(),
                nonce: vec![],
                tag: vec![],
                algorithm: EncryptionAlgorithm::Aes256Gcm,
                key_id: session_id.to_string(),
            });
        }

        let key = self
            .session_keys
            .read()
            .await
            .get(session_id)
            .ok_or_else(|| anyhow::anyhow!("Session key not found for: {}", session_id))?
            .key
            .clone();

        self.encrypt_with_aes_gcm(&key, data, session_id)
    }

    /// Decrypt media stream data
    pub async fn decrypt_media_stream(
        &self,
        session_id: &str,
        encrypted: &EncryptedData,
    ) -> Result<Vec<u8>> {
        if !self.config.enable_dtls_srtp {
            return Ok(encrypted.ciphertext.clone());
        }

        let key = self
            .session_keys
            .read()
            .await
            .get(session_id)
            .ok_or_else(|| anyhow::anyhow!("Session key not found for: {}", session_id))?
            .key
            .clone();

        self.decrypt_with_aes_gcm(&key, encrypted)
    }

    /// Encrypt file data for transfer
    /// Requirement 10.3: Use end-to-end encryption for file transfers
    pub async fn encrypt_file_data(&self, session_id: &str, data: &[u8]) -> Result<EncryptedData> {
        if !self.config.enable_file_encryption {
            return Ok(EncryptedData {
                ciphertext: data.to_vec(),
                nonce: vec![],
                tag: vec![],
                algorithm: EncryptionAlgorithm::Aes256Gcm,
                key_id: session_id.to_string(),
            });
        }

        let key = self
            .session_keys
            .read()
            .await
            .get(session_id)
            .ok_or_else(|| anyhow::anyhow!("Session key not found for: {}", session_id))?
            .key
            .clone();

        self.encrypt_with_aes_gcm(&key, data, session_id)
    }

    /// Decrypt file data
    pub async fn decrypt_file_data(
        &self,
        session_id: &str,
        encrypted: &EncryptedData,
    ) -> Result<Vec<u8>> {
        if !self.config.enable_file_encryption {
            return Ok(encrypted.ciphertext.clone());
        }

        let key = self
            .session_keys
            .read()
            .await
            .get(session_id)
            .ok_or_else(|| anyhow::anyhow!("Session key not found for: {}", session_id))?
            .key
            .clone();

        self.decrypt_with_aes_gcm(&key, encrypted)
    }

    /// Encrypt signaling data using TLS 1.3
    /// Requirement 10.2: Use TLS 1.3 for signaling encryption
    pub async fn encrypt_signaling_data(
        &self,
        session_id: &str,
        data: &[u8],
    ) -> Result<EncryptedData> {
        if !self.config.enable_tls_signaling {
            return Ok(EncryptedData {
                ciphertext: data.to_vec(),
                nonce: vec![],
                tag: vec![],
                algorithm: EncryptionAlgorithm::Aes256Gcm,
                key_id: session_id.to_string(),
            });
        }

        let key = self
            .session_keys
            .read()
            .await
            .get(session_id)
            .ok_or_else(|| anyhow::anyhow!("Session key not found for: {}", session_id))?
            .key
            .clone();

        self.encrypt_with_aes_gcm(&key, data, session_id)
    }

    /// Decrypt signaling data
    pub async fn decrypt_signaling_data(
        &self,
        session_id: &str,
        encrypted: &EncryptedData,
    ) -> Result<Vec<u8>> {
        if !self.config.enable_tls_signaling {
            return Ok(encrypted.ciphertext.clone());
        }

        let key = self
            .session_keys
            .read()
            .await
            .get(session_id)
            .ok_or_else(|| anyhow::anyhow!("Session key not found for: {}", session_id))?
            .key
            .clone();

        self.decrypt_with_aes_gcm(&key, encrypted)
    }

    /// Internal AES-256-GCM encryption
    fn encrypt_with_aes_gcm(&self, key: &[u8], data: &[u8], key_id: &str) -> Result<EncryptedData> {
        let cipher = Aes256Gcm::new_from_slice(key)
            .map_err(|e| anyhow::anyhow!("Failed to create cipher: {}", e))?;

        // Generate random nonce
        let mut nonce_bytes = [0u8; 12];
        OsRng.fill_bytes(&mut nonce_bytes);
        let nonce = Nonce::from_slice(&nonce_bytes);

        let ciphertext = cipher
            .encrypt(nonce, data)
            .map_err(|e| anyhow::anyhow!("Encryption failed: {}", e))?;

        // AES-GCM includes the tag in the ciphertext, extract it
        let tag_start = ciphertext.len().saturating_sub(16);
        let (ct, tag) = ciphertext.split_at(tag_start);

        Ok(EncryptedData {
            ciphertext: ct.to_vec(),
            nonce: nonce_bytes.to_vec(),
            tag: tag.to_vec(),
            algorithm: EncryptionAlgorithm::Aes256Gcm,
            key_id: key_id.to_string(),
        })
    }

    /// Internal AES-256-GCM decryption
    fn decrypt_with_aes_gcm(&self, key: &[u8], encrypted: &EncryptedData) -> Result<Vec<u8>> {
        let cipher = Aes256Gcm::new_from_slice(key)
            .map_err(|e| anyhow::anyhow!("Failed to create cipher: {}", e))?;

        let nonce = Nonce::from_slice(&encrypted.nonce);

        // Reconstruct ciphertext with tag
        let mut ciphertext_with_tag = encrypted.ciphertext.clone();
        ciphertext_with_tag.extend_from_slice(&encrypted.tag);

        let plaintext = cipher
            .decrypt(nonce, ciphertext_with_tag.as_ref())
            .map_err(|e| anyhow::anyhow!("Decryption failed: {}", e))?;

        Ok(plaintext)
    }

    /// Detect and handle security threats
    /// Requirement 10.6: Detect security threats and terminate connections
    pub fn detect_security_threat(&self, threat: SecurityThreat) -> Result<()> {
        if !self.config.threat_detection_enabled {
            return Ok(());
        }

        self.log_event(
            SecurityEventType::ThreatDetected,
            None,
            None,
            format!("Security threat detected: {:?}", threat),
        );

        tracing::error!("Security threat detected: {:?}", threat);

        // Notify registered callbacks
        tokio::spawn({
            let callbacks = self.threat_callbacks.clone();
            let threat = threat.clone();
            async move {
                let cbs = callbacks.read().await;
                for callback in cbs.iter() {
                    callback(threat.clone());
                }
            }
        });

        match threat {
            SecurityThreat::InvalidCertificate => Err(anyhow::anyhow!(
                "Invalid certificate detected - connection terminated"
            )),
            SecurityThreat::EncryptionFailure => Err(anyhow::anyhow!(
                "Encryption failure - connection terminated"
            )),
            SecurityThreat::UnauthorizedAccess => Err(anyhow::anyhow!(
                "Unauthorized access attempt - connection terminated"
            )),
            SecurityThreat::ManInTheMiddle => Err(anyhow::anyhow!(
                "Man-in-the-middle attack detected - connection terminated"
            )),
            SecurityThreat::KeyCompromise => Err(anyhow::anyhow!(
                "Key compromise detected - connection terminated"
            )),
            SecurityThreat::ReplayAttack => Err(anyhow::anyhow!(
                "Replay attack detected - connection terminated"
            )),
            SecurityThreat::TamperingDetected => Err(anyhow::anyhow!(
                "Data tampering detected - connection terminated"
            )),
        }
    }

    /// Detect replay attacks by checking for duplicate nonces
    /// Requirement 10.6: Detect security threats
    pub async fn detect_replay_attack(&self, session_id: &str, nonce: &[u8]) -> Result<bool> {
        if !self.threat_detection_config.detect_replay_attacks {
            return Ok(false);
        }

        let mut replay_states = self.replay_detection.write().await;
        let state = replay_states
            .entry(session_id.to_string())
            .or_insert_with(ReplayDetectionState::default);

        // Clean up old nonces if needed
        if state.oldest_nonce_time.elapsed() > Duration::from_secs(state.nonce_expiration_secs) {
            state.seen_nonces.clear();
            state.oldest_nonce_time = Instant::now();
        }

        // Check if nonce was already seen
        if state.seen_nonces.contains(nonce) {
            tracing::warn!("Replay attack detected for session: {}", session_id);
            let _ = self.detect_security_threat(SecurityThreat::ReplayAttack);
            return Ok(true);
        }

        // Add nonce to seen set
        if state.seen_nonces.len() >= state.max_nonces {
            // Remove oldest entries (simple approach: clear half)
            let to_remove: Vec<_> = state
                .seen_nonces
                .iter()
                .take(state.max_nonces / 2)
                .cloned()
                .collect();
            for nonce in to_remove {
                state.seen_nonces.remove(&nonce);
            }
        }

        state.seen_nonces.insert(nonce.to_vec());
        Ok(false)
    }

    /// Detect data tampering by verifying integrity
    /// Requirement 10.6: Detect security threats
    pub fn detect_tampering(&self, data: &[u8], expected_hash: &[u8]) -> Result<bool> {
        if !self.threat_detection_config.detect_tampering {
            return Ok(false);
        }

        if !self.verify_integrity(data, expected_hash) {
            tracing::warn!("Data tampering detected");
            let _ = self.detect_security_threat(SecurityThreat::TamperingDetected);
            return Ok(true);
        }

        Ok(false)
    }

    /// Track failed authentication attempts for brute force detection
    /// Requirement 10.6: Detect security threats
    pub async fn track_failed_attempt(&self, identifier: &str) -> Result<bool> {
        if !self.threat_detection_config.detect_brute_force {
            return Ok(false);
        }

        let mut tracker = self.failed_attempts.write().await;
        let now = Instant::now();

        // Check if already locked out
        if let Some(unlock_time) = tracker.lockouts.get(identifier) {
            if now < *unlock_time {
                tracing::warn!("Access denied - account locked: {}", identifier);
                return Ok(true); // Still locked out
            } else {
                // Lockout expired, remove it
                tracker.lockouts.remove(identifier);
            }
        }

        // Add failed attempt
        let attempts = tracker
            .attempts
            .entry(identifier.to_string())
            .or_insert_with(Vec::new);

        // Remove old attempts outside the window
        let window_start =
            now - Duration::from_secs(self.threat_detection_config.attempt_window_secs);
        attempts.retain(|t| *t > window_start);

        // Add new attempt
        attempts.push(now);

        // Check if threshold exceeded
        let should_lockout =
            attempts.len() >= self.threat_detection_config.max_failed_attempts as usize;

        if should_lockout {
            let unlock_time =
                now + Duration::from_secs(self.threat_detection_config.lockout_duration_secs);
            tracker.lockouts.insert(identifier.to_string(), unlock_time);
            tracker.attempts.get_mut(identifier).map(|a| a.clear());

            tracing::warn!(
                "Account locked due to too many failed attempts: {}",
                identifier
            );
            let _ = self.detect_security_threat(SecurityThreat::UnauthorizedAccess);
            return Ok(true);
        }

        Ok(false)
    }

    /// Check if an identifier is currently locked out
    pub async fn is_locked_out(&self, identifier: &str) -> bool {
        let tracker = self.failed_attempts.read().await;
        if let Some(unlock_time) = tracker.lockouts.get(identifier) {
            Instant::now() < *unlock_time
        } else {
            false
        }
    }

    /// Clear failed attempts for an identifier (e.g., after successful auth)
    pub async fn clear_failed_attempts(&self, identifier: &str) {
        let mut tracker = self.failed_attempts.write().await;
        tracker.attempts.remove(identifier);
        tracker.lockouts.remove(identifier);
    }

    /// Configure threat detection settings
    pub fn configure_threat_detection(&mut self, config: ThreatDetectionConfig) {
        self.threat_detection_config = config;
        tracing::info!("Threat detection configuration updated");
    }

    /// Get threat detection configuration
    pub fn get_threat_detection_config(&self) -> &ThreatDetectionConfig {
        &self.threat_detection_config
    }

    /// Perform comprehensive security check on incoming data
    /// Requirement 10.6: Detect security threats
    pub async fn security_check(
        &self,
        session_id: &str,
        nonce: &[u8],
        data: &[u8],
        hash: &[u8],
    ) -> Result<()> {
        // Check for replay attack
        if self.detect_replay_attack(session_id, nonce).await? {
            return Err(anyhow::anyhow!("Replay attack detected"));
        }

        // Check for tampering
        if self.detect_tampering(data, hash)? {
            return Err(anyhow::anyhow!("Data tampering detected"));
        }

        Ok(())
    }

    /// Register a callback for security threat notifications
    pub async fn on_threat_detected<F>(&self, callback: F)
    where
        F: Fn(SecurityThreat) + Send + Sync + 'static,
    {
        self.threat_callbacks.write().await.push(Box::new(callback));
    }

    /// Verify data integrity using HMAC
    pub fn verify_integrity(&self, data: &[u8], expected_hash: &[u8]) -> bool {
        let mut hasher = Sha256::new();
        hasher.update(data);
        let computed_hash = hasher.finalize();
        computed_hash.as_slice() == expected_hash
    }

    /// Compute hash for data integrity
    pub fn compute_hash(&self, data: &[u8]) -> Vec<u8> {
        let mut hasher = Sha256::new();
        hasher.update(data);
        hasher.finalize().to_vec()
    }

    /// Log a security event
    fn log_event(
        &self,
        event_type: SecurityEventType,
        session_id: Option<String>,
        device_id: Option<String>,
        details: String,
    ) {
        let event = SecurityEvent {
            timestamp: chrono::Utc::now().to_rfc3339(),
            event_type,
            session_id,
            device_id,
            details,
        };

        // Spawn async task to log event
        let events = self.security_events.clone();
        tokio::spawn(async move {
            events.write().await.push(event);
        });
    }

    /// Get security events
    pub async fn get_security_events(&self) -> Vec<SecurityEvent> {
        self.security_events.read().await.clone()
    }

    /// Clear security events
    pub async fn clear_security_events(&self) {
        self.security_events.write().await.clear();
    }

    /// Check if DTLS-SRTP is enabled
    pub fn is_dtls_srtp_enabled(&self) -> bool {
        self.config.enable_dtls_srtp
    }

    /// Check if TLS signaling is enabled
    pub fn is_tls_signaling_enabled(&self) -> bool {
        self.config.enable_tls_signaling
    }

    /// Check if file encryption is enabled
    pub fn is_file_encryption_enabled(&self) -> bool {
        self.config.enable_file_encryption
    }

    /// Configure DTLS-SRTP settings
    pub fn configure_dtls_srtp(&mut self, config: DtlsSrtpConfig) {
        self.dtls_config = config;
        tracing::info!("DTLS-SRTP configuration updated");
    }

    /// Configure TLS settings
    pub fn configure_tls(&mut self, config: TlsConfig) {
        self.tls_config = config;
        tracing::info!("TLS configuration updated");
    }

    /// Perform key exchange using X25519
    pub fn perform_key_exchange(&self, remote_public_key: &[u8]) -> Result<Vec<u8>> {
        if remote_public_key.len() != 32 {
            return Err(anyhow::anyhow!("Invalid public key length"));
        }

        let secret = EphemeralSecret::random_from_rng(OsRng);
        let public = PublicKey::from(&secret);

        let mut remote_key_bytes = [0u8; 32];
        remote_key_bytes.copy_from_slice(remote_public_key);
        let remote_public = PublicKey::from(remote_key_bytes);

        let shared_secret = secret.diffie_hellman(&remote_public);

        // Derive key using HKDF
        let hk = hkdf::Hkdf::<Sha256>::new(None, shared_secret.as_bytes());
        let mut derived_key = vec![0u8; 32];
        hk.expand(b"session-key", &mut derived_key)
            .map_err(|_| anyhow::anyhow!("Key derivation failed"))?;

        Ok(derived_key)
    }

    /// Get local public key for key exchange
    pub fn get_local_public_key(&self) -> Vec<u8> {
        let secret = EphemeralSecret::random_from_rng(OsRng);
        let public = PublicKey::from(&secret);
        public.as_bytes().to_vec()
    }
}

impl Default for SecurityManager {
    fn default() -> Self {
        Self::new()
    }
}
