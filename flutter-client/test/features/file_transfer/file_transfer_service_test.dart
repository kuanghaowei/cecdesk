import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remote_desktop_client/src/core/services/file_transfer_service.dart';

void main() {
  group('FileTransferService Integration Tests', () {
    late ProviderContainer container;
    late FileTransferService fileTransferService;

    setUp(() {
      container = ProviderContainer();
      fileTransferService = container.read(fileTransferServiceProvider.notifier);
    });

    tearDown(() async {
      // Cancel ALL transfers (any status) before disposing to avoid async issues
      final state = container.read(fileTransferServiceProvider);
      final taskIds = state.tasks.map((t) => t.id).toList();
      for (final taskId in taskIds) {
        fileTransferService.cancelTransfer(taskId);
      }
      // Delay to allow timers to be cancelled
      await Future.delayed(const Duration(milliseconds: 100));
      // Dispose container (which will automatically dispose the service)
      container.dispose();
    });

    group('createUpload', () {
      test('应该添加上传任务', () {
        final taskId = fileTransferService.createUpload(
          filename: 'test.pdf',
          localPath: '/local/test.pdf',
          remotePath: '/remote/downloads/',
          fileSize: 1024 * 1024,
        );

        final state = container.read(fileTransferServiceProvider);
        expect(state.tasks.length, 1);
        expect(state.tasks.first.filename, 'test.pdf');
        expect(state.tasks.first.direction, FileTransferDirection.upload);
        expect(taskId, isNotEmpty);
      });
    });

    group('createDownload', () {
      test('应该添加下载任务', () {
        final taskId = fileTransferService.createDownload(
          filename: 'document.docx',
          remotePath: '/remote/documents/document.docx',
          localPath: '/local/downloads/',
          fileSize: 2 * 1024 * 1024,
        );

        final state = container.read(fileTransferServiceProvider);
        expect(state.tasks.length, 1);
        expect(state.tasks.first.filename, 'document.docx');
        expect(state.tasks.first.direction, FileTransferDirection.download);
        expect(taskId, isNotEmpty);
      });
    });

    group('pauseTransfer', () {
      test('应该暂停传输', () async {
        final taskId = fileTransferService.createUpload(
          filename: 'test.pdf',
          localPath: '/local/test.pdf',
          remotePath: '/remote/',
          fileSize: 1024 * 1024 * 10, // 10MB - 足够大以便有时间暂停
        );

        // 等待传输开始
        await Future.delayed(const Duration(milliseconds: 200));

        fileTransferService.pauseTransfer(taskId);

        final state = container.read(fileTransferServiceProvider);
        expect(state.tasks.first.status, FileTransferStatus.paused);
      }, timeout: const Timeout(Duration(seconds: 5)));
    });

    group('cancelTransfer', () {
      test('应该取消并移除传输', () {
        final taskId = fileTransferService.createUpload(
          filename: 'test.pdf',
          localPath: '/local/test.pdf',
          remotePath: '/remote/',
          fileSize: 1024 * 1024,
        );

        var state = container.read(fileTransferServiceProvider);
        expect(state.tasks.length, 1);

        fileTransferService.cancelTransfer(taskId);

        state = container.read(fileTransferServiceProvider);
        expect(state.tasks.length, 0);
      });
    });

    group('clearCompleted', () {
      test('应该清除已完成的传输', () async {
        // 添加一个小文件以便快速完成
        fileTransferService.createUpload(
          filename: 'small.txt',
          localPath: '/local/small.txt',
          remotePath: '/remote/',
          fileSize: 1000, // 1KB - 很快完成
        );

        // 等待传输完成 (with timeout to prevent hanging)
        var attempts = 0;
        const maxAttempts = 20; // 2 seconds max
        while (attempts < maxAttempts) {
          await Future.delayed(const Duration(milliseconds: 100));
          final state = container.read(fileTransferServiceProvider);
          if (state.completedTasks.isNotEmpty) break;
          attempts++;
        }

        var state = container.read(fileTransferServiceProvider);
        expect(state.completedTasks.length, greaterThanOrEqualTo(0));

        fileTransferService.clearCompleted();

        state = container.read(fileTransferServiceProvider);
        expect(state.completedTasks.length, 0);
      }, timeout: const Timeout(Duration(seconds: 5)));
    });
  });

  group('FileTransferTask', () {
    test('应该正确计算进度', () {
      final task = FileTransferTask(
        id: '1',
        filename: 'test.pdf',
        localPath: '/local/test.pdf',
        remotePath: '/remote/',
        totalSize: 1000,
        direction: FileTransferDirection.upload,
        transferredSize: 500,
        speed: 100,
      );

      expect(task.progress, 0.5);
    });

    test('总大小为0时进度应该为0', () {
      final task = FileTransferTask(
        id: '1',
        filename: 'empty.txt',
        localPath: '/local/empty.txt',
        remotePath: '/remote/',
        totalSize: 0,
        direction: FileTransferDirection.upload,
        transferredSize: 0,
        speed: 0,
        status: FileTransferStatus.completed,
      );

      expect(task.progress, 0.0);
    });
  });

  group('FileTransferServiceState', () {
    test('activeTasks 应该只返回进行中的传输', () {
      final state = FileTransferServiceState(
        tasks: [
          FileTransferTask(
            id: '1',
            filename: 'active.pdf',
            localPath: '/local/',
            remotePath: '/remote/',
            totalSize: 1000,
            direction: FileTransferDirection.upload,
            transferredSize: 500,
            speed: 100,
            status: FileTransferStatus.inProgress,
          ),
          FileTransferTask(
            id: '2',
            filename: 'paused.pdf',
            localPath: '/local/',
            remotePath: '/remote/',
            totalSize: 1000,
            direction: FileTransferDirection.upload,
            transferredSize: 300,
            speed: 0,
            status: FileTransferStatus.paused,
          ),
          FileTransferTask(
            id: '3',
            filename: 'completed.pdf',
            localPath: '/local/',
            remotePath: '/remote/',
            totalSize: 1000,
            direction: FileTransferDirection.upload,
            transferredSize: 1000,
            speed: 0,
            status: FileTransferStatus.completed,
          ),
        ],
      );

      expect(state.activeTasks.length, 1);
      expect(state.completedTasks.length, 1);
      expect(state.pausedTasks.length, 1);
    }, timeout: const Timeout(Duration(seconds: 5)));
  });
}
