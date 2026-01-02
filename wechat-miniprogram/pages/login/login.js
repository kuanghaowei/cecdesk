// pages/login/login.js
const app = getApp();

Page({
  data: {
    isLoggedIn: false,
    userInfo: null,
    loginMethod: '', // wechat, phone
    phoneNumber: '',
    verificationCode: '',
    countdown: 0,
    isLoading: false,
    canGetPhoneNumber: false
  },

  onLoad(options) {
    console.log('登录页面加载', options);
    
    // 检查登录状态
    this.checkLoginStatus();
    
    // 检查是否支持获取手机号
    this.checkPhoneNumberCapability();
  },

  onShow() {
    // 刷新登录状态
    this.checkLoginStatus();
  },

  // 检查登录状态
  checkLoginStatus() {
    const loginInfo = wx.getStorageSync('loginInfo');
    if (loginInfo && loginInfo.token) {
      this.setData({
        isLoggedIn: true,
        userInfo: loginInfo.userInfo
      });
    }
  },

  // 检查手机号获取能力
  checkPhoneNumberCapability() {
    // 微信小程序支持获取手机号
    this.setData({
      canGetPhoneNumber: true
    });
  },

  // 微信一键登录
  wechatLogin() {
    this.setData({ isLoading: true });
    
    wx.getUserProfile({
      desc: '用于完善用户资料',
      success: (res) => {
        console.log('获取用户信息成功:', res);
        this.performWechatLogin(res.userInfo);
      },
      fail: (error) => {
        console.error('获取用户信息失败:', error);
        this.setData({ isLoading: false });
        wx.showToast({
          title: '授权失败',
          icon: 'none'
        });
      }
    });
  },

  // 执行微信登录
  performWechatLogin(userInfo) {
    wx.login({
      success: (loginRes) => {
        if (loginRes.code) {
          // 模拟发送code到服务器换取登录凭证
          this.simulateServerLogin(loginRes.code, userInfo);
        } else {
          this.setData({ isLoading: false });
          wx.showToast({
            title: '登录失败',
            icon: 'none'
          });
        }
      },
      fail: (error) => {
        console.error('wx.login失败:', error);
        this.setData({ isLoading: false });
        wx.showToast({
          title: '登录失败',
          icon: 'none'
        });
      }
    });
  },

  // 模拟服务器登录
  simulateServerLogin(code, userInfo) {
    // 模拟网络请求延迟
    setTimeout(() => {
      const loginInfo = {
        token: 'mock_token_' + Date.now(),
        userId: 'user_' + Math.random().toString(36).substr(2, 9),
        userInfo: userInfo,
        loginTime: Date.now(),
        expiresAt: Date.now() + 30 * 24 * 60 * 60 * 1000 // 30天过期
      };
      
      // 保存登录信息
      wx.setStorageSync('loginInfo', loginInfo);
      
      this.setData({
        isLoggedIn: true,
        userInfo: userInfo,
        isLoading: false
      });
      
      wx.showToast({
        title: '登录成功',
        icon: 'success'
      });
      
      // 跳转到连接页面
      setTimeout(() => {
        wx.switchTab({
          url: '/pages/connection/connection'
        });
      }, 1500);
    }, 1500);
  },

  // 获取手机号
  getPhoneNumber(e) {
    if (e.detail.errMsg === 'getPhoneNumber:ok') {
      console.log('获取手机号成功:', e.detail);
      
      // 模拟解密手机号
      this.setData({ isLoading: true });
      
      setTimeout(() => {
        const mockPhoneNumber = '138****8888';
        this.performPhoneLogin(mockPhoneNumber);
      }, 1000);
    } else {
      console.error('获取手机号失败:', e.detail.errMsg);
      wx.showToast({
        title: '获取手机号失败',
        icon: 'none'
      });
    }
  },

  // 手机号登录
  performPhoneLogin(phoneNumber) {
    const loginInfo = {
      token: 'mock_token_' + Date.now(),
      userId: 'user_' + Math.random().toString(36).substr(2, 9),
      userInfo: {
        nickName: '用户' + phoneNumber.substr(-4),
        avatarUrl: '',
        phoneNumber: phoneNumber
      },
      loginTime: Date.now(),
      expiresAt: Date.now() + 30 * 24 * 60 * 60 * 1000
    };
    
    wx.setStorageSync('loginInfo', loginInfo);
    
    this.setData({
      isLoggedIn: true,
      userInfo: loginInfo.userInfo,
      isLoading: false
    });
    
    wx.showToast({
      title: '登录成功',
      icon: 'success'
    });
    
    setTimeout(() => {
      wx.switchTab({
        url: '/pages/connection/connection'
      });
    }, 1500);
  },

  // 输入手机号
  onPhoneInput(e) {
    this.setData({
      phoneNumber: e.detail.value
    });
  },

  // 输入验证码
  onCodeInput(e) {
    this.setData({
      verificationCode: e.detail.value
    });
  },

  // 发送验证码
  sendVerificationCode() {
    const { phoneNumber, countdown } = this.data;
    
    if (countdown > 0) return;
    
    if (!phoneNumber || phoneNumber.length !== 11) {
      wx.showToast({
        title: '请输入正确的手机号',
        icon: 'none'
      });
      return;
    }
    
    // 模拟发送验证码
    wx.showLoading({ title: '发送中...' });
    
    setTimeout(() => {
      wx.hideLoading();
      wx.showToast({
        title: '验证码已发送',
        icon: 'success'
      });
      
      // 开始倒计时
      this.startCountdown();
    }, 1000);
  },

  // 开始倒计时
  startCountdown() {
    this.setData({ countdown: 60 });
    
    const timer = setInterval(() => {
      const countdown = this.data.countdown - 1;
      this.setData({ countdown });
      
      if (countdown <= 0) {
        clearInterval(timer);
      }
    }, 1000);
  },

  // 验证码登录
  verifyCodeLogin() {
    const { phoneNumber, verificationCode } = this.data;
    
    if (!phoneNumber || phoneNumber.length !== 11) {
      wx.showToast({
        title: '请输入正确的手机号',
        icon: 'none'
      });
      return;
    }
    
    if (!verificationCode || verificationCode.length !== 6) {
      wx.showToast({
        title: '请输入6位验证码',
        icon: 'none'
      });
      return;
    }
    
    this.setData({ isLoading: true });
    
    // 模拟验证
    setTimeout(() => {
      // 模拟验证码验证（实际应该调用服务器API）
      if (verificationCode === '123456') {
        this.performPhoneLogin(phoneNumber);
      } else {
        this.setData({ isLoading: false });
        wx.showToast({
          title: '验证码错误',
          icon: 'none'
        });
      }
    }, 1500);
  },

  // 退出登录
  logout() {
    wx.showModal({
      title: '退出登录',
      content: '确定要退出登录吗？',
      success: (res) => {
        if (res.confirm) {
          wx.removeStorageSync('loginInfo');
          this.setData({
            isLoggedIn: false,
            userInfo: null
          });
          
          wx.showToast({
            title: '已退出登录',
            icon: 'success'
          });
        }
      }
    });
  },

  // 切换登录方式
  switchLoginMethod(e) {
    const method = e.currentTarget.dataset.method;
    this.setData({
      loginMethod: method
    });
  }
});
