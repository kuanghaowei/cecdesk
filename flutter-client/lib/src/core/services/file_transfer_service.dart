import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 文件传输状态
enum FileTransferStatus {
  pending,
  inProgress,
  paused,
  completed,
  failed,
  cancelled,
}

/// 传输方向
enum FileTransferDirection {
  upload,
  download,
}

/// 文件块信息
class FileChunk {
  final int index;
  final int offset;
  final int size;
  bool isTransferred;
  int retryCount;

  FileChunk({
    required this.index,
    required this.offset,
    required this.size,
    this.isTransferred = false,
    this.retryCount = 0,
  });

  FileChunk copyWith({
    bool? isTransferred,
    int? retryCount,
  }) {
    return FileChunk(
      index: index,
      offset: offset,
      size: size,
      isTransferred: isTransferred ?? this.isTransferred,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}

/// 文件传输任务
class FileTransferTask {
  final String id;
  final String filename;
  final String localPath;
  final String remotePath;
  final int totalSize;
  final FileTransferDirection direction;
  final DateTime createdAt;
  final String? checksum;

  int transferredSize;
  int speed;
  FileTransferStatus status;
  String? errorMessage;
  List<FileChunk> chunks;
  DateTime? startedAt;
  DateTime? completedAt;
  DateTime? pausedAt;

  FileTransferTask({
    required this.id,
    required this.filename,
    required this.localPath,
    required this.remotePath,
    required this.totalSize,
    required this.direction,
    this.checksum,
    DateTime? createdAt,
    this.transferredSize = 0,
    this.speed = 0,
    this.status = FileTransferStatus.pending,
    this.errorMessage,
    List<FileChunk>? chunks,
    this.startedAt,
    this.completedAt,
    this.pausedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        chunks = chunks ?? [];

  double get progress => totalSize > 0 ? transferredSize / totalSize : 0.0;

  int get remainingSize => totalSize - transferredSize;

  Duration? get estimatedTimeRemaining {
    if (speed <= 0) return null;
    return Duration(seconds: (remainingSize / speed).round());
  }

  int get transferredChunks => chunks.where((c) => c.isTransferred).length;

  int get totalChunks => chunks.length;

  /// 获取下一个需要传输的块
  FileChunk? getNextChunk() {
    return chunks.firstWhere(
      (c) => !c.isTransferred,
      orElse: () => chunks.first,
    );
  }

  /// 获取断点续传的起始位置
  int getResumeOffset() {
    final lastTransferred = chunks.lastWhere(
      (c) => c.isTransferred,
      orElse: () => FileChunk(index: -1, offset: 0, size: 0),
    );
    return lastTransferred.index >= 0 ? lastTransferred.offset + lastTransferred.size : 0;
  }

  FileTransferTask copyWith({
    int? transferredSize,
    int? speed,
    FileTransferStatus? status,
    String? errorMessage,
    List<FileChunk>? chunks,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? pausedAt,
  }) {
    return FileTransferTask(
      id: id,
      filename: filename,
      localPath: localPath,
      remotePath: remotePath,
      totalSize: totalSize,
      direction: direction,
      checksum: checksum,
      createdAt: createdAt,
      transferredSize: transferredSize ?? this.transferredSize,
      speed: speed ?? this.speed,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      chunks: chunks ?? this.chunks,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      pausedAt: pausedAt ?? this.pausedAt,
    );
  }
}

/// 文件传输服务状态
class FileTransferServiceState {
  final List<FileTransferTask> tasks;
  final int maxConcurrentTransfers;
  final int chunkSize;

  const FileTransferServiceState({
    this.tasks = const [],
    this.maxConcurrentTransfers = 3,
    this.chunkSize = 1024 * 1024, // 1MB chunks
  });

  FileTransferServiceState copyWith({
    List<FileTransferTask>? tasks,
    int? maxConcurrentTransfers,
    int? chunkSize,
  }) {
    return FileTransferServiceState(
      tasks: tasks ?? this.tasks,
      maxConcurrentTransfers: maxConcurrentTransfers ?? this.maxConcurrentTransfers,
      chunkSize: chunkSize ?? this.chunkSize,
    );
  }

  List<FileTransferTask> get activeTasks =>
      tasks.where((t) => t.status == FileTransferStatus.inProgress).toList();

  List<FileTransferTask> get pendingTasks =>
      tasks.where((t) => t.status == FileTransferStatus.pending).toList();

  List<FileTransferTask> get pausedTasks =>
      tasks.where((t) => t.status == FileTransferStatus.paused).toList();

  List<FileTransferTask> get completedTasks =>
      tasks.where((t) => t.status == FileTransferStatus.completed).toList();

  List<FileTransferTask> get failedTasks =>
      tasks.where((t) => t.status == FileTransferStatus.failed).toList();
}

/// 文件传输服务
class FileTransferService extends StateNotifier<FileTransferServiceState> {
  final Map<String, Timer> _transferTimers = {};
  final Random _random = Random();

  FileTransferService() : super(const FileTransferServiceState());

  /// 创建上传任务
  String createUpload({
    required String filename,
    required String localPath,
    required String remotePath,
    required int fileSize,
    String? checksum,
  }) {
    final task = _createTask(
      filename: filename,
      localPath: localPath,
      remotePath: remotePath,
      fileSize: fileSize,
      direction: FileTransferDirection.upload,
      checksum: checksum,
    );

    state = state.copyWith(tasks: [...state.tasks, task]);
    _startTransferIfPossible();

    return task.id;
  }

  /// 创建下载任务
  String createDownload({
    required String filename,
    required String remotePath,
    required String localPath,
    required int fileSize,
    String? checksum,
  }) {
    final task = _createTask(
      filename: filename,
      localPath: localPath,
      remotePath: remotePath,
      fileSize: fileSize,
      direction: FileTransferDirection.download,
      checksum: checksum,
    );

    state = state.copyWith(tasks: [...state.tasks, task]);
    _startTransferIfPossible();

    return task.id;
  }

  /// 暂停传输
  void pauseTransfer(String taskId) {
    _transferTimers[taskId]?.cancel();
    _transferTimers.remove(taskId);

    _updateTask(taskId, (task) => task.copyWith(
          status: FileTransferStatus.paused,
          pausedAt: DateTime.now(),
        ));
  }

  /// 恢复传输（断点续传）
  void resumeTransfer(String taskId) {
    final task = state.tasks.firstWhere((t) => t.id == taskId);

    if (task.status != FileTransferStatus.paused) return;

    // 从断点位置继续
    final resumeOffset = task.getResumeOffset();

    _updateTask(taskId, (t) => t.copyWith(
          status: FileTransferStatus.inProgress,
          startedAt: t.startedAt ?? DateTime.now(),
        ));

    _startTransfer(taskId, resumeOffset: resumeOffset);
  }

  /// 取消传输
  void cancelTransfer(String taskId) {
    _transferTimers[taskId]?.cancel();
    _transferTimers.remove(taskId);

    state = state.copyWith(
      tasks: state.tasks.where((t) => t.id != taskId).toList(),
    );

    _startTransferIfPossible();
  }

  /// 重试失败的传输
  void retryTransfer(String taskId) {
    final task = state.tasks.firstWhere((t) => t.id == taskId);

    if (task.status != FileTransferStatus.failed) return;

    // 重置未完成的块
    final resetChunks = task.chunks.map((c) {
      if (!c.isTransferred) {
        return c.copyWith(retryCount: c.retryCount + 1);
      }
      return c;
    }).toList();

    _updateTask(taskId, (t) => t.copyWith(
          status: FileTransferStatus.pending,
          errorMessage: null,
          chunks: resetChunks,
        ));

    _startTransferIfPossible();
  }

  /// 清除已完成的任务
  void clearCompleted() {
    state = state.copyWith(
      tasks: state.tasks.where((t) => t.status != FileTransferStatus.completed).toList(),
    );
  }

  /// 获取任务信息
  FileTransferTask? getTask(String taskId) {
    try {
      return state.tasks.firstWhere((t) => t.id == taskId);
    } catch (_) {
      return null;
    }
  }

  FileTransferTask _createTask({
    required String filename,
    required String localPath,
    required String remotePath,
    required int fileSize,
    required FileTransferDirection direction,
    String? checksum,
  }) {
    final taskId = '${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(10000)}';

    // 创建文件块
    final chunks = <FileChunk>[];
    var offset = 0;
    var index = 0;

    while (offset < fileSize) {
      final chunkSize = min(state.chunkSize, fileSize - offset);
      chunks.add(FileChunk(
        index: index,
        offset: offset,
        size: chunkSize,
      ));
      offset += chunkSize;
      index++;
    }

    return FileTransferTask(
      id: taskId,
      filename: filename,
      localPath: localPath,
      remotePath: remotePath,
      totalSize: fileSize,
      direction: direction,
      checksum: checksum,
      chunks: chunks,
    );
  }

  void _startTransferIfPossible() {
    final activeCount = state.activeTasks.length;
    final availableSlots = state.maxConcurrentTransfers - activeCount;

    if (availableSlots <= 0) return;

    final pendingTasks = state.pendingTasks.take(availableSlots);

    for (final task in pendingTasks) {
      _updateTask(task.id, (t) => t.copyWith(
            status: FileTransferStatus.inProgress,
            startedAt: DateTime.now(),
          ));
      _startTransfer(task.id);
    }
  }

  void _startTransfer(String taskId, {int resumeOffset = 0}) {
    _transferTimers[taskId] = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _processTransfer(taskId),
    );
  }

  void _processTransfer(String taskId) {
    final task = state.tasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => throw Exception('Task not found'),
    );

    if (task.status != FileTransferStatus.inProgress) {
      _transferTimers[taskId]?.cancel();
      _transferTimers.remove(taskId);
      return;
    }

    // 找到下一个未传输的块
    final nextChunkIndex = task.chunks.indexWhere((c) => !c.isTransferred);

    if (nextChunkIndex == -1) {
      // 所有块已传输完成
      _completeTransfer(taskId);
      return;
    }

    // 模拟传输一个块
    final chunk = task.chunks[nextChunkIndex];
    final transferSpeed = 500000 + _random.nextInt(500000); // 500KB-1MB/s

    // 更新块状态
    final updatedChunks = List<FileChunk>.from(task.chunks);
    updatedChunks[nextChunkIndex] = chunk.copyWith(isTransferred: true);

    final newTransferred = task.transferredSize + chunk.size;

    _updateTask(taskId, (t) => t.copyWith(
          transferredSize: min(newTransferred, t.totalSize),
          speed: transferSpeed,
          chunks: updatedChunks,
        ));
  }

  void _completeTransfer(String taskId) {
    _transferTimers[taskId]?.cancel();
    _transferTimers.remove(taskId);

    _updateTask(taskId, (t) => t.copyWith(
          status: FileTransferStatus.completed,
          completedAt: DateTime.now(),
          transferredSize: t.totalSize,
          speed: 0,
        ));

    _startTransferIfPossible();
  }

  void _updateTask(String taskId, FileTransferTask Function(FileTransferTask) update) {
    state = state.copyWith(
      tasks: state.tasks.map((t) => t.id == taskId ? update(t) : t).toList(),
    );
  }

  @override
  void dispose() {
    for (final timer in _transferTimers.values) {
      timer.cancel();
    }
    _transferTimers.clear();
    super.dispose();
  }
}

/// 文件传输服务 Provider
final fileTransferServiceProvider =
    StateNotifierProvider<FileTransferService, FileTransferServiceState>((ref) {
  return FileTransferService();
});
