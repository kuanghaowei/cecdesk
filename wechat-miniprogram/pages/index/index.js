// pages/index/index.js
const app = getApp();

Page({
  data: {
    deviceId: '',
    accessCode: '',
    isConnecting: false,
    connectionHistory: [],
    currentDeviceId: '',
    isOnline: false
  },

  onLoad(options) {
    console.log('连接页面加载', options);
    
    // 获取设备ID
    this.setData({
      currentDeviceId: app.globalData.deviceId || '加载中...'
    });
    
    // 加载连接历史
    this.loadConnectionHistory();
    
    // 检查在线状态
    this.checkOnlineStatus();
  },

  onShow() {
    // 页面显示时刷新状态
    this.checkOnlineStatus();
  },

  // 设备ID输入
  onDeviceIdInput(e) {
    this.setData({
      deviceId: e.detail.value
    });
  },

  // 访问码输入
  onAccessCodeInput(e) {
    this.setData({
      accessCode: e.detail.value
    });
  },

  // 连接到远程设备
  async connectToDevice() {
    if (!this.data.deviceId.trim()) {
      wx.showToast({
        title: '请输入设备ID',
        icon: 'none'
      });
      return;
    }

    this.setData({
      isConnecting: true
    });

    try {
      // 检查网络状态
      const networkType = await this.checkNetwork();
      if (networkType === 'none') {
        throw new Error('网络连接失败');
      }

      // 创建WebRTC上下文
      const webrtcContext = app.createWebRTCContext();
      
      // 模拟连接过程
      await this.simulateConnection();
      
      // 保存连接历史
      this.saveConnectionHistory(this.data.deviceId);
      
      // 跳转到远程桌面页面
      wx.navigateTo({
        url: `/pages/remote-desktop/remote-desktop?deviceId=${this.data.deviceId}&accessCode=${this.data.accessCode}`
      });

    } catch (error) {
      console.error('连接失败:', error);
      wx.showModal({
        title: '连接失败',
        content: error.message || '无法连接到远程设备，请检查设备ID和网络连接',
        showCancel: false
      });
    } finally {
      this.setData({
        isConnecting: false
      });
    }
  },

  // 检查网络状态
  checkNetwork() {
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

  // 模拟连接过程
  simulateConnection() {
    return new Promise((resolve, reject) => {
      // 模拟连接延迟
      setTimeout(() => {
        // 90%的成功率用于演示
        if (Math.random() > 0.1) {
          resolve();
        } else {
          reject(new Error('连接超时'));
        }
      }, 2000);
    });
  },

  // 生成访问码
  generateAccessCode() {
    const accessCode = Math.random().toString().substr(2, 6);
    
    wx.showModal({
      title: '访问码已生成',
      content: `临时访问码: ${accessCode}\n\n此访问码10分钟内有效，请及时使用。`,
      confirmText: '复制',
      success: (res) => {
        if (res.confirm) {
          wx.setClipboardData({
            data: accessCode,
            success: () => {
              wx.showToast({
                title: '已复制到剪贴板',
                icon: 'success'
              });
            }
          });
        }
      }
    });
  },

  // 复制设备ID
  copyDeviceId() {
    wx.setClipboardData({
      data: this.data.currentDeviceId,
      success: () => {
        wx.showToast({
          title: '设备ID已复制',
          icon: 'success'
        });
      }
    });
  },

  // 加载连接历史
  loadConnectionHistory() {
    try {
      const history = wx.getStorageSync('connectionHistory') || [];
      this.setData({
        connectionHistory: history.slice(0, 5) // 只显示最近5条
      });
    } catch (error) {
      console.error('加载连接历史失败:', error);
    }
  },

  // 保存连接历史
  saveConnectionHistory(deviceId) {
    try {
      let history = wx.getStorageSync('connectionHistory') || [];
      
      // 移除重复项
      history = history.filter(item => item.deviceId !== deviceId);
      
      // 添加新记录
      history.unshift({
        deviceId: deviceId,
        timestamp: Date.now(),
        date: new Date().toLocaleString()
      });
      
      // 限制历史记录数量
      history = history.slice(0, 10);
      
      wx.setStorageSync('connectionHistory', history);
      this.loadConnectionHistory();
    } catch (error) {
      console.error('保存连接历史失败:', error);
    }
  },

  // 连接历史记录
  connectFromHistory(e) {
    const deviceId = e.currentTarget.dataset.deviceId;
    this.setData({
      deviceId: deviceId
    });
  },

  // 删除历史记录
  deleteHistory(e) {
    const deviceId = e.currentTarget.dataset.deviceId;
    
    wx.showModal({
      title: '确认删除',
      content: '确定要删除这条连接记录吗？',
      success: (res) => {
        if (res.confirm) {
          try {
            let history = wx.getStorageSync('connectionHistory') || [];
            history = history.filter(item => item.deviceId !== deviceId);
            wx.setStorageSync('connectionHistory', history);
            this.loadConnectionHistory();
            
            wx.showToast({
              title: '已删除',
              icon: 'success'
            });
          } catch (error) {
            console.error('删除历史记录失败:', error);
          }
        }
      }
    });
  },

  // 检查在线状态
  checkOnlineStatus() {
    // 模拟在线状态检查
    this.setData({
      isOnline: true
    });
  },

  // 扫码连接
  scanQRCode() {
    wx.scanCode({
      success: (res) => {
        console.log('扫码结果:', res);
        
        try {
          // 解析二维码内容
          const qrData = JSON.parse(res.result);
          if (qrData.deviceId) {
            this.setData({
              deviceId: qrData.deviceId,
              accessCode: qrData.accessCode || ''
            });
            
            wx.showToast({
              title: '扫码成功',
              icon: 'success'
            });
          } else {
            throw new Error('无效的二维码');
          }
        } catch (error) {
          // 如果不是JSON格式，直接作为设备ID使用
          this.setData({
            deviceId: res.result
          });
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
  }
});