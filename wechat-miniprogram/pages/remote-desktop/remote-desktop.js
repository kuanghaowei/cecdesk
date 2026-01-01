// pages/remote-desktop/remote-desktop.js
const app = getApp();

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
    lastTouchY: 0
  },

  onLoad(options) {
    console.log('远程桌面页面加载', options);
    
    this.setData({
      deviceId: options.deviceId || '',
      accessCode: options.accessCode || ''
    });
    
    // 初始化画布和播放器
    this.initCanvas();
    this.initLivePlayer();
    
    // 开始连接
    this.connectToRemoteDesktop();
  },

  onShow() {
    // 保持屏幕常亮
    wx.setKeepScreenOn({
      keepScreenOn: true
    });
  },

  onHide() {
    // 暂停连接但不断开
    this.pauseConnection();
  },

  onUnload() {
    // 断开连接
    this.disconnectFromRemoteDesktop();
    
    // 取消屏幕常亮
    wx.setKeepScreenOn({
      keepScreenOn: false
    });
  },

  // 初始化画布
  initCanvas() {
    const canvasContext = wx.createCanvasContext(this.data.canvasId, this);
    this.setData({
      canvasContext: canvasContext
    });
    
    // 设置画布背景
    canvasContext.setFillStyle('#000000');
    canvasContext.fillRect(0, 0, 375, 667); // 默认尺寸
    canvasContext.draw();
  },

  // 初始化实时播放器
  initLivePlayer() {
    const livePlayerContext = wx.createLivePlayerContext('livePlayer', this);
    this.setData({
      livePlayerContext: livePlayerContext
    });
    
    // 配置播放器事件
    livePlayerContext.onStateChange = this.onLivePlayerStateChange.bind(this);
    livePlayerContext.onNetStatus = this.onLivePlayerNetStatus.bind(this);
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

      // 创建WebRTC连接（使用小程序的实时音视频API）
      await this.createWebRTCConnection();

      // 模拟连接成功
      setTimeout(() => {
        this.setData({
          isConnected: true,
          isConnecting: false,
          connectionQuality: 'good',
          'networkStats.rtt': 45,
          'networkStats.fps': 30,
          'networkStats.resolution': '1080p'
        });

        wx.showToast({
          title: '连接成功',
          icon: 'success'
        });

        // 开始接收远程桌面数据
        this.startReceivingDesktopData();

      }, 2000);

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
    // 请求摄像头权限（用于屏幕共享）
    try {
      await this.requestPermission('scope.camera');
    } catch (error) {
      console.warn('摄像头权限请求失败:', error);
    }

    // 请求录音权限（用于音频传输）
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

  // 创建WebRTC连接
  async createWebRTCConnection() {
    // 在实际实现中，这里会使用微信小程序的WebRTC API
    // 例如：wx.createLivePusherContext() 和 wx.createLivePlayerContext()
    
    console.log('创建WebRTC连接到设备:', this.data.deviceId);
    
    // 模拟WebRTC连接建立过程
    return new Promise((resolve) => {
      setTimeout(resolve, 1000);
    });
  },

  // 开始接收远程桌面数据
  startReceivingDesktopData() {
    // 模拟接收远程桌面帧数据
    this.desktopDataInterval = setInterval(() => {
      this.updateDesktopFrame();
      this.updateNetworkStats();
    }, 33); // 约30FPS
  },

  // 更新桌面帧
  updateDesktopFrame() {
    if (!this.data.canvasContext || !this.data.isConnected) {
      return;
    }

    // 模拟绘制远程桌面内容
    const ctx = this.data.canvasContext;
    
    // 绘制模拟的桌面背景
    ctx.setFillStyle('#1e1e1e');
    ctx.fillRect(0, 0, 375, 667);
    
    // 绘制模拟的窗口
    ctx.setFillStyle('#2d2d30');
    ctx.fillRect(50, 100, 275, 200);
    
    // 绘制标题栏
    ctx.setFillStyle('#007acc');
    ctx.fillRect(50, 100, 275, 30);
    
    // 绘制文本
    ctx.setFillStyle('#ffffff');
    ctx.setFontSize(14);
    ctx.fillText('远程桌面 - ' + this.data.deviceId, 60, 120);
    
    // 绘制连接状态指示器
    const now = Date.now();
    const alpha = (Math.sin(now / 500) + 1) / 2; // 呼吸效果
    ctx.setGlobalAlpha(alpha);
    ctx.setFillStyle('#00ff00');
    ctx.beginPath();
    ctx.arc(320, 50, 8, 0, 2 * Math.PI);
    ctx.fill();
    ctx.setGlobalAlpha(1);
    
    ctx.draw();
  },

  // 更新网络统计
  updateNetworkStats() {
    const rtt = 40 + Math.random() * 20; // 40-60ms
    const fps = 28 + Math.random() * 4; // 28-32fps
    
    this.setData({
      'networkStats.rtt': Math.round(rtt),
      'networkStats.fps': Math.round(fps)
    });

    // 根据RTT更新连接质量
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
  onTouchStart(e) {
    if (!this.data.isConnected) return;

    const touch = e.touches[0];
    this.setData({
      touchStartTime: Date.now(),
      lastTouchX: touch.x,
      lastTouchY: touch.y
    });
  },

  // 触摸移动
  onTouchMove(e) {
    if (!this.data.isConnected) return;

    const touch = e.touches[0];
    const deltaX = touch.x - this.data.lastTouchX;
    const deltaY = touch.y - this.data.lastTouchY;

    // 发送鼠标移动事件到远程设备
    this.sendMouseMove(touch.x, touch.y, deltaX, deltaY);

    this.setData({
      lastTouchX: touch.x,
      lastTouchY: touch.y
    });
  },

  // 触摸结束
  onTouchEnd(e) {
    if (!this.data.isConnected) return;

    const touchDuration = Date.now() - this.data.touchStartTime;
    const touch = e.changedTouches[0];

    if (touchDuration < 200) {
      // 短按 - 鼠标左键点击
      this.sendMouseClick('left', touch.x, touch.y);
    }
  },

  // 长按事件
  onLongPress(e) {
    if (!this.data.isConnected) return;

    const touch = e.touches[0];
    // 长按 - 鼠标右键点击
    this.sendMouseClick('right', touch.x, touch.y);

    // 触觉反馈
    wx.vibrateShort();
  },

  // 发送鼠标移动
  sendMouseMove(x, y, deltaX, deltaY) {
    console.log('发送鼠标移动:', { x, y, deltaX, deltaY });
    // 实际实现中会通过WebRTC数据通道发送
  },

  // 发送鼠标点击
  sendMouseClick(button, x, y) {
    console.log('发送鼠标点击:', { button, x, y });
    // 实际实现中会通过WebRTC数据通道发送
    
    // 显示点击反馈
    this.showClickFeedback(x, y);
  },

  // 显示点击反馈
  showClickFeedback(x, y) {
    // 在点击位置显示短暂的视觉反馈
    const ctx = this.data.canvasContext;
    ctx.setStrokeStyle('#ffffff');
    ctx.setLineWidth(2);
    ctx.beginPath();
    ctx.arc(x, y, 20, 0, 2 * Math.PI);
    ctx.stroke();
    ctx.draw(true);

    // 0.2秒后清除反馈
    setTimeout(() => {
      this.updateDesktopFrame();
    }, 200);
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
    console.log('发送键盘输入:', text);
    // 实际实现中会通过WebRTC数据通道发送
    
    wx.showToast({
      title: '文本已发送',
      icon: 'success'
    });
  },

  // 截图
  takeScreenshot() {
    wx.canvasToTempFilePath({
      canvasId: this.data.canvasId,
      success: (res) => {
        wx.saveImageToPhotosAlbum({
          filePath: res.tempFilePath,
          success: () => {
            wx.showToast({
              title: '截图已保存',
              icon: 'success'
            });
          },
          fail: (error) => {
            console.error('保存截图失败:', error);
            wx.showToast({
              title: '保存失败',
              icon: 'none'
            });
          }
        });
      },
      fail: (error) => {
        console.error('截图失败:', error);
        wx.showToast({
          title: '截图失败',
          icon: 'none'
        });
      }
    }, this);
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
        const qualities = ['1080p', '720p', '480p'];
        const selectedQuality = qualities[res.tapIndex];
        
        this.setData({
          'networkStats.resolution': selectedQuality
        });
        
        wx.showToast({
          title: `已切换到${selectedQuality}`,
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
      content: `设备ID: ${this.data.deviceId}\n连接状态: ${this.data.isConnected ? '已连接' : '未连接'}\n连接时间: ${this.getConnectionDuration()}`,
      showCancel: false
    });
  },

  // 获取连接持续时间
  getConnectionDuration() {
    // 简化实现，实际应该记录连接开始时间
    return '00:05:23';
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
    if (this.desktopDataInterval) {
      clearInterval(this.desktopDataInterval);
      this.desktopDataInterval = null;
    }
    
    console.log('连接已暂停');
  },

  // 恢复连接
  resumeConnection() {
    if (this.data.isConnected && !this.desktopDataInterval) {
      this.startReceivingDesktopData();
      console.log('连接已恢复');
    }
  },

  // 断开连接
  disconnectFromRemoteDesktop() {
    // 清理定时器
    if (this.desktopDataInterval) {
      clearInterval(this.desktopDataInterval);
      this.desktopDataInterval = null;
    }

    // 关闭WebRTC连接
    if (this.data.livePlayerContext) {
      this.data.livePlayerContext.stop();
    }

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