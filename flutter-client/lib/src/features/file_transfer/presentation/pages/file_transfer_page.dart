import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/monitoring_service.dart';

/// 文件传输状态
enum TransferStatus {
  pending,
  inProgress,
  paused,
  completed,
  failed,
  cancelled,
}

/// 传输方向
enum TransferDirection {
  upload,
  download,
}

/// 文件传输项
class FileTransferItem {
  final String id;
  final String filename;
  final String localPath;
  final String remotePath;
  final int totalSize;
  int transferredSize;
  int speed;
  int estimatedTime;
  TransferStatus status;
  final TransferDirection direction;
  String? errorMessage;
  final DateTime startTime;

  FileTransferItem({
    required this.id,
    required this.filename,
    required this.localPath,
    required this.remotePath,
    required this.totalSize,
    required this.transferredSize,
    required this.speed,
    required this.estimatedTime,
    required this.status,
    required this.direction,
    this.errorMessage,
    DateTime? startTime,
  }) : startTime = startTime ?? DateTime.now();

  double get progress => totalSize > 0 ? transferredSize / totalSize : 0.0;

  FileTransferItem copyWith({
    int? transferredSize,
    int? speed,
    int? estimatedTime,
    TransferStatus? status,
    String? errorMessage,
  }) {
    return FileTransferItem(
      id: id,
      filename: filename,
      localPath: localPath,
      remotePath: remotePath,
      totalSize: totalSize,
      transferredSize: transferredSize ?? this.transferredSize,
      speed: speed ?? this.speed,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      status: status ?? this.status,
      direction: direction,
      errorMessage: errorMessage ?? this.errorMessage,
      startTime: startTime,
    );
  }
}

/// 文件传输服务状态
class FileTransferState {
  final List<FileTransferItem> transfers;
  final List<FileTransferItem> history;

  const FileTransferState({
    this.transfers = const [],
    this.history = const [],
  });

  FileTransferState copyWith({
    List<FileTransferItem>? transfers,
    List<FileTransferItem>? history,
  }) {
    return FileTransferState(
      transfers: transfers ?? this.transfers,
      history: history ?? this.history,
    );
  }

  List<FileTransferItem> get activeTransfers =>
      transfers.where((t) => t.status == TransferStatus.inProgress || t.status == TransferStatus.paused).toList();

  List<FileTransferItem> get completedTransfers =>
      transfers.where((t) => t.status == TransferStatus.completed).toList();
}

/// 文件传输服务
class FileTransferService extends StateNotifier<FileTransferState> {
  FileTransferService() : super(const FileTransferState());

  /// 添加上传任务
  void addUpload(String filename, String localPath, String remotePath, int size) {
    final transfer = FileTransferItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      filename: filename,
      localPath: localPath,
      remotePath: remotePath,
      totalSize: size,
      transferredSize: 0,
      speed: 0,
      estimatedTime: 0,
      status: TransferStatus.pending,
      direction: TransferDirection.upload,
    );

