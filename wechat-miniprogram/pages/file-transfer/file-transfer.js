// pages/file-transfer/file-transfer.js
const app = getApp();

Page({
  data: {
    activeTab: 0, // 0: 发送文件, 1: 接收文件, 2: 传输历史
    sendFiles: [], // 待发送文件列表
    receiveFiles: [], // 接收文件列表
    transferHistory: [], // 传输历史
    isTransferring: false,
    currentTransfer: null,
    maxFileSize: 100 * 1024 * 1024, // 100MB 限制
    supportedTypes: ['image', 'video', 'audio', 'document'] // 支持的文件类型
  },

  onLoad(options) {
    console.log('文件传输页面加载', options);
    
    // 加载传输历史
    this.loadTransferHistory();
    
    // 检查存储空间
    this.checkStorageSpace();
  },

  onShow() {
    // 刷新文件列表
    this.refreshFileList();
  },

  // 切换标签页
  switchTab(e) {
    const tabIndex = e.currentTarget.dataset.index;
    this.setData({
      activeTab: tabIndex
    });
  },

  // 选择要发送的文件
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

  // 选择图片
  chooseImages() {
    wx.chooseImage({
      count: 9,
      sizeType: ['original', 'compressed'],
      sourceType: ['album', 'camera'],
      success: (res) => {
        this.addFilesToSendList(res.tempFilePaths, 'image');
      },
      fail: (error) => {
        console.error('选择图片失败:', error);
        wx.showToast({
          title: '选择图片失败',
          icon: 'none'
        });
      }
    });
  },

  // 选择视频
  chooseVideos() {
    wx.chooseVideo({
      sourceType: ['album', 'camera'],
      maxDuration: 60,
      camera: 'back',
      success: (res) => {
        this.addFilesToSendList([res.tempFilePath], 'video');
      },
      fail: (error) => {
        console.error('选择视频失败:', error);
        wx.showToast({
          title: '选择视频失败',
          icon: 'none'
        });
      }
    });
  },

  // 选择文档
  chooseDocuments() {
    wx.chooseMessageFile({
      count: 10,
      type: 'file',
      success: (res) => {
        const filePaths = res.tempFiles.map(file => file.path);
        this.addFilesToSendList(filePaths, 'document');
      },
      fail: (error) => {
        console.error('选择文档失败:', error);
        wx.showToast({
          title: '选择文档失败',
          icon: 'none'
        });
      }
    });
  },

  // 从聊天记录选择
  chooseFromChat() {
    wx.chooseMessageFile({
      count: 10,
      type: 'all',
      success: (res) => {
        const files = res.tempFiles.map(file => ({
          path: file.path,
          name: file.name,
          size: file.size,
          type: this.getFileType(file.name)
        }));
        
        this.addFilesToSendList(files.map(f => f.path), 'mixed');
      },
      fail: (error) => {
        console.error('从聊天记录选择失败:', error);
        wx.showToast({
          title: '选择失败',
          icon: 'none'
        });
      }
    });
  },

  // 添加文件到发送列表
  async addFilesToSendList(filePaths, type) {
    const newFiles = [];
    
    for (const filePath of filePaths) {
      try {
        const fileInfo = await this.getFileInfo(filePath);
        
        // 检查文件大小
        if (fileInfo.size > this.data.maxFileSize) {
          wx.showToast({
            title: `文件 ${fileInfo.name} 超过100MB限制`,
            icon: 'none'
          });
          continue;
        }
        
        const fileItem = {
          id: this.generateFileId(),
          path: filePath,
          name: fileInfo.name,
          size: fileInfo.size,
          type: type,
          status: 'pending', // pending, sending, completed, failed
          progress: 0,
          addTime: Date.now()
        };
        
        newFiles.push(fileItem);
      } catch (error) {
        console.error('获取文件信息失败:', error);
      }
    }
    
    if (newFiles.length > 0) {
      this.setData({
        sendFiles: [...this.data.sendFiles, ...newFiles]
      });
      
      wx.showToast({
        title: `已添加 ${newFiles.length} 个文件`,
        icon: 'success'
      });
    }
  },

  // 获取文件信息
  getFileInfo(filePath) {
    return new Promise((resolve, reject) => {
      wx.getFileInfo({
        filePath: filePath,
        success: (res) => {
          const fileName = filePath.split('/').pop() || 'unknown';
          resolve({
            name: fileName,
            size: res.size,
            path: filePath
          });
        },
        fail: reject
      });
    });
  },

  // 生成文件ID
  generateFileId() {
    return Date.now().toString(36) + Math.random().toString(36).substr(2, 9);
  },

  // 获取文件类型
  getFileType(fileName) {
    const ext = fileName.split('.').pop().toLowerCase();
    
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].includes(ext)) {
      return 'image';
    } else if (['mp4', 'avi', 'mov', '3gp'].includes(ext)) {
      return 'video';
    } else if (['mp3', 'wav', 'aac', 'm4a'].includes(ext)) {
      return 'audio';
    } else {
      return 'document';
    }
  },

  // 移除发送文件
  removeSendFile(e) {
    const fileId = e.currentTarget.dataset.fileId;
    const sendFiles = this.data.sendFiles.filter(file => file.id !== fileId);
    
    this.setData({
      sendFiles: sendFiles
    });
  },

  // 开始发送文件
  startSendFiles() {
    if (this.data.sendFiles.length === 0) {
      wx.showToast({
        title: '请先选择文件',
        icon: 'none'
      });
      return;
    }
    
    if (this.data.isTransferring) {
      wx.showToast({
        title: '正在传输中',
        icon: 'none'
      });
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

  // 执行文件发送
  async performFileSend() {
    this.setData({
      isTransferring: true
    });
    
    for (let i = 0; i < this.data.sendFiles.length; i++) {
      const file = this.data.sendFiles[i];
      
      try {
        // 更新文件状态为发送中
        this.updateFileStatus(file.id, 'sending', 0);
        
        // 模拟文件发送过程
        await this.simulateFileTransfer(file);
        
        // 更新文件状态为完成
        this.updateFileStatus(file.id, 'completed', 100);
        
        // 添加到传输历史
        this.addToTransferHistory(file, 'send', 'completed');
        
      } catch (error) {
        console.error('文件发送失败:', error);
        
        // 更新文件状态为失败
        this.updateFileStatus(file.id, 'failed', 0);
        
        // 添加到传输历史
        this.addToTransferHistory(file, 'send', 'failed');
      }
    }
    
    this.setData({
      isTransferring: false
    });
    
    // 清空发送列表
    setTimeout(() => {
      this.setData({
        sendFiles: []
      });
    }, 2000);
    
    wx.showToast({
      title: '文件发送完成',
      icon: 'success'
    });
  },

  // 模拟文件传输
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
        return {
          ...file,
          status: status,
          progress: progress
        };
      }
      return file;
    });
    
    this.setData({
      sendFiles: sendFiles
    });
  },

  // 添加到传输历史
  addToTransferHistory(file, direction, status) {
    const historyItem = {
      id: this.generateFileId(),
      fileName: file.name,
      fileSize: file.size,
      fileType: file.type,
      direction: direction, // send, receive
      status: status, // completed, failed
      timestamp: Date.now(),
      date: new Date().toLocaleString()
    };
    
    const transferHistory = [historyItem, ...this.data.transferHistory];
    
    this.setData({
      transferHistory: transferHistory
    });
    
    // 保存到本地存储
    this.saveTransferHistory();
  },

  // 请求接收文件
  requestReceiveFile() {
    wx.showModal({
      title: '请求文件',
      content: '请输入要请求的文件路径或名称',
      editable: true,
      placeholderText: '例如: /Documents/report.pdf',
      success: (res) => {
        if (res.confirm && res.content) {
          this.sendFileRequest(res.content);
        }
      }
    });
  },

  // 发送文件请求
  sendFileRequest(filePath) {
    console.log('请求文件:', filePath);
    
    // 模拟文件请求
    wx.showLoading({
      title: '请求中...'
    });
    
    setTimeout(() => {
      wx.hideLoading();
      
      // 模拟收到文件
      const mockFile = {
        id: this.generateFileId(),
        name: filePath.split('/').pop() || 'requested_file',
        size: Math.floor(Math.random() * 10000000), // 随机大小
        type: this.getFileType(filePath),
        status: 'receiving',
        progress: 0,
        receiveTime: Date.now()
      };
      
      this.setData({
        receiveFiles: [mockFile, ...this.data.receiveFiles]
      });
      
      // 模拟接收过程
      this.simulateFileReceive(mockFile);
      
    }, 1500);
  },

  // 模拟文件接收
  async simulateFileReceive(file) {
    try {
      await this.simulateFileTransfer(file);
      
      // 更新接收文件状态
      const receiveFiles = this.data.receiveFiles.map(f => {
        if (f.id === file.id) {
          return { ...f, status: 'completed', progress: 100 };
        }
        return f;
      });
      
      this.setData({
        receiveFiles: receiveFiles
      });
      
      // 添加到传输历史
      this.addToTransferHistory(file, 'receive', 'completed');
      
      wx.showToast({
        title: '文件接收完成',
        icon: 'success'
      });
      
    } catch (error) {
      console.error('文件接收失败:', error);
      
      // 更新为失败状态
      const receiveFiles = this.data.receiveFiles.map(f => {
        if (f.id === file.id) {
          return { ...f, status: 'failed', progress: 0 };
        }
        return f;
      });
      
      this.setData({
        receiveFiles: receiveFiles
      });
      
      this.addToTransferHistory(file, 'receive', 'failed');
    }
  },

  // 保存接收的文件
  saveReceivedFile(e) {
    const fileId = e.currentTarget.dataset.fileId;
    const file = this.data.receiveFiles.find(f => f.id === fileId);
    
    if (!file || file.status !== 'completed') {
      wx.showToast({
        title: '文件未完成接收',
        icon: 'none'
      });
      return;
    }
    
    // 根据文件类型选择保存方式
    if (file.type === 'image') {
      this.saveImageToAlbum(file);
    } else {
      this.saveFileToLocal(file);
    }
  },

  // 保存图片到相册
  saveImageToAlbum(file) {
    // 模拟保存图片
    wx.showLoading({
      title: '保存中...'
    });
    
    setTimeout(() => {
      wx.hideLoading();
      wx.showToast({
        title: '已保存到相册',
        icon: 'success'
      });
    }, 1000);
  },

  // 保存文件到本地
  saveFileToLocal(file) {
    wx.showToast({
      title: '文件已保存',
      icon: 'success'
    });
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
          this.setData({
            receiveFiles: receiveFiles
          });
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
          this.setData({
            transferHistory: []
          });
          
          wx.removeStorageSync('transferHistory');
          
          wx.showToast({
            title: '历史已清空',
            icon: 'success'
          });
        }
      }
    });
  },

  // 加载传输历史
  loadTransferHistory() {
    try {
      const history = wx.getStorageSync('transferHistory') || [];
      this.setData({
        transferHistory: history
      });
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
    
    this.setData({
      sendFiles: sendFiles
    });
  },

  // 检查存储空间
  checkStorageSpace() {
    // 模拟存储空间检查
    const usedSpace = Math.floor(Math.random() * 500); // MB
    const totalSpace = 1000; // MB
    
    if (usedSpace > totalSpace * 0.9) {
      wx.showModal({
        title: '存储空间不足',
        content: '设备存储空间不足，可能影响文件传输',
        showCancel: false
      });
    }
  },

  // 格式化文件大小
  formatFileSize(bytes) {
    if (bytes === 0) return '0 B';
    
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
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