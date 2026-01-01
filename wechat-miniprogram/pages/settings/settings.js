// pages/settings/settings.js
const app = getApp();

Page({
  data: {
    // 连接设置
    connectionSettings: {
      autoConnect: false,
      keepAlive: true,
      reconnectInterval: 5000,
      maxReconnectAttempts: 3
    },
    
    // 视频设置
    videoSettings: {
      quality: 'medium', // low, medium, high
      frameRate: 30,
      enableHardwareAcceleration: true,
      adaptiveBitrate: true
    },
    
    // 音频设置
    audioSettings: {
      enabled: true,
      quality: 'medium', // low, medium, high
      echoCancellation: true,
      noiseSuppression: true
    },
    
    // 文件传输设置
    fileSettings: {
      maxFileSize: 100, // MB
      autoSave: false,
      compressionEnabled: true,
      allowedTypes: ['image', 'video', 'audio', 'document']
    },
    
    // 安全设置
    securitySettings: {
      requireAuth: true,
      sessionTimeout: 30, // 分钟
      encryptionEnabled: true,
      allowScreenshots: false
    },
    
    // 界面设置
    uiSettings: {
      theme: 'auto', // light, dark, auto
      language: 'zh-CN',
      showFPS: false,
      showNetworkStatus: true
    },
    
    // 系统信息
    systemInfo: null,
    deviceId: '',
    appVersion: '1.0.0',
    
    // 存储使用情况
    storageInfo: {
      used: 0,
      total: 0,
      percentage: 0
    }
  },

  onLoad(options) {
    console.log('设置页面加载', options);
    
    // 加载设置
    this.loadSettings();
    
    // 获取系统信息
    this.getSystemInfo();
    
    // 获取存储信息
    this.getStorageInfo();
    
    // 获取设备ID
    this.setData({
      deviceId: app.globalData.deviceId || '未知'
    });
  },

  onShow() {
    // 刷新存储信息
    this.getStorageInfo();
  },

  // 加载设置
  loadSettings() {
    try {
      const settings = wx.getStorageSync('appSettings') || {};
      
      this.setData({
        connectionSettings: { ...this.data.connectionSettings, ...settings.connection },
        videoSettings: { ...this.data.videoSettings, ...settings.video },
        audioSettings: { ...this.data.audioSettings, ...settings.audio },
        fileSettings: { ...this.data.fileSettings, ...settings.file },
        securitySettings: { ...this.data.securitySettings, ...settings.security },
        uiSettings: { ...this.data.uiSettings, ...settings.ui }
      });
    } catch (error) {
      console.error('加载设置失败:', error);
    }
  },

  // 保存设置
  saveSettings() {
    try {
      const settings = {
        connection: this.data.connectionSettings,
        video: this.data.videoSettings,
        audio: this.data.audioSettings,
        file: this.data.fileSettings,
        security: this.data.securitySettings,
        ui: this.data.uiSettings
      };
      
      wx.setStorageSync('appSettings', settings);
      
      wx.showToast({
        title: '设置已保存',
        icon: 'success'
      });
    } catch (error) {
      console.error('保存设置失败:', error);
      wx.showToast({
        title: '保存失败',
        icon: 'none'
      });
    }
  },

  // 连接设置变更
  onAutoConnectChange(e) {
    this.setData({
      'connectionSettings.autoConnect': e.detail.value
    });
    this.saveSettings();
  },

  onKeepAliveChange(e) {
    this.setData({
      'connectionSettings.keepAlive': e.detail.value
    });
    this.saveSettings();
  },

  onReconnectIntervalChange(e) {
    this.setData({
      'connectionSettings.reconnectInterval': parseInt(e.detail.value) * 1000
    });
    this.saveSettings();
  },

  onMaxReconnectAttemptsChange(e) {
    this.setData({
      'connectionSettings.maxReconnectAttempts': parseInt(e.detail.value)
    });
    this.saveSettings();
  },

  // 视频设置变更
  onVideoQualityChange(e) {
    const qualities = ['low', 'medium', 'high'];
    this.setData({
      'videoSettings.quality': qualities[e.detail.value]
    });
    this.saveSettings();
  },

  onFrameRateChange(e) {
    const frameRates = [15, 24, 30, 60];
    this.setData({
      'videoSettings.frameRate': frameRates[e.detail.value]
    });
    this.saveSettings();
  },

  onHardwareAccelerationChange(e) {
    this.setData({
      'videoSettings.enableHardwareAcceleration': e.detail.value
    });
    this.saveSettings();
  },

  onAdaptiveBitrateChange(e) {
    this.setData({
      'videoSettings.adaptiveBitrate': e.detail.value
    });
    this.saveSettings();
  },

  // 音频设置变更
  onAudioEnabledChange(e) {
    this.setData({
      'audioSettings.enabled': e.detail.value
    });
    this.saveSettings();
  },

  onAudioQualityChange(e) {
    const qualities = ['low', 'medium', 'high'];
    this.setData({
      'audioSettings.quality': qualities[e.detail.value]
    });
    this.saveSettings();
  },

  onEchoCancellationChange(e) {
    this.setData({
      'audioSettings.echoCancellation': e.detail.value
    });
    this.saveSettings();
  },

  onNoiseSuppressionChange(e) {
    this.setData({
      'audioSettings.noiseSuppression': e.detail.value
    });
    this.saveSettings();
  },

  // 文件设置变更
  onMaxFileSizeChange(e) {
    this.setData({
      'fileSettings.maxFileSize': parseInt(e.detail.value)
    });
    this.saveSettings();
  },

  onAutoSaveChange(e) {
    this.setData({
      'fileSettings.autoSave': e.detail.value
    });
    this.saveSettings();
  },

  onCompressionChange(e) {
    this.setData({
      'fileSettings.compressionEnabled': e.detail.value
    });
    this.saveSettings();
  },

  // 安全设置变更
  onRequireAuthChange(e) {
    this.setData({
      'securitySettings.requireAuth': e.detail.value
    });
    this.saveSettings();
  },

  onSessionTimeoutChange(e) {
    this.setData({
      'securitySettings.sessionTimeout': parseInt(e.detail.value)
    });
    this.saveSettings();
  },

  onEncryptionChange(e) {
    this.setData({
      'securitySettings.encryptionEnabled': e.detail.value
    });
    this.saveSettings();
  },

  onAllowScreenshotsChange(e) {
    this.setData({
      'securitySettings.allowScreenshots': e.detail.value
    });
    this.saveSettings();
  },

  // 界面设置变更
  onThemeChange(e) {
    const themes = ['light', 'dark', 'auto'];
    this.setData({
      'uiSettings.theme': themes[e.detail.value]
    });
    this.saveSettings();
  },

  onLanguageChange(e) {
    const languages = ['zh-CN', 'en-US'];
    this.setData({
      'uiSettings.language': languages[e.detail.value]
    });
    this.saveSettings();
  },

  onShowFPSChange(e) {
    this.setData({
      'uiSettings.showFPS': e.detail.value
    });
    this.saveSettings();
  },

  onShowNetworkStatusChange(e) {
    this.setData({
      'uiSettings.showNetworkStatus': e.detail.value
    });
    this.saveSettings();
  },

  // 获取系统信息
  getSystemInfo() {
    wx.getSystemInfo({
      success: (res) => {
        this.setData({
          systemInfo: res
        });
      },
      fail: (error) => {
        console.error('获取系统信息失败:', error);
      }
    });
  },

  // 获取存储信息
  getStorageInfo() {
    wx.getStorageInfo({
      success: (res) => {
        const used = res.currentSize;
        const total = res.limitSize;
        const percentage = Math.round((used / total) * 100);
        
        this.setData({
          storageInfo: {
            used: used,
            total: total,
            percentage: percentage
          }
        });
      },
      fail: (error) => {
        console.error('获取存储信息失败:', error);
      }
    });
  },

  // 清理缓存
  clearCache() {
    wx.showModal({
      title: '清理缓存',
      content: '确定要清理所有缓存数据吗？这将删除传输历史和临时文件。',
      success: (res) => {
        if (res.confirm) {
          this.performClearCache();
        }
      }
    });
  },

  // 执行清理缓存
  performClearCache() {
    wx.showLoading({
      title: '清理中...'
    });
    
    try {
      // 清理传输历史
      wx.removeStorageSync('transferHistory');
      
      // 清理临时文件（模拟）
      setTimeout(() => {
        wx.hideLoading();
        
        // 刷新存储信息
        this.getStorageInfo();
        
        wx.showToast({
          title: '缓存已清理',
          icon: 'success'
        });
      }, 1500);
      
    } catch (error) {
      wx.hideLoading();
      console.error('清理缓存失败:', error);
      wx.showToast({
        title: '清理失败',
        icon: 'none'
      });
    }
  },

  // 重置设置
  resetSettings() {
    wx.showModal({
      title: '重置设置',
      content: '确定要重置所有设置为默认值吗？',
      success: (res) => {
        if (res.confirm) {
          this.performResetSettings();
        }
      }
    });
  },

  // 执行重置设置
  performResetSettings() {
    try {
      wx.removeStorageSync('appSettings');
      
      // 重新加载默认设置
      this.onLoad();
      
      wx.showToast({
        title: '设置已重置',
        icon: 'success'
      });
    } catch (error) {
      console.error('重置设置失败:', error);
      wx.showToast({
        title: '重置失败',
        icon: 'none'
      });
    }
  },

  // 检查更新
  checkUpdate() {
    wx.showLoading({
      title: '检查中...'
    });
    
    // 模拟检查更新
    setTimeout(() => {
      wx.hideLoading();
      wx.showModal({
        title: '检查更新',
        content: '当前已是最新版本',
        showCancel: false
      });
    }, 1500);
  },

  // 关于应用
  showAbout() {
    wx.showModal({
      title: '关于应用',
      content: `工一远程客户端\n版本: ${this.data.appVersion}\n设备ID: ${this.data.deviceId}`,
      showCancel: false
    });
  },

  // 反馈问题
  feedback() {
    wx.showModal({
      title: '问题反馈',
      content: '请通过以下方式联系我们：\n邮箱: support@example.com\n电话: 400-123-4567',
      showCancel: false
    });
  },

  // 格式化存储大小
  formatStorageSize(kb) {
    if (kb < 1024) {
      return kb + ' KB';
    } else if (kb < 1024 * 1024) {
      return Math.round(kb / 1024 * 100) / 100 + ' MB';
    } else {
      return Math.round(kb / (1024 * 1024) * 100) / 100 + ' GB';
    }
  },

  // 获取质量文本
  getQualityText(quality) {
    const qualityMap = {
      low: '低',
      medium: '中',
      high: '高'
    };
    return qualityMap[quality] || '未知';
  },

  // 获取主题文本
  getThemeText(theme) {
    const themeMap = {
      light: '浅色',
      dark: '深色',
      auto: '跟随系统'
    };
    return themeMap[theme] || '未知';
  }
});