    state = state.copyWith(transfers: [...state.transfers, transfer]);
    _startTransfer(transfer.id);
  }

  /// 添加下载任务
  void addDownload(String filename, String remotePath, String localPath, int size) {
    final transfer = FileTransferItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      filename: filename,
      localPath: localPath,
      remotePath: remotePath,
      totalSize: size,
      transferredSize: 0,
      speed: 0,
      estimatedTime: 0,
      status: TransferStatus.pending,
      direction: TransferDirection.download,
    );

    state = state.copyWith(transfers: [...state.transfers, transfer]);
    _startTransfer(transfer.id);
  }

  /// 暂停传输
  void pauseTransfer(String id) {
    _updateTransfer(id, (t) => t.copyWith(status: TransferStatus.paused));
  }

  /// 恢复传输
  void resumeTransfer(String id) {
    _updateTransfer(id, (t) => t.copyWith(status: TransferStatus.inProgress));
    _startTransfer(id);
  }

  /// 取消传输
  void cancelTransfer(String id) {
    state = state.copyWith(
      transfers: state.transfers.where((t) => t.id != id).toList(),
    );
  }

  /// 清除已完成
  void clearCompleted() {
    state = state.copyWith(
      transfers: state.transfers.where((t) => t.status != TransferStatus.completed).toList(),
    );
  }

  void _startTransfer(String id) async {
    _updateTransfer(id, (t) => t.copyWith(status: TransferStatus.inProgress));

    // 模拟传输过程
    while (true) {
      await Future.delayed(const Duration(milliseconds: 100));

      final transfer = state.transfers.firstWhere(
        (t) => t.id == id,
        orElse: () => throw Exception('Transfer not found'),
      );

      if (transfer.status != TransferStatus.inProgress) break;
      if (transfer.transferredSize >= transfer.totalSize) {
        _updateTransfer(id, (t) => t.copyWith(
          status: TransferStatus.completed,
          transferredSize: t.totalSize,
          estimatedTime: 0,
        ));
        break;
      }

      final newTransferred = transfer.transferredSize + 50000; // 50KB per update
      final speed = 500000; // 500KB/s
      final remaining = transfer.totalSize - newTransferred;
      final eta = remaining > 0 ? (remaining / speed).round() : 0;

      _updateTransfer(id, (t) => t.copyWith(
        transferredSize: newTransferred.clamp(0, t.totalSize),
        speed: speed,
        estimatedTime: eta,
      ));
    }
  }

  void _updateTransfer(String id, FileTransferItem Function(FileTransferItem) update) {
    state = state.copyWith(
      transfers: state.transfers.map((t) => t.id == id ? update(t) : t).toList(),
    );
  }
}

final fileTransferServiceProvider =
    StateNotifierProvider<FileTransferService, FileTransferState>((ref) {
  return FileTransferService();
});

class FileTransferPage extends ConsumerStatefulWidget {
  const FileTransferPage({super.key});

  @override
  ConsumerState<FileTransferPage> createState() => _FileTransferPageState();
}

