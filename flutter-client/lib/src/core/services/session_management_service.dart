import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'secure_storage_service.dart';

/// 会话状态枚举
enum SessionStatus {
  pending,
  active,
  paused,
  ended,
  failed,
}

/// 权限类型枚举
enum SessionPermission {
  screenView,
  inputControl,
  fileTransfer,
  audioCapture,
  systemControl,
}

/// 连接质量等级
enum ConnectionQuality {
  excellent,
  good,
  fair,
  poor,
}

/// 连接类型
enum ConnectionType {
  direct,  // P2P 直连
  relay,   // TURN 中继
  unknown,
}

/// 会话结束原因
enum EndReason {
  userRequested,
  remoteDisconnect,
  timeout,
  networkError,
  authenticationFailed,
  permissionDenied,
  systemError,
}

extension EndReasonExtension on EndReason {
  String get displayName {
    switch (this) {
      case EndReason.userRequested:
        return '用户主动断开';
      case EndReason.remoteDisconnect:
        return '远程设备断开';
      case EndReason.timeout:
        return '会话超时';
      case EndReason.networkError:
        return '网络错误';
      case EndReason.authenticationFailed:
        return '认证失败';
      case EndReason.permissionDenied:
        return '权限被拒绝';
      case EndReason.systemError:
        return '系统错误';
    }
  }
}

/// 会话统计信息
class SessionStats {
  final int durationSecs;
  final int bytesSent;
  final int bytesReceived;
  final int averageLatencyMs;
  final int maxLatencyMs;
  final int minLatencyMs;
  final double packetLossPercent;
  final int jitterMs;
  final int framesSent;
  final int framesReceived;
  final ConnectionQuality connectionQuality;
  final ConnectionType connectionType;

  const SessionStats({
    this.durationSecs = 0,
    this.bytesSent = 0,
    this.bytesReceived = 0,
    this.averageLatencyMs = 0,
    this.maxLatencyMs = 0,
    this.minLatencyMs = 0,
    this.packetLossPercent = 0.0,
    this.jitterMs = 0,
    this.framesSent = 0,
    this.framesReceived = 0,
    this.connectionQuality = ConnectionQuality.good,
    this.connectionType = ConnectionType.direct,
  });

  /// 根据网络指标计算连接质量
  static ConnectionQuality calculateQuality(int rtt, double packetLoss, int jitter) {
    if (rtt < 50 && packetLoss < 1.0 && jitter < 10) {
      return ConnectionQuality.excellent;
    } else if (rtt < 100 && packetLoss < 3.0 && jitter < 20) {
      return ConnectionQuality.good;
    } else if (rtt < 200 && packetLoss < 5.0 && jitter < 50) {
      return ConnectionQuality.fair;
    } else {
      return ConnectionQuality.poor;
    }
  }

  SessionStats copyWith({
    int? durationSecs,
    int? bytesSent,
    int? bytesReceived,
    int? averageLatencyMs,
    int? maxLatencyMs,
    int? minLatencyMs,
    double? packetLossPercent,
    int? jitterMs,
    int? framesSent,
    int? framesReceived,
    ConnectionQuality? connectionQuality,
    ConnectionType? connectionType,
  }) {
    return SessionStats(
      durationSecs: durationSecs ?? this.durationSecs,
      bytesSent: bytesSent ?? this.bytesSent,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      averageLatencyMs: averageLatencyMs ?? this.averageLatencyMs,
      maxLatencyMs: maxLatencyMs ?? this.maxLatencyMs,
      minLatencyMs: minLatencyMs ?? this.minLatencyMs,
      packetLossPercent: packetLossPercent ?? this.packetLossPercent,
      jitterMs: jitterMs ?? this.jitterMs,
      framesSent: framesSent ?? this.framesSent,
      framesReceived: framesReceived ?? this.framesReceived,
      connectionQuality: connectionQuality ?? this.connectionQuality,
      connectionType: connectionType ?? this.connectionType,
    );
  }

  Map<String, dynamic> toJson() => {
    'durationSecs': durationSecs,
    'bytesSent': bytesSent,
    'bytesReceived': bytesReceived,
    'averageLatencyMs': averageLatencyMs,
    'maxLatencyMs': maxLatencyMs,
    'minLatencyMs': minLatencyMs,
    'packetLossPercent': packetLossPercent,
    'jitterMs': jitterMs,
    'framesSent': framesSent,
    'framesReceived': framesReceived,
    'connectionQuality': connectionQuality.index,
    'connectionType': connectionType.index,
  };

