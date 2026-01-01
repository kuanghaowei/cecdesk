import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 连接状态枚举
enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

/// 连接质量等级
enum ConnectionQuality {
  excellent,
  good,
  fair,
  poor,
}

/// 网络统计信息
class NetworkStats {
  final int rtt; // Round-trip time in ms
  final double packetLoss; // Packet loss percentage
  final int jitter; // Jitter in ms
  final int bitrate; // Current bitrate in kbps
  final int frameRate; // Current frame rate
  final String resolution; // Current resolution
  final String codec; // Current codec
  final bool isRelay; // Whether using TURN relay

  const NetworkStats({
    this.rtt = 0,
    this.packetLoss = 0.0,
    this.jitter = 0,
    this.bitrate = 0,
    this.frameRate = 0,
    this.resolution = 'N/A',
    this.codec = 'N/A',
    this.isRelay = false,
  });

  ConnectionQuality get quality {
    if (rtt < 50 && packetLoss < 1) return ConnectionQuality.excellent;
    if (rtt < 100 && packetLoss < 3) return ConnectionQuality.good;
    if (rtt < 200 && packetLoss < 5) return ConnectionQuality.fair;
    return ConnectionQuality.poor;
  }

  NetworkStats copyWith({
    int? rtt,
    double? packetLoss,
    int? jitter,
    int? bitrate,
    int? frameRate,
    String? resolution,
    String? codec,
    bool? isRelay,
  }) {
    return NetworkStats(
      rtt: rtt ?? this.rtt,
      packetLoss: packetLoss ?? this.packetLoss,
      jitter: jitter ?? this.jitter,
      bitrate: bitrate ?? this.bitrate,
      frameRate: frameRate ?? this.frameRate,
      resolution: resolution ?? this.resolution,
      codec: codec ?? this.codec,
      isRelay: isRelay ?? this.isRelay,
    );
  }
}

/// 会话信息
class SessionInfo {
  final String sessionId;
  final String remoteDeviceId;
  final String remoteDeviceName;
  final DateTime startTime;
  final ConnectionStatus status;
  final NetworkStats networkStats;

  const SessionInfo({
    required this.sessionId,
    required this.remoteDeviceId,
    required this.remoteDeviceName,
    required this.startTime,
    this.status = ConnectionStatus.disconnected,
    this.networkStats = const NetworkStats(),
  });

  Duration get duration => DateTime.now().difference(startTime);

  SessionInfo copyWith({
    String? sessionId,
    String? remoteDeviceId,
    String? remoteDeviceName,
    DateTime? startTime,
    ConnectionStatus? status,
    NetworkStats? networkStats,
  }) {
    return SessionInfo(
      sessionId: sessionId ?? this.sessionId,
      remoteDeviceId: remoteDeviceId ?? this.remoteDeviceId,
      remoteDeviceName: remoteDeviceName ?? this.remoteDeviceName,
      startTime: startTime ?? this.startTime,
      status: status ?? this.status,
      networkStats: networkStats ?? this.networkStats,
    );
  }
}

/// 会话历史记录
class SessionHistory {
  final String sessionId;
  final String remoteDeviceId;
  final String remoteDeviceName;
  final DateTime startTime;
  final DateTime endTime;
  final String disconnectReason;

  const SessionHistory({
    required this.sessionId,
    required this.remoteDeviceId,
    required this.remoteDeviceName,
    required this.startTime,
    required this.endTime,
    required this.disconnectReason,
  });

  Duration get duration => endTime.difference(startTime);
}

/// 连接服务状态
class ConnectionState {
  final SessionInfo? currentSession;
  final List<SessionHistory> sessionHistory;
  final bool isConnecting;
  final String? errorMessage;

  const ConnectionState({
    this.currentSession,
    this.sessionHistory = const [],
    this.isConnecting = false,
    this.errorMessage,
  });

  ConnectionState copyWith({
    SessionInfo? currentSession,
    List<SessionHistory>? sessionHistory,
    bool? isConnecting,
    String? errorMessage,
  }) {
    return ConnectionState(
      currentSession: currentSession,
      sessionHistory: sessionHistory ?? this.sessionHistory,
      isConnecting: isConnecting ?? this.isConnecting,
      errorMessage: errorMessage,
    );
  }
}

/// 连接服务
class ConnectionService extends StateNotifier<ConnectionState> {
  Timer? _statsTimer;

  ConnectionService() : super(const ConnectionState());

  /// 连接到远程设备
  Future<bool> connect({
    required String deviceCode,
    required String password,
  }) async {
    state = state.copyWith(isConnecting: true, errorMessage: null);

    try {
      // 验证设备代码格式 (9位数字)
      if (!RegExp(r'^\d{9}$').hasMatch(deviceCode)) {
        throw Exception('设备代码格式错误，应为9位数字');
      }

      // 验证密码格式 (9位数字字符)
      if (!RegExp(r'^[a-zA-Z0-9]{9}$').hasMatch(password)) {
        throw Exception('连接密码格式错误，应为9位数字字符组合');
      }

      // 模拟连接过程
      await Future.delayed(const Duration(seconds: 2));

      // 创建会话
      final session = SessionInfo(
        sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
        remoteDeviceId: deviceCode,
        remoteDeviceName: '远程设备 $deviceCode',
        startTime: DateTime.now(),
        status: ConnectionStatus.connected,
        networkStats: const NetworkStats(
          rtt: 45,
          packetLoss: 0.1,
          jitter: 5,
          bitrate: 5000,
          frameRate: 60,
          resolution: '1920x1080',
          codec: 'H.264',
          isRelay: false,
        ),
      );

      state = state.copyWith(
        currentSession: session,
        isConnecting: false,
      );

      // 启动网络统计更新
      _startStatsUpdate();

      return true;
    } catch (e) {
      state = state.copyWith(
        isConnecting: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// 断开连接
  Future<void> disconnect({String reason = '用户主动断开'}) async {
    _stopStatsUpdate();

    if (state.currentSession != null) {
      final history = SessionHistory(
        sessionId: state.currentSession!.sessionId,
        remoteDeviceId: state.currentSession!.remoteDeviceId,
        remoteDeviceName: state.currentSession!.remoteDeviceName,
        startTime: state.currentSession!.startTime,
        endTime: DateTime.now(),
        disconnectReason: reason,
      );

      state = state.copyWith(
        currentSession: null,
        sessionHistory: [history, ...state.sessionHistory].take(100).toList(),
      );
    }
  }

  /// 清除会话历史
  void clearHistory() {
    state = state.copyWith(sessionHistory: []);
  }

  void _startStatsUpdate() {
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.currentSession != null) {
        // 模拟网络统计更新
        final currentStats = state.currentSession!.networkStats;
        final newStats = currentStats.copyWith(
          rtt: 40 + (DateTime.now().millisecond % 20),
          packetLoss: (DateTime.now().millisecond % 10) / 10,
          jitter: 3 + (DateTime.now().millisecond % 5),
        );

        state = state.copyWith(
          currentSession: state.currentSession!.copyWith(
            networkStats: newStats,
          ),
        );
      }
    });
  }

  void _stopStatsUpdate() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  @override
  void dispose() {
    _stopStatsUpdate();
    super.dispose();
  }
}

/// 连接服务 Provider
final connectionServiceProvider =
    StateNotifierProvider<ConnectionService, ConnectionState>((ref) {
  return ConnectionService();
});