class _FileTransferPageState extends ConsumerState<FileTransferPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transferState = ref.watch(fileTransferServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('文件传输'),
        actions: [
          if (transferState.completedTransfers.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                ref.read(fileTransferServiceProvider.notifier).clearCompleted();
              },
              icon: const Icon(Icons.clear_all),
              label: const Text('清除已完成'),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: '传输中 (${transferState.activeTransfers.length})',
              icon: const Icon(Icons.sync),
            ),
            Tab(
              text: '已完成 (${transferState.completedTransfers.length})',
              icon: const Icon(Icons.check_circle),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveTransfers(transferState.activeTransfers),
          _buildCompletedTransfers(transferState.completedTransfers),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showTransferOptions,
        icon: const Icon(Icons.add),
        label: const Text('新建传输'),
      ),
    );
  }

  Widget _buildActiveTransfers(List<FileTransferItem> transfers) {
    if (transfers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_sync, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '没有进行中的传输',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              '点击下方按钮开始传输文件',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: transfers.length,
      itemBuilder: (context, index) => _buildTransferCard(transfers[index]),
    );
  }

  Widget _buildCompletedTransfers(List<FileTransferItem> transfers) {
    if (transfers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '没有已完成的传输',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: transfers.length,
      itemBuilder: (context, index) => _buildCompletedCard(transfers[index]),
    );
  }

  Widget _buildTransferCard(FileTransferItem transfer) {
    final service = ref.read(fileTransferServiceProvider.notifier);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  transfer.direction == TransferDirection.upload
                      ? Icons.upload
                      : Icons.download,
                  color: transfer.direction == TransferDirection.upload
                      ? Colors.blue
                      : Colors.green,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transfer.filename,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        transfer.direction == TransferDirection.upload
                            ? '上传到: ${transfer.remotePath}'
                            : '下载到: ${transfer.localPath}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _buildTransferActions(transfer, service),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: transfer.progress,
              backgroundColor: Colors.grey[300],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_formatFileSize(transfer.transferredSize)} / ${_formatFileSize(transfer.totalSize)}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  '${(transfer.progress * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  transfer.status == TransferStatus.paused
                      ? '已暂停'
                      : '${_formatSpeed(transfer.speed)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: transfer.status == TransferStatus.paused
                        ? Colors.orange
                        : Colors.grey,
                  ),
                ),
                if (transfer.status == TransferStatus.inProgress)
                  Text(
                    '剩余 ${_formatTime(transfer.estimatedTime)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferActions(FileTransferItem transfer, FileTransferService service) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (transfer.status == TransferStatus.inProgress)
          IconButton(
            icon: const Icon(Icons.pause),
            onPressed: () => service.pauseTransfer(transfer.id),
            tooltip: '暂停',
          )
        else if (transfer.status == TransferStatus.paused)
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () => service.resumeTransfer(transfer.id),
            tooltip: '继续',
          ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _confirmCancel(transfer, service),
          tooltip: '取消',
        ),
      ],
    );
  }

  Widget _buildCompletedCard(FileTransferItem transfer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          _getFileIcon(transfer.filename),
          size: 40,
          color: Colors.blue,
        ),
        title: Text(transfer.filename),
        subtitle: Text(
          '${_formatFileSize(transfer.totalSize)} • ${_formatDateTime(transfer.startTime)}',
        ),
        trailing: Icon(
          transfer.direction == TransferDirection.upload
              ? Icons.upload
              : Icons.download,
          color: Colors.green,
        ),
        onTap: () => _showTransferDetails(transfer),
      ),
    );
  }

  void _showTransferOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '文件传输',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.upload, color: Colors.blue),
              title: const Text('发送文件'),
              subtitle: const Text('从本地发送文件到远程设备'),
              onTap: () {
                Navigator.pop(context);
                _selectAndSendFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.download, color: Colors.green),
              title: const Text('接收文件'),
              subtitle: const Text('从远程设备下载文件'),
              onTap: () {
                Navigator.pop(context);
                _requestFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder, color: Colors.orange),
              title: const Text('浏览远程文件'),
              subtitle: const Text('浏览远程设备的文件系统'),
              onTap: () {
                Navigator.pop(context);
                _browseRemoteFiles();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _selectAndSendFile() {
    final service = ref.read(fileTransferServiceProvider.notifier);
    final monitoring = ref.read(monitoringServiceProvider.notifier);

    // 模拟文件选择
    service.addUpload(
      'document_${DateTime.now().millisecondsSinceEpoch}.pdf',
      '/local/documents/file.pdf',
      '/remote/downloads/',
      1024 * 1024 * 5, // 5MB
    );

    monitoring.info('FileTransfer', '开始上传文件');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('文件传输已开始')),
    );
  }

  void _requestFile() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('下载文件'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: '远程文件路径',
              hintText: '/path/to/file.txt',
              prefixIcon: Icon(Icons.folder),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (controller.text.isNotEmpty) {
                  final service = ref.read(fileTransferServiceProvider.notifier);
                  final filename = controller.text.split('/').last;
                  service.addDownload(
                    filename,
                    controller.text,
                    '/local/downloads/$filename',
                    1024 * 1024 * 3, // 3MB
                  );
                }
              },
              child: const Text('下载'),
            ),
          ],
        );
      },
    );
  }

  void _browseRemoteFiles() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('远程文件浏览功能开发中')),
    );
  }

  void _confirmCancel(FileTransferItem transfer, FileTransferService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消传输'),
        content: Text('确定要取消 "${transfer.filename}" 的传输吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('继续传输'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              service.cancelTransfer(transfer.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('取消传输'),
          ),
        ],
      ),
    );
  }

  void _showTransferDetails(FileTransferItem transfer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('传输详情'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('文件名', transfer.filename),
            _buildDetailRow('大小', _formatFileSize(transfer.totalSize)),
            _buildDetailRow('方向', transfer.direction == TransferDirection.upload ? '上传' : '下载'),
            _buildDetailRow('本地路径', transfer.localPath),
            _buildDetailRow('远程路径', transfer.remotePath),
            _buildDetailRow('开始时间', _formatDateTime(transfer.startTime)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  IconData _getFileIcon(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
      case 'flac':
        return Icons.audio_file;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond < 1024) return '$bytesPerSecond B/s';
    if (bytesPerSecond < 1024 * 1024) return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  String _formatTime(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m ${seconds % 60}s';
    return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
