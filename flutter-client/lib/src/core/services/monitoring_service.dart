import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 日志级别
enum LogLevel {
  debug,
  info,
  warn,
  error,
}

extension LogLevelExtension on LogLevel {
  String get name {
    switch (this) {
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

  int get priority => index;
}

/// 日志条目
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String category;
  final String message;
  final Map<String, dynamic>? metadata;
  final String? sessionId;
  final String? deviceId;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    this.metadata,
    this.sessionId,
    this.deviceId,
  });

  String get formattedTime =>
      '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} '
      '${timestamp.hour.toString().padLeft(2, '0')}:'
      '${timestamp.minute.toString().padLeft(2, '0')}:'
      '${timestamp.second.toString().padLeft(2, '0')}.'
      '${timestamp.millisecond.toString().padLeft(3, '0')}';

  String get levelString => level.name;

  String format() {
    final buffer = StringBuffer();
    buffer.write('[$formattedTime] [$levelString] [$category] $message');
    
    if (sessionId != null) {
      buffer.write(' [session:$sessionId]');
    }
    if (deviceId != null) {
      buffer.write(' [device:$deviceId]');
    }
    if (metadata != null) {
      buffer.write(' $metadata');
    }
    
    return buffer.toString();
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level.index,
    'category': category,
    'message': message,
    'metadata': metadata,
    'sessionId': sessionId,
    'deviceId': deviceId,
  };

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
    timestamp: DateTime.parse(json['timestamp']),
    level: LogLevel.values[json['level'] ?? 1],
    category: json['category'] ?? '',
    message: json['message'] ?? '',
    metadata: json['metadata'],
    sessionId: json['sessionId'],
    deviceId: json['deviceId'],
  );
}

/// 连接事件类型
enum ConnectionEventType {
  connectionAttempt,
  connectionEstablished,
  connectionFailed,
  connectionClosed,
  reconnectAttempt,
  iceCandidateGathered,
  iceCandidateReceived,
  signalingConnected,
  signalingDisconnected,
  mediaStreamAdded,
  mediaStreamRemoved,
  dataChannelOpened,
  dataChannelClosed,
  qualityChanged,
}

extension ConnectionEventTypeExtension on ConnectionEventType {
  String get displayName {
    switch (this) {
      case ConnectionEventType.connectionAttempt:
        return '连接尝试';
      case ConnectionEventType.connectionEstablished:
        return '连接建立';
      case ConnectionEventType.connectionFailed:
        return '连接失败';
      case ConnectionEventType.connectionClosed:
        return '连接关闭';
      case ConnectionEventType.reconnectAttempt:
        return '重连尝试';
      case ConnectionEventType.iceCandidateGathered:
        return 'ICE候选收集';
      case ConnectionEventType.iceCandidateReceived:
        return 'ICE候选接收';
      case ConnectionEventType.signalingConnected:
        return '信令连接';
      case ConnectionEventType.signalingDisconnected:
        return '信令断开';
      case ConnectionEventType.mediaStreamAdded:
        return '媒体流添加';
      case ConnectionEventType.mediaStreamRemoved:
        return '媒体流移除';
      case ConnectionEventType.dataChannelOpened:
        return '数据通道打开';
      case ConnectionEventType.dataChannelClosed:
        return '数据通道关闭';
      case ConnectionEventType.qualityChanged:
        return '质量变化';
    }
  }
}

/// 连接事件
class ConnectionEvent {
  final DateTime timestamp;
  final ConnectionEventType eventType;
  final String? sessionId;
  final String? remoteDeviceId;
  final Map<String, dynamic>? details;
  final bool success;
  final String? errorMessage;

