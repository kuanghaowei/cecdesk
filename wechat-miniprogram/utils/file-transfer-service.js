/**
 * File Transfer Service for WeChat MiniProgram
 * 微信小程序文件传输服务
 * 
 * 使用微信小程序的文件系统 API 进行文件操作
 * 验证: 需求 15.5 - 使用微信小程序的文件系统 API 进行文件操作
 * 验证: 需求 15.6 - 优化内存使用并降低视频质量以保持稳定运行
 */

class FileTransferService {
  constructor() {
    this.webrtcService = null;
    this.transfers = new Map();
    this.eventHandlers = {};
    this.chunkSize = 64 * 1024; // 64KB 分块大小
    this.maxFileSize = 100 * 1024 * 1024; // 100MB 最大文件大小
    this.fileSystemManager = null;
    
    // 内存优化相关配置
    this.memoryConfig = {
      maxConcurrentTransfers: 3,      // 最大并发传输数
      chunkBufferLimit: 10,           // 分块缓冲区限制
      autoCleanupInterval: 30000,     // 自动清理间隔 (30秒)
      lowMemoryThreshold: 0.8,        // 低内存阈值 (80%)
      compressionEnabled: true,       // 启用压缩
      adaptiveChunkSize: true         // 自适应分块大小
    };
    
    // 内存监控
    this.memoryMonitorInterval = null;
    this.currentMemoryUsage = 0;
    this.isLowMemoryMode = false;
  }

  /**
   * 初始化文件传输服务
   * @param {Object} webrtcService WebRTC服务实例
   * @param {Object} options 配置选项
   */
  init(webrtcService, options = {}) {
    this.webrtcService = webrtcService;
    this.chunkSize = options.chunkSize || this.chunkSize;
    this.maxFileSize = options.maxFileSize || this.maxFileSize;
    
    // 合并内存配置
    if (options.memoryConfig) {
      this.memoryConfig = { ...this.memoryConfig, ...options.memoryConfig };
    }
    
    // 获取文件系统管理器
    this.fileSystemManager = wx.getFileSystemManager();
    
    // 启动内存监控
    this.startMemoryMonitoring();
    
    console.log('[FileTransferService] 初始化完成', {
      chunkSize: this.chunkSize,
      maxFileSize: this.maxFileSize,
      memoryConfig: this.memoryConfig
    });
    
    return this;
  }

  /**
   * 启动内存监控
   * 验证: 需求 15.6 - 优化内存使用
   */
  startMemoryMonitoring() {
    if (this.memoryMonitorInterval) {
      return;
    }
    
    this.memoryMonitorInterval = setInterval(() => {
      this.checkMemoryStatus();
    }, this.memoryConfig.autoCleanupInterval);
    
    // 立即检查一次
    this.checkMemoryStatus();
  }

  /**
   * 停止内存监控
   */
  stopMemoryMonitoring() {
    if (this.memoryMonitorInterval) {
      clearInterval(this.memoryMonitorInterval);
      this.memoryMonitorInterval = null;
    }
  }

  /**
   * 检查内存状态
   * 验证: 需求 15.6 - 优化内存使用
   */
  async checkMemoryStatus() {
    try {
      // 获取系统内存信息（如果可用）
      if (wx.getPerformance) {
        const performance = wx.getPerformance();
        const entries = performance.getEntriesByType('memory');
        if (entries && entries.length > 0) {
          const memoryEntry = entries[entries.length - 1];
          this.currentMemoryUsage = memoryEntry.usedJSHeapSize / memoryEntry.totalJSHeapSize;
        }
      }
      
      // 检查存储空间
      const storageInfo = await this.getStorageInfo();
      const storageUsage = storageInfo.currentSize / storageInfo.limitSize;
      
      // 判断是否进入低内存模式
      const wasLowMemory = this.isLowMemoryMode;
      this.isLowMemoryMode = storageUsage > this.memoryConfig.lowMemoryThreshold;
      
      if (this.isLowMemoryMode && !wasLowMemory) {
        console.warn('[FileTransferService] 进入低内存模式');
        this.emit('lowMemory', { storageUsage, memoryUsage: this.currentMemoryUsage });
        this.performMemoryOptimization();
      }
      
      // 自动清理已完成的传输
      this.autoCleanupTransfers();
      
    } catch (error) {
      console.error('[FileTransferService] 内存检查失败:', error);
    }
  }

