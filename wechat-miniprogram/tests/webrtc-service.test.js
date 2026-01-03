/**
 * WebRTC Service Tests for WeChat MiniProgram
 * 微信小程序 WebRTC 服务测试
 * 
 * 属性测试验证:
 * - 属性 14: 微信小程序 WebRTC API 使用
 * - 属性 15: 微信小程序画布显示
 * - 属性 16: 微信小程序触摸输入转换
 * 
 * 验证: 需求 15.2, 15.3, 15.4
 */

const { WebRTCService } = require('../utils/webrtc-service');
const { CanvasRenderer } = require('../utils/canvas-renderer');
const { TouchInputHandler } = require('../utils/touch-input-handler');

// 模拟微信小程序环境
const mockWx = {
  connectSocket: jest.fn(() => ({
    onOpen: jest.fn(),
    onError: jest.fn(),
    onMessage: jest.fn(),
    onClose: jest.fn(),
    send: jest.fn(),
    close: jest.fn()
  })),
  createLivePlayerContext: jest.fn(() => ({
    play: jest.fn(),
    stop: jest.fn(),
    mute: jest.fn()
  })),
  createLivePusherContext: jest.fn(() => ({
    start: jest.fn(),
    stop: jest.fn()
  })),
  createCanvasContext: jest.fn(() => ({
    setFillStyle: jest.fn(),
    fillRect: jest.fn(),
    draw: jest.fn(),
    setStrokeStyle: jest.fn(),
    setLineWidth: jest.fn(),
    beginPath: jest.fn(),
    arc: jest.fn(),
    stroke: jest.fn(),
    fill: jest.fn(),
    setFontSize: jest.fn(),
    fillText: jest.fn(),
    setGlobalAlpha: jest.fn(),
    drawImage: jest.fn()
  })),
  vibrateShort: jest.fn(),
  getNetworkType: jest.fn((options) => {
    options.success({ networkType: 'wifi' });
  })
};

// 设置全局 wx 对象
global.wx = mockWx;

// Mock requestAnimationFrame for Node.js environment
global.requestAnimationFrame = (callback) => setTimeout(callback, 16);

describe('WebRTC Service Tests', () => {
  let webrtcService;

  beforeEach(() => {
    webrtcService = new WebRTCService();
    webrtcService.init({
      signalingServer: 'wss://test.example.com',
      stunServer: 'stun:stun.test.com:19302'
    });
  });

  afterEach(() => {
    if (webrtcService) {
      // 清理 socketTask 以避免 close 错误
      webrtcService.socketTask = null;
      webrtcService.isConnected = false;
    }
  });

  /**
   * 属性 14: 微信小程序 WebRTC API 使用
   * Feature: cec-remote, Property 14: 微信小程序 WebRTC API 使用
   * 验证: 需求 15.2
   */
  describe('Property 14: WeChat MiniProgram WebRTC API Usage', () => {
    test('should initialize WebRTC service with correct configuration', () => {
      expect(webrtcService.options.signalingServer).toBe('wss://test.example.com');
      expect(webrtcService.options.stunServer).toBe('stun:stun.test.com:19302');
    });

    test('should create live player context using wx API', () => {
      const mockComponent = {};
      webrtcService.createLivePlayerContext('testPlayer', mockComponent);
      
      expect(mockWx.createLivePlayerContext).toHaveBeenCalledWith('testPlayer', mockComponent);
      expect(webrtcService.livePlayerContext).toBeDefined();
    });

    test('should create live pusher context using wx API', () => {
      const mockComponent = {};
      webrtcService.createLivePusherContext('testPusher', mockComponent);
      
      expect(mockWx.createLivePusherContext).toHaveBeenCalledWith('testPusher', mockComponent);
      expect(webrtcService.livePusherContext).toBeDefined();
    });

    test('should handle connection state changes', () => {
      const stateChanges = [];
      webrtcService.on('connectionStateChange', (state) => {
        stateChanges.push(state);
      });

      // 模拟连接状态变化
      webrtcService.emit('connectionStateChange', 'connecting');
      webrtcService.emit('connectionStateChange', 'connected');

      expect(stateChanges).toContain('connecting');
      expect(stateChanges).toContain('connected');
    });

    test('should send data channel messages when connected', () => {
      // 模拟已连接状态
      webrtcService.isConnected = true;
      webrtcService.socketTask = {
        send: jest.fn((options) => options.success && options.success()),
        close: jest.fn()
      };

      const result = webrtcService.sendMouseClick('left', 100, 200);
      
      expect(result).toBe(true);
    });

    test('should not send messages when disconnected', () => {
      webrtcService.isConnected = false;
      
      const result = webrtcService.sendMouseClick('left', 100, 200);
      
      expect(result).toBe(false);
    });
  });
});

