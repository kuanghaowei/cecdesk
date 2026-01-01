// pages/connection/connection.js
const app = getApp();

Page({
  data: {
    // 连接状态
    connectionStatus: 'disconnected', // disconnected, connecting, connected, error
    
    // 连接信息
    connectionInfo: {
      remoteId: '',
      remoteAddress: '',
      connectionTime: null,
      lastPing: 0,
      dataTransferred: 0
    },
    
    // 输入的连接信息
    inputRemoteId: '',
    inputPassword: '',
    
    // 历史连接记录
    connectionHistory: [],
    
    // 网络状态
    networkStatus: {
      type: 'unknown',
      isConnected: true,
      signal: 0
    },
    
    // 连接选项
    connectionOptions: {
      autoReconnect: true,
      quality: 'medium',
      enableAudio: true
    },
    
    // 扫码连接
    scanResult: null,
    showScanModal: false
  },

  onLoad(options) {
    console.log('连接页面加载', options);
    
    // 加载连接历史
    this.loadConnectionHistory();
    
    // 检查网络状态
    this.checkNetworkStatus();
    
    // 监听网络状态变化
    this.setupNetworkListener();
    
    // 如果有传入的连接ID，自动填入
    if (options.remoteId) {
      this.setData({
        inputRemoteId: options.remoteId
      });
    }
  },

  onShow() {
    // 刷新网络状态
    this.checkNetworkStatus();
    
    // 检查是否有活跃连接
    this.checkActiveConnection();
  },

  onUnload() {
    // 清理网络监听
    if (this.networkListener) {
      wx.offNetworkStatusChange(this.networkListener);
    }
  },

  // 输入远程ID
  onRemoteIdInput(e) {
    this.setData({
      inputRemoteId: e.detail.value
    });
  },

  // 输入密码
  onPasswordInput(e) {
    this.setData({
      inputPassword: e.detail.value
    });
  },

  // 开始连接
  startConnection() {
    const { inputRemoteId, inputPassword } = this.data;
    
    if (!inputRemoteId.trim()) {
      wx.showToast({
        title: '请输入远程设备ID',
        icon: 'none'
      });
      return;
    }
    
    if (!this.data.networkStatus.isConnected) {
      wx.showToast({
        title: '网络连接异常',
        icon: 'none'
      });
      return;
    }
    
    this.performConnection(inputRemoteId.trim(), inputPassword);
  },

  // 执行连接
  async performConnection(remoteId, password) {
    this.setData({
      connectionStatus: 'connecting'
    });
    
    wx.showLoading({
      title: '连接中...'
    });
    
    try {
      // 模拟连接过程
      await this.simulateConnection(remoteId, password);
      
      // 连接成功
      this.setData({
        connectionStatus: 'connected',
        'connectionInfo.remoteId': remoteId,
        'connectionInfo.remoteAddress': this.generateRemoteAddress(),
        'connectionInfo.connectionTime': Date.now(),
        'connectionInfo.lastPing': Date.now(),
        'connectionInfo.dataTransferred': 0
      });
      
      // 添加到连接历史
      this.addToConnectionHistory(remoteId);
      
      // 清空输入
      this.setData({
        inputRemoteId: '',
        inputPassword: ''
      });
      
      wx.hideLoading();
      wx.showToast({
        title: '连接成功',
        icon: 'success'
      });
      
      // 跳转到远程桌面页面
      setTimeout(() => {
        wx.switchTab({
          url: '/pages/remote-desktop/remote-desktop'
        });
      }, 1500);
      
    } catch (error) {
      console.error('连接失败:', error);
      
      this.setData({
        connectionStatus: 'error'
      });
      
      wx.hideLoading();
      wx.showModal({
        title: '连接失败',
        content: error.message || '无法连接到远程设备，请检查设备ID和网络连接',
        showCancel: false
      });
    }
  },

  // 模拟连接过程
  simulateConnection(remoteId, password) {
    return new Promise((resolve, reject) => {
      // 模拟连接延迟
      setTimeout(() => {
        // 简单的ID验证
        if (remoteId.length < 6) {
          reject(new Error('设备ID格式不正确'));
          return;
        }
        
        // 模拟密码验证（如果有密码）
        if (password && password.length < 4) {
          reject(new Error('密码长度至少4位'));
          return;
        }
        
        // 随机模拟连接失败
        if (Math.random() < 0.1) {
          reject(new Error('设备不在线或网络异常'));
          return;
        }
        
        resolve();
      }, 2000 + Math.random() * 2000);
    });
  },

  // 断开连接
  disconnect() {
    wx.showModal({
      title: '断开连接',
      content: '确定要断开当前连接吗？',
      success: (res) => {
        if (res.confirm) {
          this.performDisconnect();
        }
      }
    });
  },

  // 执行断开连接
  performDisconnect() {
    this.setData({
      connectionStatus: 'disconnected',
      connectionInfo: {
        remoteId: '',
        remoteAddress: '',
        connectionTime: null,
        lastPing: 0,
        dataTransferred: 0
      }
    });
    
    // 清理WebRTC连接
    if (app.globalData.webrtcContext) {
      app.globalData.webrtcContext.disconnect();
    }
    
    app.globalData.isConnected = false;
    app.globalData.currentSession = null;
    
    wx.showToast({
      title: '已断开连接',
      icon: 'success'
    });
  },

  // 扫码连接
  scanQRCode() {
    wx.scanCode({
      scanType: ['qrCode'],
      success: (res) => {
        console.log('扫码结果:', res);
        
        try {
          // 解析二维码内容
          const scanData = JSON.parse(res.result);
          
          if (scanData.type === 'remote-desktop' && scanData.deviceId) {
            this.setData({
              inputRemoteId: scanData.deviceId,
              inputPassword: scanData.password || ''
            });
            
            wx.showToast({
              title: '扫码成功',
              icon: 'success'
            });
            
            // 自动连接
            if (scanData.autoConnect) {
              setTimeout(() => {
                this.startConnection();
              }, 1000);
            }
          } else {
            throw new Error('无效的二维码');
          }
        } catch (error) {
          console.error('解析二维码失败:', error);
          
          // 尝试直接作为设备ID使用
          if (res.result && res.result.length >= 6) {
            this.setData({
              inputRemoteId: res.result
            });
            
            wx.showToast({
              title: '已填入设备ID',
              icon: 'success'
            });
          } else {
            wx.showToast({
              title: '无效的二维码',
              icon: 'none'
            });
          }
        }
      },
      fail: (error) => {
        console.error('扫码失败:', error);
        if (error.errMsg !== 'scanCode:fail cancel') {
          wx.showToast({
            title: '扫码失败',
            icon: 'none'
          });
        }
      }
    });
  },

  // 从历史记录连接
  connectFromHistory(e) {
    const remoteId = e.currentTarget.dataset.remoteId;
    
    this.setData({
      inputRemoteId: remoteId
    });
    
    wx.showModal({
      title: '历史连接',
      content: `确定要连接到 ${remoteId} 吗？`,
      success: (res) => {
        if (res.confirm) {
          this.startConnection();
        }
      }
    });
  },

  // 删除历史记录
  deleteHistoryItem(e) {
    const index = e.currentTarget.dataset.index;
    
    wx.showModal({
      title: '删除记录',
      content: '确定要删除这条连接记录吗？',
      success: (res) => {
        if (res.confirm) {
          const connectionHistory = [...this.data.connectionHistory];
          connectionHistory.splice(index, 1);
          
          this.setData({
            connectionHistory: connectionHistory
          });
          
          this.saveConnectionHistory();
        }
      }
    });
  },

  // 清空历史记录
  clearHistory() {
    wx.showModal({
      title: '清空历史',
      content: '确定要清空所有连接历史吗？',
      success: (res) => {
        if (res.confirm) {
          this.setData({
            connectionHistory: []
          });
          
          wx.removeStorageSync('connectionHistory');
          
          wx.showToast({
            title: '历史已清空',
            icon: 'success'
          });
        }
      }
    });
  },

  // 连接选项变更
  onAutoReconnectChange(e) {
    this.setData({
      'connectionOptions.autoReconnect': e.detail.value
    });
    this.saveConnectionOptions();
  },

  onQualityChange(e) {
    const qualities = ['low', 'medium', 'high'];
    this.setData({
      'connectionOptions.quality': qualities[e.detail.value]
    });
    this.saveConnectionOptions();
  },

  onEnableAudioChange(e) {
    this.setData({
      'connectionOptions.enableAudio': e.detail.value
    });
    this.saveConnectionOptions();
  },

  // 检查网络状态
  checkNetworkStatus() {
    wx.getNetworkType({
      success: (res) => {
        const isConnected = res.networkType !== 'none';
        
        this.setData({
          'networkStatus.type': res.networkType,
          'networkStatus.isConnected': isConnected
        });
        
        // 获取网络信号强度（模拟）
        if (isConnected) {
          this.setData({
            'networkStatus.signal': Math.floor(Math.random() * 4) + 1
          });
        }
      },
      fail: (error) => {
        console.error('获取网络状态失败:', error);
      }
    });
  },

  // 设置网络监听
  setupNetworkListener() {
    this.networkListener = (res) => {
      console.log('网络状态变化:', res);
      
      const isConnected = res.networkType !== 'none';
      
      this.setData({
        'networkStatus.type': res.networkType,
        'networkStatus.isConnected': isConnected
      });
      
      if (!isConnected && this.data.connectionStatus === 'connected') {
        wx.showToast({
          title: '网络连接断开',
          icon: 'none'
        });
      }
    };
    
    wx.onNetworkStatusChange(this.networkListener);
  },

  // 检查活跃连接
  checkActiveConnection() {
    if (app.globalData.isConnected && app.globalData.currentSession) {
      this.setData({
        connectionStatus: 'connected',
        'connectionInfo.remoteId': app.globalData.currentSession.remoteId || '未知设备',
        'connectionInfo.connectionTime': app.globalData.currentSession.startTime || Date.now()
      });
    }
  },

  // 加载连接历史
  loadConnectionHistory() {
    try {
      const history = wx.getStorageSync('connectionHistory') || [];
      this.setData({
        connectionHistory: history
      });
    } catch (error) {
      console.error('加载连接历史失败:', error);
    }
    
    // 加载连接选项
    try {
      const options = wx.getStorageSync('connectionOptions') || {};
      this.setData({
        connectionOptions: { ...this.data.connectionOptions, ...options }
      });
    } catch (error) {
      console.error('加载连接选项失败:', error);
    }
  },

  // 添加到连接历史
  addToConnectionHistory(remoteId) {
    const historyItem = {
      remoteId: remoteId,
      connectTime: Date.now(),
      date: new Date().toLocaleString()
    };
    
    // 去重并添加到开头
    let connectionHistory = this.data.connectionHistory.filter(
      item => item.remoteId !== remoteId
    );
    connectionHistory.unshift(historyItem);
    
    // 限制历史记录数量
    if (connectionHistory.length > 10) {
      connectionHistory = connectionHistory.slice(0, 10);
    }
    
    this.setData({
      connectionHistory: connectionHistory
    });
    
    this.saveConnectionHistory();
  },

  // 保存连接历史
  saveConnectionHistory() {
    try {
      wx.setStorageSync('connectionHistory', this.data.connectionHistory);
    } catch (error) {
      console.error('保存连接历史失败:', error);
    }
  },

  // 保存连接选项
  saveConnectionOptions() {
    try {
      wx.setStorageSync('connectionOptions', this.data.connectionOptions);
    } catch (error) {
      console.error('保存连接选项失败:', error);
    }
  },

  // 生成远程地址
  generateRemoteAddress() {
    const ips = ['192.168.1.', '10.0.0.', '172.16.0.'];
    const randomIp = ips[Math.floor(Math.random() * ips.length)];
    const randomHost = Math.floor(Math.random() * 254) + 1;
    return `${randomIp}${randomHost}:5900`;
  },

  // 格式化连接时间
  formatConnectionTime(timestamp) {
    if (!timestamp) return '未知';
    
    const now = Date.now();
    const diff = now - timestamp;
    const minutes = Math.floor(diff / 60000);
    const hours = Math.floor(minutes / 60);
    
    if (hours > 0) {
      return `${hours}小时${minutes % 60}分钟`;
    } else {
      return `${minutes}分钟`;
    }
  },

  // 获取网络类型文本
  getNetworkTypeText(type) {
    const typeMap = {
      'wifi': 'WiFi',
      '2g': '2G',
      '3g': '3G',
      '4g': '4G',
      '5g': '5G',
      'unknown': '未知',
      'none': '无网络'
    };
    return typeMap[type] || '未知';
  },

  // 获取信号强度图标
  getSignalIcon(signal) {
    const icons = ['📶', '📶', '📶', '📶', '📶'];
    return icons[signal] || '📶';
  },

  // 获取质量文本
  getQualityText(quality) {
    const qualityMap = {
      low: '流畅',
      medium: '标准',
      high: '高清'
    };
    return qualityMap[quality] || '标准';
  },

  // 导航到远程桌面
  goToDesktop() {
    wx.switchTab({
      url: '/pages/remote-desktop/remote-desktop'
    });
  },

  // 导航到文件传输
  goToFileTransfer() {
    wx.switchTab({
      url: '/pages/file-transfer/file-transfer'
    });
  }
});