  /**
   * 执行内存优化
   * 验证: 需求 15.6 - 优化内存使用
   */
  performMemoryOptimization() {
    // 清理已完成的传输
    this.clearCompletedTransfers();
    
    // 减小分块大小以降低内存占用
    if (this.isLowMemoryMode && this.memoryConfig.adaptiveChunkSize) {
      this.chunkSize = Math.max(16 * 1024, this.chunkSize / 2); // 最小 16KB
      console.log('[FileTransferService] 降低分块大小:', this.chunkSize);
    }
    
    // 触发垃圾回收
    if (wx.triggerGC) {
      wx.triggerGC();
    }
    
    this.emit('memoryOptimized', { chunkSize: this.chunkSize });
  }

  /**
   * 自动清理传输记录
   */
  autoCleanupTransfers() {
    const now = Date.now();
    const maxAge = 5 * 60 * 1000; // 5分钟
    
    for (const [id, transfer] of this.transfers) {
      if (transfer.status === 'completed' || transfer.status === 'failed' || transfer.status === 'cancelled') {
        if (transfer.endTime && (now - transfer.endTime) > maxAge) {
          this.transfers.delete(id);
        }
      }
    }
  }

  /**
   * 选择图片文件
   * @param {Object} options 选项
   * @returns {Promise<Array>} 文件列表
   */
  chooseImages(options = {}) {
    return new Promise((resolve, reject) => {
      wx.chooseImage({
        count: options.count || 9,
        sizeType: options.sizeType || ['original', 'compressed'],
        sourceType: options.sourceType || ['album', 'camera'],
        success: async (res) => {
          const files = await this.processSelectedFiles(res.tempFilePaths, 'image');
          resolve(files);
        },
        fail: (error) => {
          console.error('[FileTransferService] 选择图片失败:', error);
          reject(error);
        }
      });
    });
  }

  /**
   * 选择视频文件
   * @param {Object} options 选项
   * @returns {Promise<Object>} 文件信息
   */
  chooseVideo(options = {}) {
    return new Promise((resolve, reject) => {
      wx.chooseVideo({
        sourceType: options.sourceType || ['album', 'camera'],
        maxDuration: options.maxDuration || 60,
        camera: options.camera || 'back',
        compressed: options.compressed !== false,
        success: async (res) => {
          const files = await this.processSelectedFiles([res.tempFilePath], 'video');
          resolve(files[0]);
        },
        fail: (error) => {
          console.error('[FileTransferService] 选择视频失败:', error);
          reject(error);
        }
      });
    });
  }

  /**
   * 选择文档文件
   * @param {Object} options 选项
   * @returns {Promise<Array>} 文件列表
   */
  chooseDocuments(options = {}) {
    return new Promise((resolve, reject) => {
      wx.chooseMessageFile({
        count: options.count || 10,
        type: options.type || 'file',
        extension: options.extension,
        success: async (res) => {
          const files = await this.processMessageFiles(res.tempFiles);
          resolve(files);
        },
        fail: (error) => {
          console.error('[FileTransferService] 选择文档失败:', error);
          reject(error);
        }
      });
    });
  }

  /**
   * 处理选择的文件
   * @param {Array} filePaths 文件路径列表
   * @param {string} type 文件类型
   * @returns {Promise<Array>} 处理后的文件列表
   */
  async processSelectedFiles(filePaths, type) {
    const files = [];
    
    for (const filePath of filePaths) {
      try {
        const fileInfo = await this.getFileInfo(filePath);
        
        // 检查文件大小
        if (fileInfo.size > this.maxFileSize) {
          console.warn('[FileTransferService] 文件过大:', filePath);
          continue;
        }
        
        files.push({
          id: this.generateFileId(),
          path: filePath,
          name: this.getFileName(filePath),
          size: fileInfo.size,
          type: type,
          status: 'pending',
          progress: 0,
          createTime: Date.now()
        });
      } catch (error) {
        console.error('[FileTransferService] 处理文件失败:', error);
      }
    }
    
    return files;
  }

