import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'secure_storage_service.dart';

/// Login method enumeration
enum LoginMethod {
  appQRCode,
  wechatQRCode,
  phoneNumber,
  wechatOneClick,
  carrierOneClick,
}

/// QR Code status enumeration
enum QRCodeStatus {
  pending,
  scanned,
  confirmed,
  expired,
  cancelled,
}

/// Login credentials stored securely
class LoginCredentials {
  final String userId;
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final LoginMethod method;
  final DateTime createdAt;

  const LoginCredentials({
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.method,
    required this.createdAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  
  /// Check if session is inactive for more than 30 days
  /// Validates: Requirement 18.6
  bool get isInactiveExpired {
    final now = DateTime.now();
    final daysSinceCreation = now.difference(createdAt).inDays;
    return daysSinceCreation > 30;
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.toIso8601String(),
    'method': method.name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory LoginCredentials.fromJson(Map<String, dynamic> json) => LoginCredentials(
    userId: json['userId'] as String,
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    expiresAt: DateTime.parse(json['expiresAt'] as String),
    method: LoginMethod.values.firstWhere(
      (e) => e.name == json['method'],
      orElse: () => LoginMethod.phoneNumber,
    ),
    createdAt: json['createdAt'] != null 
        ? DateTime.parse(json['createdAt'] as String)
        : DateTime.now(),
  );
}

/// QR Code session for App/WeChat scan login
class QRCodeSession {
  final String sessionId;
  final String qrCodeData;
  final DateTime expiresAt;
  final QRCodeStatus status;

  const QRCodeSession({
    required this.sessionId,
    required this.qrCodeData,
    required this.expiresAt,
    required this.status,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  QRCodeSession copyWith({
    String? sessionId,
    String? qrCodeData,
    DateTime? expiresAt,
    QRCodeStatus? status,
  }) => QRCodeSession(
    sessionId: sessionId ?? this.sessionId,
    qrCodeData: qrCodeData ?? this.qrCodeData,
    expiresAt: expiresAt ?? this.expiresAt,
    status: status ?? this.status,
  );
}

/// Login result
class LoginResult {
  final bool success;
  final String? userId;
  final String? accessToken;
  final String? refreshToken;
  final String? errorMessage;
  final LoginMethod? method;

  const LoginResult({
    required this.success,
    this.userId,
    this.accessToken,
    this.refreshToken,
    this.errorMessage,
    this.method,
  });

  factory LoginResult.success({
    required String userId,
    required String accessToken,
    required String refreshToken,
    required LoginMethod method,
  }) => LoginResult(
    success: true,
    userId: userId,
    accessToken: accessToken,
    refreshToken: refreshToken,
    method: method,
  );

  factory LoginResult.failure(String errorMessage) => LoginResult(
    success: false,
    errorMessage: errorMessage,
  );
}

/// SMS verification code tracking
class SMSVerificationState {
  final String phoneNumber;
  final DateTime sentAt;
  final DateTime expiresAt;
  final int failedAttempts;
  final DateTime? lockedUntil;

  const SMSVerificationState({
    required this.phoneNumber,
    required this.sentAt,
    required this.expiresAt,
    this.failedAttempts = 0,
    this.lockedUntil,
  });

  /// Check if verification code is expired (5 minutes)
  /// Validates: Requirement 17.15
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Check if phone number is locked (30 minutes after 5 failed attempts)
  /// Validates: Requirement 17.14
  bool get isLocked => lockedUntil != null && DateTime.now().isBefore(lockedUntil!);

  SMSVerificationState copyWith({
    String? phoneNumber,
    DateTime? sentAt,
    DateTime? expiresAt,
    int? failedAttempts,
    DateTime? lockedUntil,
  }) => SMSVerificationState(
    phoneNumber: phoneNumber ?? this.phoneNumber,
    sentAt: sentAt ?? this.sentAt,
    expiresAt: expiresAt ?? this.expiresAt,
    failedAttempts: failedAttempts ?? this.failedAttempts,
    lockedUntil: lockedUntil,
  );
}

/// Authentication service for handling all login methods
/// Validates: Requirements 17.x, 17a.x, 18.x
class AuthenticationService {
  static const String _credentialsKey = 'login_credentials';
  // ignore: unused_field
  static const String _smsStateKey = 'sms_verification_state';
  // ignore: unused_field
  static const String _loginAttemptsKey = 'login_attempts';
  
  /// QR code expiration time (5 minutes)
  /// Validates: Requirement 17.5
  static const Duration qrCodeExpiration = Duration(minutes: 5);
  
  /// SMS verification code expiration time (5 minutes)
  /// Validates: Requirement 17.15
  static const Duration smsCodeExpiration = Duration(minutes: 5);
  
  /// Phone number lock duration after 5 failed attempts (30 minutes)
  /// Validates: Requirement 17.14
  static const Duration phoneLockDuration = Duration(minutes: 30);
  
  /// Maximum SMS verification attempts before lock
  static const int maxSMSAttempts = 5;
  
  /// Maximum login attempts before account lock
  /// Validates: Requirement 18.7
  static const int maxLoginAttempts = 10;

  final SecureStorageService _secureStorage;
  final Map<String, SMSVerificationState> _smsStates = {};
  final Map<String, int> _loginAttempts = {};
  final Map<String, DateTime> _accountLocks = {};

  AuthenticationService({required SecureStorageService secureStorage})
      : _secureStorage = secureStorage;

  // ============ QR Code Login (App Scan) ============

  /// Generate QR code for App scan login
  /// Validates: Requirement 17.1
  Future<QRCodeSession> generateQRCode() async {
    final sessionId = _generateSessionId();
    final qrCodeData = 'remote-desktop://login?session=$sessionId';
    final expiresAt = DateTime.now().add(qrCodeExpiration);

    return QRCodeSession(
      sessionId: sessionId,
      qrCodeData: qrCodeData,
      expiresAt: expiresAt,
      status: QRCodeStatus.pending,
    );
  }

  /// Watch QR code status changes
  Stream<QRCodeStatus> watchQRCodeStatus(String sessionId) async* {
    // In real implementation, this would poll the server
    // For now, simulate status changes
    yield QRCodeStatus.pending;
  }

  /// Confirm QR code login from mobile app
  /// Validates: Requirement 17.4
  Future<LoginResult> confirmQRCodeLogin(String sessionId, String userId) async {
    // Simulate server confirmation
    final accessToken = _generateToken();
    final refreshToken = _generateToken();
    
    final credentials = LoginCredentials(
      userId: userId,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: DateTime.now().add(const Duration(days: 7)),
      method: LoginMethod.appQRCode,
      createdAt: DateTime.now(),
    );
    
    await saveCredentials(credentials);
    
    return LoginResult.success(
      userId: userId,
      accessToken: accessToken,
      refreshToken: refreshToken,
      method: LoginMethod.appQRCode,
    );
  }

  // ============ WeChat QR Code Login ============

  /// Generate WeChat OAuth QR code
  /// Validates: Requirement 17.6
  Future<QRCodeSession> generateWeChatQRCode() async {
    final sessionId = _generateSessionId();
    // In real implementation, this would call WeChat OAuth API
    final qrCodeData = 'https://open.weixin.qq.com/connect/qrconnect?appid=xxx&state=$sessionId';
    final expiresAt = DateTime.now().add(qrCodeExpiration);

    return QRCodeSession(
      sessionId: sessionId,
      qrCodeData: qrCodeData,
      expiresAt: expiresAt,
      status: QRCodeStatus.pending,
    );
  }

  /// Handle WeChat OAuth callback
  /// Validates: Requirement 17.7, 17.8
  Future<LoginResult> handleWeChatCallback(String code) async {
    try {
      // In real implementation, exchange code for access token with WeChat API
      final userId = 'wechat_${_generateSessionId()}';
      final accessToken = _generateToken();
      final refreshToken = _generateToken();
      
      final credentials = LoginCredentials(
        userId: userId,
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: DateTime.now().add(const Duration(days: 7)),
        method: LoginMethod.wechatQRCode,
        createdAt: DateTime.now(),
      );
      
      await saveCredentials(credentials);
      
      return LoginResult.success(
        userId: userId,
        accessToken: accessToken,
        refreshToken: refreshToken,
        method: LoginMethod.wechatQRCode,
      );
    } catch (e) {
      return LoginResult.failure('WeChat authorization failed: $e');
    }
  }

  // ============ Phone Number Login ============

  /// Send SMS verification code
  /// Validates: Requirement 17.11
  Future<bool> sendSMSVerificationCode(String phoneNumber) async {
    // Check if phone number is locked
    final existingState = _smsStates[phoneNumber];
    if (existingState != null && existingState.isLocked) {
      return false;
    }

    // In real implementation, call SMS API
    final state = SMSVerificationState(
      phoneNumber: phoneNumber,
      sentAt: DateTime.now(),
      expiresAt: DateTime.now().add(smsCodeExpiration),
      failedAttempts: 0,
    );
    
    _smsStates[phoneNumber] = state;
    return true;
  }

  /// Verify SMS code and login
  /// Validates: Requirement 17.13, 17.14, 17.15
  Future<LoginResult> verifySMSCode(String phoneNumber, String code) async {
    final state = _smsStates[phoneNumber];
    
    if (state == null) {
      return LoginResult.failure('No verification code sent');
    }
    
    if (state.isLocked) {
      return LoginResult.failure('Phone number is locked. Try again later.');
    }
    
    if (state.isExpired) {
      return LoginResult.failure('Verification code expired');
    }

    // In real implementation, verify code with server
    // For demo, accept any 6-digit code
    if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
      // Increment failed attempts
      final newState = state.copyWith(
        failedAttempts: state.failedAttempts + 1,
        lockedUntil: state.failedAttempts + 1 >= maxSMSAttempts
            ? DateTime.now().add(phoneLockDuration)
            : null,
      );
      _smsStates[phoneNumber] = newState;
      
      if (newState.isLocked) {
        return LoginResult.failure('Too many failed attempts. Phone number locked for 30 minutes.');
      }
      return LoginResult.failure('Invalid verification code');
    }

    // Success - create session
    final userId = 'phone_$phoneNumber';
    final accessToken = _generateToken();
    final refreshToken = _generateToken();
    
    final credentials = LoginCredentials(
      userId: userId,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: DateTime.now().add(const Duration(days: 7)),
      method: LoginMethod.phoneNumber,
      createdAt: DateTime.now(),
    );
    
    await saveCredentials(credentials);
    _smsStates.remove(phoneNumber);
    
    return LoginResult.success(
      userId: userId,
      accessToken: accessToken,
      refreshToken: refreshToken,
      method: LoginMethod.phoneNumber,
    );
  }

  // ============ Mobile One-Click Login ============

  /// WeChat one-click login for mobile
  /// Validates: Requirement 17a.1, 17a.2
  Future<LoginResult> wechatOneClickLogin() async {
    try {
      // In real implementation, call WeChat SDK
      final userId = 'wechat_mobile_${_generateSessionId()}';
      final accessToken = _generateToken();
      final refreshToken = _generateToken();
      
      final credentials = LoginCredentials(
        userId: userId,
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: DateTime.now().add(const Duration(days: 7)),
        method: LoginMethod.wechatOneClick,
        createdAt: DateTime.now(),
      );
      
      await saveCredentials(credentials);
      
      return LoginResult.success(
        userId: userId,
        accessToken: accessToken,
        refreshToken: refreshToken,
        method: LoginMethod.wechatOneClick,
      );
    } catch (e) {
      return LoginResult.failure('WeChat one-click login failed: $e');
    }
  }

  /// Carrier one-click login for mobile
  /// Validates: Requirement 17a.4, 17a.5, 17a.6
  Future<LoginResult> carrierOneClickLogin() async {
    try {
      // In real implementation, call carrier SDK
      final userId = 'carrier_${_generateSessionId()}';
      final accessToken = _generateToken();
      final refreshToken = _generateToken();
      
      final credentials = LoginCredentials(
        userId: userId,
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: DateTime.now().add(const Duration(days: 7)),
        method: LoginMethod.carrierOneClick,
        createdAt: DateTime.now(),
      );
      
      await saveCredentials(credentials);
      
      return LoginResult.success(
        userId: userId,
        accessToken: accessToken,
        refreshToken: refreshToken,
        method: LoginMethod.carrierOneClick,
      );
    } catch (e) {
      // Validates: Requirement 17a.6 - fallback to SMS on failure
      return LoginResult.failure('Carrier login failed. Please use SMS verification.');
    }
  }

  // ============ Session Management ============

  /// Get current login session
  Future<LoginCredentials?> getCurrentSession() async {
    final json = await _secureStorage.readJson(_credentialsKey);
    if (json == null) return null;
    
    final credentials = LoginCredentials.fromJson(json);
    
    // Check if session is expired due to inactivity
    if (credentials.isInactiveExpired) {
      await logout();
      return null;
    }
    
    return credentials;
  }

  /// Refresh session token
  /// Validates: Requirement 18.5
  Future<LoginCredentials?> refreshSession() async {
    final current = await getCurrentSession();
    if (current == null) return null;

    // In real implementation, call refresh token API
    final newCredentials = LoginCredentials(
      userId: current.userId,
      accessToken: _generateToken(),
      refreshToken: _generateToken(),
      expiresAt: DateTime.now().add(const Duration(days: 7)),
      method: current.method,
      createdAt: DateTime.now(),
    );
    
    await saveCredentials(newCredentials);
    return newCredentials;
  }

  /// Logout and clear session
  /// Validates: Requirement 17.18
  Future<void> logout() async {
    await _secureStorage.delete(_credentialsKey);
  }

  /// Save credentials securely
  /// Validates: Requirement 17.16, 18.2
  Future<void> saveCredentials(LoginCredentials credentials) async {
    await _secureStorage.writeJson(_credentialsKey, credentials.toJson());
  }

  /// Load credentials
  Future<LoginCredentials?> loadCredentials() async {
    return getCurrentSession();
  }

  /// Clear all credentials
  Future<void> clearCredentials() async {
    await logout();
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final session = await getCurrentSession();
    return session != null && !session.isExpired;
  }

  // ============ Account Security ============

  /// Record login attempt for account lock mechanism
  /// Validates: Requirement 18.7
  void recordLoginAttempt(String identifier, bool success) {
    if (success) {
      _loginAttempts.remove(identifier);
      _accountLocks.remove(identifier);
    } else {
      final attempts = (_loginAttempts[identifier] ?? 0) + 1;
      _loginAttempts[identifier] = attempts;
      
      if (attempts >= maxLoginAttempts) {
        _accountLocks[identifier] = DateTime.now().add(const Duration(hours: 1));
      }
    }
  }

  /// Check if account is locked
  bool isAccountLocked(String identifier) {
    final lockUntil = _accountLocks[identifier];
    if (lockUntil == null) return false;
    
    if (DateTime.now().isAfter(lockUntil)) {
      _accountLocks.remove(identifier);
      _loginAttempts.remove(identifier);
      return false;
    }
    return true;
  }

  // ============ Helper Methods ============

  String _generateSessionId() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  String _generateToken() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

/// Authentication state for UI
class AuthState {
  final bool isLoading;
  final bool isLoggedIn;
  final LoginCredentials? credentials;
  final String? error;
  final QRCodeSession? qrCodeSession;

  const AuthState({
    this.isLoading = false,
    this.isLoggedIn = false,
    this.credentials,
    this.error,
    this.qrCodeSession,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isLoggedIn,
    LoginCredentials? credentials,
    String? error,
    QRCodeSession? qrCodeSession,
  }) => AuthState(
    isLoading: isLoading ?? this.isLoading,
    isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    credentials: credentials ?? this.credentials,
    error: error,
    qrCodeSession: qrCodeSession ?? this.qrCodeSession,
  );
}

/// State notifier for authentication
class AuthStateNotifier extends StateNotifier<AuthState> {
  final AuthenticationService _authService;

  AuthStateNotifier(this._authService) : super(const AuthState()) {
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    state = state.copyWith(isLoading: true);
    try {
      final credentials = await _authService.getCurrentSession();
      state = state.copyWith(
        isLoading: false,
        isLoggedIn: credentials != null,
        credentials: credentials,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> generateQRCode() async {
    state = state.copyWith(isLoading: true);
    try {
      final session = await _authService.generateQRCode();
      state = state.copyWith(
        isLoading: false,
        qrCodeSession: session,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loginWithSMS(String phoneNumber, String code) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _authService.verifySMSCode(phoneNumber, code);
      if (result.success) {
        final credentials = await _authService.getCurrentSession();
        state = state.copyWith(
          isLoading: false,
          isLoggedIn: true,
          credentials: credentials,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result.errorMessage,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    try {
      await _authService.logout();
      state = const AuthState(isLoading: false, isLoggedIn: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    await _checkLoginStatus();
  }
}
