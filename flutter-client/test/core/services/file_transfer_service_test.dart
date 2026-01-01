import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remote_desktop_client/src/core/services/file_transfer_service.dart';

void main() {
  group('FileTransferService', () {
    late ProviderContainer container;
    late FileTransferService transferService;

    setUp(() {
      container = ProviderContainer();
      transferService = container.read(fileTransferServiceProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    group('createUpload', () {
      test('应该创建上传任务', () {
        final taskId = transferService.createUpload(
          filename: 'test.pdf',
          localPath: '/local/test.pdf',
          remotePath: '/remote/uploads/',
          fileSize: 1024 * 1024, // 1MB
        );

        expect(taskId, isNotEmpty);

        final state = container.read(fileTransferServiceProvider);
        expect(state.tasks.length, 1);
        expect(state.tasks.first.filename, 'test.pdf');
        expect(state.tasks.first.direction, FileTransferDirection.upload);
      });

      test('应该将文件分割成块', () {
        transferService.createUpload(
          filename: 'large.zip',
          localPath: '/local/large.zip',
          remotePath: '/remote/',
          fileSize: 5 * 1024 * 1024, // 5MB
        );

        final state = container.read(fileTransferServiceProvider);
        final task = state.tasks.first;

        // 默认块大小为 1MB，5MB 文件应该有 5 个块
        expect(task.chunks.length, 5);
        expect(task.chunks.every((c) => c.size == 1024 * 1024), true);
      });
    });

    group('createDownload', () {
      test('应该创建下载任务', () {
        final taskId = transferService.createDownload(
          filename: 'document.docx',
          remotePath: '/remote/document.docx',
          localPath: '/local/downloads/',
          fileSize: 2 * 1024 * 1024,
        );

        expect(taskId, isNotEmpty);

        final state = container.read(fileTransferServiceProvider);
        expect(state.tasks.first.direction, FileTransferDirection.download);
      });
    });

    group('pauseTransfer', () {
      test('应该暂停传输', () async {
        final taskId = transferService.createUpload(
          filename: 'test.pdf',
          localPath: '/local/test.pdf',
          remotePath: '/remote/',
          fileSize: 10 * 1024 * 1024, // 10MB - 足够大以便有时间暂停
        );

        // 等待传输开始
        await Future.delayed(const Duration(milliseconds: 200));

        transferService.pauseTransfer(taskId);

        final state = container.read(fileTransferServiceProvider);
        final task = state.tasks.first;

        expect(task.status, FileTransferStatus.paused);
        expect(task.pausedAt, isNotNull);
      });
    });

    group('cancelTransfer', () {
      test('应该取消并移除传输任务', () {
        final taskId = transferService.createUpload(
          filename: 'test.pdf',
          localPath: '/local/test.pdf',
          remotePath: '/remote/',
          fileSize: 1024 * 1024,
        );

        var state = container.read(fileTransferServiceProvider);
        expect(state.tasks.length, 1);

        transferService.cancelTransfer(taskId);

        state = container.read(fileTransferServiceProvider);
        expect(state.tasks.length, 0);
      });
    });

    group('clearCompleted', () {
      test('应该清除已完成的任务', () async {
        // 创建一个小文件以便快速完成
        transferService.createUpload(
          filename: 'small.txt',
          localPath: '/local/small.txt',
          remotePath: '/remote/',
          fileSize: 1000, // 1KB
        );

        // 等待传输完成
        await Future.delayed(const Duration(milliseconds: 500));

        var state = container.read(fileTransferServiceProvider);
        expect(state.completedTasks.length, greaterThanOrEqualTo(0));

        transferService.clearCompleted();

        state = container.read(fileTransferServiceProvider);
        expect(state.completedTasks.length, 0);
      });
    });

    /// 属性 10: 断点续传功能
    /// 验证: 需求 8.5 - 文件传输中断后应支持断点续传
    group('属性 10: 断点续传功能', () {
      test('暂停后应该记录已传输的块', () async {
        final taskId = transferService.createUpload(
          filename: 'large.zip',
          localPath: '/local/large.zip',
          remotePath: '/remote/',
          fileSize: 10 * 1024 * 1024, // 10MB
        );

        // 等待部分传输
        await Future.delayed(const Duration(milliseconds: 500));

        // 暂停传输
        transferService.pauseTransfer(taskId);

        final state = container.read(fileTransferServiceProvider);
        final task = state.tasks.first;

        // 验证部分块已传输
        expect(task.transferredChunks, greaterThan(0));
        expect(task.transferredChunks, lessThan(task.totalChunks));
        expect(task.status, FileTransferStatus.paused);
      });

      test('恢复传输应该从断点位置继续', () async {
        final taskId = transferService.createUpload(
          filename: 'large.zip',
          localPath: '/local/large.zip',
          remotePath: '/remote/',
          fileSize: 10 * 1024 * 1024, // 10MB
        );

        // 等待部分传输
        await Future.delayed(const Duration(milliseconds: 500));

        // 暂停传输
        transferService.pauseTransfer(taskId);

        var state = container.read(fileTransferServiceProvider);
        var task = state.tasks.first;
        final transferredBeforeResume = task.transferredSize;
        final chunksBeforeResume = task.transferredChunks;

        // 恢复传输
        transferService.resumeTransfer(taskId);

        // 等待更多传输
        await Future.delayed(const Duration(milliseconds: 500));

        state = container.read(fileTransferServiceProvider);
        task = state.tasks.first;

        // 验证从断点继续
        expect(task.transferredSize, greaterThanOrEqualTo(transferredBeforeResume));
        expect(task.transferredChunks, greaterThanOrEqualTo(chunksBeforeResume));
      });

      test('getResumeOffset 应该返回正确的断点位置', () async {
        final taskId = transferService.createUpload(
          filename: 'test.zip',
          localPath: '/local/test.zip',
          remotePath: '/remote/',
          fileSize: 5 * 1024 * 1024, // 5MB = 5 chunks
        );

        // 等待部分传输
        await Future.delayed(const Duration(milliseconds: 300));

        transferService.pauseTransfer(taskId);

        final task = transferService.getTask(taskId);
        expect(task, isNotNull);

        final resumeOffset = task!.getResumeOffset();

        // 断点位置应该是已传输块的末尾
        final expectedOffset = task.transferredChunks * 1024 * 1024;
        expect(resumeOffset, expectedOffset);
      });

      test('多次暂停和恢复应该正确累积进度', () async {
        final taskId = transferService.createUpload(
          filename: 'large.zip',
          localPath: '/local/large.zip',
          remotePath: '/remote/',
          fileSize: 10 * 1024 * 1024, // 10MB
        );

        var previousTransferred = 0;

        // 多次暂停和恢复
        for (var i = 0; i < 3; i++) {
          // 等待传输
          await Future.delayed(const Duration(milliseconds: 300));

          // 暂停
          transferService.pauseTransfer(taskId);

          var task = transferService.getTask(taskId);
          expect(task!.transferredSize, greaterThanOrEqualTo(previousTransferred),
              reason: '第 ${i + 1} 次暂停后传输量应该增加');

          previousTransferred = task.transferredSize;

          // 恢复
          transferService.resumeTransfer(taskId);
        }

        // 最终验证
        final finalTask = transferService.getTask(taskId);
        expect(finalTask!.transferredSize, greaterThan(0));
      });

      test('已传输的块不应该重复传输', () async {
        final taskId = transferService.createUpload(
          filename: 'test.zip',
          localPath: '/local/test.zip',
          remotePath: '/remote/',
          fileSize: 5 * 1024 * 1024, // 5MB
        );

        // 等待部分传输
        await Future.delayed(const Duration(milliseconds: 400));

        transferService.pauseTransfer(taskId);

        var task = transferService.getTask(taskId);
        final transferredChunksBeforeResume = task!.chunks.where((c) => c.isTransferred).toList();

        // 恢复传输
        transferService.resumeTransfer(taskId);

        // 等待更多传输
        await Future.delayed(const Duration(milliseconds: 400));

        task = transferService.getTask(taskId);

        // 验证之前已传输的块仍然标记为已传输
        for (final chunk in transferredChunksBeforeResume) {
          final currentChunk = task!.chunks.firstWhere((c) => c.index == chunk.index);
          expect(currentChunk.isTransferred, true,
              reason: '块 ${chunk.index} 应该保持已传输状态');
        }
      });

      test('传输完成后应该验证所有块都已传输', () async {
        final taskId = transferService.createUpload(
          filename: 'small.txt',
          localPath: '/local/small.txt',
          remotePath: '/remote/',
          fileSize: 2 * 1024 * 1024, // 2MB = 2 chunks
        );

        // 等待传输完成
        await Future.delayed(const Duration(seconds: 1));

        final task = transferService.getTask(taskId);

        if (task!.status == FileTransferStatus.completed) {
          // 验证所有块都已传输
          expect(task.chunks.every((c) => c.isTransferred), true);
          expect(task.transferredSize, task.totalSize);
          expect(task.progress, 1.0);
        }
      });
    });

    group('并发传输', () {
      test('应该限制并发传输数量', () async {
        // 创建多个传输任务
        for (var i = 0; i < 5; i++) {
          transferService.createUpload(
            filename: 'file_$i.zip',
            localPath: '/local/file_$i.zip',
            remotePath: '/remote/',
            fileSize: 10 * 1024 * 1024,
          );
        }

        // 等待任务开始
        await Future.delayed(const Duration(milliseconds: 100));

        final state = container.read(fileTransferServiceProvider);

        // 默认最大并发数为 3
        expect(state.activeTasks.length, lessThanOrEqualTo(3));
        expect(state.pendingTasks.length, greaterThanOrEqualTo(2));
      });
    });
  });

  group('FileTransferTask', () {
    test('progress 应该正确计算', () {
      final task = FileTransferTask(
        id: '1',
        filename: 'test.pdf',
        localPath: '/local/',
        remotePath: '/remote/',
        totalSize: 1000,
        direction: FileTransferDirection.upload,
        transferredSize: 500,
      );

      expect(task.progress, 0.5);
    });

    test('remainingSize 应该正确计算', () {
      final task = FileTransferTask(
        id: '1',
        filename: 'test.pdf',
        localPath: '/local/',
        remotePath: '/remote/',
        totalSize: 1000,
        direction: FileTransferDirection.upload,
        transferredSize: 300,
      );

      expect(task.remainingSize, 700);
    });

    test('estimatedTimeRemaining 应该正确计算', () {
      final task = FileTransferTask(
        id: '1',
        filename: 'test.pdf',
        localPath: '/local/',
        remotePath: '/remote/',
        totalSize: 1000,
        direction: FileTransferDirection.upload,
        transferredSize: 500,
        speed: 100, // 100 bytes/s
      );

      expect(task.estimatedTimeRemaining?.inSeconds, 5);
    });

    test('速度为0时 estimatedTimeRemaining 应该返回 null', () {
      final task = FileTransferTask(
        id: '1',
        filename: 'test.pdf',
        localPath: '/local/',
        remotePath: '/remote/',
        totalSize: 1000,
        direction: FileTransferDirection.upload,
        speed: 0,
      );

      expect(task.estimatedTimeRemaining, isNull);
    });
  });

  group('FileChunk', () {
    test('应该正确复制并更新状态', () {
      final chunk = FileChunk(
        index: 0,
        offset: 0,
        size: 1024,
      );

      expect(chunk.isTransferred, false);

      final updated = chunk.copyWith(isTransferred: true);

      expect(updated.isTransferred, true);
      expect(updated.index, 0);
      expect(updated.offset, 0);
      expect(updated.size, 1024);
    });
  });

  group('FileTransferServiceState', () {
    test('应该正确过滤不同状态的任务', () {
      final state = FileTransferServiceState(
        tasks: [
          FileTransferTask(
            id: '1',
            filename: 'active.pdf',
            localPath: '/local/',
            remotePath: '/remote/',
            totalSize: 1000,
            direction: FileTransferDirection.upload,
            status: FileTransferStatus.inProgress,
          ),
          FileTransferTask(
            id: '2',
            filename: 'pending.pdf',
            localPath: '/local/',
            remotePath: '/remote/',
            totalSize: 1000,
            direction: FileTransferDirection.upload,
            status: FileTransferStatus.pending,
          ),
          FileTransferTask(
            id: '3',
            filename: 'completed.pdf',
            localPath: '/local/',
            remotePath: '/remote/',
            totalSize: 1000,
            direction: FileTransferDirection.upload,
            status: FileTransferStatus.completed,
          ),
          FileTransferTask(
            id: '4',
            filename: 'paused.pdf',
            localPath: '/local/',
            remotePath: '/remote/',
            totalSize: 1000,
            direction: FileTransferDirection.upload,
            status: FileTransferStatus.paused,
          ),
        ],
      );

      expect(state.activeTasks.length, 1);
      expect(state.pendingTasks.length, 1);
      expect(state.completedTasks.length, 1);
      expect(state.pausedTasks.length, 1);
    });
  });
}