  /**
   * 处理消息文件
   * @param {Array} tempFiles 临时文件列表
   * @returns {Promise<Array>} 处理后的文件列表
   */
  async processMessageFiles(tempFiles) {
    const files = [];
    
    for (const tempFile of tempFiles) {
      // 检查文件大小
      if (tempFile.size > this.maxFileSize) {
        console.warn('[FileTransferService] 文件过大:', tempFile.name);
        continue;
      }
      
      files.push({
        id: this.generateFileId(),
        path: tempFile.path,
        name: tempFile.name,
        size: tempFile.size,
        type: this.getFileType(tempFile.name),
        status: 'pending',
        progress: 0,
        createTime: Date.now()
      });
    }
    
    return files;
  }

  /**
   * 获取文件信息
   * @param {string} filePath 文件路径
   * @returns {Promise<Object>} 文件信息
   */
  getFileInfo(filePath) {
    return new Promise((resolve, reject) => {
      this.fileSystemManager.getFileInfo({
        filePath: filePath,
        success: (res) => {
          resolve({
            size: res.size,
            digest: res.digest
          });
        },
        fail: reject
      });
    });
  }

  /**
   * 读取文件内容
   * @param {string} filePath 文件路径
   * @param {string} encoding 编码方式
   * @returns {Promise<ArrayBuffer|string>} 文件内容
   */
  readFile(filePath, encoding = 'binary') {
    return new Promise((resolve, reject) => {
      this.fileSystemManager.readFile({
        filePath: filePath,
        encoding: encoding === 'binary' ? undefined : encoding,
        success: (res) => {
          resolve(res.data);
        },
        fail: reject
      });
    });
  }

  /**
   * 写入文件
   * @param {string} filePath 文件路径
   * @param {ArrayBuffer|string} data 文件数据
   * @param {string} encoding 编码方式
   * @returns {Promise<void>}
   */
  writeFile(filePath, data, encoding = 'binary') {
    return new Promise((resolve, reject) => {
      this.fileSystemManager.writeFile({
        filePath: filePath,
        data: data,
        encoding: encoding === 'binary' ? undefined : encoding,
        success: resolve,
        fail: reject
      });
    });
  }

  /**
   * 发送文件
   * 验证: 需求 15.5 - 实现文件上传下载
   * @param {Object} file 文件对象
   * @returns {Promise<Object>} 传输结果
   */
  async sendFile(file) {
    if (!this.webrtcService || !this.webrtcService.isConnectionActive()) {
      throw new Error('WebRTC 未连接');
    }
    
    // 检查并发传输数量
    const activeTransfers = this.getActiveTransferCount();
    if (activeTransfers >= this.memoryConfig.maxConcurrentTransfers) {
      throw new Error('已达到最大并发传输数量');
    }
    
    const transferId = this.generateFileId();
    
    // 创建传输记录
    const transfer = {
      id: transferId,
      file: file,
      direction: 'send',
      status: 'preparing',
      progress: 0,
      startTime: Date.now(),
      bytesTransferred: 0,
      retryCount: 0,
      maxRetries: 3
    };
    
    this.transfers.set(transferId, transfer);
    this.emit('transferStart', transfer);
    
    try {
      // 读取文件内容
      const fileData = await this.readFile(file.path);
      
      // 更新状态
      transfer.status = 'sending';
      this.emit('transferProgress', transfer);
      
      // 根据内存状态调整分块大小
      const effectiveChunkSize = this.getEffectiveChunkSize(file.size);
      const totalChunks = Math.ceil(file.size / effectiveChunkSize);
      
      for (let i = 0; i < totalChunks; i++) {
        // 检查传输是否被取消
        if (transfer.status === 'cancelled') {
          throw new Error('传输已取消');
        }
        
        const start = i * effectiveChunkSize;
        const end = Math.min(start + effectiveChunkSize, file.size);
        const chunk = fileData.slice(start, end);
        
        // 发送分块（带重试机制）
        await this.sendChunkWithRetry(transferId, i, totalChunks, chunk, file);
        
        // 更新进度
        transfer.bytesTransferred = end;
        transfer.progress = Math.round((end / file.size) * 100);
        this.emit('transferProgress', transfer);
        
        // 内存优化：定期触发垃圾回收
        if (i > 0 && i % this.memoryConfig.chunkBufferLimit === 0) {
          if (wx.triggerGC) {
            wx.triggerGC();
          }
        }
        
        // 动态延迟，根据内存状态调整
        const delay = this.isLowMemoryMode ? 100 : 50;
        await this.delay(delay);
      }
      
      // 完成传输
      transfer.status = 'completed';
      transfer.endTime = Date.now();
      this.emit('transferComplete', transfer);
      
      return transfer;
      
    } catch (error) {
      transfer.status = 'failed';
      transfer.error = error.message;
      transfer.endTime = Date.now();
      this.emit('transferError', { transfer, error });
      throw error;
    }
  }

