// app.js
App({
  globalData: {
    deviceId: null,
    isConnected: false,
    currentSession: null,
    webrtcContext: null,
    systemInfo: null
  },

  onLaunch(options) {
    console.log('小程序启动', options);
    
    // 获取系统信息
    this.getSystemInfo();
    
    // 初始化设备ID
    this.initDeviceId();
    
    // 检查更新
    this.checkForUpdate();
  },

  onShow(options) {
    console.log('小程序显示', options);
    
    // 检查网络状态
    this.checkNetworkStatus();
  },

  onHide() {
    console.log('小程序隐藏');
    
    // 暂停WebRTC连接但不断开
    if (this.globalData.webrtcContext) {
      // 降低视频质量以节省资源
      this.globalData.webrtcContext.setVideoQuality('low');
    }
  },

  onError(error) {
    console.error('小程序错误:', error);
    
    // 上报错误信息
    wx.reportAnalytics('miniprogram_error', {
      error: error.toString(),
      timestamp: Date.now()
    });
  },

  // 获取系统信息
  getSystemInfo() {
    wx.getSystemInfo({
      success: (res) => {
        this.globalData.systemInfo = res;
        console.log('系统信息:', res);
        
        // 检查WebRTC支持
        this.checkWebRTCSupport();
      },
      fail: (err) => {
        console.error('获取系统信息失败:', err);
      }
    });
  },

  // 检查WebRTC支持
  checkWebRTCSupport() {
    // 检查是否支持实时音视频
    if (wx.createLivePlayerContext) {
      console.log('支持实时音视频');
    } else {
      console.warn('不支持实时音视频');
      wx.showModal({
        title: '兼容性提示',
        content: '当前微信版本不支持实时音视频功能，请更新微信版本',
        showCancel: false
      });
    }
  },

  // 初始化设备ID
  initDeviceId() {
    let deviceId = wx.getStorageSync('deviceId');
    if (!deviceId) {
      // 生成新的设备ID
      deviceId = this.generateDeviceId();
      wx.setStorageSync('deviceId', deviceId);
    }
    this.globalData.deviceId = deviceId;
    console.log('设备ID:', deviceId);
  },

  // 生成设备ID
  generateDeviceId() {
    const timestamp = Date.now().toString(36);
    const random = Math.random().toString(36).substr(2, 9);
    return `wx_${timestamp}_${random}`;
  },

  // 检查网络状态
  checkNetworkStatus() {
    wx.getNetworkType({
      success: (res) => {
        console.log('网络类型:', res.networkType);
        
        if (res.networkType === 'none') {
          wx.showToast({
            title: '网络连接失败',
            icon: 'none'
          });
        }
      }
    });
  },

  // 检查更新
  checkForUpdate() {
    if (wx.getUpdateManager) {
      const updateManager = wx.getUpdateManager();
      
      updateManager.onCheckForUpdate((res) => {
        console.log('检查更新结果:', res.hasUpdate);
      });
      
      updateManager.onUpdateReady(() => {
        wx.showModal({
          title: '更新提示',
          content: '新版本已经准备好，是否重启应用？',
          success: (res) => {
            if (res.confirm) {
              updateManager.applyUpdate();
            }
          }
        });
      });
      
      updateManager.onUpdateFailed(() => {
        console.error('更新失败');
      });
    }
  },

  // WebRTC相关方法
  createWebRTCContext() {
    if (!this.globalData.webrtcContext) {
      // 创建WebRTC上下文（使用小程序的实时音视频API）
      this.globalData.webrtcContext = {
        // 这里会集成微信小程序的WebRTC API
        setVideoQuality: (quality) => {
          console.log('设置视频质量:', quality);
        },
        connect: (remoteId) => {
          console.log('连接到远程设备:', remoteId);
        },
        disconnect: () => {
          console.log('断开连接');
        }
      };
    }
    return this.globalData.webrtcContext;
  },

  // 内存优化
  optimizeMemory() {
    // 清理不必要的数据
    if (this.globalData.webrtcContext && !this.globalData.isConnected) {
      this.globalData.webrtcContext = null;
    }
    
    // 触发垃圾回收
    if (wx.triggerGC) {
      wx.triggerGC();
    }
  },

  // 获取内存信息
  getMemoryInfo() {
    if (wx.getPerformance) {
      const performance = wx.getPerformance();
      if (performance.getEntries) {
        const entries = performance.getEntries();
        console.log('性能信息:', entries);
      }
    }
  }
});