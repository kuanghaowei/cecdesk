import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 鼠标按钮类型
enum MouseButton {
  left,
  right,
  middle,
}

/// 鼠标事件类型
enum MouseEventType {
  move,
  down,
  up,
  click,
  doubleClick,
  scroll,
  drag,
}

/// 键盘事件类型
enum KeyEventType {
  down,
  up,
  press,
}

/// 鼠标事件
class MouseEvent {
  final MouseEventType type;
  final double x;
  final double y;
  final MouseButton? button;
  final double? scrollDelta;
  final DateTime timestamp;

  MouseEvent({
    required this.type,
    required this.x,
    required this.y,
    this.button,
    this.scrollDelta,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'x': x,
        'y': y,
        'button': button?.name,
        'scrollDelta': scrollDelta,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };
}

/// 键盘事件
class KeyEvent {
  final KeyEventType type;
  final String key;
  final int? keyCode;
  final bool ctrlKey;
  final bool altKey;
  final bool shiftKey;
  final bool metaKey;
  final DateTime timestamp;

  KeyEvent({
    required this.type,
    required this.key,
    this.keyCode,
    this.ctrlKey = false,
    this.altKey = false,
    this.shiftKey = false,
    this.metaKey = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'key': key,
        'keyCode': keyCode,
        'ctrlKey': ctrlKey,
        'altKey': altKey,
        'shiftKey': shiftKey,
        'metaKey': metaKey,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  /// 是否为组合键
  bool get isComboKey => ctrlKey || altKey || shiftKey || metaKey;
}

/// 输入延迟统计
class InputLatencyStats {
  final int sampleCount;
  final double averageLatency;
  final double minLatency;
  final double maxLatency;
  final double p95Latency;

  const InputLatencyStats({
    this.sampleCount = 0,
    this.averageLatency = 0,
    this.minLatency = 0,
    this.maxLatency = 0,
    this.p95Latency = 0,
  });

  InputLatencyStats copyWith({
    int? sampleCount,
    double? averageLatency,
    double? minLatency,
    double? maxLatency,
    double? p95Latency,
  }) {
    return InputLatencyStats(
      sampleCount: sampleCount ?? this.sampleCount,
      averageLatency: averageLatency ?? this.averageLatency,
      minLatency: minLatency ?? this.minLatency,
      maxLatency: maxLatency ?? this.maxLatency,
      p95Latency: p95Latency ?? this.p95Latency,
    );
  }
}

/// 输入控制状态
class InputControlState {
  final bool isEnabled;
  final bool isMouseCaptured;
  final bool isKeyboardCaptured;
  final InputLatencyStats latencyStats;
  final List<double> recentLatencies;
  final int pendingEvents;

  const InputControlState({
    this.isEnabled = false,
    this.isMouseCaptured = false,
    this.isKeyboardCaptured = false,
    this.latencyStats = const InputLatencyStats(),
    this.recentLatencies = const [],
    this.pendingEvents = 0,
  });

  InputControlState copyWith({
    bool? isEnabled,
    bool? isMouseCaptured,
    bool? isKeyboardCaptured,
    InputLatencyStats? latencyStats,
    List<double>? recentLatencies,
    int? pendingEvents,
  }) {
    return InputControlState(
      isEnabled: isEnabled ?? this.isEnabled,
      isMouseCaptured: isMouseCaptured ?? this.isMouseCaptured,
      isKeyboardCaptured: isKeyboardCaptured ?? this.isKeyboardCaptured,
      latencyStats: latencyStats ?? this.latencyStats,
      recentLatencies: recentLatencies ?? this.recentLatencies,
      pendingEvents: pendingEvents ?? this.pendingEvents,
    );
  }
}

/// 输入控制服务
class InputControlService extends StateNotifier<InputControlState> {
  static const int _maxLatencySamples = 100;
  static const int _targetLatencyMs = 100; // 需求 7.1: 100ms 内响应

  final List<double> _latencySamples = [];
  Timer? _latencyUpdateTimer;

  InputControlService() : super(const InputControlState());

  /// 启用输入控制
  void enable() {
    state = state.copyWith(isEnabled: true);
    _startLatencyMonitoring();
  }

  /// 禁用输入控制
  void disable() {
    state = state.copyWith(
      isEnabled: false,
      isMouseCaptured: false,
      isKeyboardCaptured: false,
    );
    _stopLatencyMonitoring();
  }

  /// 捕获鼠标
  void captureMouse() {
    if (!state.isEnabled) return;
    state = state.copyWith(isMouseCaptured: true);
  }

  /// 释放鼠标
  void releaseMouse() {
    state = state.copyWith(isMouseCaptured: false);
  }

  /// 捕获键盘
  void captureKeyboard() {
    if (!state.isEnabled) return;
    state = state.copyWith(isKeyboardCaptured: true);
  }

  /// 释放键盘
  void releaseKeyboard() {
    state = state.copyWith(isKeyboardCaptured: false);
  }

  /// 发送鼠标事件
  Future<bool> sendMouseEvent(MouseEvent event) async {
    if (!state.isEnabled || !state.isMouseCaptured) {
      return false;
    }

    state = state.copyWith(pendingEvents: state.pendingEvents + 1);

    try {
      final startTime = DateTime.now();

      // 模拟发送事件到远程设备
      await _transmitEvent(event.toJson());

      final latency = DateTime.now().difference(startTime).inMilliseconds.toDouble();
      _recordLatency(latency);

      return latency <= _targetLatencyMs;
    } finally {
      state = state.copyWith(pendingEvents: state.pendingEvents - 1);
    }
  }

  /// 发送键盘事件
  Future<bool> sendKeyEvent(KeyEvent event) async {
    if (!state.isEnabled || !state.isKeyboardCaptured) {
      return false;
    }

    state = state.copyWith(pendingEvents: state.pendingEvents + 1);

    try {
      final startTime = DateTime.now();

      // 模拟发送事件到远程设备
      await _transmitEvent(event.toJson());

      final latency = DateTime.now().difference(startTime).inMilliseconds.toDouble();
      _recordLatency(latency);

      return latency <= _targetLatencyMs;
    } finally {
      state = state.copyWith(pendingEvents: state.pendingEvents - 1);
    }
  }

  /// 发送组合键
  Future<bool> sendKeyCombo(List<String> keys) async {
    if (!state.isEnabled || !state.isKeyboardCaptured) {
      return false;
    }

    // 按下所有键
    for (final key in keys) {
      await sendKeyEvent(KeyEvent(
        type: KeyEventType.down,
        key: key,
        ctrlKey: keys.contains('Control'),
        altKey: keys.contains('Alt'),
        shiftKey: keys.contains('Shift'),
        metaKey: keys.contains('Meta'),
      ));
    }

    // 释放所有键（逆序）
    for (final key in keys.reversed) {
      await sendKeyEvent(KeyEvent(
        type: KeyEventType.up,
        key: key,
      ));
    }

    return true;
  }

  /// 发送 Ctrl+Alt+Delete
  Future<bool> sendCtrlAltDelete() async {
    return sendKeyCombo(['Control', 'Alt', 'Delete']);
  }

  /// 发送文本输入
  Future<void> sendText(String text) async {
    for (final char in text.split('')) {
      await sendKeyEvent(KeyEvent(
        type: KeyEventType.press,
        key: char,
      ));
    }
  }

  /// 检查输入延迟是否符合要求
  bool isLatencyAcceptable() {
    return state.latencyStats.averageLatency <= _targetLatencyMs;
  }

  /// 获取当前延迟状态描述
  String getLatencyStatus() {
    final avg = state.latencyStats.averageLatency;
    if (avg == 0) return '未知';
    if (avg <= 50) return '优秀';
    if (avg <= 100) return '良好';
    if (avg <= 200) return '一般';
    return '较差';
  }

  Future<void> _transmitEvent(Map<String, dynamic> eventData) async {
    // 模拟网络传输延迟
    await Future.delayed(Duration(milliseconds: 20 + (DateTime.now().millisecond % 30)));
  }

  void _recordLatency(double latency) {
    _latencySamples.add(latency);
    if (_latencySamples.length > _maxLatencySamples) {
      _latencySamples.removeAt(0);
    }

    state = state.copyWith(
      recentLatencies: List.from(_latencySamples),
    );
  }

  void _startLatencyMonitoring() {
    _latencyUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateLatencyStats();
    });
  }

