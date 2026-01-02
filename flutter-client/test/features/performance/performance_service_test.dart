import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remote_desktop_client/src/core/services/performance_service.dart';

/// Performance Service Tests
/// 
/// Feature: cec-remote
/// Task 11.2: 性能优化
///
/// Tests:
/// - Buffer pool memory reuse
/// - Frame buffer management
/// - Transmission optimization (adaptive bitrate)
/// - Input optimization (event batching and prioritization)
/// - Performance monitoring

void main() {
  group('BufferPool', () {
    test('should create new buffers when pool is empty', () {
      final pool = BufferPool<List<int>>(
        maxBuffers: 5,
        factory: () => List<int>.filled(1024, 0),
      );

      final buffer1 = pool.acquire();
      final buffer2 = pool.acquire();

      expect(buffer1.length, 1024);
      expect(buffer2.length, 1024);
      
      final (allocated, reused) = pool.stats;
      expect(allocated, 2);
      expect(reused, 0);
    });

    test('should reuse buffers when available', () {
      final pool = BufferPool<List<int>>(
        maxBuffers: 5,
        factory: () => List<int>.filled(1024, 0),
      );

      final buffer1 = pool.acquire();
      pool.release(buffer1);
      final buffer2 = pool.acquire();

      final (allocated, reused) = pool.stats;
      expect(allocated, 1);
      expect(reused, 1);
    });

    test('should respect max buffer limit', () {
      final pool = BufferPool<List<int>>(
        maxBuffers: 2,
        factory: () => List<int>.filled(1024, 0),
      );

      final buffer1 = pool.acquire();
      final buffer2 = pool.acquire();
      final buffer3 = pool.acquire();
      
      pool.release(buffer1);
      pool.release(buffer2);
      pool.release(buffer3); // Should be discarded (pool full)

      // Acquire 3 buffers - 2 from pool, 1 new
      pool.acquire();
      pool.acquire();
      pool.acquire();

      final (allocated, reused) = pool.stats;
      expect(allocated, 4); // 3 initial + 1 new
      expect(reused, 2); // 2 reused from pool
    });
  });

  group('FrameBufferManager', () {
    test('should add and retrieve frames', () {
      final manager = FrameBufferManager(maxBuffers: 3);

      manager.pushFrame(FrameBuffer(
        id: 1,
        timestamp: 100,
        data: [1, 2, 3],
        width: 1920,
        height: 1080,
        format: 'RGBA',
      ));

      final frame = manager.popFrame();
      expect(frame, isNotNull);
      expect(frame!.id, 1);
      expect(frame.timestamp, 100);
    });

    test('should drop oldest frames when buffer is full', () {
      final manager = FrameBufferManager(maxBuffers: 2);

      for (int i = 0; i < 5; i++) {
        manager.pushFrame(FrameBuffer(
          id: i,
          timestamp: i * 100,
          data: List<int>.filled(100, i),
          width: 1920,
          height: 1080,
          format: 'RGBA',
        ));
      }

      final (count, bytes, dropped) = manager.stats;
      expect(count, 2);
      expect(dropped, 3); // 3 frames dropped
    });

    test('should track total bytes correctly', () {
      final manager = FrameBufferManager(maxBuffers: 5);

      manager.pushFrame(FrameBuffer(
        id: 1,
        timestamp: 100,
        data: List<int>.filled(1000, 0),
        width: 1920,
        height: 1080,
        format: 'RGBA',
      ));

      manager.pushFrame(FrameBuffer(
        id: 2,
        timestamp: 200,
        data: List<int>.filled(500, 0),
        width: 1920,
        height: 1080,
        format: 'RGBA',
      ));

      final (count, bytes, _) = manager.stats;
      expect(count, 2);
      expect(bytes, 1500);
    });
  });

  group('TransmissionOptimizer', () {
    test('should maintain bitrate within bounds', () {
      final optimizer = TransmissionOptimizer(
        minBitrate: 500000,
        maxBitrate: 10000000,
        targetBitrate: 4000000,
      );

      expect(optimizer.currentBitrate, 4000000);
    });

    test('should reduce bitrate when latency is high', () {
      final optimizer = TransmissionOptimizer(
        minBitrate: 500000,
        maxBitrate: 10000000,
        targetBitrate: 4000000,
      );

      // Record high latency samples
      for (int i = 0; i < 10; i++) {
        optimizer.recordLatency(200.0);
        optimizer.recordBandwidth(8000000);
      }

      final newBitrate = optimizer.adaptBitrate();
      expect(newBitrate, lessThan(4000000));
    });

    test('should increase bitrate when latency is low', () {
      final optimizer = TransmissionOptimizer(
        minBitrate: 500000,
        maxBitrate: 10000000,
        targetBitrate: 8000000,
      );

      // Start with lower bitrate
      optimizer.recordLatency(200.0);
      optimizer.recordBandwidth(8000000);
      optimizer.adaptBitrate(); // Reduce bitrate

      // Record low latency samples
      for (int i = 0; i < 20; i++) {
        optimizer.recordLatency(30.0);
        optimizer.recordBandwidth(10000000);
      }

      final initialBitrate = optimizer.currentBitrate;
      final newBitrate = optimizer.adaptBitrate();
      expect(newBitrate, greaterThanOrEqualTo(initialBitrate));
    });

    test('should calculate average latency correctly', () {
      final optimizer = TransmissionOptimizer(
        minBitrate: 500000,
        maxBitrate: 10000000,
        targetBitrate: 4000000,
      );

      optimizer.recordLatency(50.0);
      optimizer.recordLatency(100.0);
      optimizer.recordLatency(150.0);

      expect(optimizer.avgLatency, 100.0);
    });
  });

  group('InputOptimizer', () {
    test('should queue and retrieve events', () async {
      final optimizer = InputOptimizer(
        maxQueueSize: 100,
        batchIntervalMs: 1, // Short interval for testing
      );

      optimizer.queueEvent(InputEventEntry(
        eventType: InputEventType.keyDown,
        timestamp: DateTime.now(),
        data: [65], // 'A' key
      ));

      // Wait for batch interval
      await Future.delayed(const Duration(milliseconds: 5));

      final batch = optimizer.getBatch();
      expect(batch.length, 1);
      expect(batch[0].eventType, InputEventType.keyDown);
    });

    test('should prioritize key events over mouse moves', () async {
      final optimizer = InputOptimizer(
        maxQueueSize: 100,
        batchIntervalMs: 1,
      );

      // Queue mouse move first
      optimizer.queueEvent(InputEventEntry(
        eventType: InputEventType.mouseMove,
        timestamp: DateTime.now(),
        data: [100, 200],
      ));

      // Queue key event second
      optimizer.queueEvent(InputEventEntry(
        eventType: InputEventType.keyDown,
        timestamp: DateTime.now(),
        data: [65],
      ));

      await Future.delayed(const Duration(milliseconds: 5));

      final batch = optimizer.getBatch();
      expect(batch.length, 2);
      // Key events should come first (higher priority)
      expect(batch[0].eventType, InputEventType.keyDown);
      expect(batch[1].eventType, InputEventType.mouseMove);
    });

    test('should meet latency requirement when latency is low', () {
      final optimizer = InputOptimizer();

      for (int i = 0; i < 10; i++) {
        optimizer.recordLatency(50.0);
      }

      expect(optimizer.meetsLatencyRequirement, true);
    });

    test('should not meet latency requirement when latency is high', () {
      final optimizer = InputOptimizer();

      for (int i = 0; i < 10; i++) {
        optimizer.recordLatency(150.0);
      }

      expect(optimizer.meetsLatencyRequirement, false);
    });
  });

  group('PerformanceService', () {
    test('should start and stop monitoring', () {
      final container = ProviderContainer();
      final service = container.read(performanceServiceProvider.notifier);
      final state = container.read(performanceServiceProvider);

      expect(state.isMonitoring, false);

      service.startMonitoring();
      expect(container.read(performanceServiceProvider).isMonitoring, true);

      service.stopMonitoring();
      expect(container.read(performanceServiceProvider).isMonitoring, false);

      container.dispose();
    });

    test('should record and adapt bitrate', () {
      final container = ProviderContainer();
      final service = container.read(performanceServiceProvider.notifier);

      // Record good network conditions
      for (int i = 0; i < 10; i++) {
        service.recordNetworkLatency(30.0);
        service.recordBandwidth(10000000);
      }

      final bitrate = service.adaptBitrate();
      expect(bitrate, greaterThan(0));
      expect(bitrate, lessThanOrEqualTo(10000000));

      container.dispose();
    });

    test('should manage frame buffer', () {
      final container = ProviderContainer();
      final service = container.read(performanceServiceProvider.notifier);

      service.pushFrame(FrameBuffer(
        id: 1,
        timestamp: 100,
        data: [1, 2, 3, 4],
        width: 1920,
        height: 1080,
        format: 'RGBA',
      ));

      final frame = service.popFrame();
      expect(frame, isNotNull);
      expect(frame!.id, 1);

      container.dispose();
    });

    test('should queue and batch input events', () async {
      final container = ProviderContainer();
      final service = container.read(performanceServiceProvider.notifier);

      service.queueInputEvent(InputEventEntry(
        eventType: InputEventType.keyDown,
        timestamp: DateTime.now(),
        data: [65],
      ));

      // Wait for batch interval
      await Future.delayed(const Duration(milliseconds: 20));

      final batch = service.getInputBatch();
      expect(batch.length, 1);

      container.dispose();
    });

    test('should check if performance meets requirements', () {
      final container = ProviderContainer();
      final service = container.read(performanceServiceProvider.notifier);

      // Initially should not meet requirements (no data)
      expect(service.meetsRequirements, false);

      container.dispose();
    });
  });
}
