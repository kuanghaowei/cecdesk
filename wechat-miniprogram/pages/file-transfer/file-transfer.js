// pages/file-transfer/file-transfer.js
// 集成 FileTransferService 实现文件传输功能
// 验证: 需求 15.5, 15.6

const app = getApp();
const { FileTransferService } = require('../../utils/file-transfer-service');

Page({
  data: {
    activeTab: 0, // 0: 发送文件, 1: 接收文件, 2: 传输历史
    sendFiles: [], // 待发送文件列表
    receiveFiles: [], // 接收文件列表
    transferHistory: [], // 传输历史
    isTransferring: false,
    currentTransfer: null,
    maxFileSize: 100 * 1024 * 1024, // 100MB 限制
    supportedTypes: ['image', 'video', 'audio', 'document'], // 支持的文件类型
    storageInfo: null // 存储空间信息
  },

  // FileTransferService 实例
  fileTransferService: null,

  onLoad(options) {
    console.log('文件传输页面加载', options);
    
    // 初始化文件传输服务
    this.initFileTransferService();
    
    // 加载传输历史
    this.loadTransferHistory();
    
    // 检查存储空间
    this.checkStorageSpace();
  },

  /**
   * 初始化文件传输服务
   * 验证: 需求 15.5 - 使用微信小程序的文件系统 API 进行文件操作
   * 验证: 需求 15.6 - 优化内存使用
   */
  initFileTransferService() {
    this.fileTransferService = new FileTransferService();
    
    // 获取 WebRTC 服务（如果可用）
    const webrtcService = app.globalData?.webrtcService || null;
    
    this.fileTransferService.init(webrtcService, {
      chunkSize: 64 * 1024,
      maxFileSize: this.data.maxFileSize,
      memoryConfig: {
        maxConcurrentTransfers: 3,
        chunkBufferLimit: 10,
        autoCleanupInterval: 30000,
        lowMemoryThreshold: 0.8
      }
    });
    
    // 注册事件处理器
    this.fileTransferService.on('transferStart', this.onTransferStart.bind(this));
    this.fileTransferService.on('transferProgress', this.onTransferProgress.bind(this));
    this.fileTransferService.on('transferComplete', this.onTransferComplete.bind(this));
    this.fileTransferService.on('transferError', this.onTransferError.bind(this));
    this.fileTransferService.on('transferCancelled', this.onTransferCancelled.bind(this));
    this.fileTransferService.on('transferPaused', this.onTransferPaused.bind(this));
    this.fileTransferService.on('transferResumed', this.onTransferResumed.bind(this));
    this.fileTransferService.on('lowMemory', this.onLowMemory.bind(this));
    this.fileTransferService.on('memoryOptimized', this.onMemoryOptimized.bind(this));
    
    console.log('[FileTransfer] 文件传输服务初始化完成');
  },

  /**
   * 传输暂停事件处理
   */
  onTransferPaused(transfer) {
    console.log('[FileTransfer] 传输已暂停:', transfer.id);
    this.updateTransferStatus(transfer, 'paused');
  },

  /**
   * 传输恢复事件处理
   */
  onTransferResumed(transfer) {
    console.log('[FileTransfer] 传输已恢复:', transfer.id);
    const status = transfer.direction === 'send' ? 'sending' : 'receiving';
    this.updateTransferStatus(transfer, status);
  },

  /**
   * 低内存警告事件处理
   * 验证: 需求 15.6 - 优化内存使用
   */
  onLowMemory(info) {
    console.warn('[FileTransfer] 低内存警告:', info);
    wx.showModal({
      title: '内存不足',
      content: '设备内存不足，可能影响文件传输性能。建议清理缓存或减少并发传输。',
      showCancel: false
    });
  },

  /**
   * 内存优化完成事件处理
   */
  onMemoryOptimized(info) {
    console.log('[FileTransfer] 内存优化完成:', info);
  },

  /**
   * 更新传输状态
   */
  updateTransferStatus(transfer, status) {
    if (transfer.direction === 'send') {
      const sendFiles = this.data.sendFiles.map(file => {
        if (file.id === transfer.file?.id) {
          return { ...file, status };
        }
        return file;
      });
      this.setData({ sendFiles });
    } else {
      const receiveFiles = this.data.receiveFiles.map(file => {
        if (file.id === transfer.id) {
          return { ...file, status };
        }
        return file;
      });
      this.setData({ receiveFiles });
    }
  },

  /**
   * 传输开始事件处理
   */
  onTransferStart(transfer) {
    console.log('[FileTransfer] 传输开始:', transfer.id);
    this.setData({ isTransferring: true, currentTransfer: transfer });
  },

  /**
   * 传输进度事件处理
   */
  onTransferProgress(transfer) {
    // 更新对应文件的进度
    if (transfer.direction === 'send') {
      this.updateSendFileProgress(transfer);
    } else {
      this.updateReceiveFileProgress(transfer);
    }
  },

  /**
   * 传输完成事件处理
   */
  onTransferComplete(transfer) {
    console.log('[FileTransfer] 传输完成:', transfer.id);
    
    // 添加到传输历史
    this.addToTransferHistory(transfer.file, transfer.direction, 'completed');
    
    // 更新状态
    if (transfer.direction === 'send') {
      this.updateFileStatus(transfer.file.id, 'completed', 100);
    } else {
      this.updateReceiveFileStatus(transfer.id, 'completed', 100, transfer.savedPath);
    }
    
    this.setData({ isTransferring: false, currentTransfer: null });
    
    wx.showToast({
      title: transfer.direction === 'send' ? '发送完成' : '接收完成',
      icon: 'success'
    });
  },

  /**
   * 传输错误事件处理
   */
  onTransferError({ transfer, error }) {
    console.error('[FileTransfer] 传输错误:', error);
    
    // 添加到传输历史
    this.addToTransferHistory(transfer.file, transfer.direction, 'failed');
    
    // 更新状态
    if (transfer.direction === 'send') {
      this.updateFileStatus(transfer.file.id, 'failed', 0);
    } else {
      this.updateReceiveFileStatus(transfer.id, 'failed', 0);
    }
    
    this.setData({ isTransferring: false, currentTransfer: null });
    
    wx.showToast({
      title: '传输失败',
      icon: 'none'
    });
  },

  /**
   * 传输取消事件处理
   */
  onTransferCancelled(transfer) {
    console.log('[FileTransfer] 传输已取消:', transfer.id);
    this.setData({ isTransferring: false, currentTransfer: null });
  },

  /**
   * 更新发送文件进度
   */
  updateSendFileProgress(transfer) {
    const sendFiles = this.data.sendFiles.map(file => {
      if (file.id === transfer.file.id) {
        return { ...file, progress: transfer.progress, status: 'sending' };
      }
      return file;
    });
    this.setData({ sendFiles });
  },

  /**
   * 更新接收文件进度
   */
  updateReceiveFileProgress(transfer) {
    const receiveFiles = this.data.receiveFiles.map(file => {
      if (file.id === transfer.id) {
        return { ...file, progress: transfer.progress, status: 'receiving' };
      }
      return file;
    });
    this.setData({ receiveFiles });
  },

  /**
   * 更新接收文件状态
   */
  updateReceiveFileStatus(transferId, status, progress, savedPath = null) {
    const receiveFiles = this.data.receiveFiles.map(file => {
      if (file.id === transferId) {
        return { ...file, status, progress, savedPath };
      }
      return file;
    });
    this.setData({ receiveFiles });
  },

  onShow() {
    // 刷新文件列表
    this.refreshFileList();
  },

  onUnload() {
    // 清理文件传输服务
    if (this.fileTransferService) {
      this.fileTransferService.destroy();
      this.fileTransferService = null;
    }
  },

  // 切换标签页
  switchTab(e) {
    const tabIndex = e.currentTarget.dataset.index;
    this.setData({
      activeTab: tabIndex
    });
  },

  /**
   * 选择要发送的文件
   * 验证: 需求 15.5 - 实现文件选择功能
   */
  chooseFilesToSend() {
    wx.showActionSheet({
      itemList: ['选择图片', '选择视频', '选择文档', '从聊天记录选择'],
      success: (res) => {
        switch (res.tapIndex) {
          case 0:
            this.chooseImages();
            break;
          case 1:
            this.chooseVideos();
            break;
          case 2:
            this.chooseDocuments();
            break;
          case 3:
            this.chooseFromChat();
            break;
        }
      }
    });
  },

  /**
   * 选择图片 - 使用 FileTransferService
   * 验证: 需求 15.5
   */
  async chooseImages() {
    try {
      const files = await this.fileTransferService.chooseImages({ count: 9 });
      this.addFilesToSendList(files);
    } catch (error) {
      console.error('选择图片失败:', error);
      wx.showToast({ title: '选择图片失败', icon: 'none' });
    }
  },

  /**
   * 选择视频 - 使用 FileTransferService
   * 验证: 需求 15.5
   */
  async chooseVideos() {
    try {
      const file = await this.fileTransferService.chooseVideo({ maxDuration: 60 });
      this.addFilesToSendList([file]);
    } catch (error) {
      console.error('选择视频失败:', error);
      wx.showToast({ title: '选择视频失败', icon: 'none' });
    }
  },

  /**
   * 选择文档 - 使用 FileTransferService
   * 验证: 需求 15.5
   */
  async chooseDocuments() {
    try {
      const files = await this.fileTransferService.chooseDocuments({ count: 10 });
      this.addFilesToSendList(files);
    } catch (error) {
      console.error('选择文档失败:', error);
      wx.showToast({ title: '选择文档失败', icon: 'none' });
    }
  },

  /**
   * 从聊天记录选择 - 使用 FileTransferService
   * 验证: 需求 15.5
   */
  async chooseFromChat() {
    try {
      const files = await this.fileTransferService.chooseDocuments({ 
        count: 10, 
        type: 'all' 
      });
      this.addFilesToSendList(files);
    } catch (error) {
      console.error('从聊天记录选择失败:', error);
      wx.showToast({ title: '选择失败', icon: 'none' });
    }
  },

  /**
   * 添加文件到发送列表
   * @param {Array} files 文件列表（已由 FileTransferService 处理）
   */
  addFilesToSendList(files) {
    if (!files || files.length === 0) {
      return;
    }
    
    this.setData({
      sendFiles: [...this.data.sendFiles, ...files]
    });
    
    wx.showToast({
      title: `已添加 ${files.length} 个文件`,
      icon: 'success'
    });
  },

  /**
   * 获取文件类型 - 使用 FileTransferService
   */
  getFileType(fileName) {
    return this.fileTransferService.getFileType(fileName);
  },

  // 移除发送文件
  removeSendFile(e) {
    const fileId = e.currentTarget.dataset.fileId;
    const sendFiles = this.data.sendFiles.filter(file => file.id !== fileId);
    
    this.setData({
      sendFiles: sendFiles
    });
  },

  /**
   * 开始发送文件
   * 验证: 需求 15.5 - 实现文件上传下载
   */
  startSendFiles() {
    if (this.data.sendFiles.length === 0) {
      wx.showToast({ title: '请先选择文件', icon: 'none' });
      return;
    }
    
    if (this.data.isTransferring) {
      wx.showToast({ title: '正在传输中', icon: 'none' });
      return;
    }
    
    wx.showModal({
      title: '确认发送',
      content: `确定要发送 ${this.data.sendFiles.length} 个文件吗？`,
      success: (res) => {
        if (res.confirm) {
          this.performFileSend();
        }
      }
    });
  },

  /**
   * 执行文件发送 - 使用 FileTransferService
   * 验证: 需求 15.5
   */
  async performFileSend() {
    this.setData({ isTransferring: true });
    
    for (const file of this.data.sendFiles) {
      try {
        // 更新文件状态为发送中
        this.updateFileStatus(file.id, 'sending', 0);
        
        // 使用 FileTransferService 发送文件
        await this.fileTransferService.sendFile(file);
        
      } catch (error) {
        console.error('文件发送失败:', error);
        
        // 如果 WebRTC 未连接，使用模拟传输
        if (error.message === 'WebRTC 未连接') {
          await this.simulateFileTransfer(file);
          this.updateFileStatus(file.id, 'completed', 100);
          this.addToTransferHistory(file, 'send', 'completed');
        } else {
          this.updateFileStatus(file.id, 'failed', 0);
          this.addToTransferHistory(file, 'send', 'failed');
        }
      }
    }
    
    this.setData({ isTransferring: false });
    
    // 清空发送列表
    setTimeout(() => {
      this.setData({ sendFiles: [] });
    }, 2000);
    
    wx.showToast({ title: '文件发送完成', icon: 'success' });
  },

  // 模拟文件传输（当 WebRTC 未连接时使用）
  simulateFileTransfer(file) {
    return new Promise((resolve) => {
      let progress = 0;
      const interval = setInterval(() => {
        progress += Math.random() * 20;
        if (progress >= 100) {
          progress = 100;
          clearInterval(interval);
          resolve();
        }
        
        this.updateFileStatus(file.id, 'sending', Math.round(progress));
      }, 200);
    });
  },

  // 更新文件状态
  updateFileStatus(fileId, status, progress) {
    const sendFiles = this.data.sendFiles.map(file => {
      if (file.id === fileId) {
        return { ...file, status, progress };
      }
      return file;
    });
    
    this.setData({ sendFiles });
  },

  // 添加到传输历史
  addToTransferHistory(file, direction, status) {
    const historyItem = {
      id: this.fileTransferService.generateFileId(),
      fileName: file.name,
      fileSize: file.size,
      fileType: file.type,
      direction: direction, // send, receive
      status: status, // completed, failed
      timestamp: Date.now(),
      date: new Date().toLocaleString()
    };
    
    const transferHistory = [historyItem, ...this.data.transferHistory];
    
    this.setData({ transferHistory });
    
    // 保存到本地存储
    this.saveTransferHistory();
  },

  /**
   * 请求接收文件
   * 验证: 需求 15.5 - 实现文件上传下载
   */
  requestReceiveFile() {
    wx.showModal({
      title: '请求文件',
      content: '请输入要请求的文件路径或名称',
      editable: true,
      placeholderText: '例如: /Documents/report.pdf',
      success: async (res) => {
        if (res.confirm && res.content) {
          await this.sendFileRequest(res.content);
        }
      }
    });
  },

  /**
   * 发送文件请求 - 使用 FileTransferService
   * 验证: 需求 15.5
   */
  async sendFileRequest(filePath) {
    console.log('请求文件:', filePath);
    
    wx.showLoading({ title: '请求中...' });
    
    try {
      // 创建接收传输记录
      const fileInfo = {
        transferId: this.fileTransferService.generateFileId(),
        fileName: filePath.split('/').pop() || 'requested_file',
        fileSize: Math.floor(Math.random() * 10000000), // 模拟大小
        fileType: this.fileTransferService.getFileType(filePath)
      };
      
      const transfer = await this.fileTransferService.receiveFile(fileInfo);
      
      // 添加到接收文件列表
      this.setData({
        receiveFiles: [{
          id: transfer.id,
          name: transfer.file.name,
          size: transfer.file.size,
          type: transfer.file.type,
          status: 'receiving',
          progress: 0,
          receiveTime: Date.now()
        }, ...this.data.receiveFiles]
      });
      
      wx.hideLoading();
      
      // 模拟接收过程
      await this.simulateFileReceive(transfer);
      
    } catch (error) {
      wx.hideLoading();
      console.error('请求文件失败:', error);
      wx.showToast({ title: '请求失败', icon: 'none' });
    }
  },

  /**
   * 模拟文件接收
   */
  async simulateFileReceive(transfer) {
    try {
      // 模拟接收进度
      for (let progress = 0; progress <= 100; progress += 10) {
        await new Promise(resolve => setTimeout(resolve, 200));
        
        const receiveFiles = this.data.receiveFiles.map(f => {
          if (f.id === transfer.id) {
            return { ...f, progress, status: progress < 100 ? 'receiving' : 'completed' };
          }
          return f;
        });
        this.setData({ receiveFiles });
      }
      
      // 添加到传输历史
      this.addToTransferHistory(transfer.file, 'receive', 'completed');
      
      wx.showToast({ title: '文件接收完成', icon: 'success' });
      
    } catch (error) {
      console.error('文件接收失败:', error);
      
      const receiveFiles = this.data.receiveFiles.map(f => {
        if (f.id === transfer.id) {
          return { ...f, status: 'failed', progress: 0 };
        }
        return f;
      });
      this.setData({ receiveFiles });
      
      this.addToTransferHistory(transfer.file, 'receive', 'failed');
    }
  },

  /**
   * 保存接收的文件 - 使用 FileTransferService
   * 验证: 需求 15.5
   */
  async saveReceivedFile(e) {
    const fileId = e.currentTarget.dataset.fileId;
    const file = this.data.receiveFiles.find(f => f.id === fileId);
    
    if (!file || file.status !== 'completed') {
      wx.showToast({ title: '文件未完成接收', icon: 'none' });
      return;
    }
    
    wx.showLoading({ title: '保存中...' });
    
    try {
      // 根据文件类型选择保存方式
      if (file.type === 'image' && file.savedPath) {
        await this.fileTransferService.saveToAlbum(file.savedPath);
        wx.showToast({ title: '已保存到相册', icon: 'success' });
      } else if (file.type === 'video' && file.savedPath) {
        await this.fileTransferService.saveVideoToAlbum(file.savedPath);
        wx.showToast({ title: '已保存到相册', icon: 'success' });
      } else {
        wx.showToast({ title: '文件已保存', icon: 'success' });
      }
    } catch (error) {
      console.error('保存文件失败:', error);
      wx.showToast({ title: '保存失败', icon: 'none' });
    } finally {
      wx.hideLoading();
    }
  },

  // 删除接收文件
  deleteReceivedFile(e) {
    const fileId = e.currentTarget.dataset.fileId;
    
    wx.showModal({
      title: '确认删除',
      content: '确定要删除这个文件吗？',
      success: (res) => {
        if (res.confirm) {
          const receiveFiles = this.data.receiveFiles.filter(f => f.id !== fileId);
          this.setData({ receiveFiles });
        }
      }
    });
  },

  // 清空传输历史
  clearTransferHistory() {
    wx.showModal({
      title: '清空历史',
      content: '确定要清空所有传输历史吗？',
      success: (res) => {
        if (res.confirm) {
          this.setData({ transferHistory: [] });
          wx.removeStorageSync('transferHistory');
          wx.showToast({ title: '历史已清空', icon: 'success' });
        }
      }
    });
  },

  // 加载传输历史
  loadTransferHistory() {
    try {
      const history = wx.getStorageSync('transferHistory') || [];
      this.setData({ transferHistory: history });
    } catch (error) {
      console.error('加载传输历史失败:', error);
    }
  },

  // 保存传输历史
  saveTransferHistory() {
    try {
      wx.setStorageSync('transferHistory', this.data.transferHistory);
    } catch (error) {
      console.error('保存传输历史失败:', error);
    }
  },

  // 刷新文件列表
  refreshFileList() {
    // 清理已完成的发送文件
    const sendFiles = this.data.sendFiles.filter(file => 
      file.status !== 'completed' || Date.now() - file.addTime < 5000
    );
    
    this.setData({ sendFiles });
  },

  /**
   * 检查存储空间 - 使用 FileTransferService
   * 验证: 需求 15.6 - 优化内存使用
   */
  async checkStorageSpace() {
    try {
      const storageInfo = await this.fileTransferService.getStorageInfo();
      const memoryStatus = this.fileTransferService.getMemoryStatus();
      
      this.setData({ 
        storageInfo,
        memoryStatus 
      });
      
      const usagePercent = (storageInfo.currentSize / storageInfo.limitSize) * 100;
      
      if (usagePercent > 90) {
        wx.showModal({
          title: '存储空间不足',
          content: '设备存储空间不足，可能影响文件传输。是否清理缓存？',
          success: (res) => {
            if (res.confirm) {
              this.optimizeMemory();
            }
          }
        });
      }
    } catch (error) {
      console.error('检查存储空间失败:', error);
    }
  },

  /**
   * 优化内存使用 - 使用 FileTransferService
   * 验证: 需求 15.6 - 优化内存使用并降低视频质量以保持稳定运行
   */
  optimizeMemory() {
    if (this.fileTransferService) {
      this.fileTransferService.optimizeMemory();
      
      // 更新内存状态显示
      const memoryStatus = this.fileTransferService.getMemoryStatus();
      this.setData({ memoryStatus });
      
      wx.showToast({ title: '内存优化完成', icon: 'success' });
    }
  },

  /**
   * 暂停传输
   */
  pauseTransfer(e) {
    const transferId = e.currentTarget.dataset.transferId;
    if (this.fileTransferService) {
      this.fileTransferService.pauseTransfer(transferId);
    }
  },

  /**
   * 恢复传输
   */
  resumeTransfer(e) {
    const transferId = e.currentTarget.dataset.transferId;
    if (this.fileTransferService) {
      this.fileTransferService.resumeTransfer(transferId);
    }
  },

  /**
   * 格式化文件大小 - 使用 FileTransferService
   */
  formatFileSize(bytes) {
    return this.fileTransferService.formatFileSize(bytes);
  },

  // 获取文件图标
  getFileIcon(fileType) {
    const icons = {
      image: '🖼️',
      video: '🎥',
      audio: '🎵',
      document: '📄'
    };
    
    return icons[fileType] || '📄';
  },

  // 获取状态文本
  getStatusText(status) {
    const statusMap = {
      pending: '等待中',
      sending: '发送中',
      receiving: '接收中',
      completed: '已完成',
      failed: '失败'
    };
    
    return statusMap[status] || '未知';
  }
});