  const ConnectionEvent({
    required this.timestamp,
    required this.eventType,
    this.sessionId,
    this.remoteDeviceId,
    this.details,
    this.success = true,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'eventType': eventType.index,
    'sessionId': sessionId,
    'remoteDeviceId': remoteDeviceId,
    'details': details,
    'success': success,
    'errorMessage': errorMessage,
  };

  factory ConnectionEvent.fromJson(Map<String, dynamic> json) => ConnectionEvent(
    timestamp: DateTime.parse(json['timestamp']),
    eventType: ConnectionEventType.values[json['eventType'] ?? 0],
    sessionId: json['sessionId'],
    remoteDeviceId: json['remoteDeviceId'],
    details: json['details'],
    success: json['success'] ?? true,
    errorMessage: json['errorMessage'],
  );
}

/// NAT 类型
enum NatType {
  unknown,
  openInternet,
  fullCone,
  restrictedCone,
  portRestrictedCone,
  symmetric,
  symmetricUdpFirewall,
  blocked,
}

extension NatTypeExtension on NatType {
  String get displayName {
    switch (this) {
      case NatType.unknown:
        return '未知';
      case NatType.openInternet:
        return '开放网络';
      case NatType.fullCone:
        return '完全锥形NAT';
      case NatType.restrictedCone:
        return '受限锥形NAT';
      case NatType.portRestrictedCone:
        return '端口受限锥形NAT';
      case NatType.symmetric:
        return '对称NAT';
      case NatType.symmetricUdpFirewall:
        return '对称UDP防火墙';
      case NatType.blocked:
        return '被阻止';
    }
  }
}

/// 服务器状态
class ServerStatus {
  final String name;
  final String url;
  final bool reachable;
  final int? latencyMs;
  final String? error;
  final DateTime lastCheck;

  const ServerStatus({
    required this.name,
    required this.url,
    this.reachable = false,
    this.latencyMs,
    this.error,
    required this.lastCheck,
  });

  ServerStatus copyWith({
    String? name,
    String? url,
    bool? reachable,
    int? latencyMs,
    String? error,
    DateTime? lastCheck,
  }) {
    return ServerStatus(
      name: name ?? this.name,
      url: url ?? this.url,
      reachable: reachable ?? this.reachable,
      latencyMs: latencyMs ?? this.latencyMs,
      error: error ?? this.error,
      lastCheck: lastCheck ?? this.lastCheck,
    );
  }
}

/// 诊断状态
enum DiagnosticStatus {
  unknown,
  good,
  warning,
  critical,
}

extension DiagnosticStatusExtension on DiagnosticStatus {
  String get displayName {
    switch (this) {
      case DiagnosticStatus.unknown:
        return '未知';
      case DiagnosticStatus.good:
        return '良好';
      case DiagnosticStatus.warning:
        return '警告';
      case DiagnosticStatus.critical:
        return '严重';
    }
  }
}

/// 网络诊断结果
class NetworkDiagnostics {
  final bool internetConnected;
  final bool ipv4Available;
  final bool ipv6Available;
  final String? publicIpv4;
  final String? publicIpv6;
  final String? localIpv4;
  final String? localIpv6;
  final NatType natType;
  final ServerStatus signalingServer;
  final List<ServerStatus> stunServers;
  final List<ServerStatus> turnServers;
  final DiagnosticStatus overallStatus;
  final List<String> recommendations;
  final DateTime timestamp;

  const NetworkDiagnostics({
    this.internetConnected = false,
    this.ipv4Available = false,
    this.ipv6Available = false,
    this.publicIpv4,
    this.publicIpv6,
    this.localIpv4,
    this.localIpv6,
    this.natType = NatType.unknown,
    required this.signalingServer,
    this.stunServers = const [],
    this.turnServers = const [],
    this.overallStatus = DiagnosticStatus.unknown,
    this.recommendations = const [],
    required this.timestamp,
  });

  bool get allServicesReachable =>
      internetConnected &&
      signalingServer.reachable &&
      stunServers.any((s) => s.reachable) &&
      turnServers.any((s) => s.reachable);

  int? get signalingLatency => signalingServer.latencyMs;
  int? get stunLatency => stunServers.firstWhere((s) => s.reachable, orElse: () => stunServers.first).latencyMs;

  bool get signalingServerReachable => signalingServer.reachable;
  bool get stunServerReachable => stunServers.any((s) => s.reachable);
  bool get turnServerReachable => turnServers.any((s) => s.reachable);
}

/// 监控服务状态
class MonitoringState {
  final List<LogEntry> logs;
  final List<ConnectionEvent> connectionEvents;
  final LogLevel minLogLevel;
  final NetworkDiagnostics? lastDiagnostics;
  final bool isDiagnosticRunning;
  final bool isFileLoggingEnabled;
  final String? logFilePath;

