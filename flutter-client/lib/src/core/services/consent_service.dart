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

  /// Get privacy policy content
  String getPrivacyPolicyContent() {
    return '''
用户隐私协议

版本: $currentPrivacyPolicyVersion
生效日期: 2024年1月1日

1. 信息收集
我们收集以下类型的信息：
- 设备信息（设备ID、操作系统版本）
- 网络信息（IP地址、连接状态）
- 使用数据（会话时长、功能使用情况）

2. 信息使用
我们使用收集的信息用于：
- 提供远程桌面服务
- 改善用户体验
- 技术支持和故障排除

3. 信息保护
我们采取以下措施保护您的信息：
- 端到端加密传输
- 安全存储机制
- 访问控制

4. 信息共享
我们不会向第三方出售您的个人信息。

5. 用户权利
您有权：
- 访问您的个人信息
- 删除您的账户和数据
- 撤回同意

如有疑问，请联系我们。
''';
  }

  /// Get license agreement content
  String getLicenseAgreementContent() {
    return '''
软件许可协议

版本: $currentLicenseAgreementVersion
生效日期: 2024年1月1日

1. 许可授予
本软件授予您非独占、不可转让的使用许可。

2. 使用限制
您不得：
- 反编译或逆向工程本软件
- 将本软件用于非法目的
- 未经授权分发本软件

3. 知识产权
本软件及其所有组件的知识产权归开发者所有。

4. 免责声明
本软件按"现状"提供，不提供任何明示或暗示的保证。

5. 责任限制
在法律允许的最大范围内，开发者不对任何间接、附带或后果性损害承担责任。

6. 终止
如果您违反本协议的任何条款，您的许可将自动终止。

7. 适用法律
本协议受中华人民共和国法律管辖。

使用本软件即表示您同意本协议的所有条款。
''';
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
