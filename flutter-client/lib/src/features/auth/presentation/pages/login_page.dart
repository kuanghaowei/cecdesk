import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/services/authentication_service.dart';

/// Login page with multiple authentication methods
/// Validates: Requirements 17.x - Multiple login methods
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Phone login state
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _codeSent = false;
  int _countdown = 0;
  bool _isLoading = false;

  // QR code state
  QRCodeSession? _qrCodeSession;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    // If already logged in, redirect to main page
    if (authState.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/remote-control');
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('登录'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/settings'),
        ),
      ),
      body: Column(
        children: [
          // Tab bar for login methods
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'App扫码'),
              Tab(text: '微信扫码'),
              Tab(text: '手机号码'),
            ],
          ),
          
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAppQRCodeLogin(),
                _buildWeChatQRCodeLogin(),
                _buildPhoneLogin(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// App QR code login tab
  /// Validates: Requirements 17.1, 17.2, 17.3, 17.4, 17.5
  Widget _buildAppQRCodeLogin() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Text(
            '使用移动端App扫描二维码登录',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          
          // QR Code display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _qrCodeSession != null
                ? Column(
                    children: [
                      QrImageView(
                        data: _qrCodeSession!.qrCodeData,
                        version: QrVersions.auto,
                        size: 200,
                      ),
                      const SizedBox(height: 8),
                      if (_qrCodeSession!.isExpired)
                        const Text(
                          '二维码已过期',
                          style: TextStyle(color: Colors.red),
                        )
                      else
                        Text(
                          '有效期: ${_getRemainingTime(_qrCodeSession!.expiresAt)}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                    ],
                  )
                : const SizedBox(
                    width: 200,
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
          ),
          
          const SizedBox(height: 24),
          
          // Refresh button
          OutlinedButton.icon(
            onPressed: _generateAppQRCode,
            icon: const Icon(Icons.refresh),
            label: const Text('刷新二维码'),
          ),
          
          const SizedBox(height: 16),
          
          // Instructions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '使用说明',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text('1. 打开远程桌面移动端App'),
                  const Text('2. 点击"扫一扫"功能'),
                  const Text('3. 扫描上方二维码'),
                  const Text('4. 在手机上确认登录'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// WeChat QR code login tab
  /// Validates: Requirements 17.6, 17.7, 17.8, 17.9
  Widget _buildWeChatQRCodeLogin() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Text(
            '使用微信扫描二维码登录',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          
          // WeChat QR Code placeholder
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wechat,
                        size: 64,
                        color: Colors.green[600],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '微信登录',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '请使用微信扫描',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Generate WeChat QR code button
          ElevatedButton.icon(
            onPressed: _generateWeChatQRCode,
            icon: const Icon(Icons.qr_code),
            label: const Text('生成微信登录二维码'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Instructions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '使用说明',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text('1. 点击"生成微信登录二维码"'),
                  const Text('2. 打开微信扫一扫'),
                  const Text('3. 扫描二维码'),
                  const Text('4. 在微信中确认授权'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Phone number login tab
  /// Validates: Requirements 17.10, 17.11, 17.12, 17.13, 17.14, 17.15
  Widget _buildPhoneLogin() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text(
            '使用手机号码登录',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          // Phone number input
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: '手机号码',
              hintText: '请输入手机号码',
              prefixIcon: Icon(Icons.phone),
              prefixText: '+86 ',
            ),
            enabled: !_codeSent,
          ),
          
          const SizedBox(height: 16),
          
          // Verification code input
          if (_codeSent) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: '验证码',
                      hintText: '请输入6位验证码',
                      prefixIcon: Icon(Icons.lock),
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 120,
                  child: OutlinedButton(
                    onPressed: _countdown > 0 ? null : _sendVerificationCode,
                    child: Text(
                      _countdown > 0 ? '${_countdown}s' : '重新发送',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
          
          // Send code / Login button
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : (_codeSent ? _loginWithPhone : _sendVerificationCode),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_codeSent ? '登录' : '获取验证码'),
            ),
          ),
          
          if (_codeSent) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _codeSent = false;
                  _codeController.clear();
                });
              },
              child: const Text('更换手机号码'),
            ),
          ],
          
          const SizedBox(height: 32),
          
          // Tips
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '温馨提示',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• 验证码有效期为5分钟\n'
                    '• 连续输错5次将锁定30分钟\n'
                    '• 如未收到验证码，请检查手机号码是否正确',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAppQRCode() async {
    final authService = ref.read(authenticationServiceProvider);
    final session = await authService.generateQRCode();
    setState(() {
      _qrCodeSession = session;
    });
  }

  Future<void> _generateWeChatQRCode() async {
    final authService = ref.read(authenticationServiceProvider);
    final session = await authService.generateWeChatQRCode();
    setState(() {
      _qrCodeSession = session;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('微信登录二维码已生成')),
    );
  }

  Future<void> _sendVerificationCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入正确的手机号码')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = ref.read(authenticationServiceProvider);
      final success = await authService.sendSMSVerificationCode(phone);
      
      if (success) {
        setState(() {
          _codeSent = true;
          _countdown = 60;
        });
        _startCountdown();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('验证码已发送')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('发送失败，手机号码可能已被锁定')),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      
      setState(() {
        _countdown--;
      });
      return _countdown > 0;
    });
  }

  Future<void> _loginWithPhone() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入6位验证码')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authNotifier = ref.read(authStateProvider.notifier);
      await authNotifier.loginWithSMS(phone, code);
      
      final authState = ref.read(authStateProvider);
      if (authState.isLoggedIn) {
        if (mounted) {
          context.go('/remote-control');
        }
      } else if (authState.error != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(authState.error!)),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getRemainingTime(DateTime expiresAt) {
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return '已过期';
    
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