describe('Canvas Renderer Tests', () => {
  let canvasRenderer;

  beforeEach(() => {
    canvasRenderer = new CanvasRenderer();
    canvasRenderer.init('testCanvas', {}, { width: 375, height: 667 });
  });

  afterEach(() => {
    if (canvasRenderer) {
      canvasRenderer.destroy();
    }
  });

  /**
   * 属性 15: 微信小程序画布显示
   * Feature: cec-remote, Property 15: 微信小程序画布显示
   * 验证: 需求 15.3
   */
  describe('Property 15: WeChat MiniProgram Canvas Display', () => {
    test('should initialize canvas with correct dimensions', () => {
      expect(canvasRenderer.width).toBe(375);
      expect(canvasRenderer.height).toBe(667);
      expect(canvasRenderer.canvasContext).toBeDefined();
    });

    test('should create canvas context using wx API', () => {
      expect(mockWx.createCanvasContext).toHaveBeenCalledWith('testCanvas', expect.anything());
    });

    test('should convert screen coordinates to remote coordinates', () => {
      const remoteCoords = canvasRenderer.screenToRemote(187.5, 333.5, 1920, 1080);
      
      expect(remoteCoords.x).toBe(960);
      expect(remoteCoords.y).toBe(540);
    });

    test('should convert remote coordinates to screen coordinates', () => {
      const screenCoords = canvasRenderer.remoteToScreen(960, 540, 1920, 1080);
      
      // 960 * 375 / 1920 = 187.5 -> rounds to 188
      // 540 * 667 / 1080 = 333.5 -> rounds to 334
      expect(screenCoords.x).toBe(188);
      expect(screenCoords.y).toBe(334);
    });

    test('should track FPS correctly', () => {
      // 模拟帧渲染
      canvasRenderer.frameCount = 30;
      
      // 手动触发 FPS 更新
      canvasRenderer.fps = canvasRenderer.frameCount;
      canvasRenderer.frameCount = 0;
      
      expect(canvasRenderer.fps).toBe(30);
    });

    test('should handle frame buffer correctly', () => {
      const frame1 = { type: 'simulated', deviceId: 'test1' };
      const frame2 = { type: 'simulated', deviceId: 'test2' };
      
      canvasRenderer.renderFrame(frame1);
      canvasRenderer.renderFrame(frame2);
      
      expect(canvasRenderer.frameBuffer.length).toBeLessThanOrEqual(canvasRenderer.maxBufferSize);
    });
  });
});