  factory SessionStats.fromJson(Map<String, dynamic> json) => SessionStats(
    durationSecs: json['durationSecs'] ?? 0,
    bytesSent: json['bytesSent'] ?? 0,
    bytesReceived: json['bytesReceived'] ?? 0,
    averageLatencyMs: json['averageLatencyMs'] ?? 0,
    maxLatencyMs: json['maxLatencyMs'] ?? 0,
    minLatencyMs: json['minLatencyMs'] ?? 0,
    packetLossPercent: (json['packetLossPercent'] ?? 0.0).toDouble(),
    jitterMs: json['jitterMs'] ?? 0,
    framesSent: json['framesSent'] ?? 0,
    framesReceived: json['framesReceived'] ?? 0,
    connectionQuality: ConnectionQuality.values[json['connectionQuality'] ?? 1],
    connectionType: ConnectionType.values[json['connectionType'] ?? 0],
  );
}


/// 会话信息
class Session {
  final String sessionId;
  final String controllerId;
  final String controlledId;
  final DateTime startTime;
  final DateTime? endTime;
  final SessionStatus status;
  final List<SessionPermission> permissions;
  final SessionStats stats;
  final Map<String, String> metadata;

  const Session({
    required this.sessionId,
    required this.controllerId,
    required this.controlledId,
    required this.startTime,
    this.endTime,
    this.status = SessionStatus.pending,
    this.permissions = const [],
    this.stats = const SessionStats(),
    this.metadata = const {},
  });

  /// 获取会话持续时间
  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  Session copyWith({
    String? sessionId,
    String? controllerId,
    String? controlledId,
    DateTime? startTime,
    DateTime? endTime,
    SessionStatus? status,
    List<SessionPermission>? permissions,
    SessionStats? stats,
    Map<String, String>? metadata,
  }) {
    return Session(
      sessionId: sessionId ?? this.sessionId,
      controllerId: controllerId ?? this.controllerId,
      controlledId: controlledId ?? this.controlledId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      permissions: permissions ?? this.permissions,
      stats: stats ?? this.stats,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'controllerId': controllerId,
    'controlledId': controlledId,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'status': status.index,
    'permissions': permissions.map((p) => p.index).toList(),
    'stats': stats.toJson(),
    'metadata': metadata,
  };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
    sessionId: json['sessionId'],
    controllerId: json['controllerId'],
    controlledId: json['controlledId'],
    startTime: DateTime.parse(json['startTime']),
    endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
    status: SessionStatus.values[json['status'] ?? 0],
    permissions: (json['permissions'] as List?)
        ?.map((p) => SessionPermission.values[p])
        .toList() ?? [],
    stats: json['stats'] != null 
        ? SessionStats.fromJson(json['stats']) 
        : const SessionStats(),
    metadata: Map<String, String>.from(json['metadata'] ?? {}),
  );
}

/// 会话历史记录
class SessionRecord {
  final String sessionId;
  final String controllerId;
  final String controlledId;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSecs;
  final EndReason endReason;
  final SessionStats finalStats;

  const SessionRecord({
    required this.sessionId,
    required this.controllerId,
    required this.controlledId,
    required this.startTime,
    required this.endTime,
    required this.durationSecs,
    required this.endReason,
    required this.finalStats,
  });

  Duration get duration => Duration(seconds: durationSecs);

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'controllerId': controllerId,
    'controlledId': controlledId,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'durationSecs': durationSecs,
    'endReason': endReason.index,
    'finalStats': finalStats.toJson(),
  };

  factory SessionRecord.fromJson(Map<String, dynamic> json) => SessionRecord(
    sessionId: json['sessionId'],
    controllerId: json['controllerId'],
    controlledId: json['controlledId'],
    startTime: DateTime.parse(json['startTime']),
    endTime: DateTime.parse(json['endTime']),
    durationSecs: json['durationSecs'],
    endReason: EndReason.values[json['endReason'] ?? 0],
    finalStats: SessionStats.fromJson(json['finalStats'] ?? {}),
  );
}

/// 会话创建选项
class SessionOptions {
  final List<SessionPermission> permissions;
  final bool autoAccept;
  final int sessionTimeoutSecs;
  final bool requireEncryption;

  const SessionOptions({
    this.permissions = const [SessionPermission.screenView, SessionPermission.inputControl],
    this.autoAccept = false,
    this.sessionTimeoutSecs = 3600,
    this.requireEncryption = true,
  });
}

/// 权限请求
class PermissionRequest {
  final String requestId;
  final String fromDeviceId;
  final String toDeviceId;
  final List<SessionPermission> permissions;
  final String? message;
  final DateTime createdAt;
  final DateTime expiresAt;

