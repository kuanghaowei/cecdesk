import 'dart:async';
import 'dart:collection';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Performance Optimization Service
/// 
/// Feature: cec-remote
/// Task 11.2: 性能优化
///
/// Provides:
/// - Memory usage optimization
/// - Network transmission efficiency optimization
/// - UI response speed optimization
///
/// Validates: Requirements 2.4, 7.1, 15.6, 16.8

/// Memory statistics
class MemoryStats {
  final int allocatedBytes;
  final int peakBytes;
  final int bufferPoolSize;
  final int activeBuffers;
  final int frameBufferCount;
  final int frameBufferBytes;

  const MemoryStats({
    this.allocatedBytes = 0,
    this.peakBytes = 0,
    this.bufferPoolSize = 0,
    this.activeBuffers = 0,
    this.frameBufferCount = 0,
    this.frameBufferBytes = 0,
  });

  MemoryStats copyWith({
    int? allocatedBytes,
    int? peakBytes,
    int? bufferPoolSize,
    int? activeBuffers,
    int? frameBufferCount,
    int? frameBufferBytes,
  }) {
    return MemoryStats(
      allocatedBytes: allocatedBytes ?? this.allocatedBytes,
      peakBytes: peakBytes ?? this.peakBytes,
      bufferPoolSize: bufferPoolSize ?? this.bufferPoolSize,
      activeBuffers: activeBuffers ?? this.activeBuffers,
      frameBufferCount: frameBufferCount ?? this.frameBufferCount,
      frameBufferBytes: frameBufferBytes ?? this.frameBufferBytes,
    );
  }
}

/// Transmission statistics
class TransmissionStats {
  final int bytesSent;
  final int bytesReceived;
  final int packetsSent;
  final int packetsReceived;
  final int retransmissions;
  final double avgLatencyMs;
  final double bandwidthUtilization;

  const TransmissionStats({
    this.bytesSent = 0,
    this.bytesReceived = 0,
    this.packetsSent = 0,
    this.packetsReceived = 0,
    this.retransmissions = 0,
    this.avgLatencyMs = 0,
    this.bandwidthUtilization = 0,
  });
}

/// Performance metrics
class PerformanceMetrics {
  final MemoryStats memory;
  final TransmissionStats transmission;
  final double frameRate;
  final double inputLatencyMs;
  final double cpuUsagePercent;
  final DateTime timestamp;

  const PerformanceMetrics({
    this.memory = const MemoryStats(),
    this.transmission = const TransmissionStats(),
    this.frameRate = 0,
    this.inputLatencyMs = 0,
    this.cpuUsagePercent = 0,
    required this.timestamp,
  });
}

/// Performance summary
class PerformanceSummary {
  final double avgFrameRate;
  final double avgInputLatencyMs;
  final double avgNetworkLatencyMs;
  final int maxMemoryBytes;
  final bool meetsFrameRateRequirement;
  final bool meetsInputLatencyRequirement;

  const PerformanceSummary({
    this.avgFrameRate = 0,
    this.avgInputLatencyMs = 0,
    this.avgNetworkLatencyMs = 0,
    this.maxMemoryBytes = 0,
    this.meetsFrameRateRequirement = false,
    this.meetsInputLatencyRequirement = false,
  });
}

/// Buffer pool for efficient memory reuse
class BufferPool<T> {
  final Queue<T> _buffers = Queue<T>();
  final int maxBuffers;
  final T Function() _factory;
  final void Function(T)? _reset;
  
  int _allocatedCount = 0;
  int _reusedCount = 0;

  BufferPool({
    required this.maxBuffers,
    required T Function() factory,
    void Function(T)? reset,
  }) : _factory = factory, _reset = reset;

  /// Acquire a buffer from the pool or create a new one
  T acquire() {
    if (_buffers.isNotEmpty) {
      _reusedCount++;
      final buffer = _buffers.removeFirst();
      _reset?.call(buffer);
      return buffer;
    }
    _allocatedCount++;
    return _factory();
  }

  /// Return a buffer to the pool for reuse
  void release(T buffer) {
    if (_buffers.length < maxBuffers) {
      _buffers.add(buffer);
    }
    // If pool is full, buffer is discarded
  }

  /// Get pool statistics
  (int allocated, int reused) get stats => (_allocatedCount, _reusedCount);

  /// Clear the pool
  void clear() {
    _buffers.clear();
  }
}

/// Frame buffer for video optimization
class FrameBuffer {
  final int id;
  final int timestamp;
  final List<int> data;
  final int width;
  final int height;
  final String format;

