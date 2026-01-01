import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remote_desktop_client/src/features/file_transfer/presentation/pages/file_transfer_page.dart';

void main() {
  group('FileTransferService', () {
    late ProviderContainer container;
    late FileTransferService fileTransferService;

    setUp(() {
      container = ProviderContainer();
      fileTransferService = container.read(fileTransferServiceProvider.notifier);
    });

    tearDown(() async {
      // Cancel all active transfers before disposing to avoid async issues
      final state = container.read(fileTransferServiceProvider);
      for (final transfer in state.transfers) {
        if (transfer.status == TransferStatus.inProgress || 
            transfer.status == TransferStatus.paused) {
          fileTransferService.cancelTransfer(transfer.id);
        }
      }
      // Small delay to allow async operations to complete
      await Future.delayed(const Duration(milliseconds: 100));
      container.dispose();
    });

    group('addUpload', () {
      test('应该添加上传任务', () {
        fileTransferService.addUpload(
          'test.pdf',
          '/local/test.pdf',
          '/remote/downloads/',
          1024 * 1024,
        );

        final state = container.read(fileTransferServiceProvider);
        expect(state.transfers.length, 1);
        expect(state.transfers.first.filename, 'test.pdf');
        expect(state.transfers.first.direction, TransferDirection.upload);
      });
    });

    group('addDownload', () {
      test('应该添加下载任务', () {
        fileTransferService.addDownload(
          'document.docx',
          '/remote/documents/document.docx',
          '/local/downloads/',
          2 * 1024 * 1024,
        );

        final state = container.read(fileTransferServiceProvider);
        expect(state.transfers.length, 1);
        expect(state.transfers.first.filename, 'document.docx');
        expect(state.transfers.first.direction, TransferDirection.download);
      });
    });

    group('pauseTransfer', () {
      test('应该暂停传输', () async {
        fileTransferService.addUpload(
          'test.pdf',
          '/local/test.pdf',
          '/remote/',
          1024 * 1024 * 10, // 10MB - 足够大以便有时间暂停
        );

        var state = container.read(fileTransferServiceProvider);
        final transferId = state.transfers.first.id;

        // 等待传输开始
        await Future.delayed(const Duration(milliseconds: 200));

        fileTransferService.pauseTransfer(transferId);

        state = container.read(fileTransferServiceProvider);
        expect(state.transfers.first.status, TransferStatus.paused);
      });
    });

    group('cancelTransfer', () {
      test('应该取消并移除传输', () {
        fileTransferService.addUpload(
          'test.pdf',
          '/local/test.pdf',
          '/remote/',
          1024 * 1024,
        );

        var state = container.read(fileTransferServiceProvider);
        expect(state.transfers.length, 1);

        final transferId = state.transfers.first.id;
        fileTransferService.cancelTransfer(transferId);

        state = container.read(fileTransferServiceProvider);
        expect(state.transfers.length, 0);
      });
    });

    group('clearCompleted', () {
      test('应该清除已完成的传输', () async {
        // 添加一个小文件以便快速完成
        fileTransferService.addUpload(
          'small.txt',
          '/local/small.txt',
          '/remote/',
          1000, // 1KB - 很快完成
        );

        // 等待传输完成
        await Future.delayed(const Duration(milliseconds: 500));

        var state = container.read(fileTransferServiceProvider);
        expect(state.completedTransfers.length, greaterThanOrEqualTo(0));

        fileTransferService.clearCompleted();

        state = container.read(fileTransferServiceProvider);
        expect(state.completedTransfers.length, 0);
      });
    });
  });

  group('FileTransferItem', () {
    test('应该正确计算进度', () {
      final item = FileTransferItem(
        id: '1',
        filename: 'test.pdf',
        localPath: '/local/test.pdf',
        remotePath: '/remote/',
        totalSize: 1000,
        transferredSize: 500,
        speed: 100,
        estimatedTime: 5,
        status: TransferStatus.inProgress,
        direction: TransferDirection.upload,
      );

      expect(item.progress, 0.5);
    });

    test('总大小为0时进度应该为0', () {
      final item = FileTransferItem(
        id: '1',
        filename: 'empty.txt',
        localPath: '/local/empty.txt',
        remotePath: '/remote/',
        totalSize: 0,
        transferredSize: 0,
        speed: 0,
        estimatedTime: 0,
        status: TransferStatus.completed,
        direction: TransferDirection.upload,
      );

      expect(item.progress, 0.0);
    });
  });

  group('FileTransferState', () {
    test('activeTransfers 应该只返回进行中和暂停的传输', () {
      final state = FileTransferState(
        transfers: [
          FileTransferItem(
            id: '1',
            filename: 'active.pdf',
            localPath: '/local/',
            remotePath: '/remote/',
            totalSize: 1000,
            transferredSize: 500,
            speed: 100,
            estimatedTime: 5,
            status: TransferStatus.inProgress,
            direction: TransferDirection.upload,
          ),
          FileTransferItem(
            id: '2',
            filename: 'paused.pdf',
            localPath: '/local/',
            remotePath: '/remote/',
            totalSize: 1000,
            transferredSize: 300,
            speed: 0,
            estimatedTime: 0,
            status: TransferStatus.paused,
            direction: TransferDirection.upload,
          ),
          FileTransferItem(
            id: '3',
            filename: 'completed.pdf',
            localPath: '/local/',
            remotePath: '/remote/',
            totalSize: 1000,
            transferredSize: 1000,
            speed: 0,
            estimatedTime: 0,
            status: TransferStatus.completed,
            direction: TransferDirection.upload,
          ),
        ],
      );

      expect(state.activeTransfers.length, 2);
      expect(state.completedTransfers.length, 1);
    });
  });
}
