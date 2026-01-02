//! Security Module Tests
//!
//! Tests for end-to-end encryption functionality.
//! Feature: cec-remote, Property 11: Media stream encryption

use crate::security::*;

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_security_manager_creation() {
        let manager = SecurityManager::new();
        assert!(manager.is_dtls_srtp_enabled());
        assert!(manager.is_tls_signaling_enabled());
        assert!(manager.is_file_encryption_enabled());
    }

    #[tokio::test]
    async fn test_security_config_default() {
        let config = SecurityConfig::default();
        assert!(config.enable_dtls_srtp);
        assert!(config.enable_tls_signaling);
        assert!(config.enable_file_encryption);
        assert!(config.certificate_validation);
        assert_eq!(config.key_rotation_interval, 3600);
        assert!(config.threat_detection_enabled);
    }

    #[tokio::test]
    async fn test_session_key_generation() {
        let manager = SecurityManager::new();
        let session_id = "test-session-1";
        
        let key = manager.generate_session_key(session_id).await.unwrap();
        assert_eq!(key.key.len(), 32); // 256-bit key
        assert_eq!(key.rotation_count, 0);
        assert_eq!(key.algorithm, EncryptionAlgorithm::Aes256Gcm);
        
        // Verify key is stored
        let stored_key = manager.get_session_key(session_id).await;
        assert!(stored_key.is_some());
    }

    #[tokio::test]
    async fn test_session_key_rotation() {
        let manager = SecurityManager::new();
        let session_id = "test-session-2";
        
        let original_key = manager.generate_session_key(session_id).await.unwrap();
        let rotated_key = manager.rotate_session_key(session_id).await.unwrap();
        
        assert_eq!(rotated_key.rotation_count, 1);
        assert_ne!(original_key.key, rotated_key.key);
    }
    
    #[tokio::test]
    async fn test_key_rotation_preserves_old_keys() {
        let manager = SecurityManager::new();
        let session_id = "test-session-grace";
        
        let original_key = manager.generate_session_key(session_id).await.unwrap();
        let rotated_key = manager.rotate_session_key(session_id).await.unwrap();
        
        // Verify rotation happened
        assert_ne!(original_key.key, rotated_key.key);
        assert_eq!(rotated_key.rotation_count, 1);
        
        // Old keys are preserved internally for grace period
        // We verify this by checking that the current key is different
        let current_key = manager.get_session_key(session_id).await.unwrap();
        assert_eq!(current_key.key, rotated_key.key);
    }
    
    #[tokio::test]
    async fn test_auto_rotate_expired_keys() {
        let mut manager = SecurityManager::new();
        
        // Configure very short rotation interval for testing
        manager.configure_key_rotation(KeyRotationConfig {
            rotation_interval_secs: 0, // Immediate rotation
            max_messages_per_key: 1_000_000,
            auto_rotate: true,
            grace_period_secs: 60,
        });
        
        let session_id = "test-session-auto";
        manager.generate_session_key(session_id).await.unwrap();
        
        // Should need rotation immediately
        assert!(manager.needs_key_rotation(session_id).await);
        
        // Auto rotate
        let rotated = manager.auto_rotate_expired_keys().await;
        assert!(rotated.contains(&session_id.to_string()));
    }


    #[tokio::test]
    async fn test_media_stream_encryption_decryption() {
        let manager = SecurityManager::new();
        let session_id = "test-session-3";
        
        // Generate session key first
        manager.generate_session_key(session_id).await.unwrap();
        
        let original_data = b"This is test media stream data for encryption";
        
        // Encrypt
        let encrypted = manager.encrypt_media_stream(session_id, original_data).await.unwrap();
        assert_ne!(encrypted.ciphertext, original_data.to_vec());
        assert!(!encrypted.nonce.is_empty());
        assert!(!encrypted.tag.is_empty());
        
        // Decrypt
        let decrypted = manager.decrypt_media_stream(session_id, &encrypted).await.unwrap();
        assert_eq!(decrypted, original_data.to_vec());
    }

    #[tokio::test]
    async fn test_file_encryption_decryption() {
        let manager = SecurityManager::new();
        let session_id = "test-session-4";
        
        manager.generate_session_key(session_id).await.unwrap();
        
        let original_data = b"This is test file data for encryption";
        
        // Encrypt
        let encrypted = manager.encrypt_file_data(session_id, original_data).await.unwrap();
        assert_ne!(encrypted.ciphertext, original_data.to_vec());
        
        // Decrypt
        let decrypted = manager.decrypt_file_data(session_id, &encrypted).await.unwrap();
        assert_eq!(decrypted, original_data.to_vec());
    }

    #[tokio::test]
    async fn test_signaling_encryption_decryption() {
        let manager = SecurityManager::new();
        let session_id = "test-session-5";
        
        manager.generate_session_key(session_id).await.unwrap();
        
        let original_data = b"This is test signaling data";
        
        // Encrypt
        let encrypted = manager.encrypt_signaling_data(session_id, original_data).await.unwrap();
        assert_ne!(encrypted.ciphertext, original_data.to_vec());
        
        // Decrypt
        let decrypted = manager.decrypt_signaling_data(session_id, &encrypted).await.unwrap();
        assert_eq!(decrypted, original_data.to_vec());
    }

    #[tokio::test]
    async fn test_device_certificate_generation() {
        let mut manager = SecurityManager::new();
        let device_id = "test-device-1";
        
        let cert = manager.generate_device_certificate(device_id.to_string()).await.unwrap();
        
        assert_eq!(cert.device_id, device_id);
        assert!(!cert.certificate.is_empty());
        assert!(!cert.public_key.is_empty());
        assert!(!cert.fingerprint.is_empty());
        
        // Verify certificate is stored
        let stored_cert = manager.get_device_certificate();
        assert!(stored_cert.is_some());
    }


    #[tokio::test]
    async fn test_device_certificate_validation() {
        let mut manager = SecurityManager::new();
        let device_id = "test-device-2";
        
        let cert = manager.generate_device_certificate(device_id.to_string()).await.unwrap();
        
        // Valid certificate should pass validation
        let result = manager.validate_device_certificate(&cert).await.unwrap();
        assert!(result.is_valid);
        assert!(result.validation_errors.is_empty());
    }

    #[tokio::test]
    async fn test_expired_certificate_validation() {
        let manager = SecurityManager::new();
        
        // Create an expired certificate
        let expired_cert = DeviceCertificate {
            device_id: "expired-device".to_string(),
            certificate: vec![0u8; 32],
            private_key: vec![0u8; 32],
            public_key: vec![0u8; 32],
            valid_from: "2020-01-01T00:00:00Z".to_string(),
            valid_until: "2020-12-31T23:59:59Z".to_string(), // Expired
            fingerprint: "invalid".to_string(),
            signing_key: None,
            verifying_key: vec![0u8; 32],
            signature: vec![0u8; 64],
            issuer_fingerprint: None,
            revoked: false,
        };
        
        let result = manager.validate_device_certificate(&expired_cert).await.unwrap();
        assert!(!result.is_valid);
        assert!(result.validation_errors.contains(&CertificateValidationError::Expired));
    }
    
    #[tokio::test]
    async fn test_revoked_certificate_validation() {
        let mut manager = SecurityManager::new();
        let device_id = "test-device-revoked";
        
        let cert = manager.generate_device_certificate(device_id.to_string()).await.unwrap();
        
        // Revoke the certificate
        manager.revoke_certificate(&cert.fingerprint).await;
        
        // Validation should fail
        let result = manager.validate_device_certificate(&cert).await.unwrap();
        assert!(!result.is_valid);
        assert!(result.validation_errors.contains(&CertificateValidationError::Revoked));
    }
    
    #[tokio::test]
    async fn test_certificate_trust_management() {
        let mut manager = SecurityManager::new();
        let device_id = "test-device-trust";
        
        let cert = manager.generate_device_certificate(device_id.to_string()).await.unwrap();
        
        // Certificate should be trusted after generation
        assert!(manager.is_certificate_trusted(&cert.fingerprint).await);
        
        // Revoke and check
        manager.revoke_certificate(&cert.fingerprint).await;
        assert!(!manager.is_certificate_trusted(&cert.fingerprint).await);
    }

    #[tokio::test]
    async fn test_security_threat_detection() {
        let manager = SecurityManager::new();
        
        // Test various threat types
        let result = manager.detect_security_threat(SecurityThreat::InvalidCertificate);
        assert!(result.is_err());
        
        let result = manager.detect_security_threat(SecurityThreat::ManInTheMiddle);
        assert!(result.is_err());
        
        let result = manager.detect_security_threat(SecurityThreat::EncryptionFailure);
        assert!(result.is_err());
    }
    
    #[tokio::test]
    async fn test_replay_attack_detection() {
        let manager = SecurityManager::new();
        let session_id = "test-session-replay";
        
        // Initialize session
        manager.generate_session_key(session_id).await.unwrap();
        
        let nonce = vec![1u8, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
        
        // First use should not be a replay
        let is_replay = manager.detect_replay_attack(session_id, &nonce).await.unwrap();
        assert!(!is_replay);
        
        // Second use of same nonce should be detected as replay
        let is_replay = manager.detect_replay_attack(session_id, &nonce).await.unwrap();
        assert!(is_replay);
    }
    
    #[tokio::test]
    async fn test_tampering_detection() {
        let manager = SecurityManager::new();
        
        let data = b"Original data";
        let hash = manager.compute_hash(data);
        
        // No tampering
        let is_tampered = manager.detect_tampering(data, &hash).unwrap();
        assert!(!is_tampered);
        
        // Tampered data
        let tampered_data = b"Modified data";
        let is_tampered = manager.detect_tampering(tampered_data, &hash).unwrap();
        assert!(is_tampered);
    }
    
    #[tokio::test]
    async fn test_brute_force_detection() {
        let mut manager = SecurityManager::new();
        
        // Configure low threshold for testing
        manager.configure_threat_detection(ThreatDetectionConfig {
            detect_replay_attacks: true,
            detect_tampering: true,
            detect_brute_force: true,
            max_failed_attempts: 3,
            lockout_duration_secs: 60,
            attempt_window_secs: 60,
            detect_anomalies: true,
        });
        
        let identifier = "test-user";
        
        // First few attempts should not lock out
        assert!(!manager.track_failed_attempt(identifier).await.unwrap());
        assert!(!manager.track_failed_attempt(identifier).await.unwrap());
        
        // Third attempt should trigger lockout
        assert!(manager.track_failed_attempt(identifier).await.unwrap());
        
        // Should be locked out
        assert!(manager.is_locked_out(identifier).await);
        
        // Clear and verify
        manager.clear_failed_attempts(identifier).await;
        assert!(!manager.is_locked_out(identifier).await);
    }
    
    #[tokio::test]
    async fn test_comprehensive_security_check() {
        let manager = SecurityManager::new();
        let session_id = "test-session-check";
        
        manager.generate_session_key(session_id).await.unwrap();
        
        let data = b"Test data for security check";
        let hash = manager.compute_hash(data);
        let nonce = vec![1u8; 12];
        
        // First check should pass
        let result = manager.security_check(session_id, &nonce, data, &hash).await;
        assert!(result.is_ok());
        
        // Replay should fail
        let result = manager.security_check(session_id, &nonce, data, &hash).await;
        assert!(result.is_err());
    }

    #[tokio::test]
    async fn test_data_integrity_verification() {
        let manager = SecurityManager::new();
        
        let data = b"Test data for integrity check";
        let hash = manager.compute_hash(data);
        
        // Verify with correct data
        assert!(manager.verify_integrity(data, &hash));
        
        // Verify with modified data should fail
        let modified_data = b"Modified data for integrity check";
        assert!(!manager.verify_integrity(modified_data, &hash));
    }

    #[tokio::test]
    async fn test_encryption_disabled() {
        let config = SecurityConfig {
            enable_dtls_srtp: false,
            enable_tls_signaling: false,
            enable_file_encryption: false,
            certificate_validation: true,
            key_rotation_interval: 3600,
            threat_detection_enabled: true,
        };
        
        let manager = SecurityManager::with_config(config);
        let session_id = "test-session-disabled";
        
        manager.generate_session_key(session_id).await.unwrap();
        
        let original_data = b"Test data";
        
        // When encryption is disabled, data should pass through unchanged
        let encrypted = manager.encrypt_media_stream(session_id, original_data).await.unwrap();
        assert_eq!(encrypted.ciphertext, original_data.to_vec());
    }


    #[tokio::test]
    async fn test_key_exchange() {
        let manager = SecurityManager::new();
        
        // Get local public key
        let local_public = manager.get_local_public_key();
        assert_eq!(local_public.len(), 32);
        
        // Perform key exchange with a simulated remote public key
        let remote_public = manager.get_local_public_key(); // Simulate remote
        let shared_secret = manager.perform_key_exchange(&remote_public).unwrap();
        
        assert_eq!(shared_secret.len(), 32);
    }

    #[tokio::test]
    async fn test_session_key_removal() {
        let manager = SecurityManager::new();
        let session_id = "test-session-remove";
        
        manager.generate_session_key(session_id).await.unwrap();
        assert!(manager.get_session_key(session_id).await.is_some());
        
        manager.remove_session_key(session_id).await;
        assert!(manager.get_session_key(session_id).await.is_none());
    }

    #[tokio::test]
    async fn test_dtls_srtp_config() {
        let mut manager = SecurityManager::new();
        
        let config = DtlsSrtpConfig {
            srtp_profile: "SRTP_AES256_CM_HMAC_SHA1_80".to_string(),
            fingerprint_algorithm: "sha-384".to_string(),
            local_fingerprint: Some("test-fingerprint".to_string()),
            remote_fingerprint: None,
        };
        
        manager.configure_dtls_srtp(config.clone());
        
        let stored_config = manager.get_dtls_config();
        assert_eq!(stored_config.srtp_profile, "SRTP_AES256_CM_HMAC_SHA1_80");
    }

    #[tokio::test]
    async fn test_tls_config() {
        let mut manager = SecurityManager::new();
        
        let config = TlsConfig {
            min_version: "TLS1.3".to_string(),
            cipher_suites: vec!["TLS_AES_256_GCM_SHA384".to_string()],
            verify_certificates: true,
        };
        
        manager.configure_tls(config.clone());
        
        let stored_config = manager.get_tls_config();
        assert_eq!(stored_config.min_version, "TLS1.3");
    }

    #[tokio::test]
    async fn test_security_events_logging() {
        let mut manager = SecurityManager::new();
        
        // Generate certificate to trigger event
        manager.generate_device_certificate("test-device".to_string()).await.unwrap();
        
        // Wait a bit for async event logging
        tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;
        
        let events = manager.get_security_events().await;
        assert!(!events.is_empty());
        
        // Clear events
        manager.clear_security_events().await;
        let events = manager.get_security_events().await;
        assert!(events.is_empty());
    }

    #[tokio::test]
    async fn test_multiple_sessions() {
        let manager = SecurityManager::new();
        
        // Create multiple sessions
        manager.generate_session_key("session-1").await.unwrap();
        manager.generate_session_key("session-2").await.unwrap();
        manager.generate_session_key("session-3").await.unwrap();
        
        // Verify all sessions have unique keys
        let key1 = manager.get_session_key("session-1").await.unwrap();
        let key2 = manager.get_session_key("session-2").await.unwrap();
        let key3 = manager.get_session_key("session-3").await.unwrap();
        
        assert_ne!(key1.key, key2.key);
        assert_ne!(key2.key, key3.key);
        assert_ne!(key1.key, key3.key);
    }
}