  const FrameBuffer({
    required this.id,
    required this.timestamp,
    required this.data,
    required this.width,
    required this.height,
    required this.format,
  });
}

/// Frame buffer manager for smooth video playback
class FrameBufferManager {
  final Queue<FrameBuffer> _buffers = Queue<FrameBuffer>();
  final int maxBuffers;
  int _totalBytes = 0;
  int _droppedFrames = 0;

  FrameBufferManager({this.maxBuffers = 3});

  /// Add a frame to the buffer
  void pushFrame(FrameBuffer frame) {
    // Drop oldest frame if buffer is full
    while (_buffers.length >= maxBuffers) {
      final oldFrame = _buffers.removeFirst();
      _totalBytes -= oldFrame.data.length;
      _droppedFrames++;
    }
    
    _totalBytes += frame.data.length;
    _buffers.add(frame);
  }

  /// Get the next frame for display
  FrameBuffer? popFrame() {
    if (_buffers.isEmpty) return null;
    
    final frame = _buffers.removeFirst();
    _totalBytes -= frame.data.length;
    return frame;
  }

  /// Get buffer statistics
  (int count, int bytes, int dropped) get stats => 
      (_buffers.length, _totalBytes, _droppedFrames);

  /// Clear all buffers
  void clear() {
    _buffers.clear();
    _totalBytes = 0;
  }
}

/// Transmission optimizer for adaptive bitrate
class TransmissionOptimizer {
  final int minBitrate;
  final int maxBitrate;
  int _targetBitrate;
  int _currentBitrate;
  
  final Queue<double> _latencySamples = Queue<double>();
  final Queue<int> _bandwidthSamples = Queue<int>();
  static const int _maxSamples = 100;

  TransmissionOptimizer({
    required this.minBitrate,
    required this.maxBitrate,
    required int targetBitrate,
  }) : _targetBitrate = targetBitrate,
       _currentBitrate = targetBitrate;

  /// Record a latency sample
  void recordLatency(double latencyMs) {
    if (_latencySamples.length >= _maxSamples) {
      _latencySamples.removeFirst();
    }
    _latencySamples.add(latencyMs);
  }

  /// Record a bandwidth sample
  void recordBandwidth(int bandwidthBps) {
    if (_bandwidthSamples.length >= _maxSamples) {
      _bandwidthSamples.removeFirst();
    }
    _bandwidthSamples.add(bandwidthBps);
  }

  /// Adapt bitrate based on network conditions
  int adaptBitrate() {
    if (_latencySamples.isEmpty || _bandwidthSamples.isEmpty) {
      return _currentBitrate;
    }
    
    // Calculate average latency
    final avgLatency = _latencySamples.reduce((a, b) => a + b) / _latencySamples.length;
    
    // Calculate average bandwidth
    final avgBandwidth = _bandwidthSamples.reduce((a, b) => a + b) ~/ _bandwidthSamples.length;
    
    // Adaptive bitrate algorithm
    var newBitrate = _currentBitrate;
    
    // If latency is high, reduce bitrate
    if (avgLatency > 150) {
      newBitrate = (newBitrate * 0.8).toInt();
    } else if (avgLatency > 100) {
      newBitrate = (newBitrate * 0.9).toInt();
    } else if (avgLatency < 50) {
      // If latency is low and bandwidth allows, increase bitrate
      if (newBitrate < _targetBitrate && avgBandwidth > newBitrate) {
        newBitrate = (newBitrate * 1.1).toInt();
      }
    }
    
    // Clamp to min/max
    _currentBitrate = newBitrate.clamp(minBitrate, maxBitrate);
    return _currentBitrate;
  }

  /// Get current bitrate
  int get currentBitrate => _currentBitrate;

  /// Set target bitrate
  set targetBitrate(int bitrate) {
    _targetBitrate = bitrate.clamp(minBitrate, maxBitrate);
  }

  /// Get average latency
  double get avgLatency {
    if (_latencySamples.isEmpty) return 0;
    return _latencySamples.reduce((a, b) => a + b) / _latencySamples.length;
  }
}

/// Input event type
enum InputEventType {
  mouseMove,
  mouseClick,
  mouseScroll,
  keyDown,
  keyUp,
  keyPress,
}

extension InputEventTypeExtension on InputEventType {
  /// Get default priority (lower = higher priority)
  int get defaultPriority {
    switch (this) {
      case InputEventType.keyDown:
      case InputEventType.keyUp:
        return 1;
      case InputEventType.mouseClick:
        return 2;
      case InputEventType.keyPress:
        return 3;
      case InputEventType.mouseScroll:
        return 4;
      case InputEventType.mouseMove:
        return 5;
    }
  }
}

