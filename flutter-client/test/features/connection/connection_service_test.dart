import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remote_desktop_client/src/core/services/connection_service.dart';

void main() {
  group('ConnectionService', () {
    late ProviderContainer container;
    late ConnectionService connectionService;

    setUp(() {
      container = ProviderContainer();
      connectionService = container.read(connectionServiceProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    group('connect', () {
      test('应该验证设备代码格式为9位数字', () async {
        // 无效的设备代码
        final result1 = await connectionService.connect(
          deviceCode: '12345678', // 8位
          password: 'abc123def',
        );
        expect(result1, false);

        final result2 = await connectionService.connect(
          deviceCode: '1234567890', // 10位
          password: 'abc123def',
        );
        expect(result2, false);

        final result3 = await connectionService.connect(
          deviceCode: 'abcdefghi', // 非数字
          password: 'abc123def',
        );
        expect(result3, false);
      });

      test('应该验证连接密码格式为9位数字字符组合', () async {
        // 无效的密码
        final result1 = await connectionService.connect(
          deviceCode: '123456789',
          password: '12345678', // 8位
        );
        expect(result1, false);

        final result2 = await connectionService.connect(
          deviceCode: '123456789',
          password: 'abc!@#def', // 包含特殊字符
        );
        expect(result2, false);
      });

      test('有效的设备代码和密码应该连接成功', () async {
        final result = await connectionService.connect(
          deviceCode: '123456789',
          password: 'abc123def',
        );
        expect(result, true);

        final state = container.read(connectionServiceProvider);
        expect(state.currentSession, isNotNull);
        expect(state.currentSession!.remoteDeviceId, '123456789');
        expect(state.currentSession!.status, ConnectionStatus.connected);
      });
    });

    group('disconnect', () {
      test('断开连接应该清除当前会话并添加到历史', () async {
        // 先建立连接
        await connectionService.connect(
          deviceCode: '123456789',
          password: 'abc123def',
        );

        var state = container.read(connectionServiceProvider);
        expect(state.currentSession, isNotNull);

        // 断开连接
        await connectionService.disconnect(reason: '测试断开');

        state = container.read(connectionServiceProvider);
        expect(state.currentSession, isNull);
        expect(state.sessionHistory.length, 1);
        expect(state.sessionHistory.first.disconnectReason, '测试断开');
      });
    });

    group('clearHistory', () {
      test('应该清除所有会话历史', () async {
        // 建立并断开多个连接
        await connectionService.connect(
          deviceCode: '123456789',
          password: 'abc123def',
        );
        await connectionService.disconnect();

        await connectionService.connect(
          deviceCode: '987654321',
          password: 'def456abc',
        );
        await connectionService.disconnect();

        var state = container.read(connectionServiceProvider);
        expect(state.sessionHistory.length, 2);

        // 清除历史
        connectionService.clearHistory();

        state = container.read(connectionServiceProvider);
        expect(state.sessionHistory.length, 0);
      });
    });
  });

  group('NetworkStats', () {
    test('应该根据RTT和丢包率计算连接质量', () {
      // 优秀
      const excellent = NetworkStats(rtt: 30, packetLoss: 0.5);
      expect(excellent.quality, ConnectionQuality.excellent);

      // 良好
      const good = NetworkStats(rtt: 80, packetLoss: 2.0);
      expect(good.quality, ConnectionQuality.good);

      // 一般
      const fair = NetworkStats(rtt: 150, packetLoss: 4.0);
      expect(fair.quality, ConnectionQuality.fair);

      // 较差
      const poor = NetworkStats(rtt: 300, packetLoss: 10.0);
      expect(poor.quality, ConnectionQuality.poor);
    });
  });

  group('SessionInfo', () {
    test('应该正确计算会话时长', () {
      final startTime = DateTime.now().subtract(const Duration(minutes: 5));
      final session = SessionInfo(
        sessionId: 'test',
        remoteDeviceId: '123456789',
        remoteDeviceName: 'Test Device',
        startTime: startTime,
      );

      expect(session.duration.inMinutes, greaterThanOrEqualTo(5));
    });
  });
}