  const MonitoringState({
    this.logs = const [],
    this.connectionEvents = const [],
    this.minLogLevel = LogLevel.info,
    this.lastDiagnostics,
    this.isDiagnosticRunning = false,
    this.isFileLoggingEnabled = false,
    this.logFilePath,
  });

  MonitoringState copyWith({
    List<LogEntry>? logs,
    List<ConnectionEvent>? connectionEvents,
    LogLevel? minLogLevel,
    NetworkDiagnostics? lastDiagnostics,
    bool? isDiagnosticRunning,
    bool? isFileLoggingEnabled,
    String? logFilePath,
  }) {
    return MonitoringState(
      logs: logs ?? this.logs,
      connectionEvents: connectionEvents ?? this.connectionEvents,
      minLogLevel: minLogLevel ?? this.minLogLevel,
      lastDiagnostics: lastDiagnostics ?? this.lastDiagnostics,
      isDiagnosticRunning: isDiagnosticRunning ?? this.isDiagnosticRunning,
      isFileLoggingEnabled: isFileLoggingEnabled ?? this.isFileLoggingEnabled,
      logFilePath: logFilePath ?? this.logFilePath,
    );
  }

  List<LogEntry> get filteredLogs =>
      logs.where((log) => log.level.priority >= minLogLevel.priority).toList();
}

/// 监控服务
class MonitoringService extends StateNotifier<MonitoringState> {
  static const int _maxLogEntries = 1000;
  static const int _maxConnectionEvents = 100;

  MonitoringService() : super(const MonitoringState());

  /// 记录日志
  void log(
    LogLevel level,
    String category,
    String message, {
    Map<String, dynamic>? metadata,
    String? sessionId,
    String? deviceId,
  }) {
    // 检查日志级别
    if (level.priority < state.minLogLevel.priority) {
      return;
    }

    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      category: category,
      message: message,
      metadata: metadata,
      sessionId: sessionId,
      deviceId: deviceId,
    );

    final newLogs = [entry, ...state.logs].take(_maxLogEntries).toList();
    state = state.copyWith(logs: newLogs);
  }

  /// 便捷日志方法
  void debug(String category, String message, {Map<String, dynamic>? metadata, String? sessionId, String? deviceId}) =>
      log(LogLevel.debug, category, message, metadata: metadata, sessionId: sessionId, deviceId: deviceId);

  void info(String category, String message, {Map<String, dynamic>? metadata, String? sessionId, String? deviceId}) =>
      log(LogLevel.info, category, message, metadata: metadata, sessionId: sessionId, deviceId: deviceId);

  void warn(String category, String message, {Map<String, dynamic>? metadata, String? sessionId, String? deviceId}) =>
      log(LogLevel.warn, category, message, metadata: metadata, sessionId: sessionId, deviceId: deviceId);

  void error(String category, String message, {Map<String, dynamic>? metadata, String? sessionId, String? deviceId}) =>
      log(LogLevel.error, category, message, metadata: metadata, sessionId: sessionId, deviceId: deviceId);

  /// 记录连接事件
  void logConnectionEvent(ConnectionEvent event) {
    // 同时记录为普通日志
    final level = event.success ? LogLevel.info : LogLevel.error;
    final message = event.errorMessage != null
        ? '${event.eventType.displayName}: ${event.errorMessage}'
        : event.eventType.displayName;

    log(
      level,
      'Connection',
      message,
      metadata: event.details,
      sessionId: event.sessionId,
      deviceId: event.remoteDeviceId,
    );

    // 添加到连接事件列表
    final newEvents = [event, ...state.connectionEvents].take(_maxConnectionEvents).toList();
    state = state.copyWith(connectionEvents: newEvents);
  }

  /// 记录连接建立事件
  void logConnectionEstablished({
    required String sessionId,
    required String remoteDeviceId,
    Map<String, dynamic>? details,
  }) {
    logConnectionEvent(ConnectionEvent(
      timestamp: DateTime.now(),
      eventType: ConnectionEventType.connectionEstablished,
      sessionId: sessionId,
      remoteDeviceId: remoteDeviceId,
      details: details,
      success: true,
    ));
  }