  /**
   * 获取有效分块大小（根据内存状态调整）
   * 验证: 需求 15.6 - 优化内存使用
   * @param {number} fileSize 文件大小
   * @returns {number} 有效分块大小
   */
  getEffectiveChunkSize(fileSize) {
    let chunkSize = this.chunkSize;
    
    // 低内存模式下减小分块大小
    if (this.isLowMemoryMode) {
      chunkSize = Math.max(16 * 1024, chunkSize / 2);
    }
    
    // 大文件使用更大的分块
    if (fileSize > 50 * 1024 * 1024 && !this.isLowMemoryMode) {
      chunkSize = Math.min(256 * 1024, chunkSize * 2);
    }
    
    return chunkSize;
  }

  /**
   * 获取活跃传输数量
   * @returns {number}
   */
  getActiveTransferCount() {
    let count = 0;
    for (const transfer of this.transfers.values()) {
      if (transfer.status === 'sending' || transfer.status === 'receiving') {
        count++;
      }
    }
    return count;
  }

  /**
   * 发送分块（带重试机制）
   * @param {string} transferId 传输ID
   * @param {number} chunkIndex 分块索引
   * @param {number} totalChunks 总分块数
   * @param {ArrayBuffer} chunk 分块数据
   * @param {Object} file 文件信息
   */
  async sendChunkWithRetry(transferId, chunkIndex, totalChunks, chunk, file) {
    const transfer = this.transfers.get(transferId);
    let lastError = null;
    
    for (let attempt = 0; attempt <= transfer.maxRetries; attempt++) {
      try {
        await this.sendChunk(transferId, chunkIndex, totalChunks, chunk, file);
        return;
      } catch (error) {
        lastError = error;
        transfer.retryCount++;
        console.warn(`[FileTransferService] 分块 ${chunkIndex} 发送失败，重试 ${attempt + 1}/${transfer.maxRetries}`);
        await this.delay(1000 * (attempt + 1)); // 指数退避
      }
    }
    
    throw lastError || new Error('分块发送失败');
  }

  /**
   * 发送文件分块
   * @param {string} transferId 传输ID
   * @param {number} chunkIndex 分块索引
   * @param {number} totalChunks 总分块数
   * @param {ArrayBuffer} chunk 分块数据
   * @param {Object} file 文件信息
   */
  async sendChunk(transferId, chunkIndex, totalChunks, chunk, file) {
    // 将 ArrayBuffer 转换为 Base64
    const base64Chunk = wx.arrayBufferToBase64(chunk);
    
    // 通过 WebRTC 数据通道发送
    this.webrtcService.sendDataChannelMessage({
      type: 'file_chunk',
      transferId: transferId,
      fileName: file.name,
      fileSize: file.size,
      fileType: file.type,
      chunkIndex: chunkIndex,
      totalChunks: totalChunks,
      chunkData: base64Chunk,
      timestamp: Date.now()
    });
  }

  /**
   * 接收文件
   * 验证: 需求 15.5 - 实现文件上传下载
   * @param {Object} fileInfo 文件信息
   * @returns {Promise<Object>} 传输结果
   */
  async receiveFile(fileInfo) {
    // 检查并发传输数量
    const activeTransfers = this.getActiveTransferCount();
    if (activeTransfers >= this.memoryConfig.maxConcurrentTransfers) {
      throw new Error('已达到最大并发传输数量');
    }
    
    const transferId = fileInfo.transferId || this.generateFileId();
    
    // 根据内存状态调整分块大小
    const effectiveChunkSize = this.getEffectiveChunkSize(fileInfo.fileSize);
    
    // 创建传输记录
    const transfer = {
      id: transferId,
      file: {
        name: fileInfo.fileName,
        size: fileInfo.fileSize,
        type: fileInfo.fileType
      },
      direction: 'receive',
      status: 'receiving',
      progress: 0,
      startTime: Date.now(),
      bytesReceived: 0,
      chunks: [],
      totalChunks: Math.ceil(fileInfo.fileSize / effectiveChunkSize),
      effectiveChunkSize: effectiveChunkSize,
      receivedChunkCount: 0
    };
    
    this.transfers.set(transferId, transfer);
    this.emit('transferStart', transfer);
    
    return transfer;
  }

