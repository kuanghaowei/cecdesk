/**
 * Touch Input Handler for WeChat MiniProgram
 * 微信小程序触摸输入处理器
 * 
 * 将触摸事件转换为鼠标和键盘操作
 * 验证: 需求 15.4 - 通过触摸事件模拟鼠标和键盘操作
 */

class TouchInputHandler {
  constructor() {
    this.webrtcService = null;
    this.canvasRenderer = null;
    
    // 触摸状态
    this.touchState = {
      isActive: false,
      startTime: 0,
      startX: 0,
      startY: 0,
      lastX: 0,
      lastY: 0,
      touchCount: 0,
      lastTapTime: 0,
      tapCount: 0
    };
    
    // 手势配置
    this.config = {
      tapThreshold: 200,        // 点击时间阈值 (ms)
      doubleTapThreshold: 300,  // 双击时间阈值 (ms)
      longPressThreshold: 500,  // 长按时间阈值 (ms)
      moveThreshold: 10,        // 移动距离阈值 (px)
      scrollSensitivity: 2,     // 滚动灵敏度
      pinchSensitivity: 1.5     // 缩放灵敏度
    };
    
    // 远程桌面尺寸
    this.remoteWidth = 1920;
    this.remoteHeight = 1080;
    
    // 长按定时器
    this.longPressTimer = null;
    
    // 事件处理器
    this.eventHandlers = {};
  }

  /**
   * 初始化触摸输入处理器
   * @param {Object} webrtcService WebRTC服务实例
   * @param {Object} canvasRenderer 画布渲染器实例
   * @param {Object} options 配置选项
   */
  init(webrtcService, canvasRenderer, options = {}) {
    this.webrtcService = webrtcService;
    this.canvasRenderer = canvasRenderer;
    
    // 合并配置
    this.config = { ...this.config, ...options };
    
    // 设置远程桌面尺寸
    if (options.remoteWidth) this.remoteWidth = options.remoteWidth;
    if (options.remoteHeight) this.remoteHeight = options.remoteHeight;
    
    console.log('[TouchInputHandler] 初始化完成', this.config);
    return this;
  }

  /**
   * 设置远程桌面尺寸
   * @param {number} width 宽度
   * @param {number} height 高度
   */
  setRemoteSize(width, height) {
    this.remoteWidth = width;
    this.remoteHeight = height;
  }

  /**
   * 处理触摸开始事件
   * @param {Object} event 触摸事件
   */
  handleTouchStart(event) {
    const touch = event.touches[0];
    const now = Date.now();
    
    this.touchState = {
      isActive: true,
      startTime: now,
      startX: touch.x,
      startY: touch.y,
      lastX: touch.x,
      lastY: touch.y,
      touchCount: event.touches.length,
      lastTapTime: this.touchState.lastTapTime,
      tapCount: this.touchState.tapCount
    };
    
    // 开始长按检测
    this.startLongPressDetection(touch.x, touch.y);
    
    // 触发事件
    this.emit('touchStart', {
      x: touch.x,
      y: touch.y,
      touchCount: event.touches.length
    });
    
    console.log('[TouchInputHandler] 触摸开始', { x: touch.x, y: touch.y });
  }

  /**
   * 处理触摸移动事件
   * @param {Object} event 触摸事件
   */
  handleTouchMove(event) {
    if (!this.touchState.isActive) return;
    
    const touch = event.touches[0];
    const deltaX = touch.x - this.touchState.lastX;
    const deltaY = touch.y - this.touchState.lastY;
    
    // 取消长按检测（因为有移动）
    this.cancelLongPressDetection();
    
    // 检查是否超过移动阈值
    const totalDeltaX = touch.x - this.touchState.startX;
    const totalDeltaY = touch.y - this.touchState.startY;
    const distance = Math.sqrt(totalDeltaX * totalDeltaX + totalDeltaY * totalDeltaY);
    
    if (distance > this.config.moveThreshold) {
      // 处理不同的手势
      if (this.touchState.touchCount === 1) {
        // 单指移动 -> 鼠标移动
        this.handleMouseMove(touch.x, touch.y, deltaX, deltaY);
      } else if (this.touchState.touchCount === 2) {
        // 双指移动 -> 滚动
        this.handleScroll(deltaX, deltaY);
      }
    }
    
    // 更新最后位置
    this.touchState.lastX = touch.x;
    this.touchState.lastY = touch.y;
    
    // 触发事件
    this.emit('touchMove', {
      x: touch.x,
      y: touch.y,
      deltaX: deltaX,
      deltaY: deltaY
    });
  }