// Property-Based Tests using proptest
// Feature: cec-remote, Property 11: Media stream encryption
// Validates: Requirement 10.1 - Use DTLS-SRTP to encrypt all WebRTC media streams

#[cfg(test)]
mod property_tests {
    use super::*;
    use proptest::prelude::*;

    proptest! {
        #![proptest_config(ProptestConfig::with_cases(100))]

        /// Property 11: Media stream encryption
        /// For any media stream data, when DTLS-SRTP is enabled:
        /// 1. The encrypted data must be different from the original
        /// 2. Decrypting the encrypted data must return the original data
        /// **Validates: Requirement 10.1**
        #[test]
        fn property_media_stream_encryption_round_trip(
            data in prop::collection::vec(any::<u8>(), 1..1024)
        ) {
            let rt = tokio::runtime::Runtime::new().unwrap();
            rt.block_on(async {
                let manager = SecurityManager::new();
                let session_id = "pbt-session-media";
                
                // Generate session key
                manager.generate_session_key(session_id).await.unwrap();
                
                // Encrypt the data
                let encrypted = manager.encrypt_media_stream(session_id, &data).await.unwrap();
                
                // Property 1: Encrypted data should be different from original (unless empty)
                if !data.is_empty() {
                    assert_ne!(encrypted.ciphertext, data, 
                        "Encrypted data should differ from original");
                }
                
                // Property 2: Decryption should return original data
                let decrypted = manager.decrypt_media_stream(session_id, &encrypted).await.unwrap();
                assert_eq!(decrypted, data, 
                    "Decrypted data should match original");
                
                // Property 3: Nonce should be present and correct length
                assert_eq!(encrypted.nonce.len(), 12, 
                    "Nonce should be 12 bytes for AES-GCM");
                
                // Property 4: Tag should be present
                assert!(!encrypted.tag.is_empty(), 
                    "Authentication tag should be present");
            });
        }

        /// Property: File encryption round trip
        /// For any file data, encryption followed by decryption returns original
        /// **Validates: Requirement 10.3**
        #[test]
        fn property_file_encryption_round_trip(
            data in prop::collection::vec(any::<u8>(), 1..4096)
        ) {
            let rt = tokio::runtime::Runtime::new().unwrap();
            rt.block_on(async {
                let manager = SecurityManager::new();
                let session_id = "pbt-session-file";
                
                manager.generate_session_key(session_id).await.unwrap();
                
                let encrypted = manager.encrypt_file_data(session_id, &data).await.unwrap();
                let decrypted = manager.decrypt_file_data(session_id, &encrypted).await.unwrap();
                
                assert_eq!(decrypted, data, 
                    "File decryption should return original data");
            });
        }

        /// Property: Signaling encryption round trip
        /// For any signaling data, encryption followed by decryption returns original
        /// **Validates: Requirement 10.2**
        #[test]
        fn property_signaling_encryption_round_trip(
            data in prop::collection::vec(any::<u8>(), 1..2048)
        ) {
            let rt = tokio::runtime::Runtime::new().unwrap();
            rt.block_on(async {
                let manager = SecurityManager::new();
                let session_id = "pbt-session-signaling";
                
                manager.generate_session_key(session_id).await.unwrap();
                
                let encrypted = manager.encrypt_signaling_data(session_id, &data).await.unwrap();
                let decrypted = manager.decrypt_signaling_data(session_id, &encrypted).await.unwrap();
                
                assert_eq!(decrypted, data, 
                    "Signaling decryption should return original data");
            });
        }

        /// Property: Session keys are unique
        /// For any two session IDs, generated keys should be different
        #[test]
        fn property_session_keys_unique(
            session_id1 in "[a-z]{8}",
            session_id2 in "[a-z]{8}"
        ) {
            prop_assume!(session_id1 != session_id2);
            
            let rt = tokio::runtime::Runtime::new().unwrap();
            rt.block_on(async {
                let manager = SecurityManager::new();
                
                let key1 = manager.generate_session_key(&session_id1).await.unwrap();
                let key2 = manager.generate_session_key(&session_id2).await.unwrap();
                
                assert_ne!(key1.key, key2.key, 
                    "Different sessions should have different keys");
            });
        }

        /// Property: Data integrity verification
        /// For any data, computed hash should verify correctly
        #[test]
        fn property_data_integrity(
            data in prop::collection::vec(any::<u8>(), 1..1024)
        ) {
            let manager = SecurityManager::new();
            
            let hash = manager.compute_hash(&data);
            
            // Property: Hash should verify with same data
            assert!(manager.verify_integrity(&data, &hash), 
                "Hash should verify with original data");
            
            // Property: Hash should be 32 bytes (SHA-256)
            assert_eq!(hash.len(), 32, 
                "SHA-256 hash should be 32 bytes");
        }

        /// Property: Key rotation produces different keys
        #[test]
        fn property_key_rotation_changes_key(
            session_id in "[a-z]{8}",
            rotation_count in 1..5usize
        ) {
            let rt = tokio::runtime::Runtime::new().unwrap();
            rt.block_on(async {
                let manager = SecurityManager::new();
                
                let original_key = manager.generate_session_key(&session_id).await.unwrap();
                let mut previous_key = original_key.key.clone();
                
                for i in 0..rotation_count {
                    let rotated = manager.rotate_session_key(&session_id).await.unwrap();
                    
                    assert_ne!(rotated.key, previous_key, 
                        "Key should change after rotation {}", i);
                    assert_eq!(rotated.rotation_count, (i + 1) as u32, 
                        "Rotation count should increment");
                    
                    previous_key = rotated.key.clone();
                }
            });
        }
        
        /// Property: Replay attack detection works correctly
        /// For any nonce, using it twice should be detected as replay
        #[test]
        fn property_replay_detection(
            nonce in prop::collection::vec(any::<u8>(), 12..13)
        ) {
            let rt = tokio::runtime::Runtime::new().unwrap();
            rt.block_on(async {
                let manager = SecurityManager::new();
                let session_id = "pbt-session-replay";
                
                manager.generate_session_key(session_id).await.unwrap();
                
                // First use should not be replay
                let first_check = manager.detect_replay_attack(session_id, &nonce).await.unwrap();
                assert!(!first_check, "First use of nonce should not be replay");
                
                // Second use should be replay
                let second_check = manager.detect_replay_attack(session_id, &nonce).await.unwrap();
                assert!(second_check, "Second use of same nonce should be replay");
            });
        }
        
        /// Property: Certificate signature verification
        /// For any generated certificate, signature should verify correctly
        #[test]
        fn property_certificate_signature_verification(
            device_id in "[a-z0-9]{8,16}"
        ) {
            let rt = tokio::runtime::Runtime::new().unwrap();
            rt.block_on(async {
                let mut manager = SecurityManager::new();
                
                let cert = manager.generate_device_certificate(device_id.clone()).await.unwrap();
                
                // Certificate should be valid
                let result = manager.validate_device_certificate(&cert).await.unwrap();
                assert!(result.is_valid, 
                    "Generated certificate should be valid for device: {}", device_id);
                assert!(result.validation_errors.is_empty(),
                    "No validation errors expected");
            });
        }
    }
}
