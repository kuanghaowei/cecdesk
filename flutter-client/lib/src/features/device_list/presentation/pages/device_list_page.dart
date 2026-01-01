import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/services/device_management_service.dart';

/// Device list page for managing connected devices
/// Validates: Requirements 21.x - Device list management
class DeviceListPage extends ConsumerStatefulWidget {
  const DeviceListPage({super.key});

  @override
  ConsumerState<DeviceListPage> createState() => _DeviceListPageState();
}

class _DeviceListPageState extends ConsumerState<DeviceListPage> {
  List<DeviceRecord> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final deviceService = ref.read(deviceManagementServiceProvider);
      final devices = await deviceService.getDeviceList();
      
      setState(() {
        _devices = devices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设备列表'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDevices,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
              ? _buildEmptyState()
              : _buildDeviceList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.devices_other,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无设备',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '连接过的设备会显示在这里',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/remote-control'),
            icon: const Icon(Icons.add),
            label: const Text('连接新设备'),
          ),
        ],
      ),
    );
  }

  /// Build device list
  /// Validates: Requirements 21.1, 21.2, 21.3, 21.4
  Widget _buildDeviceList() {
    return RefreshIndicator(
      onRefresh: _loadDevices,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _devices.length,
        itemBuilder: (context, index) {
          final device = _devices[index];
          return _buildDeviceCard(device);
        },
      ),
    );
  }

  Widget _buildDeviceCard(DeviceRecord device) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: device.isOnline ? () => _showQuickConnectDialog(device) : null,
        onLongPress: () => _showDeviceMenu(device),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Device icon with status indicator
              Stack(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getDeviceIcon(device.platform),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  // Online status indicator
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: device.isOnline ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).cardColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(width: 16),
              
              // Device info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '设备代码: ${device.deviceCode}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device.isOnline
                          ? '在线'
                          : '最后在线: ${_formatLastOnline(device.lastOnlineTime)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: device.isOnline ? Colors.green : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Quick connect button for online devices
              if (device.isOnline)
                IconButton(
                  icon: const Icon(Icons.play_circle_outline),
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: () => _quickConnect(device),
                  tooltip: '快速连接',
                ),
              
              // Menu button
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => _showDeviceMenu(device),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getDeviceIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'windows':
        return Icons.desktop_windows;
      case 'macos':
        return Icons.laptop_mac;
      case 'linux':
        return Icons.computer;
      case 'android':
        return Icons.phone_android;
      case 'ios':
        return Icons.phone_iphone;
      default:
        return Icons.devices;
    }
  }

  String _formatLastOnline(DateTime lastOnline) {
    final now = DateTime.now();
    final diff = now.difference(lastOnline);
    
    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${lastOnline.month}/${lastOnline.day}';
    }
  }

  /// Show quick connect dialog
  /// Validates: Requirements 21.5, 21.6
  void _showQuickConnectDialog(DeviceRecord device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('连接到 ${device.displayName}'),
        content: const Text('是否快速连接到此设备？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _quickConnect(device);
            },
            child: const Text('连接'),
          ),
        ],
      ),
    );
  }

  /// Quick connect to device
  /// Validates: Requirements 21.5, 21.6
  void _quickConnect(DeviceRecord device) {
    // Navigate to remote control page with device code pre-filled
    context.go('/remote-control');
    // In real implementation, would auto-fill the device code
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('正在连接到 ${device.displayName}...')),
    );
  }

  /// Show device management menu
  /// Validates: Requirements 21.7, 21.8, 21.9
  void _showDeviceMenu(DeviceRecord device) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('查看详情'),
              onTap: () {
                Navigator.pop(context);
                _showDeviceDetails(device);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('重命名'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(device);
              },
            ),
            if (device.isOnline)
              ListTile(
                leading: Icon(
                  Icons.play_circle_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('快速连接'),
                onTap: () {
                  Navigator.pop(context);
                  _quickConnect(device);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(device);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeviceDetails(DeviceRecord device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(device.displayName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('设备代码', device.deviceCode),
            _buildDetailRow('平台', device.platform),
            _buildDetailRow('状态', device.isOnline ? '在线' : '离线'),
            _buildDetailRow('最后在线', _formatLastOnline(device.lastOnlineTime)),
          ],
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  /// Show rename dialog
  /// Validates: Requirement 21.9
  void _showRenameDialog(DeviceRecord device) {
    final controller = TextEditingController(text: device.displayName);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名设备'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '设备名称',
            hintText: '请输入新的设备名称',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                Navigator.pop(context);
                await _renameDevice(device, newName);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _renameDevice(DeviceRecord device, String newName) async {
    try {
      final deviceService = ref.read(deviceManagementServiceProvider);
      await deviceService.renameDevice(device.deviceId, newName);
      await _loadDevices();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设备已重命名')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('重命名失败: $e')),
        );
      }
    }
  }

  /// Show delete confirmation dialog
  /// Validates: Requirement 21.8
  void _showDeleteDialog(DeviceRecord device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除设备'),
        content: Text('确定要从列表中删除 "${device.displayName}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _deleteDevice(device);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDevice(DeviceRecord device) async {
    try {
      final deviceService = ref.read(deviceManagementServiceProvider);
      await deviceService.removeDevice(device.deviceId);
      await _loadDevices();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设备已删除')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }
}
