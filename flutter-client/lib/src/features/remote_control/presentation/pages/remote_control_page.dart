import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/services/device_management_service.dart';

/// Remote control main page
/// Validates: Requirements 20.x - Remote control main interface
class RemoteControlPage extends ConsumerStatefulWidget {
  const RemoteControlPage({super.key});

  @override
  ConsumerState<RemoteControlPage> createState() => _RemoteControlPageState();
}

class _RemoteControlPageState extends ConsumerState<RemoteControlPage> {
  final _targetDeviceCodeController = TextEditingController();
  final _targetPasswordController = TextEditingController();
  bool _isConnecting = false;
  String? _connectionError;

  @override
  void dispose() {
    _targetDeviceCodeController.dispose();
    _targetPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final deviceService = ref.watch(deviceManagementServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('远程控制'),
        actions: [
          // User info
          if (authState.isLoggedIn && authState.credentials != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  authState.credentials!.userId.substring(0, 8),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // This device section
            _buildThisDeviceSection(deviceService),
            
            const SizedBox(height: 24),
            
            // Connect to remote device section
            _buildConnectSection(),
          ],
        ),
      ),
    );
  }

  /// Build "This Device" section
  /// Validates: Requirements 20.1, 20.2, 20.3, 20.4, 20.5, 20.6, 20.7
  Widget _buildThisDeviceSection(DeviceManagementService deviceService) {
    return FutureBuilder<RemoteControlSettings>(
      future: deviceService.getRemoteControlSettings(),
      builder: (context, snapshot) {
        final settings = snapshot.data;
        
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.computer,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '本设备',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Allow remote control switch
                SwitchListTile(
                  title: const Text('允许控制本设备'),
                  subtitle: Text(
                    settings?.allowRemoteControl == true
                        ? '其他设备可以连接到本设备'
                        : '已禁止远程连接',
                  ),
                  value: settings?.allowRemoteControl ?? false,
                  onChanged: (value) async {
                    await deviceService.setAllowRemoteControl(value);
                    setState(() {});
                  },
                ),
                
                if (settings?.allowRemoteControl == true) ...[
                  const Divider(),
                  
                  // Device code
                  ListTile(
                    title: const Text('设备代码'),
                    subtitle: Text(
                      settings?.deviceCode ?? '加载中...',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontFamily: 'monospace',
                        letterSpacing: 2,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        if (settings?.deviceCode != null) {
                          Clipboard.setData(ClipboardData(text: settings!.deviceCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('设备代码已复制')),
                          );
                        }
                      },
                    ),
                  ),
                  
                  // Connection password
                  ListTile(
                    title: const Text('连接密码'),
                    subtitle: Text(
                      settings?.connectionPassword ?? '加载中...',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontFamily: 'monospace',
                        letterSpacing: 2,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () {
                            if (settings?.connectionPassword != null) {
                              Clipboard.setData(ClipboardData(text: settings!.connectionPassword));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('连接密码已复制')),
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () async {
                            await deviceService.refreshConnectionPassword();
                            setState(() {});
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('连接密码已刷新')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  const Divider(),
                  
                  // Screen lock password option
                  SwitchListTile(
                    title: const Text('控制本设备需校验本机锁屏密码'),
                    subtitle: const Text('增强安全性，连接前需验证'),
                    value: settings?.requireScreenLockPassword ?? false,
                    onChanged: (value) async {
                      await deviceService.setRequireScreenLockPassword(value);
                      setState(() {});
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build "Connect to Remote Device" section
  /// Validates: Requirements 20.8, 20.9, 20.10, 20.11, 20.12
  Widget _buildConnectSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.link,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '连接远程设备',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Target device code input
            TextField(
              controller: _targetDeviceCodeController,
              keyboardType: TextInputType.number,
              maxLength: 9,
              decoration: const InputDecoration(
                labelText: '目标设备代码',
                hintText: '请输入9位设备代码',
                prefixIcon: Icon(Icons.computer),
                counterText: '',
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Connection password input
            TextField(
              controller: _targetPasswordController,
              maxLength: 9,
              decoration: const InputDecoration(
                labelText: '连接密码',
                hintText: '请输入9位连接密码',
                prefixIcon: Icon(Icons.lock),
                counterText: '',
              ),
              inputFormatters: [
                LengthLimitingTextInputFormatter(9),
              ],
            ),
            
            if (_connectionError != null) ...[
              const SizedBox(height: 8),
              Text(
                _connectionError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Connect button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _canConnect && !_isConnecting ? _connectToDevice : null,
                icon: _isConnecting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(_isConnecting ? '连接中...' : '连接'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _canConnect {
    final deviceCode = _targetDeviceCodeController.text;
    final password = _targetPasswordController.text;
    return DeviceManagementService.isValidDeviceCode(deviceCode) &&
           DeviceManagementService.isValidConnectionPassword(password);
  }

  Future<void> _connectToDevice() async {
    setState(() {
      _isConnecting = true;
      _connectionError = null;
    });

    try {
      final deviceCode = _targetDeviceCodeController.text;
      final password = _targetPasswordController.text;
      
      // Validate inputs
      if (!DeviceManagementService.isValidDeviceCode(deviceCode)) {
        throw Exception('设备代码格式不正确');
      }
      if (!DeviceManagementService.isValidConnectionPassword(password)) {
        throw Exception('连接密码格式不正确');
      }

      // Simulate connection attempt
      await Future.delayed(const Duration(seconds: 2));
      
      // In real implementation, would establish WebRTC connection
      // For now, navigate to remote desktop page
      if (mounted) {
        context.go('/remote-desktop/$deviceCode');
      }
    } catch (e) {
      setState(() {
        _connectionError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final authNotifier = ref.read(authStateProvider.notifier);
              await authNotifier.logout();
              if (mounted) {
                context.go('/login');
              }
            },
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }
}
