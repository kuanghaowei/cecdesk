/**
 * File Transfer Service Tests for WeChat MiniProgram
 * 微信小程序文件传输服务测试
 * 
 * 属性测试验证:
 * - 属性 17: 微信小程序文件系统 API 使用
 * 
 * 验证: 需求 15.5, 15.6
 */

const { FileTransferService } = require('../utils/file-transfer-service');

// 模拟微信小程序环境
const mockFileSystemManager = {
  getFileInfo: jest.fn((options) => {
    options.success({ size: 1024, digest: 'mock-digest' });
  }),
  readFile: jest.fn((options) => {
    const mockData = new ArrayBuffer(1024);
    options.success({ data: mockData });
  }),
  writeFile: jest.fn((options) => {
    options.success();
  })
};

const mockWx = {
  getFileSystemManager: jest.fn(() => mockFileSystemManager),
  chooseImage: jest.fn((options) => {
    options.success({
      tempFilePaths: ['/tmp/test-image.jpg']
    });
  }),
  chooseVideo: jest.fn((options) => {
    options.success({
      tempFilePath: '/tmp/test-video.mp4'
    });
  }),
  chooseMessageFile: jest.fn((options) => {
    options.success({
      tempFiles: [
        { path: '/tmp/test-doc.pdf', name: 'test-doc.pdf', size: 2048 }
      ]
    });
  }),
  saveImageToPhotosAlbum: jest.fn((options) => {
    options.success();
  }),
  saveVideoToPhotosAlbum: jest.fn((options) => {
    options.success();
  }),
  getStorageInfo: jest.fn((options) => {
    options.success({
      currentSize: 5000,
      limitSize: 10000,
      keys: ['key1', 'key2']
    });
  }),
  arrayBufferToBase64: jest.fn((buffer) => 'base64-encoded-data'),
  base64ToArrayBuffer: jest.fn((base64) => new ArrayBuffer(1024)),
  triggerGC: jest.fn(),
  getPerformance: jest.fn(() => ({
    getEntriesByType: jest.fn(() => [])
  })),
  env: {
    USER_DATA_PATH: '/user/data'
  }
};

// 设置全局 wx 对象
global.wx = mockWx;

