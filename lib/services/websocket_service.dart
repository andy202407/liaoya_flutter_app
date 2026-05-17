import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';
import 'storage_service.dart';

typedef WsMessageHandler = void Function(Map<String, dynamic> message);

class WebSocketService {
  static WebSocketService? _instance;
  WebSocketChannel? _channel;
  Timer? _pingTimer;
  Timer? _pongTimeoutTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _isConnected = false;
  bool _shouldReconnect = true;
  bool _isConnecting = false;
  DateTime? _lastPongTime;

  final Map<String, List<WsMessageHandler>> _handlers = {};
  final StreamController<bool> _connectionState = StreamController<bool>.broadcast();

  Stream<bool> get connectionStream => _connectionState.stream;
  bool get isConnected => _isConnected;

  // 配置
  static const int _pingInterval = 25; // 每25秒发一次ping
  static const int _pongTimeout = 10; // 10秒没收到pong认为断开
  static const int _maxReconnectDelay = 5; // 最大重连延迟5秒
  static const int _initialReconnectDelay = 1; // 初始重连延迟1秒

  WebSocketService._();

  static WebSocketService get instance {
    _instance ??= WebSocketService._();
    return _instance!;
  }

  Future<void> connect() async {
    if (_isConnected || _isConnecting) return;

    final storage = await StorageService.getInstance();
    final token = storage.getToken();
    if (token == null) {
      debugPrint('[WS] No token, skip connect');
      return;
    }

    _isConnecting = true;
    _shouldReconnect = true;
    final wsUrl = '${ApiConfig.wsEndpoint}?token=$token';
    debugPrint('[WS] Connecting to: $wsUrl');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;
      _isConnecting = false;
      _lastPongTime = DateTime.now();
      _connectionState.add(true);
      debugPrint('[WS] Connected!');

      // 连接稳定 10 秒后才重置重连计数器
      Future.delayed(const Duration(seconds: 10), () {
        if (_isConnected) _reconnectAttempts = 0;
      });

      _startPing();

      _channel!.stream.listen(
        (data) {
          final str = data.toString();
          debugPrint('[WS] Received: ${str.substring(0, str.length > 100 ? 100 : str.length)}');
          _onMessage(data);
        },
        onDone: () {
          debugPrint('[WS] Connection closed');
          _onDisconnected();
        },
        onError: (error) {
          debugPrint('[WS] Error: $error');
          _onDisconnected();
        },
      );
    } catch (e) {
      debugPrint('[WS] Connect failed: $e');
      _isConnecting = false;
      _onDisconnected();
    }
  }

  void _onMessage(dynamic data) {
    try {
      final message = jsonDecode(data as String) as Map<String, dynamic>;
      final type = message['type'] as String?;
      if (type == null) return;

      // Handle pong - 更新最后收到 pong 的时间
      if (type == 'pong') {
        _lastPongTime = DateTime.now();
        _pongTimeoutTimer?.cancel();
        return;
      }

      // Dispatch to handlers
      final handlers = _handlers[type];
      if (handlers != null) {
        for (final handler in List<WsMessageHandler>.from(handlers)) {
          handler(message);
        }
      }

      // Also dispatch to wildcard handlers
      final wildcardHandlers = _handlers['*'];
      if (wildcardHandlers != null) {
        for (final handler in List<WsMessageHandler>.from(wildcardHandlers)) {
          handler(message);
        }
      }
    } catch (e) {
      // ignore parse errors
    }
  }

  void _onDisconnected() {
    final wasConnected = _isConnected;
    _isConnected = false;
    _isConnecting = false;
    _connectionState.add(false);
    _stopPing();

    if (_shouldReconnect) {
      _scheduleReconnect();
    }

    if (wasConnected) {
      debugPrint('[WS] Disconnected, will reconnect...');
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts++;

    // 指数退避：1s, 2s, 4s, 8s, 16s, 30s, 30s, ...（永不停止）
    final delay = (_initialReconnectDelay * (1 << (_reconnectAttempts - 1).clamp(0, 4)))
        .clamp(1, _maxReconnectDelay);

    debugPrint('[WS] Reconnecting in ${delay}s (attempt $_reconnectAttempts)');

    _reconnectTimer = Timer(Duration(seconds: delay), () {
      if (_shouldReconnect && !_isConnected && !_isConnecting) {
        connect();
      }
    });
  }

  void _startPing() {
    _stopPing();
    _pingTimer = Timer.periodic(
      const Duration(seconds: _pingInterval),
      (_) {
        if (_isConnected) {
          send({'type': 'ping'});
          // 设置 pong 超时检测
          _pongTimeoutTimer?.cancel();
          _pongTimeoutTimer = Timer(const Duration(seconds: _pongTimeout), () {
            debugPrint('[WS] Pong timeout, connection dead');
            _forceReconnect();
          });
        }
      },
    );
  }

  void _stopPing() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _pongTimeoutTimer?.cancel();
    _pongTimeoutTimer = null;
  }

  /// 强制重连（连接已死但没有触发 onDone/onError）
  void _forceReconnect() {
    debugPrint('[WS] Force reconnect');
    _stopPing();
    _isConnected = false;
    _isConnecting = false;
    _connectionState.add(false);
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    if (_shouldReconnect) {
      _scheduleReconnect();
    }
  }

  void send(Map<String, dynamic> data) {
    if (_isConnected && _channel != null) {
      try {
        _channel!.sink.add(jsonEncode(data));
      } catch (e) {
        debugPrint('[WS] Send error: $e');
        _forceReconnect();
      }
    }
  }

  void on(String type, WsMessageHandler handler) {
    _handlers.putIfAbsent(type, () => []).add(handler);
  }

  void off(String type, WsMessageHandler handler) {
    _handlers[type]?.remove(handler);
  }

  void disconnect() {
    _shouldReconnect = false;
    _stopPing();
    _reconnectTimer?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _isConnected = false;
    _isConnecting = false;
    _connectionState.add(false);
  }

  void dispose() {
    disconnect();
    _connectionState.close();
  }
}