  /**
   * 处理触摸结束事件
   * @param {Object} event 触摸事件
   */
  handleTouchEnd(event) {
    if (!this.touchState.isActive) return;
    
    const touch = event.changedTouches[0];
    const now = Date.now();
    const duration = now - this.touchState.startTime;
    
    // 取消长按检测
    this.cancelLongPressDetection();
    
    // 计算移动距离
    const deltaX = touch.x - this.touchState.startX;
    const deltaY = touch.y - this.touchState.startY;
    const distance = Math.sqrt(deltaX * deltaX + deltaY * deltaY);
    
    // 判断手势类型
    if (distance < this.config.moveThreshold) {
      // 没有明显移动，判断为点击
      if (duration < this.config.tapThreshold) {
        // 检查是否为双击
        if (now - this.touchState.lastTapTime < this.config.doubleTapThreshold) {
          this.handleDoubleTap(touch.x, touch.y);
          this.touchState.tapCount = 0;
        } else {
          this.handleTap(touch.x, touch.y);
          this.touchState.tapCount = 1;
        }
        this.touchState.lastTapTime = now;
      }
    }
    
    // 重置触摸状态
    this.touchState.isActive = false;
    
    // 触发事件
    this.emit('touchEnd', {
      x: touch.x,
      y: touch.y,
      duration: duration,
      distance: distance
    });
    
    console.log('[TouchInputHandler] 触摸结束', { duration, distance });
  }

  /**
   * 处理长按事件
   * @param {Object} event 触摸事件
   */
  handleLongPress(event) {
    const touch = event.touches[0];
    
    // 取消长按定时器
    this.cancelLongPressDetection();
    
    // 发送右键点击
    this.handleRightClick(touch.x, touch.y);
    
    // 触觉反馈
    wx.vibrateShort({ type: 'medium' });
    
    // 触发事件
    this.emit('longPress', {
      x: touch.x,
      y: touch.y
    });
    
    console.log('[TouchInputHandler] 长按', { x: touch.x, y: touch.y });
  }

  /**
   * 开始长按检测
   * @param {number} x X坐标
   * @param {number} y Y坐标
   */
  startLongPressDetection(x, y) {
    this.cancelLongPressDetection();
    
    this.longPressTimer = setTimeout(() => {
      if (this.touchState.isActive) {
        // 检查是否有明显移动
        const deltaX = this.touchState.lastX - this.touchState.startX;
        const deltaY = this.touchState.lastY - this.touchState.startY;
        const distance = Math.sqrt(deltaX * deltaX + deltaY * deltaY);
        
        if (distance < this.config.moveThreshold) {
          this.handleRightClick(x, y);
          wx.vibrateShort({ type: 'medium' });
          this.emit('longPress', { x, y });
        }
      }
    }, this.config.longPressThreshold);
  }

  /**
   * 取消长按检测
   */
  cancelLongPressDetection() {
    if (this.longPressTimer) {
      clearTimeout(this.longPressTimer);
      this.longPressTimer = null;
    }
  }

  /**
   * 处理单击
   * @param {number} x X坐标
   * @param {number} y Y坐标
   */
  handleTap(x, y) {
    const remoteCoords = this.convertToRemoteCoords(x, y);
    
    // 发送鼠标左键点击
    if (this.webrtcService) {
      this.webrtcService.sendMouseClick('left', remoteCoords.x, remoteCoords.y);
    }
    
    // 显示点击反馈
    if (this.canvasRenderer) {
      this.canvasRenderer.showClickFeedback(x, y, 'left');
    }
    
    this.emit('tap', { x, y, remoteX: remoteCoords.x, remoteY: remoteCoords.y });
    console.log('[TouchInputHandler] 单击 -> 左键点击', remoteCoords);
  }

  /**
   * 处理双击
   * @param {number} x X坐标
   * @param {number} y Y坐标
   */
  handleDoubleTap(x, y) {
    const remoteCoords = this.convertToRemoteCoords(x, y);
    
    // 发送双击（两次左键点击）
    if (this.webrtcService) {
      this.webrtcService.sendMouseClick('left', remoteCoords.x, remoteCoords.y);
      setTimeout(() => {
        this.webrtcService.sendMouseClick('left', remoteCoords.x, remoteCoords.y);
      }, 50);
    }
    
    // 显示点击反馈
    if (this.canvasRenderer) {
      this.canvasRenderer.showClickFeedback(x, y, 'left');
    }
    
    this.emit('doubleTap', { x, y, remoteX: remoteCoords.x, remoteY: remoteCoords.y });
    console.log('[TouchInputHandler] 双击', remoteCoords);
  }