describe('File Transfer Service Tests', () => {
  let fileTransferService;
  let mockWebrtcService;

  beforeEach(() => {
    mockWebrtcService = {
      isConnectionActive: () => true,
      sendDataChannelMessage: jest.fn()
    };

    fileTransferService = new FileTransferService();
    fileTransferService.init(mockWebrtcService, {
      chunkSize: 64 * 1024,
      maxFileSize: 100 * 1024 * 1024
    });
  });

  afterEach(() => {
    if (fileTransferService) {
      fileTransferService.destroy();
    }
    jest.clearAllMocks();
  });

  /**
   * 属性 17: 微信小程序文件系统 API 使用
   * Feature: cec-remote, Property 17: 微信小程序文件系统 API 使用
   * 验证: 需求 15.5
   */
  describe('Property 17: WeChat MiniProgram File System API Usage', () => {
    test('should initialize with file system manager', () => {
      expect(mockWx.getFileSystemManager).toHaveBeenCalled();
      expect(fileTransferService.fileSystemManager).toBeDefined();
    });

    test('should choose images using wx.chooseImage API', async () => {
      const files = await fileTransferService.chooseImages({ count: 3 });
      
      expect(mockWx.chooseImage).toHaveBeenCalledWith(expect.objectContaining({
        count: 3
      }));
      expect(files).toHaveLength(1);
      expect(files[0].type).toBe('image');
    });

    test('should choose video using wx.chooseVideo API', async () => {
      const file = await fileTransferService.chooseVideo({ maxDuration: 30 });
      
      expect(mockWx.chooseVideo).toHaveBeenCalledWith(expect.objectContaining({
        maxDuration: 30
      }));
      expect(file.type).toBe('video');
    });

    test('should choose documents using wx.chooseMessageFile API', async () => {
      const files = await fileTransferService.chooseDocuments({ count: 5 });
      
      expect(mockWx.chooseMessageFile).toHaveBeenCalledWith(expect.objectContaining({
        count: 5,
        type: 'file'
      }));
      expect(files).toHaveLength(1);
      expect(files[0].name).toBe('test-doc.pdf');
    });

    test('should get file info using file system manager', async () => {
      const fileInfo = await fileTransferService.getFileInfo('/tmp/test.txt');
      
      expect(mockFileSystemManager.getFileInfo).toHaveBeenCalledWith(expect.objectContaining({
        filePath: '/tmp/test.txt'
      }));
      expect(fileInfo.size).toBe(1024);
    });

    test('should read file using file system manager', async () => {
      const data = await fileTransferService.readFile('/tmp/test.txt');
      
      expect(mockFileSystemManager.readFile).toHaveBeenCalledWith(expect.objectContaining({
        filePath: '/tmp/test.txt'
      }));
      expect(data).toBeInstanceOf(ArrayBuffer);
    });

    test('should write file using file system manager', async () => {
      const data = new ArrayBuffer(1024);
      await fileTransferService.writeFile('/tmp/output.txt', data);
      
      expect(mockFileSystemManager.writeFile).toHaveBeenCalledWith(expect.objectContaining({
        filePath: '/tmp/output.txt',
        data: data
      }));
    });

    test('should save image to album using wx API', async () => {
      await fileTransferService.saveToAlbum('/tmp/image.jpg');
      
      expect(mockWx.saveImageToPhotosAlbum).toHaveBeenCalledWith(expect.objectContaining({
        filePath: '/tmp/image.jpg'
      }));
    });

    test('should save video to album using wx API', async () => {
      await fileTransferService.saveVideoToAlbum('/tmp/video.mp4');
      
      expect(mockWx.saveVideoToPhotosAlbum).toHaveBeenCalledWith(expect.objectContaining({
        filePath: '/tmp/video.mp4'
      }));
    });

    test('should get storage info using wx API', async () => {
      const storageInfo = await fileTransferService.getStorageInfo();
      
      expect(mockWx.getStorageInfo).toHaveBeenCalled();
      expect(storageInfo.currentSize).toBe(5000);
      expect(storageInfo.limitSize).toBe(10000);
    });

    test('should correctly identify file types', () => {
      expect(fileTransferService.getFileType('photo.jpg')).toBe('image');
      expect(fileTransferService.getFileType('photo.png')).toBe('image');
      expect(fileTransferService.getFileType('video.mp4')).toBe('video');
      expect(fileTransferService.getFileType('audio.mp3')).toBe('audio');
      expect(fileTransferService.getFileType('document.pdf')).toBe('document');
      expect(fileTransferService.getFileType('unknown.xyz')).toBe('other');
    });

    test('should format file size correctly', () => {
      expect(fileTransferService.formatFileSize(0)).toBe('0 B');
      expect(fileTransferService.formatFileSize(512)).toBe('512 B');
      expect(fileTransferService.formatFileSize(1024)).toBe('1 KB');
      expect(fileTransferService.formatFileSize(1048576)).toBe('1 MB');
      expect(fileTransferService.formatFileSize(1073741824)).toBe('1 GB');
    });

    test('should generate unique file IDs', () => {
      const id1 = fileTransferService.generateFileId();
      const id2 = fileTransferService.generateFileId();
      
      expect(id1).not.toBe(id2);
      expect(typeof id1).toBe('string');
      expect(id1.length).toBeGreaterThan(0);
    });

    test('should reject files exceeding max size', async () => {
      // 修改 mock 返回大文件
      mockFileSystemManager.getFileInfo.mockImplementationOnce((options) => {
        options.success({ size: 200 * 1024 * 1024 }); // 200MB
      });

      const files = await fileTransferService.processSelectedFiles(['/tmp/large-file.zip'], 'document');
      
      // 大文件应该被过滤掉
      expect(files).toHaveLength(0);
    });

    test('should track transfer progress', async () => {
      const progressEvents = [];
      fileTransferService.on('transferProgress', (transfer) => {
        progressEvents.push(transfer.progress);
      });

      const file = {
        id: 'test-file-id',
        path: '/tmp/test.txt',
        name: 'test.txt',
        size: 1024,
        type: 'document'
      };

      // 模拟发送文件
      try {
        await fileTransferService.sendFile(file);
      } catch (e) {
        // 忽略错误，我们只关心进度事件
      }

      // 应该有进度更新
      expect(progressEvents.length).toBeGreaterThan(0);
    });

    test('should emit events correctly', () => {
      const startHandler = jest.fn();
      const progressHandler = jest.fn();
      const completeHandler = jest.fn();

      fileTransferService.on('transferStart', startHandler);
      fileTransferService.on('transferProgress', progressHandler);
      fileTransferService.on('transferComplete', completeHandler);

      // 触发事件
      fileTransferService.emit('transferStart', { id: 'test' });
      fileTransferService.emit('transferProgress', { id: 'test', progress: 50 });
      fileTransferService.emit('transferComplete', { id: 'test' });

      expect(startHandler).toHaveBeenCalled();
      expect(progressHandler).toHaveBeenCalled();
      expect(completeHandler).toHaveBeenCalled();
    });

    test('should cancel transfer correctly', () => {
      const transfer = {
        id: 'cancel-test',
        status: 'sending',
        progress: 50
      };
      fileTransferService.transfers.set('cancel-test', transfer);

      const cancelHandler = jest.fn();
      fileTransferService.on('transferCancelled', cancelHandler);

      fileTransferService.cancelTransfer('cancel-test');

      expect(transfer.status).toBe('cancelled');
      expect(cancelHandler).toHaveBeenCalled();
    });

    test('should get all transfers', () => {
      fileTransferService.transfers.set('t1', { id: 't1' });
      fileTransferService.transfers.set('t2', { id: 't2' });

      const transfers = fileTransferService.getAllTransfers();

      expect(transfers).toHaveLength(2);
    });

    test('should sanitize file names', () => {
      expect(fileTransferService.sanitizeFileName('test/file.txt')).toBe('test_file.txt');
      expect(fileTransferService.sanitizeFileName('test\\file.txt')).toBe('test_file.txt');
      expect(fileTransferService.sanitizeFileName('test:file.txt')).toBe('test_file.txt');
      expect(fileTransferService.sanitizeFileName('normal.txt')).toBe('normal.txt');
    });
  });


  /**
   * 内存优化测试
   * 验证: 需求 15.6 - 优化内存使用并降低视频质量以保持稳定运行
   */
  describe('Memory Optimization (Requirement 15.6)', () => {
    test('should optimize memory when called', () => {
      // 添加一些已完成的传输
      fileTransferService.transfers.set('completed-1', { status: 'completed', endTime: Date.now() - 600000 });
      fileTransferService.transfers.set('failed-1', { status: 'failed', endTime: Date.now() - 600000 });
      fileTransferService.transfers.set('pending-1', { status: 'pending' });

      fileTransferService.optimizeMemory();

      // 已完成和失败的传输应该被清理
      expect(fileTransferService.transfers.has('completed-1')).toBe(false);
      expect(fileTransferService.transfers.has('failed-1')).toBe(false);
      expect(fileTransferService.transfers.has('pending-1')).toBe(true);
      expect(mockWx.triggerGC).toHaveBeenCalled();
    });

    test('should get memory status', () => {
      const status = fileTransferService.getMemoryStatus();
      
      expect(status).toHaveProperty('isLowMemoryMode');
      expect(status).toHaveProperty('activeTransfers');
      expect(status).toHaveProperty('totalTransfers');
      expect(status).toHaveProperty('chunkSize');
      expect(status).toHaveProperty('maxConcurrentTransfers');
    });

    test('should update memory config', () => {
      fileTransferService.setMemoryConfig({
        maxConcurrentTransfers: 5,
        lowMemoryThreshold: 0.9
      });

      expect(fileTransferService.memoryConfig.maxConcurrentTransfers).toBe(5);
      expect(fileTransferService.memoryConfig.lowMemoryThreshold).toBe(0.9);
    });

    test('should get effective chunk size based on file size', () => {
      // Normal mode
      fileTransferService.isLowMemoryMode = false;
      
      // Small file
      const smallChunk = fileTransferService.getEffectiveChunkSize(1024);
      expect(smallChunk).toBe(64 * 1024);
      
      // Large file (> 50MB)
      const largeChunk = fileTransferService.getEffectiveChunkSize(60 * 1024 * 1024);
      expect(largeChunk).toBe(128 * 1024); // Should be doubled
    });

    test('should reduce chunk size in low memory mode', () => {
      fileTransferService.isLowMemoryMode = true;
      
      const chunkSize = fileTransferService.getEffectiveChunkSize(1024);
      expect(chunkSize).toBe(32 * 1024); // Should be halved
    });

    test('should count active transfers', () => {
      fileTransferService.transfers.set('t1', { status: 'sending' });
      fileTransferService.transfers.set('t2', { status: 'receiving' });
      fileTransferService.transfers.set('t3', { status: 'completed' });
      fileTransferService.transfers.set('t4', { status: 'pending' });

      const count = fileTransferService.getActiveTransferCount();
      expect(count).toBe(2);
    });

    test('should pause and resume transfer', () => {
      const transfer = {
        id: 'pause-test',
        status: 'sending',
        direction: 'send'
      };
      fileTransferService.transfers.set('pause-test', transfer);

      const pauseHandler = jest.fn();
      const resumeHandler = jest.fn();
      fileTransferService.on('transferPaused', pauseHandler);
      fileTransferService.on('transferResumed', resumeHandler);

      // Pause
      fileTransferService.pauseTransfer('pause-test');
      expect(transfer.status).toBe('paused');
      expect(pauseHandler).toHaveBeenCalled();

      // Resume
      fileTransferService.resumeTransfer('pause-test');
      expect(transfer.status).toBe('sending');
      expect(resumeHandler).toHaveBeenCalled();
    });

    test('should emit low memory event', () => {
      const lowMemoryHandler = jest.fn();
      fileTransferService.on('lowMemory', lowMemoryHandler);

      fileTransferService.emit('lowMemory', { storageUsage: 0.9 });

      expect(lowMemoryHandler).toHaveBeenCalledWith({ storageUsage: 0.9 });
    });

    test('should auto cleanup old transfers', () => {
      const now = Date.now();
      
      // Old completed transfer (> 5 minutes)
      fileTransferService.transfers.set('old-1', { 
        status: 'completed', 
        endTime: now - 6 * 60 * 1000 
      });
      
      // Recent completed transfer
      fileTransferService.transfers.set('recent-1', { 
        status: 'completed', 
        endTime: now - 1 * 60 * 1000 
      });
      
      // Active transfer
      fileTransferService.transfers.set('active-1', { 
        status: 'sending' 
      });

      fileTransferService.autoCleanupTransfers();

      expect(fileTransferService.transfers.has('old-1')).toBe(false);
      expect(fileTransferService.transfers.has('recent-1')).toBe(true);
      expect(fileTransferService.transfers.has('active-1')).toBe(true);
    });

    test('should start and stop memory monitoring', () => {
      // Stop first (from init)
      fileTransferService.stopMemoryMonitoring();
      expect(fileTransferService.memoryMonitorInterval).toBeNull();

      // Start
      fileTransferService.startMemoryMonitoring();
      expect(fileTransferService.memoryMonitorInterval).not.toBeNull();

      // Stop again
      fileTransferService.stopMemoryMonitoring();
      expect(fileTransferService.memoryMonitorInterval).toBeNull();
    });
  });

  /**
   * 文件接收测试
   * 验证: 需求 15.5 - 实现文件上传下载
   */
  describe('File Receiving (Requirement 15.5)', () => {
    test('should create receive transfer record', async () => {
      const fileInfo = {
        transferId: 'recv-test',
        fileName: 'received.txt',
        fileSize: 2048,
        fileType: 'document'
      };

      const transfer = await fileTransferService.receiveFile(fileInfo);

      expect(transfer.id).toBe('recv-test');
      expect(transfer.file.name).toBe('received.txt');
      expect(transfer.direction).toBe('receive');
      expect(transfer.status).toBe('receiving');
    });

    test('should handle received chunks', async () => {
      // First create a receive transfer
      await fileTransferService.receiveFile({
        transferId: 'chunk-test',
        fileName: 'chunked.txt',
        fileSize: 1024,
        fileType: 'document'
      });

      const progressHandler = jest.fn();
      fileTransferService.on('transferProgress', progressHandler);

      // Handle a chunk
      await fileTransferService.handleReceivedChunk({
        transferId: 'chunk-test',
        fileName: 'chunked.txt',
        fileSize: 1024,
        fileType: 'document',
        chunkIndex: 0,
        totalChunks: 1,
        chunkData: 'base64data'
      });

      expect(progressHandler).toHaveBeenCalled();
    });
  });
});

// 运行测试
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    FileTransferService
  };
}
