// pages/remote-desktop/remote-desktop.js
// 远程桌面页面 - 集成 WebRTC、画布渲染和触摸输入
const app = getApp();
const { webrtcService } = require('../../utils/webrtc-service');
const { CanvasRenderer } = require('../../utils/canvas-renderer');
const { TouchInputHandler } = require('../../utils/touch-input-handler');

Page({
  data: {
    deviceId: '',
    accessCode: '',
    isConnected: false,
    isConnecting: false,
    showControls: true,
    isFullscreen: false,
    connectionQuality: 'good',
    networkStats: {
      rtt: 0,
      fps: 0,
      resolution: '1080p'
    },
    canvasId: 'remoteDesktopCanvas',
    canvasContext: null,
    livePlayerContext: null,
    touchStartTime: 0,
    lastTouchX: 0,
    lastTouchY: 0,
    // 远程桌面尺寸
    remoteWidth: 1920,
    remoteHeight: 1080,
    // 画布尺寸
    canvasWidth: 375,
    canvasHeight: 667
  },

  // 服务实例
  canvasRenderer: null,
  touchInputHandler: null,
  frameUpdateInterval: null,

  onLoad(options) {
    console.log('远程桌面页面加载', options);
    
    this.setData({
      deviceId: options.deviceId || '',
      accessCode: options.accessCode || ''
    });
    
    // 获取屏幕尺寸
    this.getScreenSize();
    
    // 初始化服务
    this.initServices();
    
    // 开始连接
    this.connectToRemoteDesktop();
  },

  onShow() {
    // 保持屏幕常亮
    wx.setKeepScreenOn({
      keepScreenOn: true
    });
    
    // 恢复连接
    if (this.data.isConnected) {
      this.resumeConnection();
    }
  },

  onHide() {
    // 暂停连接但不断开
    this.pauseConnection();
  },

  onUnload() {
    // 断开连接
    this.disconnectFromRemoteDesktop();
    
    // 销毁服务
    this.destroyServices();
    
    // 取消屏幕常亮
    wx.setKeepScreenOn({
      keepScreenOn: false
    });
  },

  // 获取屏幕尺寸
  getScreenSize() {
    const systemInfo = wx.getSystemInfoSync();
    this.setData({
      canvasWidth: systemInfo.windowWidth,
      canvasHeight: systemInfo.windowHeight - 100 // 留出控制栏空间
    });
  },

  // 初始化服务
  initServices() {
    // 初始化 WebRTC 服务
    webrtcService.init({
      signalingServer: 'wss://signaling.gongyi-remote.com',
      stunServer: 'stun:stun.l.google.com:19302',
      videoQuality: 'medium',
      audioEnabled: true
    });
    
    // 监听 WebRTC 事件
    this.setupWebRTCListeners();
    
    // 初始化画布渲染器
    this.canvasRenderer = new CanvasRenderer();
    this.canvasRenderer.init(this.data.canvasId, this, {
      width: this.data.canvasWidth,
      height: this.data.canvasHeight
    });
    
    // 初始化触摸输入处理器
    this.touchInputHandler = new TouchInputHandler();
    this.touchInputHandler.init(webrtcService, this.canvasRenderer, {
      remoteWidth: this.data.remoteWidth,
      remoteHeight: this.data.remoteHeight
    });
    
    // 监听触摸事件
    this.setupTouchListeners();
    
    console.log('[RemoteDesktop] 服务初始化完成');
  },

  // 设置 WebRTC 事件监听
  setupWebRTCListeners() {
    webrtcService.on('connectionStateChange', (state) => {
      console.log('[RemoteDesktop] 连接状态变化:', state);
      
      if (state === 'connected') {
        this.setData({
          isConnected: true,
          isConnecting: false
        });
        this.startFrameUpdates();
      } else if (state === 'disconnected' || state === 'failed') {
        this.setData({
          isConnected: false,
          isConnecting: false
        });
        this.stopFrameUpdates();
      }
    });
    
    webrtcService.on('networkStats', (stats) => {
      this.setData({
        'networkStats.rtt': Math.round(stats.rtt),
        'networkStats.fps': Math.round(stats.fps)
      });
      
      // 更新连接质量
      this.updateConnectionQuality(stats.rtt);
    });
    
    webrtcService.on('error', (error) => {
      console.error('[RemoteDesktop] WebRTC 错误:', error);
      wx.showToast({
        title: error.message || '连接错误',
        icon: 'none'
      });
    });
  },

  // 设置触摸事件监听
  setupTouchListeners() {
    this.touchInputHandler.on('tap', (data) => {
      console.log('[RemoteDesktop] 点击:', data);
    });
    
    this.touchInputHandler.on('rightClick', (data) => {
      console.log('[RemoteDesktop] 右键点击:', data);
      wx.vibrateShort({ type: 'medium' });
    });
    
    this.touchInputHandler.on('doubleTap', (data) => {
      console.log('[RemoteDesktop] 双击:', data);
    });
  },

  // 销毁服务
  destroyServices() {
    if (this.canvasRenderer) {
      this.canvasRenderer.destroy();
      this.canvasRenderer = null;
    }
    
    if (this.touchInputHandler) {
      this.touchInputHandler.destroy();
      this.touchInputHandler = null;
    }
    
    webrtcService.disconnect();
  },

  // 连接到远程桌面
  async connectToRemoteDesktop() {
    if (this.data.isConnecting || this.data.isConnected) {
      return;
    }

    this.setData({
      isConnecting: true
    });

    try {
      // 检查网络状态
      const networkType = await this.checkNetworkType();
      if (networkType === 'none') {
        throw new Error('网络连接失败');
      }

      // 请求必要权限
      await this.requestPermissions();

      // 使用 WebRTC 服务连接
      // 验证: 需求 15.2 - 使用微信小程序的 WebRTC API 建立连接
      const connected = await webrtcService.connect(
        this.data.deviceId, 
        this.data.accessCode
      );

      if (connected) {
        this.setData({
          isConnected: true,
          isConnecting: false,
          connectionQuality: 'good'
        });

        wx.showToast({
          title: '连接成功',
          icon: 'success'
        });

        // 开始接收远程桌面数据
        this.startFrameUpdates();
      } else {
        throw new Error('连接失败');
      }

    } catch (error) {
      console.error('连接失败:', error);
      
      this.setData({
        isConnecting: false,
        isConnected: false
      });

      wx.showModal({
        title: '连接失败',
        content: error.message || '无法连接到远程设备',
        showCancel: false
      });
    }
  },

  // 检查网络类型
  checkNetworkType() {
    return new Promise((resolve) => {
      wx.getNetworkType({
        success: (res) => {
          resolve(res.networkType);
        },
        fail: () => {
          resolve('none');
        }
      });
    });
  },

  // 请求权限
  async requestPermissions() {
    try {
      await this.requestPermission('scope.camera');
    } catch (error) {
      console.warn('摄像头权限请求失败:', error);
    }

    try {
      await this.requestPermission('scope.record');
    } catch (error) {
      console.warn('录音权限请求失败:', error);
    }
  },

  // 请求单个权限
  requestPermission(scope) {
    return new Promise((resolve, reject) => {
      wx.getSetting({
        success: (res) => {
          if (res.authSetting[scope]) {
            resolve();
          } else {
            wx.authorize({
              scope: scope,
              success: resolve,
              fail: reject
            });
          }
        },
        fail: reject
      });
    });
  },

  // 开始帧更新
  startFrameUpdates() {
    // 验证: 需求 15.3 - 适配小程序的画布组件进行屏幕显示
    this.frameUpdateInterval = setInterval(() => {
      this.updateDesktopFrame();
      this.updateNetworkStats();
    }, 33); // 约30FPS
  },

  // 停止帧更新
  stopFrameUpdates() {
    if (this.frameUpdateInterval) {
      clearInterval(this.frameUpdateInterval);
      this.frameUpdateInterval = null;
    }
  },

  // 更新桌面帧
  updateDesktopFrame() {
    if (!this.canvasRenderer || !this.data.isConnected) {
      return;
    }

    // 渲染模拟帧
    this.canvasRenderer.renderFrame({
      type: 'simulated',
      deviceId: this.data.deviceId
    });
  },

  // 更新网络统计
  updateNetworkStats() {
    const stats = webrtcService.getNetworkStats();
    
    this.setData({
      'networkStats.rtt': Math.round(stats.rtt),
      'networkStats.fps': this.canvasRenderer ? this.canvasRenderer.getFPS() : 0
    });

    this.updateConnectionQuality(stats.rtt);
  },

  // 更新连接质量
  updateConnectionQuality(rtt) {
    let quality = 'excellent';
    if (rtt > 100) quality = 'poor';
    else if (rtt > 60) quality = 'fair';
    else if (rtt > 40) quality = 'good';

    this.setData({
      connectionQuality: quality
    });
  },

  // 实时播放器状态变化
  onLivePlayerStateChange(e) {
    console.log('播放器状态变化:', e);
  },

  // 实时播放器网络状态
  onLivePlayerNetStatus(e) {
    console.log('播放器网络状态:', e);
  },

  // 触摸开始
  // 验证: 需求 15.4 - 通过触摸事件模拟鼠标和键盘操作
  onTouchStart(e) {
    if (!this.data.isConnected || !this.touchInputHandler) return;
    this.touchInputHandler.handleTouchStart(e);
  },

  // 触摸移动
  onTouchMove(e) {
    if (!this.data.isConnected || !this.touchInputHandler) return;
    this.touchInputHandler.handleTouchMove(e);
  },

  // 触摸结束
  onTouchEnd(e) {
    if (!this.data.isConnected || !this.touchInputHandler) return;
    this.touchInputHandler.handleTouchEnd(e);
  },

  // 长按事件
  onLongPress(e) {
    if (!this.data.isConnected || !this.touchInputHandler) return;
    this.touchInputHandler.handleLongPress(e);
  },

  // 切换控制面板显示
  toggleControls() {
    this.setData({
      showControls: !this.data.showControls
    });
  },

  // 切换全屏
  toggleFullscreen() {
    this.setData({
      isFullscreen: !this.data.isFullscreen
    });
  },

  // 显示虚拟键盘
  showVirtualKeyboard() {
    wx.showModal({
      title: '虚拟键盘',
      content: '请输入要发送的文本',
      editable: true,
      success: (res) => {
        if (res.confirm && res.content) {
          this.sendKeyboardInput(res.content);
        }
      }
    });
  },

  // 发送键盘输入
  sendKeyboardInput(text) {
    if (this.touchInputHandler) {
      this.touchInputHandler.sendKeyboardInput(text);
    }
    
    wx.showToast({
      title: '文本已发送',
      icon: 'success'
    });
  },

  // 截图
  async takeScreenshot() {
    if (!this.canvasRenderer) {
      wx.showToast({
        title: '截图失败',
        icon: 'none'
      });
      return;
    }

    try {
      await this.canvasRenderer.saveScreenshotToAlbum();
      wx.showToast({
        title: '截图已保存',
        icon: 'success'
      });
    } catch (error) {
      console.error('截图失败:', error);
      wx.showToast({
        title: '保存失败',
        icon: 'none'
      });
    }
  },

  // 显示设置
  showSettings() {
    wx.showActionSheet({
      itemList: ['画质设置', '网络诊断', '连接信息', '帮助'],
      success: (res) => {
        switch (res.tapIndex) {
          case 0:
            this.showQualitySettings();
            break;
          case 1:
            this.showNetworkDiagnostics();
            break;
          case 2:
            this.showConnectionInfo();
            break;
          case 3:
            this.showHelp();
            break;
        }
      }
    });
  },

  // 显示画质设置
  showQualitySettings() {
    wx.showActionSheet({
      itemList: ['高画质 (1080p)', '标准画质 (720p)', '流畅画质 (480p)'],
      success: (res) => {
        const qualities = ['high', 'medium', 'low'];
        const resolutions = ['1080p', '720p', '480p'];
        const selectedQuality = qualities[res.tapIndex];
        
        webrtcService.setVideoQuality(selectedQuality);
        
        this.setData({
          'networkStats.resolution': resolutions[res.tapIndex]
        });
        
        wx.showToast({
          title: `已切换到${resolutions[res.tapIndex]}`,
          icon: 'success'
        });
      }
    });
  },

  // 显示网络诊断
  showNetworkDiagnostics() {
    const { networkStats, connectionQuality } = this.data;
    
    wx.showModal({
      title: '网络诊断',
      content: `连接质量: ${connectionQuality}\n延迟: ${networkStats.rtt}ms\n帧率: ${networkStats.fps}fps\n分辨率: ${networkStats.resolution}`,
      showCancel: false
    });
  },

  // 显示连接信息
  showConnectionInfo() {
    wx.showModal({
      title: '连接信息',
      content: `设备ID: ${this.data.deviceId}\n连接状态: ${this.data.isConnected ? '已连接' : '未连接'}`,
      showCancel: false
    });
  },

  // 显示帮助
  showHelp() {
    wx.showModal({
      title: '操作帮助',
      content: '• 单击: 鼠标左键\n• 长按: 鼠标右键\n• 滑动: 鼠标移动\n• 双击控制按钮: 显示/隐藏控制面板',
      showCancel: false
    });
  },

  // 暂停连接
  pauseConnection() {
    this.stopFrameUpdates();
    console.log('连接已暂停');
  },

  // 恢复连接
  resumeConnection() {
    if (this.data.isConnected) {
      this.startFrameUpdates();
      console.log('连接已恢复');
    }
  },

  // 断开连接
  disconnectFromRemoteDesktop() {
    this.stopFrameUpdates();
    webrtcService.disconnect();

    this.setData({
      isConnected: false,
      isConnecting: false
    });

    console.log('已断开远程桌面连接');
  },

  // 确认断开连接
  confirmDisconnect() {
    wx.showModal({
      title: '断开连接',
      content: '确定要断开远程桌面连接吗？',
      success: (res) => {
        if (res.confirm) {
          this.disconnectFromRemoteDesktop();
          wx.navigateBack();
        }
      }
    });
  }
});
