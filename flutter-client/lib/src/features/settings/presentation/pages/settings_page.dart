import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/monitoring_service.dart';
import '../../../../core/services/service_locator.dart' show consentServiceProvider;

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _autoStart = false;
  bool _minimizeToTray = true;
  bool _enableNotifications = true;
  bool _hardwareAcceleration = true;
  String _videoQuality = 'High';
  String _audioQuality = 'High';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '常规', icon: Icon(Icons.settings)),
            Tab(text: '监控', icon: Icon(Icons.monitor_heart)),
            Tab(text: '关于', icon: Icon(Icons.info)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGeneralTab(),
          _buildMonitoringTab(),
          _buildAboutTab(),
        ],
      ),
    );
  }

  Widget _buildGeneralTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSection(
          '启动设置',
          [
            SwitchListTile(
              title: const Text('开机自启动'),
              subtitle: const Text('系统启动时自动运行客户端'),
              value: _autoStart,
              onChanged: (value) => setState(() => _autoStart = value),
            ),
            SwitchListTile(
              title: const Text('最小化到系统托盘'),
              subtitle: const Text('关闭窗口时保持后台运行'),
              value: _minimizeToTray,
              onChanged: (value) => setState(() => _minimizeToTray = value),
            ),
            SwitchListTile(
              title: const Text('启用通知'),
              subtitle: const Text('显示连接和传输通知'),
              value: _enableNotifications,
              onChanged: (value) => setState(() => _enableNotifications = value),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSection(
          '性能设置',
          [
            SwitchListTile(
              title: const Text('硬件加速'),
              subtitle: const Text('使用 GPU 进行视频编解码'),
              value: _hardwareAcceleration,
              onChanged: (value) =>
                  setState(() => _hardwareAcceleration = value),
            ),
            ListTile(
              title: const Text('视频质量'),
              subtitle: Text(_videoQuality),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showQualityDialog('视频质量', _videoQuality, (value) {
                setState(() => _videoQuality = value);
              }),
            ),
            ListTile(
              title: const Text('音频质量'),
              subtitle: Text(_audioQuality),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showQualityDialog('音频质量', _audioQuality, (value) {
                setState(() => _audioQuality = value);
              }),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSection(
          '安全设置',
          [
            ListTile(
              leading: const Icon(Icons.security),
              title: const Text('登录安全'),
              subtitle: const Text('管理登录会话和设备'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showSecuritySettings(),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip),
              title: const Text('隐私设置'),
              subtitle: const Text('管理数据收集和隐私选项'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showPrivacySettings(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMonitoringTab() {
    final monitoringState = ref.watch(monitoringServiceProvider);
    final monitoringService = ref.read(monitoringServiceProvider.notifier);

    return Column(
      children: [
        // 网络诊断卡片
        Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '网络诊断',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    ElevatedButton.icon(
                      onPressed: monitoringState.isDiagnosticRunning
                          ? null
                          : () => monitoringService.runDiagnostics(),
                      icon: monitoringState.isDiagnosticRunning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.network_check, size: 18),
                      label: Text(
                        monitoringState.isDiagnosticRunning ? '诊断中...' : '运行诊断',
                      ),
                    ),
                  ],
                ),
                if (monitoringState.lastDiagnostics != null) ...[
                  const SizedBox(height: 16),
                  _buildDiagnosticsResult(monitoringState.lastDiagnostics!),
                ],
              ],
            ),
          ),
        ),

        // 日志级别选择
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text('日志级别: '),
              const SizedBox(width: 8),
              DropdownButton<LogLevel>(
                value: monitoringState.minLogLevel,
                items: LogLevel.values.map((level) {
                  return DropdownMenuItem(
                    value: level,
                    child: Text(level.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (level) {
                  if (level != null) {
                    monitoringService.setMinLogLevel(level);
                  }
                },
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => monitoringService.clearLogs(),
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('清除'),
              ),
              TextButton.icon(
                onPressed: () => _exportLogs(monitoringService),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('导出'),
              ),
            ],
          ),
        ),

        // 日志列表
        Expanded(
          child: Card(
            margin: const EdgeInsets.all(16),
            child: monitoringState.filteredLogs.isEmpty
                ? const Center(
                    child: Text(
                      '暂无日志',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: monitoringState.filteredLogs.length,
                    itemBuilder: (context, index) {
                      final log = monitoringState.filteredLogs[index];
                      return _buildLogEntry(log);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiagnosticsResult(NetworkDiagnostics diagnostics) {
    return Column(
      children: [
        _buildDiagnosticItem(
          '互联网连接',
          diagnostics.internetConnected,
          null,
        ),
        _buildDiagnosticItem(
          '信令服务器',
          diagnostics.signalingServerReachable,
          diagnostics.signalingLatency != null
              ? '${diagnostics.signalingLatency}ms'
              : null,
        ),
        _buildDiagnosticItem(
          'STUN 服务器',
          diagnostics.stunServerReachable,
          diagnostics.stunLatency != null
              ? '${diagnostics.stunLatency}ms'
              : null,
        ),
        _buildDiagnosticItem(
          'TURN 服务器',
          diagnostics.turnServerReachable,
          null,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              const Icon(Icons.router, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text('NAT 类型: ${diagnostics.natType}'),
            ],
          ),
        ),
        if (diagnostics.publicIpv4 != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                const Icon(Icons.language, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text('IPv4: ${diagnostics.publicIpv4}'),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDiagnosticItem(String name, bool success, String? latency) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            success ? Icons.check_circle : Icons.error,
            color: success ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(name),
          if (latency != null) ...[
            const Spacer(),
            Text(
              latency,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogEntry(LogEntry log) {
    Color levelColor;
    switch (log.level) {
      case LogLevel.debug:
        levelColor = Colors.grey;
        break;
      case LogLevel.info:
        levelColor = Colors.blue;
        break;
      case LogLevel.warn:
        levelColor = Colors.orange;
        break;
      case LogLevel.error:
        levelColor = Colors.red;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            log.formattedTime,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: levelColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              log.levelString,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: levelColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '[${log.category}] ${log.message}',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutTab() {
    final consentService = ref.read(consentServiceProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSection(
          '应用信息',
          [
            const ListTile(
              title: Text('版本'),
              subtitle: Text('1.0.0'),
            ),
            const ListTile(
              title: Text('构建日期'),
              subtitle: Text('2026.01.01'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSection(
          '法律信息',
          [
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('用户隐私协议'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showAgreement(
                '用户隐私协议',
                consentService.getPrivacyPolicyContent(),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.gavel),
              title: const Text('软件许可协议'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showAgreement(
                '软件许可协议',
                consentService.getLicenseAgreementContent(),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.library_books),
              title: const Text('开源许可'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => showLicensePage(context: context),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSection(
          '支持',
          [
            ListTile(
              leading: const Icon(Icons.help),
              title: const Text('帮助中心'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.feedback),
              title: const Text('反馈问题'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  void _showQualityDialog(
    String title,
    String currentValue,
    Function(String) onChanged,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Low', 'Medium', 'High'].map((value) {
            return RadioListTile<String>(
              title: Text(_getQualityLabel(value)),
              value: value,
              groupValue: currentValue,
              onChanged: (v) {
                if (v != null) {
                  onChanged(v);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  String _getQualityLabel(String value) {
    switch (value) {
      case 'Low':
        return '低 (节省带宽)';
      case 'Medium':
        return '中 (平衡)';
      case 'High':
        return '高 (最佳质量)';
      default:
        return value;
    }
  }

  void _showSecuritySettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '登录安全',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.devices),
              title: const Text('已登录设备'),
              subtitle: const Text('管理当前登录的设备'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('登出所有设备'),
              subtitle: const Text('从所有设备上登出'),
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

  void _showPrivacySettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '隐私设置',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('匿名使用统计'),
              subtitle: const Text('帮助我们改进产品'),
              value: true,
              onChanged: (value) {},
            ),
            SwitchListTile(
              title: const Text('崩溃报告'),
              subtitle: const Text('自动发送崩溃报告'),
              value: true,
              onChanged: (value) {},
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

  void _showAgreement(String title, String content) {
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _exportLogs(MonitoringService service) {
    final logs = service.exportLogs();
    Clipboard.setData(ClipboardData(text: logs));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('日志已复制到剪贴板')),
    );
  }
}
