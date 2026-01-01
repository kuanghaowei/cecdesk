import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/services/consent_service.dart';

/// Consent page for first-time users to accept privacy policy and license agreement
/// Validates: Requirements 17b.1, 17b.2, 17b.3, 17b.4, 17b.5, 17b.6, 17b.7, 17b.8
class ConsentPage extends ConsumerStatefulWidget {
  final VoidCallback onConsentAccepted;

  const ConsentPage({
    super.key,
    required this.onConsentAccepted,
  });

  @override
  ConsumerState<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends ConsumerState<ConsentPage> {
  bool _privacyPolicyChecked = false;
  bool _licenseAgreementChecked = false;
  bool _isLoading = false;

  bool get _canAccept => _privacyPolicyChecked && _licenseAgreementChecked;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // App logo and title
              Icon(
                Icons.desktop_windows,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                '远程桌面客户端',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '欢迎使用',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              
              // Consent section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '用户协议',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '在使用本应用之前，请阅读并同意以下协议：',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Privacy Policy checkbox
                      _buildConsentItem(
                        title: '用户隐私协议',
                        description: '了解我们如何收集、使用和保护您的个人信息',
                        checked: _privacyPolicyChecked,
                        onChanged: (value) {
                          setState(() {
                            _privacyPolicyChecked = value ?? false;
                          });
                        },
                        onViewPressed: () => _openPrivacyPolicy(),
                      ),
                      
                      const Divider(),
                      
                      // License Agreement checkbox
                      _buildConsentItem(
                        title: '软件许可协议',
                        description: '了解软件使用条款和限制',
                        checked: _licenseAgreementChecked,
                        onChanged: (value) {
                          setState(() {
                            _licenseAgreementChecked = value ?? false;
                          });
                        },
                        onViewPressed: () => _openLicenseAgreement(),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Accept button
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _canAccept && !_isLoading ? _acceptConsent : null,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('同意并继续'),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Decline button
              TextButton(
                onPressed: _isLoading ? null : _declineConsent,
                child: Text(
                  '不同意',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Version info
              Text(
                '隐私协议版本: ${ConsentService.currentPrivacyPolicyVersion}\n'
                '许可协议版本: ${ConsentService.currentLicenseAgreementVersion}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
              
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConsentItem({
    required String title,
    required String description,
    required bool checked,
    required ValueChanged<bool?> onChanged,
    required VoidCallback onViewPressed,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: checked,
          onChanged: onChanged,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  TextButton(
                    onPressed: onViewPressed,
                    child: const Text('查看'),
                  ),
                ],
              ),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _acceptConsent() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final consentNotifier = ref.read(consentStateProvider.notifier);
      await consentNotifier.acceptConsent();
      
      if (mounted) {
        widget.onConsentAccepted();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _declineConsent() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('您需要同意用户协议才能使用本应用。确定要退出吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // In real app, would exit the application
              // For now, just show a message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请同意协议以继续使用')),
              );
            },
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    // In real implementation, open privacy policy URL or show in-app
    _showPolicyDialog(
      title: '用户隐私协议',
      content: '''
用户隐私协议

版本: ${ConsentService.currentPrivacyPolicyVersion}
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
      ''',
    );
  }

  Future<void> _openLicenseAgreement() async {
    _showPolicyDialog(
      title: '软件许可协议',
      content: '''
软件许可协议

版本: ${ConsentService.currentLicenseAgreementVersion}
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
      ''',
    );
  }

  void _showPolicyDialog({required String title, required String content}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Text(content),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
