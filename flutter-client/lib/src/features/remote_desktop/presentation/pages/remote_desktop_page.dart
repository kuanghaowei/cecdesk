import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/connection_service.dart';
import '../../../../core/services/monitoring_service.dart';

class RemoteDesktopPage extends ConsumerStatefulWidget {
  final String sessionId;

  const RemoteDesktopPage({
    super.key,
    required this.sessionId,
  });

  @override
  ConsumerState<RemoteDesktopPage> createState() => _RemoteDesktopPageState();
}

class _RemoteDesktopPageState extends ConsumerState<RemoteDesktopPage> {
  bool _isFullscreen = false;
  bool _showControls = true;
  bool _showKeyboard = false;
  bool _audioEnabled = true;
  String _mouseMode = 'touch'; // touch, trackpad

  @override
  void initState() {
    super.initState();
    _logSessionStart();
  }

  void _logSessionStart() {
    final monitoring = ref.read(monitoringServiceProvider.notifier);
    monitoring.info('Session', '远程桌面会话开始: ${widget.sessionId}');
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionServiceProvider);
    final session = connectionState.currentSession;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _showControls
          ? AppBar(
              backgroundColor: Colors.black87,
              title: Text(
                session?.remoteDeviceName ?? '远程桌面',
                style: const TextStyle(color: Colors.white),
              ),
              iconTheme: const IconThemeData(color: Colors.white),
              actions: [
                // 全屏切换
                IconButton(
                  icon: Icon(
                    _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    color: Colors.white,
                  ),
                  tooltip: _isFullscreen ? '退出全屏' : '全屏',
                  onPressed: _toggleFullscreen,
                ),
                // 文件传输
                IconButton(
                  icon: const Icon(Icons.folder, color: Colors.white),
                  tooltip: '文件传输',
                  onPressed: () => context.push('/file-transfer'),
                ),
                // 会话设置
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  tooltip: '会话设置',
                  onPressed: _showSessionSettings,
                ),
                // 断开连接
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  tooltip: '断开连接',
                  onPressed: _disconnectSession,
                ),
              ],
            )
          : null,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        onPanUpdate: _handlePanUpdate,
        onTapDown: _handleTapDown,
        onDoubleTap: _handleDoubleTap,
        child: Stack(
          children: [
            // 远程桌面显示区域
            _buildRemoteDisplay(),

            // 连接状态指示器
            if (_showControls) _buildConnectionStatus(session),

            // 网络质量指示器
            if (_showControls && session != null)
              _buildNetworkQuality(session.networkStats),

            // 虚拟键盘
            if (_showKeyboard) _buildVirtualKeyboard(),
          ],
        ),
      ),
      bottomNavigationBar: _showControls ? _buildControlBar() : null,
    );
  }

  Widget _buildRemoteDisplay() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.desktop_windows,
              size: 80,
              color: Colors.white24,
            ),
            SizedBox(height: 24),
            Text(
              '远程桌面显示区域',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '点击屏幕显示/隐藏控制栏',
              style: TextStyle(
                color: Colors.white24,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(SessionInfo? session) {
    final isConnected = session?.status == ConnectionStatus.connected;

    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.circle,
              color: isConnected ? Colors.green : Colors.red,
              size: 12,
            ),
            const SizedBox(width: 6),
            Text(
              isConnected ? '已连接' : '未连接',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
            if (session != null) ...[
              const SizedBox(width: 8),
              Text(
                _formatDuration(session.duration),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkQuality(NetworkStats stats) {
    Color qualityColor;
    String qualityText;

    switch (stats.quality) {
      case ConnectionQuality.excellent:
        qualityColor = Colors.green;
        qualityText = '优秀';
        break;
      case ConnectionQuality.good:
        qualityColor = Colors.lightGreen;
        qualityText = '良好';
        break;
      case ConnectionQuality.fair:
        qualityColor = Colors.orange;
        qualityText = '一般';
        break;
      case ConnectionQuality.poor:
        qualityColor = Colors.red;
        qualityText = '较差';
        break;
    }

    return Positioned(
      bottom: 80,
      left: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getQualityIcon(stats.quality),
                  color: qualityColor,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  qualityText,
                  style: TextStyle(
                    color: qualityColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildStatRow('延迟', '${stats.rtt}ms'),
            _buildStatRow('丢包', '${stats.packetLoss.toStringAsFixed(1)}%'),
            _buildStatRow('帧率', '${stats.frameRate}fps'),
            _buildStatRow('分辨率', stats.resolution),
            _buildStatRow('编码器', stats.codec),
            if (stats.isRelay)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 12),
                    SizedBox(width: 4),
                    Text(
                      '中继连接',
                      style: TextStyle(color: Colors.orange, fontSize: 10),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }

  IconData _getQualityIcon(ConnectionQuality quality) {
    switch (quality) {
      case ConnectionQuality.excellent:
        return Icons.signal_wifi_4_bar;
      case ConnectionQuality.good:
        return Icons.network_wifi_3_bar;
      case ConnectionQuality.fair:
        return Icons.network_wifi_2_bar;
      case ConnectionQuality.poor:
        return Icons.network_wifi_1_bar;
    }
  }

  Widget _buildControlBar() {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(
              icon: Icons.keyboard,
              label: '键盘',
              isActive: _showKeyboard,
              onPressed: () => setState(() => _showKeyboard = !_showKeyboard),
            ),
            _buildControlButton(
              icon: _mouseMode == 'touch' ? Icons.touch_app : Icons.mouse,
              label: _mouseMode == 'touch' ? '触控' : '触控板',
              onPressed: _toggleMouseMode,
            ),
            _buildControlButton(
              icon: Icons.screenshot,
              label: '截图',
              onPressed: _takeScreenshot,
            ),
            _buildControlButton(
              icon: _audioEnabled ? Icons.volume_up : Icons.volume_off,
              label: _audioEnabled ? '静音' : '取消静音',
              isActive: !_audioEnabled,
              onPressed: () => setState(() => _audioEnabled = !_audioEnabled),
            ),
            _buildControlButton(
              icon: Icons.more_horiz,
              label: '更多',
              onPressed: _showMoreOptions,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    bool isActive = false,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.blue : Colors.white,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.blue : Colors.white70,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVirtualKeyboard() {
    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.black87,
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 功能键行
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildKeyButton('Esc', () => _sendKey('Escape')),
                _buildKeyButton('Tab', () => _sendKey('Tab')),
                _buildKeyButton('Ctrl', () => _sendKey('Control')),
                _buildKeyButton('Alt', () => _sendKey('Alt')),
                _buildKeyButton('Win', () => _sendKey('Meta')),
                _buildKeyButton('Del', () => _sendKey('Delete')),
              ],
            ),
            const SizedBox(height: 8),
            // 方向键行
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildKeyButton('←', () => _sendKey('ArrowLeft')),
                Column(
                  children: [
                    _buildKeyButton('↑', () => _sendKey('ArrowUp')),
                    _buildKeyButton('↓', () => _sendKey('ArrowDown')),
                  ],
                ),
                _buildKeyButton('→', () => _sendKey('ArrowRight')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyButton(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[800],
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 36),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _toggleMouseMode() {
    setState(() {
      _mouseMode = _mouseMode == 'touch' ? 'trackpad' : 'touch';
    });
    _showSnackBar('鼠标模式: ${_mouseMode == 'touch' ? '触控' : '触控板'}');
  }

  void _takeScreenshot() {
    final monitoring = ref.read(monitoringServiceProvider.notifier);
    monitoring.info('Screenshot', '截图已保存');
    _showSnackBar('截图已保存');
  }

  void _sendKey(String key) {
    final monitoring = ref.read(monitoringServiceProvider.notifier);
    monitoring.debug('Input', '发送按键: $key');
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    // 处理鼠标移动
  }

  void _handleTapDown(TapDownDetails details) {
    // 处理点击
  }

  void _handleDoubleTap() {
    // 处理双击
  }

  void _showSessionSettings() {
    final connectionState = ref.read(connectionServiceProvider);
    final session = connectionState.currentSession;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '会话设置',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.speed, color: Colors.white70),
              title: const Text('画质', style: TextStyle(color: Colors.white)),
              subtitle: Text(
                session?.networkStats.resolution ?? 'N/A',
                style: const TextStyle(color: Colors.white54),
              ),
              trailing: const Icon(Icons.arrow_forward_ios,
                  color: Colors.white54, size: 16),
              onTap: () => _showQualitySettings(),
            ),
            ListTile(
              leading: const Icon(Icons.network_check, color: Colors.white70),
              title:
                  const Text('网络统计', style: TextStyle(color: Colors.white)),
              subtitle: Text(
                'RTT: ${session?.networkStats.rtt ?? 0}ms, 丢包: ${session?.networkStats.packetLoss.toStringAsFixed(1) ?? 0}%',
                style: const TextStyle(color: Colors.white54),
              ),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.security, color: Colors.white70),
              title: const Text('安全', style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                '端到端加密已启用',
                style: TextStyle(color: Colors.green),
              ),
              onTap: () {},
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQualitySettings() {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('画质设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('自动'),
              subtitle: const Text('根据网络自动调整'),
              value: 'auto',
              groupValue: 'auto',
              onChanged: (v) => Navigator.pop(context),
            ),
            RadioListTile<String>(
              title: const Text('高清 (1080p)'),
              subtitle: const Text('需要较好网络'),
              value: 'high',
              groupValue: 'auto',
              onChanged: (v) => Navigator.pop(context),
            ),
            RadioListTile<String>(
              title: const Text('标清 (720p)'),
              subtitle: const Text('平衡画质和流畅度'),
              value: 'medium',
              groupValue: 'auto',
              onChanged: (v) => Navigator.pop(context),
            ),
            RadioListTile<String>(
              title: const Text('流畅 (480p)'),
              subtitle: const Text('优先保证流畅'),
              value: 'low',
              groupValue: 'auto',
              onChanged: (v) => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.white70),
              title: const Text('刷新画面', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showSnackBar('画面已刷新');
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock, color: Colors.white70),
              title:
                  const Text('发送 Ctrl+Alt+Del', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _sendKey('Ctrl+Alt+Delete');
                _showSnackBar('已发送 Ctrl+Alt+Del');
              },
            ),
            ListTile(
              leading: const Icon(Icons.desktop_windows, color: Colors.white70),
              title: const Text('切换显示器', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showDisplaySelector();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info, color: Colors.white70),
              title: const Text('会话信息', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showSessionInfo();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDisplaySelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择显示器'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.monitor),
              title: const Text('显示器 1 (主)'),
              subtitle: const Text('1920x1080'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.monitor),
              title: const Text('显示器 2'),
              subtitle: const Text('1920x1080'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.view_array),
              title: const Text('所有显示器'),
              subtitle: const Text('3840x1080'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showSessionInfo() {
    final connectionState = ref.read(connectionServiceProvider);
    final session = connectionState.currentSession;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('会话信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('会话 ID', session?.sessionId ?? 'N/A'),
            _buildInfoRow('远程设备', session?.remoteDeviceName ?? 'N/A'),
            _buildInfoRow('设备代码', session?.remoteDeviceId ?? 'N/A'),
            _buildInfoRow('连接时长', _formatDuration(session?.duration ?? Duration.zero)),
            _buildInfoRow('编码器', session?.networkStats.codec ?? 'N/A'),
            _buildInfoRow('连接类型', session?.networkStats.isRelay == true ? '中继' : '直连'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value),
        ],
      ),
    );
  }

  void _disconnectSession() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('断开连接'),
        content: const Text('确定要断开远程桌面连接吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _doDisconnect();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('断开'),
          ),
        ],
      ),
    );
  }

  void _doDisconnect() {
    final connectionService = ref.read(connectionServiceProvider.notifier);
    final monitoring = ref.read(monitoringServiceProvider.notifier);

    connectionService.disconnect(reason: '用户主动断开');
    monitoring.info('Session', '远程桌面会话结束: ${widget.sessionId}');

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    context.go('/remote-control');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}