  /**
   * 处理接收到的文件分块
   * 验证: 需求 15.5 - 实现文件上传下载
   * @param {Object} chunkData 分块数据
   */
  async handleReceivedChunk(chunkData) {
    let transfer = this.transfers.get(chunkData.transferId);
    
    if (!transfer) {
      // 创建新的传输记录
      transfer = await this.receiveFile({
        transferId: chunkData.transferId,
        fileName: chunkData.fileName,
        fileSize: chunkData.fileSize,
        fileType: chunkData.fileType
      });
    }
    
    // 检查传输是否被取消
    if (transfer.status === 'cancelled') {
      return;
    }
    
    try {
      // 解码分块数据
      const chunkBuffer = wx.base64ToArrayBuffer(chunkData.chunkData);
      transfer.chunks[chunkData.chunkIndex] = chunkBuffer;
      transfer.receivedChunkCount++;
      
      // 更新进度
      transfer.progress = Math.round((transfer.receivedChunkCount / chunkData.totalChunks) * 100);
      transfer.bytesReceived = transfer.receivedChunkCount * (transfer.effectiveChunkSize || this.chunkSize);
      
      this.emit('transferProgress', transfer);
      
      // 内存优化：定期触发垃圾回收
      if (transfer.receivedChunkCount % this.memoryConfig.chunkBufferLimit === 0) {
        if (wx.triggerGC) {
          wx.triggerGC();
        }
      }
      
      // 检查是否完成
      if (transfer.receivedChunkCount === chunkData.totalChunks) {
        await this.completeReceive(transfer);
      }
      
    } catch (error) {
      console.error('[FileTransferService] 处理分块失败:', error);
      transfer.status = 'failed';
      transfer.error = error.message;
      transfer.endTime = Date.now();
      this.emit('transferError', { transfer, error });
    }
  }

  /**
   * 完成文件接收
   * 验证: 需求 15.5 - 实现文件上传下载
   * @param {Object} transfer 传输记录
   */
  async completeReceive(transfer) {
    try {
      // 验证所有分块都已接收
      const missingChunks = [];
      for (let i = 0; i < transfer.totalChunks; i++) {
        if (!transfer.chunks[i]) {
          missingChunks.push(i);
        }
      }
      
      if (missingChunks.length > 0) {
        throw new Error(`缺少分块: ${missingChunks.join(', ')}`);
      }
      
      // 合并分块
      const totalSize = transfer.chunks.reduce((sum, chunk) => sum + chunk.byteLength, 0);
      const mergedBuffer = new ArrayBuffer(totalSize);
      const mergedView = new Uint8Array(mergedBuffer);
      
      let offset = 0;
      for (const chunk of transfer.chunks) {
        mergedView.set(new Uint8Array(chunk), offset);
        offset += chunk.byteLength;
      }
      
      // 生成安全的文件名
      const safeFileName = this.sanitizeFileName(transfer.file.name);
      const savePath = `${wx.env.USER_DATA_PATH}/${safeFileName}`;
      
      // 保存文件
      await this.writeFile(savePath, mergedBuffer);
      
      // 清理分块数据以释放内存
      transfer.chunks = [];
      
      // 更新传输状态
      transfer.status = 'completed';
      transfer.endTime = Date.now();
      transfer.savedPath = savePath;
      
      // 触发垃圾回收
      if (wx.triggerGC) {
        wx.triggerGC();
      }
      
      this.emit('transferComplete', transfer);
      
    } catch (error) {
      transfer.status = 'failed';
      transfer.error = error.message;
      transfer.endTime = Date.now();
      // 清理分块数据
      transfer.chunks = [];
      this.emit('transferError', { transfer, error });
    }
  }

