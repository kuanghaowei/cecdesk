import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:remote_desktop_client/src/core/services/consent_service.dart';
import 'package:remote_desktop_client/src/core/services/secure_storage_service.dart';

/// Property-based tests for ConsentService
/// Feature: remote-desktop-client
/// Validates: Requirements 17b.1, 17b.4, 17b.5, 17b.7

void main() {
  late SecureStorageService secureStorage;
  late ConsentService consentService;

  setUp(() async {
    // Initialize SharedPreferences with empty values for testing
    SharedPreferences.setMockInitialValues({});
    secureStorage = SecureStorageService();
    consentService = ConsentService(secureStorage: secureStorage);
  });

  tearDown(() async {
    await consentService.clearConsent();
  });

  group('ConsentService Property Tests', () {
    /// Property 45: First launch consent requirement
    /// *For any* first-time user launching the client, the system should show
    /// the privacy policy and license agreement consent interface
    /// **Validates: Requirement 17b.1**
    test('Property 45: First launch shows consent requirement', () async {
      // Feature: remote-desktop-client, Property 45: First launch consent requirement
      
      const iterations = 100;
      final random = Random();
      
      for (var i = 0; i < iterations; i++) {
        // Clear any existing consent
        await consentService.clearConsent();
        
        // Property: For any fresh state, hasUserConsent should return false
        final hasConsent = await consentService.hasUserConsent();
        expect(hasConsent, isFalse,
            reason: 'First launch should require consent (iteration $i)');
        
        // Property: For any fresh state, isFirstLaunch should return true
        final isFirstLaunch = await consentService.isFirstLaunch();
        expect(isFirstLaunch, isTrue,
            reason: 'Should detect first launch (iteration $i)');
      }
    });

    /// Property 46: Consent required to use app
    /// *For any* user who has not agreed to the policies, the system should
    /// prevent them from using client features
    /// **Validates: Requirement 17b.4**
    test('Property 46: Consent required to use app', () async {
      // Feature: remote-desktop-client, Property 46: Consent required to use app
      
      const iterations = 100;
      final random = Random();
      
      for (var i = 0; i < iterations; i++) {
        // Clear consent
        await consentService.clearConsent();
        
        // Generate random partial consent states
        final privacyAccepted = random.nextBool();
        final licenseAccepted = random.nextBool();
        
        if (privacyAccepted || licenseAccepted) {
          // Record partial consent
          final partialConsent = ConsentInfo(
            privacyPolicyAccepted: privacyAccepted,
            licenseAgreementAccepted: licenseAccepted,
            consentTime: DateTime.now(),
            privacyPolicyVersion: ConsentService.currentPrivacyPolicyVersion,
            licenseAgreementVersion: ConsentService.currentLicenseAgreementVersion,
          );
          await consentService.recordUserConsent(partialConsent);
        }
        
        final hasConsent = await consentService.hasUserConsent();
        
        // Property: Only when BOTH policies are accepted should hasConsent be true
        if (privacyAccepted && licenseAccepted) {
          expect(hasConsent, isTrue,
              reason: 'Full consent should allow usage (iteration $i)');
        } else {
          expect(hasConsent, isFalse,
              reason: 'Partial consent should not allow usage (iteration $i, privacy=$privacyAccepted, license=$licenseAccepted)');
        }
      }
    });

    /// Property 47: Consent state recording
    /// *For any* user consent action, the system should record the consent
    /// status and consent time
    /// **Validates: Requirement 17b.5**
    test('Property 47: Consent state recording', () async {
      // Feature: remote-desktop-client, Property 47: Consent state recording
      
      const iterations = 100;
      
      for (var i = 0; i < iterations; i++) {
        // Clear previous consent
        await consentService.clearConsent();
        
        final beforeConsent = DateTime.now();
        
        // Record full consent
        final consent = ConsentInfo(
          privacyPolicyAccepted: true,
          licenseAgreementAccepted: true,
          consentTime: DateTime.now(),
          privacyPolicyVersion: ConsentService.currentPrivacyPolicyVersion,
          licenseAgreementVersion: ConsentService.currentLicenseAgreementVersion,
        );
        await consentService.recordUserConsent(consent);
        
        final afterConsent = DateTime.now();
        
        // Retrieve recorded consent
        final recordedConsent = await consentService.getConsentInfo();
        
        // Property: Consent info should be persisted
        expect(recordedConsent, isNotNull,
            reason: 'Consent should be recorded (iteration $i)');
        
        // Property: Consent status should match what was recorded
        expect(recordedConsent!.privacyPolicyAccepted, isTrue,
            reason: 'Privacy policy acceptance should be recorded (iteration $i)');
        expect(recordedConsent.licenseAgreementAccepted, isTrue,
            reason: 'License agreement acceptance should be recorded (iteration $i)');
        
        // Property: Consent time should be recorded and within expected range
        expect(recordedConsent.consentTime, isNotNull,
            reason: 'Consent time should be recorded (iteration $i)');
        expect(
          recordedConsent.consentTime!.isAfter(beforeConsent.subtract(const Duration(seconds: 1))) &&
          recordedConsent.consentTime!.isBefore(afterConsent.add(const Duration(seconds: 1))),
          isTrue,
          reason: 'Consent time should be within expected range (iteration $i)',
        );
        
        // Property: Version should be recorded
        expect(recordedConsent.privacyPolicyVersion, equals(ConsentService.currentPrivacyPolicyVersion),
            reason: 'Privacy policy version should be recorded (iteration $i)');
        expect(recordedConsent.licenseAgreementVersion, equals(ConsentService.currentLicenseAgreementVersion),
            reason: 'License agreement version should be recorded (iteration $i)');
      }
    });

    /// Property 48: Policy update requires re-consent
    /// *For any* policy content update, the system should re-show the consent
    /// interface on next launch
    /// **Validates: Requirement 17b.7**
    test('Property 48: Policy update requires re-consent', () async {
      // Feature: remote-desktop-client, Property 48: Policy update requires re-consent
      
      const iterations = 100;
      final random = Random();
      
      for (var i = 0; i < iterations; i++) {
        // Clear previous consent
        await consentService.clearConsent();
        
        // Generate random old version numbers
        final oldPrivacyVersion = '${random.nextInt(10)}.${random.nextInt(10)}.${random.nextInt(10)}';
        final oldLicenseVersion = '${random.nextInt(10)}.${random.nextInt(10)}.${random.nextInt(10)}';
        
        // Record consent with old versions
        final oldConsent = ConsentInfo(
          privacyPolicyAccepted: true,
          licenseAgreementAccepted: true,
          consentTime: DateTime.now(),
          privacyPolicyVersion: oldPrivacyVersion,
          licenseAgreementVersion: oldLicenseVersion,
        );
        
        // Directly write to storage to simulate old consent
        await secureStorage.writeJson('user_consent', oldConsent.toJson());
        
        // Check if update is needed
        final needsUpdate = await consentService.needsConsentUpdate(
          ConsentService.currentPrivacyPolicyVersion,
        );
        
        // Property: If versions don't match current, re-consent is needed
        final versionsMatch = 
            oldPrivacyVersion == ConsentService.currentPrivacyPolicyVersion &&
            oldLicenseVersion == ConsentService.currentLicenseAgreementVersion;
        
        if (versionsMatch) {
          expect(needsUpdate, isFalse,
              reason: 'Matching versions should not require re-consent (iteration $i)');
        } else {
          expect(needsUpdate, isTrue,
              reason: 'Different versions should require re-consent (iteration $i, old privacy=$oldPrivacyVersion, old license=$oldLicenseVersion)');
        }
        
        // Property: hasUserConsent should return false if versions don't match
        final hasConsent = await consentService.hasUserConsent();
        if (versionsMatch) {
          expect(hasConsent, isTrue,
              reason: 'Matching versions should have valid consent (iteration $i)');
        } else {
          expect(hasConsent, isFalse,
              reason: 'Different versions should invalidate consent (iteration $i)');
        }
      }
    });

    /// Additional property: Consent persistence across service instances
    test('Consent persists across service instances', () async {
      // Feature: remote-desktop-client, Property: Consent persistence
      
      const iterations = 50;
      
      for (var i = 0; i < iterations; i++) {
        // Clear previous consent
        await consentService.clearConsent();
        
        // Record consent with first service instance
        final consent = ConsentInfo(
          privacyPolicyAccepted: true,
          licenseAgreementAccepted: true,
          consentTime: DateTime.now(),
          privacyPolicyVersion: ConsentService.currentPrivacyPolicyVersion,
          licenseAgreementVersion: ConsentService.currentLicenseAgreementVersion,
        );
        await consentService.recordUserConsent(consent);
        
        // Create new service instance (simulating app restart)
        final newConsentService = ConsentService(secureStorage: secureStorage);
        
        // Property: Consent should persist across service instances
        final hasConsent = await newConsentService.hasUserConsent();
        expect(hasConsent, isTrue,
            reason: 'Consent should persist across service instances (iteration $i)');
        
        final recordedConsent = await newConsentService.getConsentInfo();
        expect(recordedConsent, isNotNull,
            reason: 'Consent info should be retrievable from new instance (iteration $i)');
        expect(recordedConsent!.hasConsented, isTrue,
            reason: 'Consent status should be preserved (iteration $i)');
      }
    });

    /// Additional property: Clear consent removes all consent data
    test('Clear consent removes all data', () async {
      // Feature: remote-desktop-client, Property: Clear consent
      
      const iterations = 50;
      
      for (var i = 0; i < iterations; i++) {
        // Record consent
        final consent = ConsentInfo(
          privacyPolicyAccepted: true,
          licenseAgreementAccepted: true,
          consentTime: DateTime.now(),
          privacyPolicyVersion: ConsentService.currentPrivacyPolicyVersion,
          licenseAgreementVersion: ConsentService.currentLicenseAgreementVersion,
        );
        await consentService.recordUserConsent(consent);
        
        // Verify consent exists
        var hasConsent = await consentService.hasUserConsent();
        expect(hasConsent, isTrue);
        
        // Clear consent
        await consentService.clearConsent();
        
        // Property: After clearing, consent should not exist
        hasConsent = await consentService.hasUserConsent();
        expect(hasConsent, isFalse,
            reason: 'Consent should be cleared (iteration $i)');
        
        final consentInfo = await consentService.getConsentInfo();
        expect(consentInfo, isNull,
            reason: 'Consent info should be null after clearing (iteration $i)');
        
        final isFirstLaunch = await consentService.isFirstLaunch();
        expect(isFirstLaunch, isTrue,
            reason: 'Should appear as first launch after clearing (iteration $i)');
      }
    });
  });
}
