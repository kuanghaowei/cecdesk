/**
 * Canvas Renderer for WeChat MiniProgram
 * 微信小程序画布渲染器
 * 
 * 用于在画布上渲染远程桌面视频帧
 * 验证: 需求 15.3 - 适配小程序的画布组件进行屏幕显示
 */

class CanvasRenderer {
  constructor() {
    this.canvasContext = null;
    this.canvasId = null;
    this.component = null;
    this.width = 0;
    this.height = 0;
    this.isRendering = false;
    this.frameBuffer = [];
    this.maxBufferSize = 3;
    this.lastFrameTime = 0;
    this.fps = 0;
    this.frameCount = 0;
    this.fpsUpdateInterval = null;
  }

  /**
   * 初始化画布渲染器
   * @param {string} canvasId 画布组件ID
   * @param {Object} component 组件实例
   * @param {Object} options 配置选项
   */
  init(canvasId, component, options = {}) {
    this.canvasId = canvasId;
    this.component = component;
    this.width = options.width || 375;
    this.height = options.height || 667;
    
    // 创建画布上下文
    this.canvasContext = wx.createCanvasContext(canvasId, component);
    
    // 初始化画布背景
    this.clearCanvas();
    
    // 开始FPS计算
    this.startFPSCounter();
    
    console.log('[CanvasRenderer] 初始化完成', { canvasId, width: this.width, height: this.height });
    return this;
  }

  /**
   * 设置画布尺寸
   * @param {number} width 宽度
   * @param {number} height 高度
   */
  setSize(width, height) {
    this.width = width;
    this.height = height;
    console.log('[CanvasRenderer] 设置尺寸:', { width, height });
  }

  /**
   * 清空画布
   */
  clearCanvas() {
    if (!this.canvasContext) return;
    
    this.canvasContext.setFillStyle('#1e1e1e');
    this.canvasContext.fillRect(0, 0, this.width, this.height);
    this.canvasContext.draw();
  }

  /**
   * 渲染视频帧
   * @param {Object} frame 帧数据
   */
  renderFrame(frame) {
    if (!this.canvasContext || !frame) return;
    
    // 添加到帧缓冲
    this.frameBuffer.push(frame);
    
    // 限制缓冲区大小
    if (this.frameBuffer.length > this.maxBufferSize) {
      this.frameBuffer.shift();
    }
    
    // 如果没有在渲染，开始渲染
    if (!this.isRendering) {
      this.processFrameBuffer();
    }
  }

  /**
   * 处理帧缓冲区
   */
  processFrameBuffer() {
    if (this.frameBuffer.length === 0) {
      this.isRendering = false;
      return;
    }
    
    this.isRendering = true;
    const frame = this.frameBuffer.shift();
    
    // 渲染帧
    this.drawFrame(frame);
    
    // 更新帧计数
    this.frameCount++;
    
    // 继续处理下一帧
    requestAnimationFrame(() => {
      this.processFrameBuffer();
    });
  }

  /**
   * 绘制单帧
   * @param {Object} frame 帧数据
   */
  drawFrame(frame) {
    const ctx = this.canvasContext;
    
    if (frame.type === 'image') {
      // 绘制图片帧
      this.drawImageFrame(frame);
    } else if (frame.type === 'raw') {
      // 绘制原始像素数据
      this.drawRawFrame(frame);
    } else {
      // 绘制模拟帧
      this.drawSimulatedFrame(frame);
    }
    
    ctx.draw(false);
    this.lastFrameTime = Date.now();
  }

  /**
   * 绘制图片帧
   * @param {Object} frame 帧数据
   */
  drawImageFrame(frame) {
    const ctx = this.canvasContext;
    
    // 计算缩放比例以适应画布
    const scaleX = this.width / frame.width;
    const scaleY = this.height / frame.height;
    const scale = Math.min(scaleX, scaleY);
    
    const drawWidth = frame.width * scale;
    const drawHeight = frame.height * scale;
    const offsetX = (this.width - drawWidth) / 2;
    const offsetY = (this.height - drawHeight) / 2;
    
    // 清空画布
    ctx.setFillStyle('#000000');
    ctx.fillRect(0, 0, this.width, this.height);
    
    // 绘制图片
    ctx.drawImage(frame.data, offsetX, offsetY, drawWidth, drawHeight);
  }

  /**
   * 绘制原始像素帧
   * @param {Object} frame 帧数据
   */
  drawRawFrame(frame) {
    // 微信小程序不直接支持 ImageData
    // 需要将原始数据转换为图片格式
    console.log('[CanvasRenderer] 原始帧渲染暂不支持');
  }

  /**
   * 绘制模拟帧（用于测试）
   * @param {Object} frame 帧数据
   */
  drawSimulatedFrame(frame) {
    const ctx = this.canvasContext;
    const now = Date.now();
    
    // 绘制背景
    ctx.setFillStyle('#1e1e1e');
    ctx.fillRect(0, 0, this.width, this.height);
    
    // 绘制模拟窗口
    ctx.setFillStyle('#2d2d30');
    ctx.fillRect(20, 60, this.width - 40, 200);
    
    // 绘制标题栏
    ctx.setFillStyle('#007acc');
    ctx.fillRect(20, 60, this.width - 40, 30);
    
    // 绘制标题文本
    ctx.setFillStyle('#ffffff');
    ctx.setFontSize(14);
    ctx.fillText('远程桌面 - ' + (frame.deviceId || '未知设备'), 30, 80);
    
    // 绘制内容区域
    ctx.setFillStyle('#ffffff');
    ctx.setFontSize(12);
    ctx.fillText('连接状态: 已连接', 30, 120);
    ctx.fillText('帧率: ' + this.fps + ' FPS', 30, 140);
    ctx.fillText('时间: ' + new Date().toLocaleTimeString(), 30, 160);
    
    // 绘制连接状态指示器（呼吸效果）
    const alpha = (Math.sin(now / 500) + 1) / 2;
    ctx.setGlobalAlpha(alpha);
    ctx.setFillStyle('#00ff00');
    ctx.beginPath();
    ctx.arc(this.width - 40, 40, 8, 0, 2 * Math.PI);
    ctx.fill();
    ctx.setGlobalAlpha(1);
    
    // 绘制任务栏
    ctx.setFillStyle('#333333');
    ctx.fillRect(0, this.height - 40, this.width, 40);
    
    // 绘制任务栏图标
    ctx.setFillStyle('#ffffff');
    ctx.setFontSize(20);
    ctx.fillText('🖥️', 20, this.height - 15);
    ctx.fillText('📁', 60, this.height - 15);
    ctx.fillText('🌐', 100, this.height - 15);
  }