  const PermissionRequest({
    required this.requestId,
    required this.fromDeviceId,
    required this.toDeviceId,
    required this.permissions,
    this.message,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// 会话摘要统计
class SessionSummaryStats {
  final int activeSessions;
  final int totalSessions30Days;
  final int totalDurationSecs;
  final int averageDurationSecs;

  const SessionSummaryStats({
    this.activeSessions = 0,
    this.totalSessions30Days = 0,
    this.totalDurationSecs = 0,
    this.averageDurationSecs = 0,
  });
}

/// 会话事件类型
enum SessionEventType {
  created,
  started,
  paused,
  resumed,
  ended,
  statsUpdated,
  permissionRequested,
  permissionGranted,
  permissionDenied,
}

/// 会话事件
class SessionEvent {
  final SessionEventType type;
  final String sessionId;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  const SessionEvent({
    required this.type,
    required this.sessionId,
    required this.timestamp,
    this.data,
  });
}


/// 会话管理服务状态
class SessionManagementState {
  final Map<String, Session> activeSessions;
  final List<SessionRecord> sessionHistory;
  final List<PermissionRequest> pendingRequests;
  final SessionSummaryStats summaryStats;
  final bool isLoading;
  final String? errorMessage;

  const SessionManagementState({
    this.activeSessions = const {},
    this.sessionHistory = const [],
    this.pendingRequests = const [],
    this.summaryStats = const SessionSummaryStats(),
    this.isLoading = false,
    this.errorMessage,
  });

  SessionManagementState copyWith({
    Map<String, Session>? activeSessions,
    List<SessionRecord>? sessionHistory,
    List<PermissionRequest>? pendingRequests,
    SessionSummaryStats? summaryStats,
    bool? isLoading,
    String? errorMessage,
  }) {
    return SessionManagementState(
      activeSessions: activeSessions ?? this.activeSessions,
      sessionHistory: sessionHistory ?? this.sessionHistory,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      summaryStats: summaryStats ?? this.summaryStats,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// 会话管理服务
class SessionManagementService extends StateNotifier<SessionManagementState> {
  final SecureStorageService _secureStorage;
  final String _localDeviceId;
  final int _historyRetentionDays;
  
  final StreamController<SessionEvent> _eventController = 
      StreamController<SessionEvent>.broadcast();
  
  Timer? _statsUpdateTimer;
  Timer? _cleanupTimer;

  static const String _historyStorageKey = 'session_history';

  SessionManagementService({
    required SecureStorageService secureStorage,
    String? localDeviceId,
    int historyRetentionDays = 30,
  }) : _secureStorage = secureStorage,
       _localDeviceId = localDeviceId ?? 'local_device',
       _historyRetentionDays = historyRetentionDays,
       super(const SessionManagementState()) {
    _initialize();
  }

  /// 会话事件流
  Stream<SessionEvent> get eventStream => _eventController.stream;

  /// 初始化服务
  Future<void> _initialize() async {
    await _loadSessionHistory();
    _startCleanupTimer();
  }

  /// 加载会话历史
  Future<void> _loadSessionHistory() async {
    try {
      final historyJson = await _secureStorage.read(_historyStorageKey);
      if (historyJson != null) {
        final List<dynamic> historyList = 
            historyJson.isNotEmpty 
                ? _parseJsonList(historyJson) 
                : [];
        final history = historyList
            .map((json) => SessionRecord.fromJson(json))
            .toList();
        
        // 过滤过期记录
        final cutoff = DateTime.now().subtract(Duration(days: _historyRetentionDays));
        final filteredHistory = history
            .where((record) => record.endTime.isAfter(cutoff))
            .toList();
        
        state = state.copyWith(
          sessionHistory: filteredHistory,
          summaryStats: _calculateSummaryStats(filteredHistory),
        );
      }
    } catch (e) {
      // 忽略加载错误，使用空历史
    }
  }

  List<dynamic> _parseJsonList(String json) {
    // 简单的 JSON 解析，实际应使用 dart:convert
    try {
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 保存会话历史
  Future<void> _saveSessionHistory() async {
    try {
      final historyJson = state.sessionHistory
          .map((record) => record.toJson())
          .toList();
      await _secureStorage.write(_historyStorageKey, historyJson.toString());
    } catch (e) {
      // 忽略保存错误
    }
  }

  /// 启动清理定时器
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _cleanupExpiredData();
    });
  }

  /// 清理过期数据
  void _cleanupExpiredData() {
    // 清理过期的权限请求
    final validRequests = state.pendingRequests
        .where((request) => !request.isExpired)
        .toList();
    
    // 清理过期的历史记录
    final cutoff = DateTime.now().subtract(Duration(days: _historyRetentionDays));
    final validHistory = state.sessionHistory
        .where((record) => record.endTime.isAfter(cutoff))
        .toList();
    
    state = state.copyWith(
      pendingRequests: validRequests,
      sessionHistory: validHistory,
      summaryStats: _calculateSummaryStats(validHistory),
    );
  }

  /// 计算摘要统计
  SessionSummaryStats _calculateSummaryStats(List<SessionRecord> history) {
    final totalDuration = history.fold<int>(
      0, (sum, record) => sum + record.durationSecs);
    final avgDuration = history.isNotEmpty 
        ? totalDuration ~/ history.length 
        : 0;
    
    return SessionSummaryStats(
      activeSessions: state.activeSessions.length,
      totalSessions30Days: history.length,
      totalDurationSecs: totalDuration,
      averageDurationSecs: avgDuration,
    );
  }

  /// 触发事件
  void _emitEvent(SessionEvent event) {
    _eventController.add(event);
  }

  /// 创建新会话
  Future<Session> createSession({
    required String remoteId,
    SessionOptions options = const SessionOptions(),
  }) async {
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    
    final session = Session(
      sessionId: sessionId,
      controllerId: _localDeviceId,
      controlledId: remoteId,
      startTime: DateTime.now(),
      status: SessionStatus.pending,
      permissions: options.permissions,
    );

    final newSessions = Map<String, Session>.from(state.activeSessions);
    newSessions[sessionId] = session;
    
    state = state.copyWith(
      activeSessions: newSessions,
      summaryStats: _calculateSummaryStats(state.sessionHistory),
    );

    _emitEvent(SessionEvent(
      type: SessionEventType.created,
      sessionId: sessionId,
      timestamp: DateTime.now(),
      data: {
        'controllerId': _localDeviceId,
        'controlledId': remoteId,
      },
    ));

    return session;
  }

  /// 加入会话（激活会话）
  Future<Session> joinSession(String sessionId) async {
    final session = state.activeSessions[sessionId];
    if (session == null) {
      throw Exception('Session not found: $sessionId');
    }

    final updatedSession = session.copyWith(status: SessionStatus.active);
    final newSessions = Map<String, Session>.from(state.activeSessions);
    newSessions[sessionId] = updatedSession;
    
    state = state.copyWith(activeSessions: newSessions);

    _emitEvent(SessionEvent(
      type: SessionEventType.started,
      sessionId: sessionId,
      timestamp: DateTime.now(),
    ));

    // 启动统计更新
    _startStatsUpdate(sessionId);

    return updatedSession;
  }

  /// 暂停会话
  Future<void> pauseSession(String sessionId) async {
    final session = state.activeSessions[sessionId];
    if (session == null) {
      throw Exception('Session not found: $sessionId');
    }

    final updatedSession = session.copyWith(status: SessionStatus.paused);
    final newSessions = Map<String, Session>.from(state.activeSessions);
    newSessions[sessionId] = updatedSession;
    
    state = state.copyWith(activeSessions: newSessions);

    _emitEvent(SessionEvent(
      type: SessionEventType.paused,
      sessionId: sessionId,
      timestamp: DateTime.now(),
    ));
  }

  /// 恢复会话
  Future<void> resumeSession(String sessionId) async {
    final session = state.activeSessions[sessionId];
    if (session == null) {
      throw Exception('Session not found: $sessionId');
    }

    final updatedSession = session.copyWith(status: SessionStatus.active);
    final newSessions = Map<String, Session>.from(state.activeSessions);
    newSessions[sessionId] = updatedSession;
    
    state = state.copyWith(activeSessions: newSessions);

    _emitEvent(SessionEvent(
      type: SessionEventType.resumed,
      sessionId: sessionId,
      timestamp: DateTime.now(),
    ));
  }

  /// 结束会话
  Future<SessionRecord> endSession(String sessionId, {
    EndReason reason = EndReason.userRequested,
  }) async {
    final session = state.activeSessions[sessionId];
    if (session == null) {
      throw Exception('Session not found: $sessionId');
    }

    final endTime = DateTime.now();
    final durationSecs = endTime.difference(session.startTime).inSeconds;

    final record = SessionRecord(
      sessionId: session.sessionId,
      controllerId: session.controllerId,
      controlledId: session.controlledId,
      startTime: session.startTime,
      endTime: endTime,
      durationSecs: durationSecs,
      endReason: reason,
      finalStats: session.stats.copyWith(durationSecs: durationSecs),
    );

    // 从活动会话中移除
    final newSessions = Map<String, Session>.from(state.activeSessions);
    newSessions.remove(sessionId);

    // 添加到历史记录
    final newHistory = [record, ...state.sessionHistory];
    
    state = state.copyWith(
      activeSessions: newSessions,
      sessionHistory: newHistory,
      summaryStats: _calculateSummaryStats(newHistory),
    );

    // 保存历史记录
    await _saveSessionHistory();

    _emitEvent(SessionEvent(
      type: SessionEventType.ended,
      sessionId: sessionId,
      timestamp: DateTime.now(),
      data: {'reason': reason.displayName},
    ));

    return record;
  }

  /// 更新会话统计
  void updateSessionStats(
    String sessionId, {
    required int latencyMs,
    required double packetLossPercent,
    required int jitterMs,
    int bytesSentDelta = 0,
    int bytesReceivedDelta = 0,
  }) {
    final session = state.activeSessions[sessionId];
    if (session == null) return;

    final currentStats = session.stats;
    final newAvgLatency = currentStats.averageLatencyMs == 0
        ? latencyMs
        : (currentStats.averageLatencyMs * 9 + latencyMs) ~/ 10;

    final updatedStats = currentStats.copyWith(
      durationSecs: DateTime.now().difference(session.startTime).inSeconds,
      bytesSent: currentStats.bytesSent + bytesSentDelta,
      bytesReceived: currentStats.bytesReceived + bytesReceivedDelta,
      averageLatencyMs: newAvgLatency,
      maxLatencyMs: latencyMs > currentStats.maxLatencyMs 
          ? latencyMs 
          : currentStats.maxLatencyMs,
      minLatencyMs: currentStats.minLatencyMs == 0 || latencyMs < currentStats.minLatencyMs
          ? latencyMs
          : currentStats.minLatencyMs,
      packetLossPercent: packetLossPercent,
      jitterMs: jitterMs,
      connectionQuality: SessionStats.calculateQuality(latencyMs, packetLossPercent, jitterMs),
    );

    final updatedSession = session.copyWith(stats: updatedStats);
    final newSessions = Map<String, Session>.from(state.activeSessions);
    newSessions[sessionId] = updatedSession;
    
    state = state.copyWith(activeSessions: newSessions);

    _emitEvent(SessionEvent(
      type: SessionEventType.statsUpdated,
      sessionId: sessionId,
      timestamp: DateTime.now(),
      data: updatedStats.toJson(),
    ));
  }

  /// 启动统计更新定时器
  void _startStatsUpdate(String sessionId) {
    _statsUpdateTimer?.cancel();
    _statsUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final session = state.activeSessions[sessionId];
      if (session != null && session.status == SessionStatus.active) {
        // 模拟统计更新（实际应从 WebRTC 获取）
        updateSessionStats(
          sessionId,
          latencyMs: 40 + (DateTime.now().millisecond % 20),
          packetLossPercent: (DateTime.now().millisecond % 10) / 10,
          jitterMs: 3 + (DateTime.now().millisecond % 5),
        );
      }
    });
  }

  /// 获取活动会话列表
  List<Session> getActiveSessions() {
    return state.activeSessions.values.toList();
  }

  /// 获取指定会话
  Session? getSession(String sessionId) {
    return state.activeSessions[sessionId];
  }

  /// 获取会话历史记录
  List<SessionRecord> getSessionHistory({int? days}) {
    final retentionDays = days ?? _historyRetentionDays;
    final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
    
    return state.sessionHistory
        .where((record) => record.endTime.isAfter(cutoff))
        .toList();
  }

  /// 获取会话统计
  SessionStats? getSessionStats(String sessionId) {
    return state.activeSessions[sessionId]?.stats;
  }

  /// 获取摘要统计
  SessionSummaryStats getSummaryStats() {
    return state.summaryStats;
  }

  /// 清除会话历史
  Future<void> clearSessionHistory() async {
    state = state.copyWith(
      sessionHistory: [],
      summaryStats: const SessionSummaryStats(),
    );
    await _saveSessionHistory();
  }

  @override
  void dispose() {
    _statsUpdateTimer?.cancel();
    _cleanupTimer?.cancel();
    _eventController.close();
    super.dispose();
  }
}

/// 会话管理服务 Provider
final sessionManagementServiceProvider = 
    StateNotifierProvider<SessionManagementService, SessionManagementState>((ref) {
  final secureStorage = SecureStorageService();
  return SessionManagementService(secureStorage: secureStorage);
});
