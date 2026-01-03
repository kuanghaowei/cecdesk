import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/connection_service.dart' as conn;
import '../../../../core/services/monitoring_service.dart';

class ConnectionPage extends ConsumerStatefulWidget {
  const ConnectionPage({super.key});

  @override
  ConsumerState<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends ConsumerState<ConnectionPage> {
  final _deviceCodeController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _deviceCodeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(conn.connectionServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('连接管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '连接历史',
            onPressed: () => _showConnectionHistory(connectionState),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 当前连接状态
            if (connectionState.currentSession != null)
              _buildActiveSessionCard(connectionState.currentSession!),

            // 新建连接
            _buildNewConnectionCard(connectionState),

            const SizedBox(height: 16),

            // 最近连接
            _buildRecentConnectionsCard(connectionState),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSessionCard(conn.SessionInfo session) {
    return Card(
      color: Colors.green.shade50,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.link, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  '当前连接',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.computer, color: Colors.white),
              ),
              title: Text(session.remoteDeviceName),
              subtitle: Text('设备代码: ${session.remoteDeviceId}'),
              trailing: Text(
                _formatDuration(session.duration),
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.push('/remote-desktop/${session.sessionId}');
                    },
                    icon: const Icon(Icons.desktop_windows),
                    label: const Text('查看桌面'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _disconnectSession(),
                    icon: const Icon(Icons.link_off, color: Colors.red),
                    label: const Text('断开', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewConnectionCard(conn.ConnectionState connectionState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '连接到远程设备',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _deviceCodeController,
              decoration: const InputDecoration(
                labelText: '设备代码',
                hintText: '输入9位设备代码',
                prefixIcon: Icon(Icons.computer),
                helperText: '设备代码为9位数字',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: '连接密码',
                hintText: '输入9位连接密码',
                prefixIcon: Icon(Icons.key),
                helperText: '连接密码为9位数字字符组合',
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                LengthLimitingTextInputFormatter(9),
              ],
            ),
            if (connectionState.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        connectionState.errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: connectionState.isConnecting ? null : _connectToDevice,
                icon: connectionState.isConnecting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link),
                label: Text(connectionState.isConnecting ? '连接中...' : '连接'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentConnectionsCard(conn.ConnectionState connectionState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '最近连接',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (connectionState.sessionHistory.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      ref.read(conn.connectionServiceProvider.notifier).clearHistory();
                    },
                    child: const Text('清除'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (connectionState.sessionHistory.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    '暂无连接历史',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: connectionState.sessionHistory.take(5).length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final history = connectionState.sessionHistory[index];
                  return _buildHistoryItem(history);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(conn.SessionHistory history) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        child: Icon(Icons.computer),
      ),
      title: Text(history.remoteDeviceName),
      subtitle: Text(
        '${_formatDateTime(history.startTime)} • ${_formatDuration(history.duration)}',
      ),
      trailing: IconButton(
        icon: const Icon(Icons.arrow_forward),
        onPressed: () => _quickConnect(history.remoteDeviceId),
      ),
      onTap: () => _quickConnect(history.remoteDeviceId),
    );
  }

  Future<void> _connectToDevice() async {
    final deviceCode = _deviceCodeController.text.trim();
    final password = _passwordController.text.trim();

    if (deviceCode.isEmpty) {
      _showSnackBar('请输入设备代码');
      return;
    }

    if (password.isEmpty) {
      _showSnackBar('请输入连接密码');
      return;
    }

    final connectionService = ref.read(conn.connectionServiceProvider.notifier);
    final monitoring = ref.read(monitoringServiceProvider.notifier);

    monitoring.info('Connection', '尝试连接到设备: $deviceCode');

    final success = await connectionService.connect(
      deviceCode: deviceCode,
      password: password,
    );

    if (success && mounted) {
      monitoring.info('Connection', '连接成功: $deviceCode');
      final session = ref.read(conn.connectionServiceProvider).currentSession;
      if (session != null) {
        context.push('/remote-desktop/${session.sessionId}');
      }
    } else {
      monitoring.warn('Connection', '连接失败: $deviceCode');
    }
  }

  void _quickConnect(String deviceCode) {
    _deviceCodeController.text = deviceCode;
    _showSnackBar('已填充设备代码，请输入连接密码');
  }

  void _disconnectSession() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('断开连接'),
        content: const Text('确定要断开当前连接吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(conn.connectionServiceProvider.notifier).disconnect();
              ref.read(monitoringServiceProvider.notifier).info(
                    'Connection',
                    '用户断开连接',
                  );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('断开'),
          ),
        ],
      ),
    );
  }

  void _showConnectionHistory(conn.ConnectionState connectionState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '连接历史',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: connectionState.sessionHistory.isEmpty
                  ? const Center(
                      child: Text(
                        '暂无连接历史',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: connectionState.sessionHistory.length,
                      itemBuilder: (context, index) {
                        final history = connectionState.sessionHistory[index];
                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.computer),
                          ),
                          title: Text(history.remoteDeviceName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('设备代码: ${history.remoteDeviceId}'),
                              Text(
                                '${_formatDateTime(history.startTime)} - ${_formatDateTime(history.endTime)}',
                              ),
                              Text(
                                '断开原因: ${history.disconnectReason}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.arrow_forward),
                            onPressed: () {
                              Navigator.pop(context);
                              _quickConnect(history.remoteDeviceId);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
