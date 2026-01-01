import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FileTransferPage extends ConsumerStatefulWidget {
  const FileTransferPage({super.key});

  @override
  ConsumerState<FileTransferPage> createState() => _FileTransferPageState();
}

class _FileTransferPageState extends ConsumerState<FileTransferPage> {
  final List<FileTransferItem> _transfers = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Transfer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addFileTransfer,
          ),
        ],
      ),
      body: _transfers.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No file transfers',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap + to start a file transfer',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _transfers.length,
              itemBuilder: (context, index) {
                final transfer = _transfers[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      _getFileIcon(transfer.filename),
                      size: 32,
                    ),
                    title: Text(transfer.filename),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_formatFileSize(transfer.transferredSize)} / ${_formatFileSize(transfer.totalSize)}',
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: transfer.progress,
                          backgroundColor: Colors.grey[300],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatSpeed(transfer.speed)} • ${_formatTime(transfer.estimatedTime)} remaining',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'pause':
                            _pauseTransfer(transfer);
                            break;
                          case 'resume':
                            _resumeTransfer(transfer);
                            break;
                          case 'cancel':
                            _cancelTransfer(transfer);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        if (transfer.status == TransferStatus.inProgress)
                          const PopupMenuItem(
                            value: 'pause',
                            child: Text('Pause'),
                          ),
                        if (transfer.status == TransferStatus.paused)
                          const PopupMenuItem(
                            value: 'resume',
                            child: Text('Resume'),
                          ),
                        const PopupMenuItem(
                          value: 'cancel',
                          child: Text('Cancel'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _addFileTransfer() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'File Transfer',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.upload),
              title: const Text('Send File'),
              subtitle: const Text('Send file to remote device'),
              onTap: () {
                Navigator.pop(context);
                _selectAndSendFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Receive File'),
              subtitle: const Text('Request file from remote device'),
              onTap: () {
                Navigator.pop(context);
                _requestFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _selectAndSendFile() async {
    // Simulate file selection and transfer
    final transfer = FileTransferItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      filename: 'document.pdf',
      totalSize: 1024 * 1024 * 5, // 5MB
      transferredSize: 0,
      speed: 0,
      estimatedTime: 0,
      status: TransferStatus.inProgress,
      direction: TransferDirection.upload,
    );

    setState(() {
      _transfers.add(transfer);
    });

    // Simulate transfer progress
    _simulateTransfer(transfer);
  }

  void _requestFile() {
    // Show dialog to request file from remote device
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request File'),
        content: const TextField(
          decoration: InputDecoration(
            labelText: 'File path on remote device',
            hintText: '/path/to/file.txt',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Start file request
            },
            child: const Text('Request'),
          ),
        ],
      ),
    );
  }

  void _simulateTransfer(FileTransferItem transfer) async {
    while (transfer.transferredSize < transfer.totalSize && 
           transfer.status == TransferStatus.inProgress) {
      await Future.delayed(const Duration(milliseconds: 100));
      
      if (transfer.status == TransferStatus.inProgress) {
        setState(() {
          transfer.transferredSize += 50000; // 50KB per update
          transfer.speed = 500000; // 500KB/s
          transfer.estimatedTime = 
              ((transfer.totalSize - transfer.transferredSize) / transfer.speed).round();
        });
      }
    }

    if (transfer.transferredSize >= transfer.totalSize) {
      setState(() {
        transfer.status = TransferStatus.completed;
        transfer.transferredSize = transfer.totalSize;
        transfer.estimatedTime = 0;
      });
    }
  }

  void _pauseTransfer(FileTransferItem transfer) {
    setState(() {
      transfer.status = TransferStatus.paused;
    });
  }

  void _resumeTransfer(FileTransferItem transfer) {
    setState(() {
      transfer.status = TransferStatus.inProgress;
    });
    _simulateTransfer(transfer);
  }

  void _cancelTransfer(FileTransferItem transfer) {
    setState(() {
      _transfers.remove(transfer);
    });
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
}

class FileTransferItem {
  final String id;
  final String filename;
  final int totalSize;
  int transferredSize;
  int speed;
  int estimatedTime;
  TransferStatus status;
  final TransferDirection direction;

  FileTransferItem({
    required this.id,
    required this.filename,
    required this.totalSize,
    required this.transferredSize,
    required this.speed,
    required this.estimatedTime,
    required this.status,
    required this.direction,
  });

  double get progress => totalSize > 0 ? transferredSize / totalSize : 0.0;
}

enum TransferStatus {
  pending,
  inProgress,
  paused,
  completed,
  failed,
  cancelled,
}

enum TransferDirection {
  upload,
  download,
}