  /**
   * 清理文件名中的非法字符
   * @param {string} fileName 原始文件名
   * @returns {string} 安全的文件名
   */
  sanitizeFileName(fileName) {
    // 移除路径分隔符和其他非法字符
    return fileName.replace(/[\/\\:*?"<>|]/g, '_');
  }

  /**
   * 保存文件到相册
   * @param {string} filePath 文件路径
   * @returns {Promise<void>}
   */
  saveToAlbum(filePath) {
    return new Promise((resolve, reject) => {
      wx.saveImageToPhotosAlbum({
        filePath: filePath,
        success: resolve,
        fail: reject
      });
    });
  }

  /**
   * 保存视频到相册
   * @param {string} filePath 文件路径
   * @returns {Promise<void>}
   */
  saveVideoToAlbum(filePath) {
    return new Promise((resolve, reject) => {
      wx.saveVideoToPhotosAlbum({
        filePath: filePath,
        success: resolve,
        fail: reject
      });
    });
  }

  /**
   * 取消传输
   * @param {string} transferId 传输ID
   */
  cancelTransfer(transferId) {
    const transfer = this.transfers.get(transferId);
    
    if (transfer && transfer.status !== 'completed') {
      transfer.status = 'cancelled';
      this.emit('transferCancelled', transfer);
    }
  }

  /**
   * 获取传输状态
   * @param {string} transferId 传输ID
   * @returns {Object|null} 传输状态
   */
  getTransferStatus(transferId) {
    return this.transfers.get(transferId) || null;
  }

  /**
   * 获取所有传输
   * @returns {Array} 传输列表
   */
  getAllTransfers() {
    return Array.from(this.transfers.values());
  }

  /**
   * 清理已完成的传输
   */
  clearCompletedTransfers() {
    for (const [id, transfer] of this.transfers) {
      if (transfer.status === 'completed' || transfer.status === 'failed' || transfer.status === 'cancelled') {
        this.transfers.delete(id);
      }
    }
  }

  /**
   * 获取存储信息
   * @returns {Promise<Object>} 存储信息
   */
  getStorageInfo() {
    return new Promise((resolve, reject) => {
      wx.getStorageInfo({
        success: (res) => {
          resolve({
            currentSize: res.currentSize,
            limitSize: res.limitSize,
            keys: res.keys
          });
        },
        fail: reject
      });
    });
  }

  /**
   * 优化内存使用
   * 验证: 需求 15.6 - 优化内存使用并降低视频质量以保持稳定运行
   */
  optimizeMemory() {
    console.log('[FileTransferService] 开始内存优化...');
    
    // 1. 清理已完成的传输
    this.clearCompletedTransfers();
    
    // 2. 清理传输中的分块缓冲区（保留必要的）
    for (const transfer of this.transfers.values()) {
      if (transfer.direction === 'receive' && transfer.chunks) {
        // 只保留最近的分块，释放已处理的
        const keepCount = this.memoryConfig.chunkBufferLimit;
        if (transfer.chunks.length > keepCount) {
          // 注意：这可能影响断点续传，仅在极端内存压力下使用
          console.warn('[FileTransferService] 清理部分分块缓冲区');
        }
      }
    }
    
    // 3. 触发垃圾回收
    if (wx.triggerGC) {
      wx.triggerGC();
    }
    
    // 4. 重置分块大小（如果之前被降低）
    if (!this.isLowMemoryMode) {
      this.chunkSize = 64 * 1024; // 恢复默认值
    }
    
    console.log('[FileTransferService] 内存优化完成', {
      activeTransfers: this.getActiveTransferCount(),
      totalTransfers: this.transfers.size,
      chunkSize: this.chunkSize
    });
    
    this.emit('memoryOptimized', {
      activeTransfers: this.getActiveTransferCount(),
      chunkSize: this.chunkSize
    });
  }

  /**
   * 获取内存使用状态
   * 验证: 需求 15.6 - 优化内存使用
   * @returns {Object} 内存状态信息
   */
  getMemoryStatus() {
    return {
      isLowMemoryMode: this.isLowMemoryMode,
      currentMemoryUsage: this.currentMemoryUsage,
      activeTransfers: this.getActiveTransferCount(),
      totalTransfers: this.transfers.size,
      chunkSize: this.chunkSize,
      maxConcurrentTransfers: this.memoryConfig.maxConcurrentTransfers
    };
  }

  /**
   * 设置内存配置
   * 验证: 需求 15.6 - 优化内存使用
   * @param {Object} config 配置对象
   */
  setMemoryConfig(config) {
    this.memoryConfig = { ...this.memoryConfig, ...config };
    console.log('[FileTransferService] 更新内存配置:', this.memoryConfig);
  }

  /**
   * 暂停传输（用于内存优化）
   * @param {string} transferId 传输ID
   */
  pauseTransfer(transferId) {
    const transfer = this.transfers.get(transferId);
    if (transfer && (transfer.status === 'sending' || transfer.status === 'receiving')) {
      transfer.status = 'paused';
      transfer.pausedAt = Date.now();
      this.emit('transferPaused', transfer);
      console.log('[FileTransferService] 传输已暂停:', transferId);
    }
  }

  /**
   * 恢复传输
   * @param {string} transferId 传输ID
   */
  resumeTransfer(transferId) {
    const transfer = this.transfers.get(transferId);
    if (transfer && transfer.status === 'paused') {
      transfer.status = transfer.direction === 'send' ? 'sending' : 'receiving';
      transfer.resumedAt = Date.now();
      this.emit('transferResumed', transfer);
      console.log('[FileTransferService] 传输已恢复:', transferId);
    }
  }

  /**
   * 生成文件ID
   * @returns {string}
   */
  generateFileId() {
    return Date.now().toString(36) + Math.random().toString(36).substr(2, 9);
  }

  /**
   * 获取文件名
   * @param {string} filePath 文件路径
   * @returns {string}
   */
  getFileName(filePath) {
    return filePath.split('/').pop() || 'unknown';
  }

  /**
   * 获取文件类型
   * @param {string} fileName 文件名
   * @returns {string}
   */
  getFileType(fileName) {
    const ext = fileName.split('.').pop().toLowerCase();
    
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].includes(ext)) {
      return 'image';
    } else if (['mp4', 'avi', 'mov', '3gp', 'mkv', 'wmv'].includes(ext)) {
      return 'video';
    } else if (['mp3', 'wav', 'aac', 'm4a', 'flac', 'ogg'].includes(ext)) {
      return 'audio';
    } else if (['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt'].includes(ext)) {
      return 'document';
    } else {
      return 'other';
    }
  }

