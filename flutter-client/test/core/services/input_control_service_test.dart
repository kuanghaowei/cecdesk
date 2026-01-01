import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remote_desktop_client/src/core/services/input_control_service.dart';

void main() {
  group('InputControlService', () {
    late ProviderContainer container;
    late InputControlService inputService;

    setUp(() {
      container = ProviderContainer();
      inputService = container.read(inputControlServiceProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    group('enable/disable', () {
      test('启用后应该设置 isEnabled 为 true', () {
        inputService.enable();
        final state = container.read(inputControlServiceProvider);
        expect(state.isEnabled, true);
      });

      test('禁用后应该重置所有状态', () {
        inputService.enable();
        inputService.captureMouse();
        inputService.captureKeyboard();

        inputService.disable();

        final state = container.read(inputControlServiceProvider);
        expect(state.isEnabled, false);
        expect(state.isMouseCaptured, false);
        expect(state.isKeyboardCaptured, false);
      });
    });

    group('mouse capture', () {
      test('未启用时不应该捕获鼠标', () {
        inputService.captureMouse();
        final state = container.read(inputControlServiceProvider);
        expect(state.isMouseCaptured, false);
      });

      test('启用后应该能捕获鼠标', () {
        inputService.enable();
        inputService.captureMouse();
        final state = container.read(inputControlServiceProvider);
        expect(state.isMouseCaptured, true);
      });

      test('应该能释放鼠标', () {
        inputService.enable();
        inputService.captureMouse();
        inputService.releaseMouse();
        final state = container.read(inputControlServiceProvider);
        expect(state.isMouseCaptured, false);
      });
    });

    group('keyboard capture', () {
      test('未启用时不应该捕获键盘', () {
        inputService.captureKeyboard();
        final state = container.read(inputControlServiceProvider);
        expect(state.isKeyboardCaptured, false);
      });

      test('启用后应该能捕获键盘', () {
        inputService.enable();
        inputService.captureKeyboard();
        final state = container.read(inputControlServiceProvider);
        expect(state.isKeyboardCaptured, true);
      });
    });

    group('sendMouseEvent', () {
      test('未启用时应该返回 false', () async {
        final result = await inputService.sendMouseEvent(MouseEvent(
          type: MouseEventType.move,
          x: 100,
          y: 100,
        ));
        expect(result, false);
      });

      test('未捕获鼠标时应该返回 false', () async {
        inputService.enable();
        final result = await inputService.sendMouseEvent(MouseEvent(
          type: MouseEventType.move,
          x: 100,
          y: 100,
        ));
        expect(result, false);
      });

      test('启用并捕获后应该成功发送事件', () async {
        inputService.enable();
        inputService.captureMouse();

        final result = await inputService.sendMouseEvent(MouseEvent(
          type: MouseEventType.click,
          x: 100,
          y: 100,
          button: MouseButton.left,
        ));

        expect(result, true);
      });
    });

    group('sendKeyEvent', () {
      test('未启用时应该返回 false', () async {
        final result = await inputService.sendKeyEvent(KeyEvent(
          type: KeyEventType.press,
          key: 'a',
        ));
        expect(result, false);
      });

      test('启用并捕获后应该成功发送事件', () async {
        inputService.enable();
        inputService.captureKeyboard();

        final result = await inputService.sendKeyEvent(KeyEvent(
          type: KeyEventType.press,
          key: 'a',
        ));

        expect(result, true);
      });
    });

    group('sendKeyCombo', () {
      test('应该能发送组合键', () async {
        inputService.enable();
        inputService.captureKeyboard();

        final result = await inputService.sendKeyCombo(['Control', 'c']);
        expect(result, true);
      });
    });

    group('sendCtrlAltDelete', () {
      test('应该能发送 Ctrl+Alt+Delete', () async {
        inputService.enable();
        inputService.captureKeyboard();

        final result = await inputService.sendCtrlAltDelete();
        expect(result, true);
      });
    });

    /// 属性 9: 输入响应延迟
    /// 验证: 需求 7.1 - 鼠标和键盘事件应在 100ms 内执行
    group('属性 9: 输入响应延迟', () {
      test('鼠标事件应在 100ms 内响应', () async {
        inputService.enable();
        inputService.captureMouse();

        // 发送多个鼠标事件并验证延迟
        for (var i = 0; i < 10; i++) {
          final startTime = DateTime.now();

          final result = await inputService.sendMouseEvent(MouseEvent(
            type: MouseEventType.move,
            x: i * 10.0,
            y: i * 10.0,
          ));

          final latency = DateTime.now().difference(startTime).inMilliseconds;

          // 验证事件成功发送且延迟在 100ms 内
          expect(result, true, reason: '鼠标事件应该成功发送');
          expect(latency, lessThanOrEqualTo(100),
              reason: '鼠标事件延迟应在 100ms 内，实际: ${latency}ms');
        }
      });

      test('键盘事件应在 100ms 内响应', () async {
        inputService.enable();
        inputService.captureKeyboard();

        // 发送多个键盘事件并验证延迟
        final testKeys = ['a', 'b', 'c', 'd', 'e', 'Enter', 'Escape', 'Tab'];

        for (final key in testKeys) {
          final startTime = DateTime.now();

          final result = await inputService.sendKeyEvent(KeyEvent(
            type: KeyEventType.press,
            key: key,
          ));

          final latency = DateTime.now().difference(startTime).inMilliseconds;

          // 验证事件成功发送且延迟在 100ms 内
          expect(result, true, reason: '键盘事件应该成功发送');
          expect(latency, lessThanOrEqualTo(100),
              reason: '键盘事件延迟应在 100ms 内，实际: ${latency}ms');
        }
      });

      test('组合键应在 100ms 内响应', () async {
        inputService.enable();
        inputService.captureKeyboard();

        final combos = [
          ['Control', 'c'],
          ['Control', 'v'],
          ['Control', 'Shift', 's'],
          ['Alt', 'Tab'],
        ];

        for (final combo in combos) {
          final startTime = DateTime.now();

          final result = await inputService.sendKeyCombo(combo);

          final latency = DateTime.now().difference(startTime).inMilliseconds;

          expect(result, true, reason: '组合键应该成功发送');
          // 组合键允许稍长的延迟，因为需要发送多个事件
          expect(latency, lessThanOrEqualTo(500),
              reason: '组合键延迟应在合理范围内，实际: ${latency}ms');
        }
      });

      test('延迟统计应该正确计算', () async {
        inputService.enable();
        inputService.captureMouse();

        // 发送足够多的事件以生成统计数据
        for (var i = 0; i < 20; i++) {
          await inputService.sendMouseEvent(MouseEvent(
            type: MouseEventType.move,
            x: i.toDouble(),
            y: i.toDouble(),
          ));
        }

        // 等待统计更新
        await Future.delayed(const Duration(seconds: 2));

        final state = container.read(inputControlServiceProvider);

        // 验证统计数据
        expect(state.latencyStats.sampleCount, greaterThan(0));
        expect(state.latencyStats.averageLatency, greaterThan(0));
        expect(state.latencyStats.minLatency, greaterThan(0));
        expect(state.latencyStats.maxLatency, greaterThanOrEqualTo(state.latencyStats.minLatency));
        expect(state.latencyStats.p95Latency, greaterThanOrEqualTo(state.latencyStats.averageLatency * 0.5));
      });

      test('isLatencyAcceptable 应该正确判断延迟是否可接受', () async {
        inputService.enable();
        inputService.captureMouse();

        // 发送事件
        for (var i = 0; i < 10; i++) {
          await inputService.sendMouseEvent(MouseEvent(
            type: MouseEventType.move,
            x: i.toDouble(),
            y: i.toDouble(),
          ));
        }

        // 等待统计更新
        await Future.delayed(const Duration(seconds: 2));

        // 由于模拟延迟在 20-50ms 范围内，应该是可接受的
        expect(inputService.isLatencyAcceptable(), true);
      });
    });
  });

  group('MouseEvent', () {
    test('应该正确序列化为 JSON', () {
      final event = MouseEvent(
        type: MouseEventType.click,
        x: 100.5,
        y: 200.5,
        button: MouseButton.left,
      );

      final json = event.toJson();

      expect(json['type'], 'click');
      expect(json['x'], 100.5);
      expect(json['y'], 200.5);
      expect(json['button'], 'left');
    });
  });

  group('KeyEvent', () {
    test('应该正确序列化为 JSON', () {
      final event = KeyEvent(
        type: KeyEventType.press,
        key: 'a',
        keyCode: 65,
        ctrlKey: true,
      );

      final json = event.toJson();

      expect(json['type'], 'press');
      expect(json['key'], 'a');
      expect(json['keyCode'], 65);
      expect(json['ctrlKey'], true);
    });

    test('isComboKey 应该正确判断组合键', () {
      final normalKey = KeyEvent(type: KeyEventType.press, key: 'a');
      expect(normalKey.isComboKey, false);

      final ctrlCombo = KeyEvent(type: KeyEventType.press, key: 'c', ctrlKey: true);
      expect(ctrlCombo.isComboKey, true);

      final altCombo = KeyEvent(type: KeyEventType.press, key: 'Tab', altKey: true);
      expect(altCombo.isComboKey, true);
    });
  });

  group('InputLatencyStats', () {
    test('应该正确复制并更新值', () {
      const stats = InputLatencyStats(
        sampleCount: 10,
        averageLatency: 50,
        minLatency: 20,
        maxLatency: 80,
        p95Latency: 75,
      );

      final updated = stats.copyWith(averageLatency: 60);

      expect(updated.sampleCount, 10);
      expect(updated.averageLatency, 60);
      expect(updated.minLatency, 20);
    });
  });
}
