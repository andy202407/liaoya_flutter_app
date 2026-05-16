import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';
import '../config/constants.dart';
import 'storage_service.dart';

typedef WsMessageHandler = void Function(Map<String, dynamic> message);

class WebSocketService {
  static WebSocketService? _instance;
  WebSocketChannel? _channel;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _isConnected = false;
  bool _shouldReconnect = true;

  final Map<String, List<WsMessageHandler>> _handlers = {};
  final StreamController<bool> _connectionState = StreamController<bool>.broadcast();

  Stream<bool> get connectionStream => _connectionState.stream;
  bool get isConnected => _isConnected;

  WebSocketService._();

  static WebSocketService get instance {
    _instance ??= WebSocketService._();
    return _instance!;
  }

  Future<void> connect() async {
    if (_isConnected) return;

    final storage = await StorageService.getInstance();
    final token = storage.getToken();
    if (token == null) {
      debugPrint('[WS] No token, skip connect');
      return;
    }

    _shouldReconnect = true;
    final wsUrl = '${ApiConfig.wsEndpoint}?token=$token';
    debugPrint('[WS] Connecting to: $wsUrl');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;
      _reconnectAttempts = 0;
      _connectionState.add(true);
      debugPrint('[WS] Connected!');

      _startPing();

      _channel!.stream.listen(
        (data) {
          debugPrint('[WS] Received: ${data.toString().substring(0, data.toString().length > 100 ? 100 : data.toString().length)}');
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
      _onDisconnected();
    }
  }

  void _onMessage(dynamic data) {
    try {
      final message = jsonDecode(data as String) as Map<String, dynamic>;
      final type = message['type'] as String?;
      if (type == null) return;

      // Handle pong
      if (type == 'pong') return;

      // Dispatch to handlers
      final handlers = _handlers[type];
      if (handlers != null) {
        for (final handler in handlers) {
          handler(message);
        }
      }

      // Also dispatch to wildcard handlers
      final wildcardHandlers = _handlers['*'];
      if (wildcardHandlers != null) {
        for (final handler in wildcardHandlers) {
          handler(message);
        }
      }
    } catch (e) {
      // ignore parse errors
    }
  }

  void _onDisconnected() {
    _isConnected = false;
    _connectionState.add(false);
    _stopPing();

    if (_shouldReconnect && _reconnectAttempts < AppConstants.wsMaxReconnectAttempts) {
      _reconnectAttempts++;
      final delay = Duration(seconds: AppConstants.wsReconnectDelay * _reconnectAttempts);
      _reconnectTimer = Timer(delay, connect);
    }
  }

  void _startPing() {
    _pingTimer = Timer.periodic(
      const Duration(seconds: AppConstants.wsPingInterval),
      (_) => send({'type': 'ping'}),
    );
  }

  void _stopPing() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void send(Map<String, dynamic> data) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode(data));
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
    _channel?.sink.close();
    _isConnected = false;
    _connectionState.add(false);
  }

  void dispose() {
    disconnect();
    _connectionState.close();
  }
}