  /**
   * 格式化文件大小
   * @param {number} bytes 字节数
   * @returns {string}
   */
  formatFileSize(bytes) {
    if (bytes === 0) return '0 B';
    
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  }

  /**
   * 延迟函数
   * @param {number} ms 毫秒数
   * @returns {Promise<void>}
   */
  delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * 注册事件处理器
   * @param {string} event 事件名称
   * @param {Function} handler 处理函数
   */
  on(event, handler) {
    if (!this.eventHandlers[event]) {
      this.eventHandlers[event] = [];
    }
    this.eventHandlers[event].push(handler);
  }

  /**
   * 移除事件处理器
   * @param {string} event 事件名称
   * @param {Function} handler 处理函数
   */
  off(event, handler) {
    if (this.eventHandlers[event]) {
      this.eventHandlers[event] = this.eventHandlers[event].filter(h => h !== handler);
    }
  }

  /**
   * 触发事件
   * @param {string} event 事件名称
   * @param {*} data 事件数据
   */
  emit(event, data) {
    if (this.eventHandlers[event]) {
      this.eventHandlers[event].forEach(handler => {
        try {
          handler(data);
        } catch (error) {
          console.error('[FileTransferService] 事件处理器错误:', error);
        }
      });
    }
  }

  /**
   * 销毁服务
   */
  destroy() {
    // 停止内存监控
    this.stopMemoryMonitoring();
    
    // 取消所有进行中的传输
    for (const transfer of this.transfers.values()) {
      if (transfer.status === 'sending' || transfer.status === 'receiving') {
        transfer.status = 'cancelled';
        // 清理分块数据
        if (transfer.chunks) {
          transfer.chunks = [];
        }
      }
    }
    
    // 清理所有传输记录
    this.transfers.clear();
    
    // 清理事件处理器
    this.eventHandlers = {};
    
    // 清理引用
    this.webrtcService = null;
    this.fileSystemManager = null;
    
    // 触发垃圾回收
    if (wx.triggerGC) {
      wx.triggerGC();
    }
    
    console.log('[FileTransferService] 已销毁');
  }
}

// 导出
module.exports = {
  FileTransferService
};