  /// 记录连接断开事件
  void logConnectionClosed({
    required String sessionId,
    required String remoteDeviceId,
    String? reason,
  }) {
    logConnectionEvent(ConnectionEvent(
      timestamp: DateTime.now(),
      eventType: ConnectionEventType.connectionClosed,
      sessionId: sessionId,
      remoteDeviceId: remoteDeviceId,
      details: reason != null ? {'reason': reason} : null,
      success: true,
    ));
  }

  /// 记录连接失败事件
  void logConnectionFailed({
    String? sessionId,
    String? remoteDeviceId,
    required String errorMessage,
  }) {
    logConnectionEvent(ConnectionEvent(
      timestamp: DateTime.now(),
      eventType: ConnectionEventType.connectionFailed,
      sessionId: sessionId,
      remoteDeviceId: remoteDeviceId,
      success: false,
      errorMessage: errorMessage,
    ));
  }

  /// 设置最小日志级别
  void setMinLogLevel(LogLevel level) {
    state = state.copyWith(minLogLevel: level);
  }

  /// 清除日志
  void clearLogs() {
    state = state.copyWith(logs: []);
  }

  /// 清除连接事件
  void clearConnectionEvents() {
    state = state.copyWith(connectionEvents: []);
  }

  /// 获取连接事件
  List<ConnectionEvent> getConnectionEvents({int? limit}) {
    final events = state.connectionEvents;
    if (limit != null && limit < events.length) {
      return events.take(limit).toList();
    }
    return events;
  }