  /**
   * 处理右键点击（长按）
   * @param {number} x X坐标
   * @param {number} y Y坐标
   */
  handleRightClick(x, y) {
    const remoteCoords = this.convertToRemoteCoords(x, y);
    
    // 发送鼠标右键点击
    if (this.webrtcService) {
      this.webrtcService.sendMouseClick('right', remoteCoords.x, remoteCoords.y);
    }
    
    // 显示点击反馈
    if (this.canvasRenderer) {
      this.canvasRenderer.showClickFeedback(x, y, 'right');
    }
    
    this.emit('rightClick', { x, y, remoteX: remoteCoords.x, remoteY: remoteCoords.y });
    console.log('[TouchInputHandler] 长按 -> 右键点击', remoteCoords);
  }

  /**
   * 处理鼠标移动
   * @param {number} x X坐标
   * @param {number} y Y坐标
   * @param {number} deltaX X偏移
   * @param {number} deltaY Y偏移
   */
  handleMouseMove(x, y, deltaX, deltaY) {
    const remoteCoords = this.convertToRemoteCoords(x, y);
    const remoteDelta = this.convertDeltaToRemote(deltaX, deltaY);
    
    // 发送鼠标移动
    if (this.webrtcService) {
      this.webrtcService.sendMouseMove(
        remoteCoords.x, 
        remoteCoords.y, 
        remoteDelta.x, 
        remoteDelta.y
      );
    }
    
    this.emit('mouseMove', { 
      x, y, 
      deltaX, deltaY,
      remoteX: remoteCoords.x, 
      remoteY: remoteCoords.y 
    });
  }

  /**
   * 处理滚动
   * @param {number} deltaX X偏移
   * @param {number} deltaY Y偏移
   */
  handleScroll(deltaX, deltaY) {
    const scrollX = deltaX * this.config.scrollSensitivity;
    const scrollY = deltaY * this.config.scrollSensitivity;
    
    // 发送滚轮事件
    if (this.webrtcService) {
      this.webrtcService.sendDataChannelMessage({
        type: 'mouse_wheel',
        deltaX: scrollX,
        deltaY: scrollY,
        timestamp: Date.now()
      });
    }
    
    this.emit('scroll', { deltaX: scrollX, deltaY: scrollY });
    console.log('[TouchInputHandler] 双指滚动', { scrollX, scrollY });
  }

  /**
   * 发送键盘输入
   * @param {string} text 文本内容
   */
  sendKeyboardInput(text) {
    if (!text) return;
    
    if (this.webrtcService) {
      this.webrtcService.sendTextInput(text);
    }
    
    this.emit('keyboardInput', { text });
    console.log('[TouchInputHandler] 键盘输入:', text);
  }

  /**
   * 发送特殊按键
   * @param {string} key 按键名称
   * @param {Object} modifiers 修饰键
   */
  sendSpecialKey(key, modifiers = {}) {
    if (this.webrtcService) {
      this.webrtcService.sendKeyboardInput(key, modifiers);
    }
    
    this.emit('specialKey', { key, modifiers });
    console.log('[TouchInputHandler] 特殊按键:', key, modifiers);
  }

  /**
   * 转换为远程坐标
   * @param {number} x 本地X坐标
   * @param {number} y 本地Y坐标
   * @returns {Object} 远程坐标
   */
  convertToRemoteCoords(x, y) {
    if (this.canvasRenderer) {
      return this.canvasRenderer.screenToRemote(x, y, this.remoteWidth, this.remoteHeight);
    }
    
    // 默认转换
    const screenWidth = 375;  // 默认屏幕宽度
    const screenHeight = 667; // 默认屏幕高度
    
    return {
      x: Math.round(x * this.remoteWidth / screenWidth),
      y: Math.round(y * this.remoteHeight / screenHeight)
    };
  }

  /**
   * 转换偏移量为远程坐标系
   * @param {number} deltaX X偏移
   * @param {number} deltaY Y偏移
   * @returns {Object} 远程偏移量
   */
  convertDeltaToRemote(deltaX, deltaY) {
    const screenWidth = this.canvasRenderer ? this.canvasRenderer.width : 375;
    const screenHeight = this.canvasRenderer ? this.canvasRenderer.height : 667;
    
    return {
      x: Math.round(deltaX * this.remoteWidth / screenWidth),
      y: Math.round(deltaY * this.remoteHeight / screenHeight)
    };
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
          console.error('[TouchInputHandler] 事件处理器错误:', error);
        }
      });
    }
  }

  /**
   * 销毁处理器
   */
  destroy() {
    this.cancelLongPressDetection();
    this.eventHandlers = {};
    this.webrtcService = null;
    this.canvasRenderer = null;
    console.log('[TouchInputHandler] 已销毁');
  }
}

// 导出
module.exports = {
  TouchInputHandler
};