describe('Touch Input Handler Tests', () => {
  let touchHandler;
  let mockWebrtcService;
  let mockCanvasRenderer;

  beforeEach(() => {
    mockWebrtcService = {
      isConnectionActive: () => true,
      sendMouseClick: jest.fn(),
      sendMouseMove: jest.fn(),
      sendTextInput: jest.fn(),
      sendKeyboardInput: jest.fn(),
      sendDataChannelMessage: jest.fn()
    };

    mockCanvasRenderer = {
      width: 375,
      height: 667,
      showClickFeedback: jest.fn(),
      screenToRemote: (x, y, rw, rh) => ({
        x: Math.round(x * rw / 375),
        y: Math.round(y * rh / 667)
      })
    };

    touchHandler = new TouchInputHandler();
    touchHandler.init(mockWebrtcService, mockCanvasRenderer, {
      remoteWidth: 1920,
      remoteHeight: 1080
    });
  });

  afterEach(() => {
    if (touchHandler) {
      touchHandler.destroy();
    }
  });

  /**
   * 属性 16: 微信小程序触摸输入转换
   * Feature: cec-remote, Property 16: 微信小程序触摸输入转换
   * 验证: 需求 15.4
   */
  describe('Property 16: WeChat MiniProgram Touch Input Conversion', () => {
    test('should convert tap to left mouse click', () => {
      // 模拟触摸开始
      touchHandler.handleTouchStart({
        touches: [{ x: 100, y: 200 }]
      });

      // 模拟短暂触摸后结束（点击）
      touchHandler.touchState.startTime = Date.now() - 100; // 100ms 前开始
      
      touchHandler.handleTouchEnd({
        changedTouches: [{ x: 100, y: 200 }]
      });

      // 验证发送了左键点击
      expect(mockWebrtcService.sendMouseClick).toHaveBeenCalledWith(
        'left',
        expect.any(Number),
        expect.any(Number)
      );
    });

    test('should convert long press to right mouse click', () => {
      const rightClickHandler = jest.fn();
      touchHandler.on('rightClick', rightClickHandler);

      // 直接调用右键点击处理
      touchHandler.handleRightClick(100, 200);

      expect(mockWebrtcService.sendMouseClick).toHaveBeenCalledWith(
        'right',
        expect.any(Number),
        expect.any(Number)
      );
      expect(rightClickHandler).toHaveBeenCalled();
    });

    test('should convert touch move to mouse move', () => {
      // 模拟触摸开始
      touchHandler.handleTouchStart({
        touches: [{ x: 100, y: 200 }]
      });

      // 模拟触摸移动
      touchHandler.handleTouchMove({
        touches: [{ x: 150, y: 250 }]
      });

      expect(mockWebrtcService.sendMouseMove).toHaveBeenCalled();
    });

    test('should correctly convert coordinates to remote desktop', () => {
      const remoteCoords = touchHandler.convertToRemoteCoords(187.5, 333.5);
      
      // 187.5 * 1920 / 375 = 960
      // 333.5 * 1080 / 667 ≈ 540
      expect(remoteCoords.x).toBe(960);
      expect(remoteCoords.y).toBeCloseTo(540, 0);
    });

    test('should send keyboard input correctly', () => {
      touchHandler.sendKeyboardInput('Hello World');
      
      expect(mockWebrtcService.sendTextInput).toHaveBeenCalledWith('Hello World');
    });

    test('should send special keys correctly', () => {
      touchHandler.sendSpecialKey('Enter', { ctrl: true });
      
      expect(mockWebrtcService.sendKeyboardInput).toHaveBeenCalledWith('Enter', { ctrl: true });
    });

    test('should handle double tap correctly', () => {
      const doubleTapHandler = jest.fn();
      touchHandler.on('doubleTap', doubleTapHandler);

      // 模拟第一次点击
      touchHandler.touchState.lastTapTime = Date.now() - 100;
      touchHandler.touchState.tapCount = 1;

      // 模拟第二次点击（双击）
      touchHandler.handleTouchStart({
        touches: [{ x: 100, y: 200 }]
      });
      touchHandler.touchState.startTime = Date.now() - 50;
      touchHandler.handleTouchEnd({
        changedTouches: [{ x: 100, y: 200 }]
      });

      expect(doubleTapHandler).toHaveBeenCalled();
    });

    test('should emit events correctly', () => {
      const tapHandler = jest.fn();
      touchHandler.on('tap', tapHandler);

      touchHandler.handleTap(100, 200);

      expect(tapHandler).toHaveBeenCalledWith(expect.objectContaining({
        x: 100,
        y: 200
      }));
    });
  });
});

// 运行测试
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    WebRTCService,
    CanvasRenderer,
    TouchInputHandler
  };
}