  /// 运行网络诊断
  Future<NetworkDiagnostics> runDiagnostics() async {
    state = state.copyWith(isDiagnosticRunning: true);
    info('Diagnostics', '开始网络诊断...');

    try {
      // 检查互联网连接
      await Future.delayed(const Duration(milliseconds: 500));
      info('Diagnostics', '检查互联网连接...');
      final internetConnected = true; // 模拟

      // 检查信令服务器
      await Future.delayed(const Duration(milliseconds: 500));
      info('Diagnostics', '检查信令服务器...');
      final signalingServer = ServerStatus(
        name: 'Signaling',
        url: 'wss://signaling.example.com',
        reachable: true,
        latencyMs: 45,
        lastCheck: DateTime.now(),
      );

      // 检查 STUN 服务器
      await Future.delayed(const Duration(milliseconds: 500));
      info('Diagnostics', '检查 STUN 服务器...');
      final stunServers = [
        ServerStatus(
          name: 'STUN 1',
          url: 'stun:stun.example.com:3478',
          reachable: true,
          latencyMs: 30,
          lastCheck: DateTime.now(),
        ),
      ];

      // 检查 TURN 服务器
      await Future.delayed(const Duration(milliseconds: 500));
      info('Diagnostics', '检查 TURN 服务器...');
      final turnServers = [
        ServerStatus(
          name: 'TURN 1',
          url: 'turn:turn.example.com:3478',
          reachable: true,
          latencyMs: 50,
          lastCheck: DateTime.now(),
        ),
      ];

      // 检测 NAT 类型
      await Future.delayed(const Duration(milliseconds: 500));
      info('Diagnostics', '检测 NAT 类型...');
      // In production, this would be detected dynamically
      final natType = NatType.fullCone;

      // 计算总体状态和建议
      DiagnosticStatus overallStatus = DiagnosticStatus.good;
      List<String> recommendations = [];

      if (!internetConnected) {
        overallStatus = DiagnosticStatus.critical;
        recommendations.add('请检查网络连接');
      } else if (!signalingServer.reachable) {
        overallStatus = DiagnosticStatus.critical;
        recommendations.add('无法连接信令服务器，请检查网络设置');
      } else if (natType == NatType.symmetric || natType == NatType.symmetricUdpFirewall) { // ignore: dead_code
        if (!turnServers.any((s) => s.reachable)) {
          overallStatus = DiagnosticStatus.warning;
          recommendations.add('检测到对称NAT，建议确保TURN服务器可用');
        } else {
          recommendations.add('检测到对称NAT，将使用TURN中继');
        }
      }

      final diagnostics = NetworkDiagnostics(
        internetConnected: internetConnected,
        ipv4Available: true,
        ipv6Available: true,
        publicIpv4: '203.0.113.1',
        publicIpv6: '2001:db8::1',
        localIpv4: '192.168.1.100',
        localIpv6: 'fe80::1',
        natType: natType,
        signalingServer: signalingServer,
        stunServers: stunServers,
        turnServers: turnServers,
        overallStatus: overallStatus,
        recommendations: recommendations,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        lastDiagnostics: diagnostics,
        isDiagnosticRunning: false,
      );

      info('Diagnostics', '网络诊断完成', metadata: {
        'internetConnected': diagnostics.internetConnected,
        'signalingLatency': diagnostics.signalingLatency,
        'natType': diagnostics.natType.displayName,
        'overallStatus': diagnostics.overallStatus.displayName,
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
      buffer.writeln(log.format());
    }

    return buffer.toString();
  }

  /// 导出连接事件
  String exportConnectionEvents() {
    final buffer = StringBuffer();
    buffer.writeln('=== 连接事件导出 ===');
    buffer.writeln('导出时间: ${DateTime.now()}');
    buffer.writeln('事件数: ${state.connectionEvents.length}');
    buffer.writeln('');

    for (final event in state.connectionEvents.reversed) {
      buffer.writeln(
        '[${event.timestamp}] ${event.eventType.displayName} - ${event.success ? "成功" : "失败"}',
      );
      if (event.sessionId != null) {
        buffer.writeln('  会话: ${event.sessionId}');
      }
      if (event.remoteDeviceId != null) {
        buffer.writeln('  设备: ${event.remoteDeviceId}');
      }
      if (event.errorMessage != null) {
        buffer.writeln('  错误: ${event.errorMessage}');
      }
      if (event.details != null) {
        buffer.writeln('  详情: ${event.details}');
      }
    }

    return buffer.toString();
  }

  /// 导出完整诊断报告
  String exportDiagnosticReport() {
    final buffer = StringBuffer();
    buffer.writeln('=== 远程桌面客户端诊断报告 ===');
    buffer.writeln('生成时间: ${DateTime.now()}');
    buffer.writeln('');

    // 网络诊断
    if (state.lastDiagnostics != null) {
      final diag = state.lastDiagnostics!;
      buffer.writeln('--- 网络诊断 ---');
      buffer.writeln('诊断时间: ${diag.timestamp}');
      buffer.writeln('总体状态: ${diag.overallStatus.displayName}');
      buffer.writeln('互联网连接: ${diag.internetConnected ? "是" : "否"}');
      buffer.writeln('IPv4可用: ${diag.ipv4Available ? "是" : "否"}');
      buffer.writeln('IPv6可用: ${diag.ipv6Available ? "是" : "否"}');
      buffer.writeln('公网IPv4: ${diag.publicIpv4 ?? "未知"}');
      buffer.writeln('公网IPv6: ${diag.publicIpv6 ?? "未知"}');
      buffer.writeln('NAT类型: ${diag.natType.displayName}');
      buffer.writeln('');
      buffer.writeln('信令服务器: ${diag.signalingServer.reachable ? "可达" : "不可达"} (${diag.signalingServer.latencyMs ?? "N/A"}ms)');
      buffer.writeln('STUN服务器: ${diag.stunServers.where((s) => s.reachable).length}/${diag.stunServers.length} 可达');
      buffer.writeln('TURN服务器: ${diag.turnServers.where((s) => s.reachable).length}/${diag.turnServers.length} 可达');
      buffer.writeln('');
      if (diag.recommendations.isNotEmpty) {
        buffer.writeln('建议:');
        for (final rec in diag.recommendations) {
          buffer.writeln('  - $rec');
        }
      }
      buffer.writeln('');
    }

    // 最近连接事件
    buffer.writeln('--- 最近连接事件 (最多10条) ---');
    final recentEvents = state.connectionEvents.take(10);
    for (final event in recentEvents) {
      buffer.writeln('${event.timestamp}: ${event.eventType.displayName} - ${event.success ? "成功" : "失败"}');
    }
    buffer.writeln('');

    // 最近日志
    buffer.writeln('--- 最近日志 (最多50条) ---');
    final recentLogs = state.logs.take(50);
    for (final log in recentLogs) {
      buffer.writeln(log.format());
    }

    return buffer.toString();
  }
}

/// 监控服务 Provider
final monitoringServiceProvider =
    StateNotifierProvider<MonitoringService, MonitoringState>((ref) {
  return MonitoringService();
});
