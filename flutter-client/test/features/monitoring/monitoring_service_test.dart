import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remote_desktop_client/src/core/services/monitoring_service.dart';

void main() {
  group('MonitoringService', () {
    late ProviderContainer container;
    late MonitoringService monitoringService;

    setUp(() {
      container = ProviderContainer();
      monitoringService = container.read(monitoringServiceProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    group('log', () {
      test('应该记录不同级别的日志', () {
        monitoringService.debug('Test', 'Debug message');
        monitoringService.info('Test', 'Info message');
        monitoringService.warn('Test', 'Warning message');
        monitoringService.error('Test', 'Error message');

        final state = container.read(monitoringServiceProvider);
        // debug 级别默认被过滤，所以只有3条
        expect(state.logs.length, 3);
      });

      test('应该按时间倒序排列日志', () {
        monitoringService.info('Test', 'First');
        monitoringService.info('Test', 'Second');
        monitoringService.info('Test', 'Third');

        final state = container.read(monitoringServiceProvider);
        expect(state.logs.first.message, 'Third');
        expect(state.logs.last.message, 'First');
      });

      test('应该支持元数据', () {
        monitoringService.info('Test', 'With metadata', metadata: {
          'key': 'value',
          'number': 42,
        });

        final state = container.read(monitoringServiceProvider);
        expect(state.logs.first.metadata, isNotNull);
        expect(state.logs.first.metadata!['key'], 'value');
        expect(state.logs.first.metadata!['number'], 42);
      });

      test('应该支持会话ID和设备ID', () {
        monitoringService.info(
          'Test',
          'With session and device',
          sessionId: 'session-123',
          deviceId: 'device-456',
        );

        final state = container.read(monitoringServiceProvider);
        expect(state.logs.first.sessionId, 'session-123');
        expect(state.logs.first.deviceId, 'device-456');
      });
    });

    group('setMinLogLevel', () {
      test('应该过滤低于最小级别的日志', () {
        // 先设置为debug级别以记录所有日志
        monitoringService.setMinLogLevel(LogLevel.debug);
        
        monitoringService.debug('Test', 'Debug');
        monitoringService.info('Test', 'Info');
        monitoringService.warn('Test', 'Warn');
        monitoringService.error('Test', 'Error');

        // 设置最小级别为 warn
        monitoringService.setMinLogLevel(LogLevel.warn);

        final state = container.read(monitoringServiceProvider);
        expect(state.filteredLogs.length, 2);
        expect(state.filteredLogs.every((l) => l.level.priority >= LogLevel.warn.priority), true);
      });
    });

    group('clearLogs', () {
      test('应该清除所有日志', () {
        monitoringService.info('Test', 'Message 1');
        monitoringService.info('Test', 'Message 2');

        var state = container.read(monitoringServiceProvider);
        expect(state.logs.length, 2);

        monitoringService.clearLogs();

        state = container.read(monitoringServiceProvider);
        expect(state.logs.length, 0);
      });
    });

    group('exportLogs', () {
      test('应该导出格式化的日志', () {
        monitoringService.info('Connection', 'Connected to device');
        monitoringService.warn('Network', 'High latency detected');

        final exported = monitoringService.exportLogs();

        expect(exported, contains('远程桌面客户端日志导出'));
        expect(exported, contains('Connected to device'));
        expect(exported, contains('High latency detected'));
        expect(exported, contains('[INFO]'));
        expect(exported, contains('[WARN]'));
      });
    });

    group('connectionEvents', () {
      test('应该记录连接建立事件', () {
        monitoringService.logConnectionEstablished(
          sessionId: 'session-123',
          remoteDeviceId: 'device-456',
          details: {'connectionType': 'direct'},
        );

        final state = container.read(monitoringServiceProvider);
        expect(state.connectionEvents.length, 1);
        expect(state.connectionEvents.first.eventType, ConnectionEventType.connectionEstablished);
        expect(state.connectionEvents.first.sessionId, 'session-123');
        expect(state.connectionEvents.first.success, true);
      });

      test('应该记录连接失败事件', () {
        monitoringService.logConnectionFailed(
          sessionId: 'session-123',
          remoteDeviceId: 'device-456',
          errorMessage: 'Connection timeout',
        );

        final state = container.read(monitoringServiceProvider);
        expect(state.connectionEvents.length, 1);
        expect(state.connectionEvents.first.eventType, ConnectionEventType.connectionFailed);
        expect(state.connectionEvents.first.success, false);
        expect(state.connectionEvents.first.errorMessage, 'Connection timeout');
      });

      test('应该记录连接关闭事件', () {
        monitoringService.logConnectionClosed(
          sessionId: 'session-123',
          remoteDeviceId: 'device-456',
          reason: 'User requested',
        );

        final state = container.read(monitoringServiceProvider);
        expect(state.connectionEvents.length, 1);
        expect(state.connectionEvents.first.eventType, ConnectionEventType.connectionClosed);
      });

      test('应该清除连接事件', () {
        monitoringService.logConnectionEstablished(
          sessionId: 'session-123',
          remoteDeviceId: 'device-456',
        );

        var state = container.read(monitoringServiceProvider);
        expect(state.connectionEvents.length, 1);

        monitoringService.clearConnectionEvents();

        state = container.read(monitoringServiceProvider);
        expect(state.connectionEvents.length, 0);
      });
    });

    group('runDiagnostics', () {
      test('应该运行网络诊断并返回结果', () async {
        final diagnostics = await monitoringService.runDiagnostics();

        expect(diagnostics.internetConnected, true);
        expect(diagnostics.signalingServer.reachable, true);
        expect(diagnostics.stunServers.any((s) => s.reachable), true);
        expect(diagnostics.turnServers.any((s) => s.reachable), true);
        expect(diagnostics.allServicesReachable, true);
      });

      test('诊断过程中应该记录日志', () async {
        await monitoringService.runDiagnostics();

        final state = container.read(monitoringServiceProvider);
        expect(state.logs.any((l) => l.message.contains('网络诊断')), true);
      });

      test('应该返回NAT类型', () async {
        final diagnostics = await monitoringService.runDiagnostics();

        expect(diagnostics.natType, isNot(NatType.unknown));
      });

      test('应该返回总体状态', () async {
        final diagnostics = await monitoringService.runDiagnostics();

        expect(diagnostics.overallStatus, DiagnosticStatus.good);
      });
    });

    group('exportDiagnosticReport', () {
      test('应该导出完整诊断报告', () async {
        await monitoringService.runDiagnostics();
        monitoringService.logConnectionEstablished(
          sessionId: 'session-123',
          remoteDeviceId: 'device-456',
        );

        final report = monitoringService.exportDiagnosticReport();

        expect(report, contains('远程桌面客户端诊断报告'));
        expect(report, contains('网络诊断'));
        expect(report, contains('连接事件'));
        expect(report, contains('最近日志'));
      });
    });
  });

  group('LogEntry', () {
    test('应该正确格式化时间', () {
      final entry = LogEntry(
        timestamp: DateTime(2026, 1, 1, 14, 30, 45, 123),
        level: LogLevel.info,
        category: 'Test',
        message: 'Test message',
      );

      expect(entry.formattedTime, contains('14:30:45'));
    });

    test('应该正确返回级别字符串', () {
      expect(
        LogEntry(
          timestamp: DateTime.now(),
          level: LogLevel.debug,
          category: 'Test',
          message: 'Test',
        ).levelString,
        'DEBUG',
      );

      expect(
        LogEntry(
          timestamp: DateTime.now(),
          level: LogLevel.error,
          category: 'Test',
          message: 'Test',
        ).levelString,
        'ERROR',
      );
    });

    test('应该正确格式化完整日志条目', () {
      final entry = LogEntry(
        timestamp: DateTime(2026, 1, 1, 14, 30, 45),
        level: LogLevel.info,
        category: 'Test',
        message: 'Test message',
        sessionId: 'session-123',
        deviceId: 'device-456',
      );

      final formatted = entry.format();
      expect(formatted, contains('[INFO]'));
      expect(formatted, contains('[Test]'));
      expect(formatted, contains('Test message'));
      expect(formatted, contains('[session:session-123]'));
      expect(formatted, contains('[device:device-456]'));
    });
  });

  group('NetworkDiagnostics', () {
    test('allServicesReachable 应该在所有服务可达时返回 true', () {
      final diagnostics = NetworkDiagnostics(
        internetConnected: true,
        signalingServer: ServerStatus(
          name: 'Signaling',
          url: 'wss://test.com',
          reachable: true,
          lastCheck: DateTime.now(),
        ),
        stunServers: [
          ServerStatus(
            name: 'STUN',
            url: 'stun:test.com',
            reachable: true,
            lastCheck: DateTime.now(),
          ),
        ],
        turnServers: [
          ServerStatus(
            name: 'TURN',
            url: 'turn:test.com',
            reachable: true,
            lastCheck: DateTime.now(),
          ),
        ],
        timestamp: DateTime.now(),
      );

      expect(diagnostics.allServicesReachable, true);
    });

    test('allServicesReachable 应该在任一服务不可达时返回 false', () {
      final diagnostics = NetworkDiagnostics(
        internetConnected: true,
        signalingServer: ServerStatus(
          name: 'Signaling',
          url: 'wss://test.com',
          reachable: true,
          lastCheck: DateTime.now(),
        ),
        stunServers: [
          ServerStatus(
            name: 'STUN',
            url: 'stun:test.com',
            reachable: false,
            lastCheck: DateTime.now(),
          ),
        ],
        turnServers: [
          ServerStatus(
            name: 'TURN',
            url: 'turn:test.com',
            reachable: true,
            lastCheck: DateTime.now(),
          ),
        ],
        timestamp: DateTime.now(),
      );

      expect(diagnostics.allServicesReachable, false);
    });
  });

  group('ConnectionEvent', () {
    test('应该正确创建连接事件', () {
      final event = ConnectionEvent(
        timestamp: DateTime.now(),
        eventType: ConnectionEventType.connectionEstablished,
        sessionId: 'session-123',
        remoteDeviceId: 'device-456',
        success: true,
      );

      expect(event.eventType, ConnectionEventType.connectionEstablished);
      expect(event.sessionId, 'session-123');
      expect(event.success, true);
    });

    test('应该正确序列化和反序列化', () {
      final event = ConnectionEvent(
        timestamp: DateTime.now(),
        eventType: ConnectionEventType.connectionFailed,
        sessionId: 'session-123',
        errorMessage: 'Connection timeout',
        success: false,
      );

      final json = event.toJson();
      final restored = ConnectionEvent.fromJson(json);

      expect(restored.eventType, event.eventType);
      expect(restored.sessionId, event.sessionId);
      expect(restored.errorMessage, event.errorMessage);
      expect(restored.success, event.success);
    });
  });

  group('NatType', () {
    test('应该正确显示NAT类型名称', () {
      expect(NatType.fullCone.displayName, '完全锥形NAT');
      expect(NatType.symmetric.displayName, '对称NAT');
      expect(NatType.unknown.displayName, '未知');
    });
  });
}