  /**
   * 显示点击反馈
   * @param {number} x X坐标
   * @param {number} y Y坐标
   * @param {string} type 点击类型
   */
  showClickFeedback(x, y, type = 'left') {
    const ctx = this.canvasContext;
    
    // 绘制点击圆圈
    ctx.setStrokeStyle(type === 'left' ? '#ffffff' : '#ff6600');
    ctx.setLineWidth(2);
    ctx.beginPath();
    ctx.arc(x, y, 20, 0, 2 * Math.PI);
    ctx.stroke();
    ctx.draw(true);
    
    // 0.3秒后清除反馈
    setTimeout(() => {
      // 重新绘制当前帧
      if (this.frameBuffer.length > 0) {
        this.drawFrame(this.frameBuffer[this.frameBuffer.length - 1]);
      }
    }, 300);
  }

  /**
   * 显示拖拽轨迹
   * @param {Array} points 轨迹点数组
   */
  showDragTrail(points) {
    if (!points || points.length < 2) return;
    
    const ctx = this.canvasContext;
    
    ctx.setStrokeStyle('rgba(255, 255, 255, 0.5)');
    ctx.setLineWidth(2);
    ctx.setLineCap('round');
    ctx.setLineJoin('round');
    
    ctx.beginPath();
    ctx.moveTo(points[0].x, points[0].y);
    
    for (let i = 1; i < points.length; i++) {
      ctx.lineTo(points[i].x, points[i].y);
    }
    
    ctx.stroke();
    ctx.draw(true);
  }

  /**
   * 开始FPS计数器
   */
  startFPSCounter() {
    this.fpsUpdateInterval = setInterval(() => {
      this.fps = this.frameCount;
      this.frameCount = 0;
    }, 1000);
  }

  /**
   * 停止FPS计数器
   */
  stopFPSCounter() {
    if (this.fpsUpdateInterval) {
      clearInterval(this.fpsUpdateInterval);
      this.fpsUpdateInterval = null;
    }
  }

  /**
   * 获取当前FPS
   * @returns {number}
   */
  getFPS() {
    return this.fps;
  }

  /**
   * 截图
   * @returns {Promise<string>} 临时文件路径
   */
  takeScreenshot() {
    return new Promise((resolve, reject) => {
      wx.canvasToTempFilePath({
        canvasId: this.canvasId,
        success: (res) => {
          console.log('[CanvasRenderer] 截图成功:', res.tempFilePath);
          resolve(res.tempFilePath);
        },
        fail: (error) => {
          console.error('[CanvasRenderer] 截图失败:', error);
          reject(error);
        }
      }, this.component);
    });
  }

  /**
   * 保存截图到相册
   * @returns {Promise<void>}
   */
  async saveScreenshotToAlbum() {
    try {
      const tempFilePath = await this.takeScreenshot();
      
      return new Promise((resolve, reject) => {
        wx.saveImageToPhotosAlbum({
          filePath: tempFilePath,
          success: () => {
            console.log('[CanvasRenderer] 截图已保存到相册');
            resolve();
          },
          fail: (error) => {
            console.error('[CanvasRenderer] 保存截图失败:', error);
            reject(error);
          }
        });
      });
    } catch (error) {
      throw error;
    }
  }

  /**
   * 坐标转换：屏幕坐标 -> 远程桌面坐标
   * @param {number} screenX 屏幕X坐标
   * @param {number} screenY 屏幕Y坐标
   * @param {number} remoteWidth 远程桌面宽度
   * @param {number} remoteHeight 远程桌面高度
   * @returns {Object} 远程桌面坐标
   */
  screenToRemote(screenX, screenY, remoteWidth, remoteHeight) {
    const scaleX = remoteWidth / this.width;
    const scaleY = remoteHeight / this.height;
    
    return {
      x: Math.round(screenX * scaleX),
      y: Math.round(screenY * scaleY)
    };
  }

  /**
   * 坐标转换：远程桌面坐标 -> 屏幕坐标
   * @param {number} remoteX 远程桌面X坐标
   * @param {number} remoteY 远程桌面Y坐标
   * @param {number} remoteWidth 远程桌面宽度
   * @param {number} remoteHeight 远程桌面高度
   * @returns {Object} 屏幕坐标
   */
  remoteToScreen(remoteX, remoteY, remoteWidth, remoteHeight) {
    const scaleX = this.width / remoteWidth;
    const scaleY = this.height / remoteHeight;
    
    return {
      x: Math.round(remoteX * scaleX),
      y: Math.round(remoteY * scaleY)
    };
  }

  /**
   * 销毁渲染器
   */
  destroy() {
    this.stopFPSCounter();
    this.frameBuffer = [];
    this.isRendering = false;
    this.canvasContext = null;
    console.log('[CanvasRenderer] 已销毁');
  }
}

// 导出
module.exports = {
  CanvasRenderer
};
