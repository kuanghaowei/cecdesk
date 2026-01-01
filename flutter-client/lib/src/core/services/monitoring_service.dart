import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 日志级别
enum LogLevel {
  debug,
  info,
  warn,
  error,
}

/// 日志条目
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String category;
  final String message;
  final Map<String, dynamic>? metadata;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    this.metadata,
  });

  String get formattedTime =>
      '${timestamp.hour.toString().padLeft(2, '0')}:'
      '${timestamp.minute.toString().padLeft(2, '0')}:'
      '${timestamp.second.toString().padLeft(2, '0')}';

  String get levelString {
    switch (level) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warn:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
    }
  }
}

/// 网络诊断结果
class NetworkDiagnostics {
  final bool internetConnected;
  final bool signalingServerReachable;
  final bool stunServerReachable;
  final bool turnServerReachable;
  final int? signalingLatency;
  final int? stunLatency;
  final String? publicIpv4;
  final String? publicIpv6;
  final String? natType;
  final DateTime timestamp;

  const NetworkDiagnostics({
    this.internetConnected = false,
    this.signalingServerReachable = false,
    this.stunServerReachable = false,
    this.turnServerReachable = false,
    this.signalingLatency,
    this.stunLatency,
    this.publicIpv4,
    this.publicIpv6,
    this.natType,
    required this.timestamp,
  });

  bool get allServicesReachable =>
      internetConnected &&
      signalingServerReachable &&
      stunServerReachable &&
      turnServerReachable;
}

/// 监控服务状态
class MonitoringState {
  final List<LogEntry> logs;
  final LogLevel minLogLevel;
  final NetworkDiagnostics? lastDiagnostics;
  final bool isDiagnosticRunning;

  const MonitoringState({
    this.logs = const [],
    this.minLogLevel = LogLevel.info,
    this.lastDiagnostics,
    this.isDiagnosticRunning = false,
  });

  MonitoringState copyWith({
    List<LogEntry>? logs,
    LogLevel? minLogLevel,
    NetworkDiagnostics? lastDiagnostics,
    bool? isDiagnosticRunning,
  }) {
    return MonitoringState(
      logs: logs ?? this.logs,
      minLogLevel: minLogLevel ?? this.minLogLevel,
      lastDiagnostics: lastDiagnostics ?? this.lastDiagnostics,
      isDiagnosticRunning: isDiagnosticRunning ?? this.isDiagnosticRunning,
    );
  }

  List<LogEntry> get filteredLogs =>
      logs.where((log) => log.level.index >= minLogLevel.index).toList();
}

/// 监控服务
class MonitoringService extends StateNotifier<MonitoringState> {
  static const int _maxLogEntries = 1000;

  MonitoringService() : super(const MonitoringState());

  /// 记录日志
  void log(
    LogLevel level,
    String category,
    String message, {
    Map<String, dynamic>? metadata,
  }) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      category: category,
      message: message,
      metadata: metadata,
    );

    final newLogs = [entry, ...state.logs].take(_maxLogEntries).toList();
    state = state.copyWith(logs: newLogs);
  }

  /// 便捷日志方法
  void debug(String category, String message, {Map<String, dynamic>? metadata}) =>
      log(LogLevel.debug, category, message, metadata: metadata);

  void info(String category, String message, {Map<String, dynamic>? metadata}) =>
      log(LogLevel.info, category, message, metadata: metadata);

  void warn(String category, String message, {Map<String, dynamic>? metadata}) =>
      log(LogLevel.warn, category, message, metadata: metadata);

  void error(String category, String message, {Map<String, dynamic>? metadata}) =>
      log(LogLevel.error, category, message, metadata: metadata);

  /// 设置最小日志级别
  void setMinLogLevel(LogLevel level) {
    state = state.copyWith(minLogLevel: level);
  }

  /// 清除日志
  void clearLogs() {
    state = state.copyWith(logs: []);
  }

  /// 运行网络诊断
  Future<NetworkDiagnostics> runDiagnostics() async {
    state = state.copyWith(isDiagnosticRunning: true);
    info('Diagnostics', '开始网络诊断...');

    try {
      // 模拟诊断过程
      await Future.delayed(const Duration(milliseconds: 500));
      info('Diagnostics', '检查互联网连接...');

      await Future.delayed(const Duration(milliseconds: 500));
      info('Diagnostics', '检查信令服务器...');

      await Future.delayed(const Duration(milliseconds: 500));
      info('Diagnostics', '检查 STUN 服务器...');

      await Future.delayed(const Duration(milliseconds: 500));
      info('Diagnostics', '检查 TURN 服务器...');

      await Future.delayed(const Duration(milliseconds: 500));
      info('Diagnostics', '检测 NAT 类型...');

      final diagnostics = NetworkDiagnostics(
        internetConnected: true,
        signalingServerReachable: true,
        stunServerReachable: true,
        turnServerReachable: true,
        signalingLatency: 45,
        stunLatency: 30,
        publicIpv4: '203.0.113.1',
        publicIpv6: '2001:db8::1',
        natType: 'Full Cone NAT',
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        lastDiagnostics: diagnostics,
        isDiagnosticRunning: false,
      );

      info('Diagnostics', '网络诊断完成', metadata: {
        'internetConnected': diagnostics.internetConnected,
        'signalingLatency': diagnostics.signalingLatency,
        'natType': diagnostics.natType,
      });

      return diagnostics;
    } catch (e) {
      error('Diagnostics', '网络诊断失败: $e');
      state = state.copyWith(isDiagnosticRunning: false);
      rethrow;
    }
  }

  /// 导出日志
  String exportLogs() {
    final buffer = StringBuffer();
    buffer.writeln('=== 远程桌面客户端日志导出 ===');
    buffer.writeln('导出时间: ${DateTime.now()}');
    buffer.writeln('日志条目数: ${state.logs.length}');
    buffer.writeln('');

    for (final log in state.logs.reversed) {
      buffer.writeln(
        '[${log.formattedTime}] [${log.levelString}] [${log.category}] ${log.message}',
      );
      if (log.metadata != null) {
        buffer.writeln('  Metadata: ${log.metadata}');
      }
    }

    return buffer.toString();
  }
}

/// 监控服务 Provider
final monitoringServiceProvider =
    StateNotifierProvider<MonitoringService, MonitoringState>((ref) {
  return MonitoringService();
});