  void _stopLatencyMonitoring() {
    _latencyUpdateTimer?.cancel();
    _latencyUpdateTimer = null;
  }

  void _updateLatencyStats() {
    if (_latencySamples.isEmpty) return;

    final sorted = List<double>.from(_latencySamples)..sort();
    final sum = sorted.reduce((a, b) => a + b);
    final avg = sum / sorted.length;
    final min = sorted.first;
    final max = sorted.last;
    final p95Index = (sorted.length * 0.95).floor().clamp(0, sorted.length - 1);
    final p95 = sorted[p95Index];

    state = state.copyWith(
      latencyStats: InputLatencyStats(
        sampleCount: sorted.length,
        averageLatency: avg,
        minLatency: min,
        maxLatency: max,
        p95Latency: p95,
      ),
    );
  }

  @override
  void dispose() {
    _stopLatencyMonitoring();
    super.dispose();
  }
}

/// 输入控制服务 Provider
final inputControlServiceProvider =
    StateNotifierProvider<InputControlService, InputControlState>((ref) {
  return InputControlService();
});

/// 特殊键映射
class SpecialKeys {
  static const String escape = 'Escape';
  static const String tab = 'Tab';
  static const String enter = 'Enter';
  static const String backspace = 'Backspace';
  static const String delete = 'Delete';
  static const String insert = 'Insert';
  static const String home = 'Home';
  static const String end = 'End';
  static const String pageUp = 'PageUp';
  static const String pageDown = 'PageDown';
  static const String arrowUp = 'ArrowUp';
  static const String arrowDown = 'ArrowDown';
  static const String arrowLeft = 'ArrowLeft';
  static const String arrowRight = 'ArrowRight';
  static const String control = 'Control';
  static const String alt = 'Alt';
  static const String shift = 'Shift';
  static const String meta = 'Meta';
  static const String capsLock = 'CapsLock';
  static const String numLock = 'NumLock';
  static const String scrollLock = 'ScrollLock';
  static const String printScreen = 'PrintScreen';
  static const String pause = 'Pause';

  // 功能键
  static const String f1 = 'F1';
  static const String f2 = 'F2';
  static const String f3 = 'F3';
  static const String f4 = 'F4';
  static const String f5 = 'F5';
  static const String f6 = 'F6';
  static const String f7 = 'F7';
  static const String f8 = 'F8';
  static const String f9 = 'F9';
  static const String f10 = 'F10';
  static const String f11 = 'F11';
  static const String f12 = 'F12';
}