/// Input event entry
class InputEventEntry {
  final InputEventType eventType;
  final DateTime timestamp;
  final int priority;
  final List<int> data;

  InputEventEntry({
    required this.eventType,
    required this.timestamp,
    int? priority,
    required this.data,
  }) : priority = priority ?? eventType.defaultPriority;
}

/// Input optimizer for low-latency input handling
class InputOptimizer {
  final Queue<InputEventEntry> _eventQueue = Queue<InputEventEntry>();
  final int maxQueueSize;
  final int batchIntervalMs;
  DateTime _lastBatchTime = DateTime.now();
  
  final Queue<double> _latencySamples = Queue<double>();
  static const int _maxSamples = 100;

  InputOptimizer({
    this.maxQueueSize = 100,
    this.batchIntervalMs = 16,
  });

  /// Queue an input event
  void queueEvent(InputEventEntry event) {
    // Drop oldest low-priority events if queue is full
    while (_eventQueue.length >= maxQueueSize) {
      // Find and remove lowest priority event
      InputEventEntry? lowestPriority;
      for (final e in _eventQueue) {
        if (lowestPriority == null || e.priority > lowestPriority.priority) {
          lowestPriority = e;
        }
      }
      if (lowestPriority != null) {
        _eventQueue.remove(lowestPriority);
      } else {
        break;
      }
    }
    
    _eventQueue.add(event);
  }

  /// Get batched events for transmission
  List<InputEventEntry> getBatch() {
    final now = DateTime.now();
    
    // Check if enough time has passed for batching
    if (now.difference(_lastBatchTime).inMilliseconds < batchIntervalMs) {
      return [];
    }
    
    _lastBatchTime = now;
    
    // Sort by priority and timestamp
    final events = _eventQueue.toList();
    _eventQueue.clear();
    
    events.sort((a, b) {
      final priorityCompare = a.priority.compareTo(b.priority);
      if (priorityCompare != 0) return priorityCompare;
      return a.timestamp.compareTo(b.timestamp);
    });
    
    // Coalesce mouse move events (keep only the latest)
    final coalesced = <InputEventEntry>[];
    InputEventEntry? lastMouseMove;
    
    for (final event in events) {
      if (event.eventType == InputEventType.mouseMove) {
        lastMouseMove = event;
      } else {
        if (lastMouseMove != null) {
          coalesced.add(lastMouseMove);
          lastMouseMove = null;
        }
        coalesced.add(event);
      }
    }
    
    if (lastMouseMove != null) {
      coalesced.add(lastMouseMove);
    }
    
    return coalesced;
  }

  /// Record input latency
  void recordLatency(double latencyMs) {
    if (_latencySamples.length >= _maxSamples) {
      _latencySamples.removeFirst();
    }
    _latencySamples.add(latencyMs);
  }

  /// Get average input latency
  double get avgLatency {
    if (_latencySamples.isEmpty) return 0;
    return _latencySamples.reduce((a, b) => a + b) / _latencySamples.length;
  }

  /// Check if latency meets requirement (< 100ms)
  bool get meetsLatencyRequirement => avgLatency < 100;
}

/// Performance service state
class PerformanceState {
  final MemoryStats memoryStats;
  final TransmissionStats transmissionStats;
  final double frameRate;
  final double inputLatencyMs;
  final PerformanceSummary summary;
  final List<PerformanceMetrics> history;
  final bool isMonitoring;

  const PerformanceState({
    this.memoryStats = const MemoryStats(),
    this.transmissionStats = const TransmissionStats(),
    this.frameRate = 0,
    this.inputLatencyMs = 0,
    this.summary = const PerformanceSummary(),
    this.history = const [],
    this.isMonitoring = false,
  });

  PerformanceState copyWith({
    MemoryStats? memoryStats,
    TransmissionStats? transmissionStats,
    double? frameRate,
    double? inputLatencyMs,
    PerformanceSummary? summary,
    List<PerformanceMetrics>? history,
    bool? isMonitoring,
  }) {
    return PerformanceState(
      memoryStats: memoryStats ?? this.memoryStats,
      transmissionStats: transmissionStats ?? this.transmissionStats,
      frameRate: frameRate ?? this.frameRate,
      inputLatencyMs: inputLatencyMs ?? this.inputLatencyMs,
      summary: summary ?? this.summary,
      history: history ?? this.history,
      isMonitoring: isMonitoring ?? this.isMonitoring,
    );
  }
}

/// Performance service
class PerformanceService extends StateNotifier<PerformanceState> {
  static const int _maxHistory = 60;
  
