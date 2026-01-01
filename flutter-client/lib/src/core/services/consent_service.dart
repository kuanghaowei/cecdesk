import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'secure_storage_service.dart';

/// User consent information for privacy policy and license agreement
class ConsentInfo {
  final bool privacyPolicyAccepted;
  final bool licenseAgreementAccepted;
  final DateTime? consentTime;
  final String privacyPolicyVersion;
  final String licenseAgreementVersion;

  const ConsentInfo({
    required this.privacyPolicyAccepted,
    required this.licenseAgreementAccepted,
    this.consentTime,
    required this.privacyPolicyVersion,
    required this.licenseAgreementVersion,
  });

  bool get hasConsented => privacyPolicyAccepted && licenseAgreementAccepted;

  Map<String, dynamic> toJson() => {
    'privacyPolicyAccepted': privacyPolicyAccepted,
    'licenseAgreementAccepted': licenseAgreementAccepted,
    'consentTime': consentTime?.toIso8601String(),
    'privacyPolicyVersion': privacyPolicyVersion,
    'licenseAgreementVersion': licenseAgreementVersion,
  };

  factory ConsentInfo.fromJson(Map<String, dynamic> json) => ConsentInfo(
    privacyPolicyAccepted: json['privacyPolicyAccepted'] as bool? ?? false,
    licenseAgreementAccepted: json['licenseAgreementAccepted'] as bool? ?? false,
    consentTime: json['consentTime'] != null 
        ? DateTime.parse(json['consentTime'] as String)
        : null,
    privacyPolicyVersion: json['privacyPolicyVersion'] as String? ?? '',
    licenseAgreementVersion: json['licenseAgreementVersion'] as String? ?? '',
  );

  factory ConsentInfo.empty() => const ConsentInfo(
    privacyPolicyAccepted: false,
    licenseAgreementAccepted: false,
    privacyPolicyVersion: '',
    licenseAgreementVersion: '',
  );

  ConsentInfo copyWith({
    bool? privacyPolicyAccepted,
    bool? licenseAgreementAccepted,
    DateTime? consentTime,
    String? privacyPolicyVersion,
    String? licenseAgreementVersion,
  }) => ConsentInfo(
    privacyPolicyAccepted: privacyPolicyAccepted ?? this.privacyPolicyAccepted,
    licenseAgreementAccepted: licenseAgreementAccepted ?? this.licenseAgreementAccepted,
    consentTime: consentTime ?? this.consentTime,
    privacyPolicyVersion: privacyPolicyVersion ?? this.privacyPolicyVersion,
    licenseAgreementVersion: licenseAgreementVersion ?? this.licenseAgreementVersion,
  );
}

/// Service for managing user consent for privacy policy and license agreement
/// Validates: Requirements 17b.1, 17b.2, 17b.3, 17b.4, 17b.5, 17b.6, 17b.7, 17b.8
class ConsentService {
  static const String _consentKey = 'user_consent';
  static const String currentPrivacyPolicyVersion = '1.0.0';
  static const String currentLicenseAgreementVersion = '1.0.0';

  final SecureStorageService _secureStorage;

  ConsentService({required SecureStorageService secureStorage})
      : _secureStorage = secureStorage;

  /// Check if user has given consent
  /// Returns true if user has consented to current versions of both policies
  Future<bool> hasUserConsent() async {
    final consentInfo = await getConsentInfo();
    if (consentInfo == null) return false;
    
    return consentInfo.hasConsented &&
           consentInfo.privacyPolicyVersion == currentPrivacyPolicyVersion &&
           consentInfo.licenseAgreementVersion == currentLicenseAgreementVersion;
  }

  /// Record user consent
  /// Validates: Requirement 17b.5 - record consent status and time
  Future<void> recordUserConsent(ConsentInfo consent) async {
    final consentWithTime = consent.copyWith(
      consentTime: DateTime.now(),
      privacyPolicyVersion: currentPrivacyPolicyVersion,
      licenseAgreementVersion: currentLicenseAgreementVersion,
    );
    await _secureStorage.writeJson(_consentKey, consentWithTime.toJson());
  }

  /// Get current consent information
  Future<ConsentInfo?> getConsentInfo() async {
    final json = await _secureStorage.readJson(_consentKey);
    if (json == null) return null;
    return ConsentInfo.fromJson(json);
  }

  /// Check if consent update is needed due to policy version changes
  /// Validates: Requirement 17b.7 - re-show consent on policy update
  Future<bool> needsConsentUpdate(String currentVersion) async {
    final consentInfo = await getConsentInfo();
    if (consentInfo == null) return true;
    
    return consentInfo.privacyPolicyVersion != currentPrivacyPolicyVersion ||
           consentInfo.licenseAgreementVersion != currentLicenseAgreementVersion;
  }

  /// Clear consent (for testing or user request)
  Future<void> clearConsent() async {
    await _secureStorage.delete(_consentKey);
  }

  /// Check if this is first launch (no consent record exists)
  Future<bool> isFirstLaunch() async {
    return !await _secureStorage.containsKey(_consentKey);
  }
}

/// Consent state for UI
class ConsentState {
  final bool isLoading;
  final bool hasConsented;
  final bool needsUpdate;
  final ConsentInfo? consentInfo;
  final String? error;

  const ConsentState({
    this.isLoading = false,
    this.hasConsented = false,
    this.needsUpdate = false,
    this.consentInfo,
    this.error,
  });

  ConsentState copyWith({
    bool? isLoading,
    bool? hasConsented,
    bool? needsUpdate,
    ConsentInfo? consentInfo,
    String? error,
  }) => ConsentState(
    isLoading: isLoading ?? this.isLoading,
    hasConsented: hasConsented ?? this.hasConsented,
    needsUpdate: needsUpdate ?? this.needsUpdate,
    consentInfo: consentInfo ?? this.consentInfo,
    error: error,
  );
}

/// State notifier for consent management
class ConsentStateNotifier extends StateNotifier<ConsentState> {
  final ConsentService _consentService;

  ConsentStateNotifier(this._consentService) : super(const ConsentState()) {
    _checkConsent();
  }

  Future<void> _checkConsent() async {
    state = state.copyWith(isLoading: true);
    try {
      final hasConsent = await _consentService.hasUserConsent();
      final needsUpdate = await _consentService.needsConsentUpdate(
        ConsentService.currentPrivacyPolicyVersion,
      );
      final consentInfo = await _consentService.getConsentInfo();
      
      state = state.copyWith(
        isLoading: false,
        hasConsented: hasConsent,
        needsUpdate: needsUpdate,
        consentInfo: consentInfo,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> acceptConsent() async {
    state = state.copyWith(isLoading: true);
    try {
      final consent = ConsentInfo(
        privacyPolicyAccepted: true,
        licenseAgreementAccepted: true,
        consentTime: DateTime.now(),
        privacyPolicyVersion: ConsentService.currentPrivacyPolicyVersion,
        licenseAgreementVersion: ConsentService.currentLicenseAgreementVersion,
      );
      await _consentService.recordUserConsent(consent);
      
      state = state.copyWith(
        isLoading: false,
        hasConsented: true,
        needsUpdate: false,
        consentInfo: consent,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    await _checkConsent();
  }
}