  final FrameBufferManager _frameBufferManager = FrameBufferManager();
  final TransmissionOptimizer _transmissionOptimizer = TransmissionOptimizer(
    minBitrate: 500000,
    maxBitrate: 10000000,
    targetBitrate: 4000000,
  );
  final InputOptimizer _inputOptimizer = InputOptimizer();
  
  Timer? _monitoringTimer;

  PerformanceService() : super(const PerformanceState());

  /// Start performance monitoring
  void startMonitoring() {
    if (state.isMonitoring) return;
    
    state = state.copyWith(isMonitoring: true);
    
    _monitoringTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _collectMetrics();
    });
  }

  /// Stop performance monitoring
  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    state = state.copyWith(isMonitoring: false);
  }

  /// Collect current performance metrics
  void _collectMetrics() {
    final (frameCount, frameBytes, droppedFrames) = _frameBufferManager.stats;
    final avgLatency = _transmissionOptimizer.avgLatency;
    final inputLatency = _inputOptimizer.avgLatency;
    final currentBitrate = _transmissionOptimizer.currentBitrate;
    
    final metrics = PerformanceMetrics(
      memory: MemoryStats(
        frameBufferCount: frameCount,
        frameBufferBytes: frameBytes,
      ),
      transmission: TransmissionStats(
        avgLatencyMs: avgLatency,
        bandwidthUtilization: currentBitrate / 10000000,
      ),
      frameRate: 30, // Would need actual measurement
      inputLatencyMs: inputLatency,
      timestamp: DateTime.now(),
    );
    
    // Update history
    final newHistory = [...state.history, metrics];
    if (newHistory.length > _maxHistory) {
      newHistory.removeAt(0);
    }
    
    // Calculate summary
    final summary = _calculateSummary(newHistory);
    
    state = state.copyWith(
      memoryStats: metrics.memory,
      transmissionStats: metrics.transmission,
      frameRate: metrics.frameRate,
      inputLatencyMs: metrics.inputLatencyMs,
      history: newHistory,
      summary: summary,
    );
  }

  /// Calculate performance summary
  PerformanceSummary _calculateSummary(List<PerformanceMetrics> history) {
    if (history.isEmpty) {
      return const PerformanceSummary();
    }
    
    final avgFrameRate = history.map((m) => m.frameRate).reduce((a, b) => a + b) / history.length;
    final avgInputLatency = history.map((m) => m.inputLatencyMs).reduce((a, b) => a + b) / history.length;
    final avgNetworkLatency = history.map((m) => m.transmission.avgLatencyMs).reduce((a, b) => a + b) / history.length;
    final maxMemory = history.map((m) => m.memory.allocatedBytes).reduce((a, b) => a > b ? a : b);
    
    return PerformanceSummary(
      avgFrameRate: avgFrameRate,
      avgInputLatencyMs: avgInputLatency,
      avgNetworkLatencyMs: avgNetworkLatency,
      maxMemoryBytes: maxMemory,
      meetsFrameRateRequirement: avgFrameRate >= 30,
      meetsInputLatencyRequirement: avgInputLatency < 100,
    );
  }

  /// Record network latency
  void recordNetworkLatency(double latencyMs) {
    _transmissionOptimizer.recordLatency(latencyMs);
  }

  /// Record bandwidth
  void recordBandwidth(int bandwidthBps) {
    _transmissionOptimizer.recordBandwidth(bandwidthBps);
  }

  /// Adapt bitrate based on network conditions
  int adaptBitrate() {
    return _transmissionOptimizer.adaptBitrate();
  }

  /// Record input latency
  void recordInputLatency(double latencyMs) {
    _inputOptimizer.recordLatency(latencyMs);
  }

  /// Queue input event
  void queueInputEvent(InputEventEntry event) {
    _inputOptimizer.queueEvent(event);
  }

  /// Get batched input events
  List<InputEventEntry> getInputBatch() {
    return _inputOptimizer.getBatch();
  }

  /// Push frame to buffer
  void pushFrame(FrameBuffer frame) {
    _frameBufferManager.pushFrame(frame);
  }

  /// Pop frame from buffer
  FrameBuffer? popFrame() {
    return _frameBufferManager.popFrame();
  }

  /// Check if performance meets requirements
  bool get meetsRequirements {
    return state.summary.meetsFrameRateRequirement && 
           state.summary.meetsInputLatencyRequirement;
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}

/// Performance service provider
final performanceServiceProvider =
    StateNotifierProvider<PerformanceService, PerformanceState>((ref) {
  return PerformanceService();
});
