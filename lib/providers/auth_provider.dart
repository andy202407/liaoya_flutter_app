import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../main.dart' show navigatorKey;
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/websocket_service.dart';
import '../services/push_service.dart';

const _nativeChannel = MethodChannel('com.liaoya.liaoya_app/bridge');

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;
  bool _isKickedOut = false;
  String? _kickoutMessage;

  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;
  bool get isKickedOut => _isKickedOut;
  String? get kickoutMessage => _kickoutMessage;
  int? get userId => _user?['id'];
  String? get nickname => _user?['nickname'];
  String? get avatar => _user?['avatar'];

  Future<void> init() async {
    final storage = await StorageService.getInstance();
    final token = storage.getToken();
    final userData = storage.getUser();
    if (token != null) {
      if (userData != null) {
        _user = userData;
      }
      _isAuthenticated = true;
      _isKickedOut = false;
      notifyListeners();
      // Connect WebSocket and register kickout handlers
      _registerKickoutHandlers();
      WebSocketService.instance.connect();
      // 注册推送 token 并清除角标
      PushService.setAuthToken(token);
      PushService.clearBadge();
      // 通知原生层（JPush 上报）
      try { _nativeChannel.invokeMethod('onLogin', {'token': token}); } catch (_) {}
      // Refresh profile (also fixes missing user data)
      await refreshProfile();
    }
  }

  /// 注册被踢下线的 WebSocket 消息监听
  void _registerKickoutHandlers() {
    final ws = WebSocketService.instance;
    // 在线时被踢（后端通过 onKickOtherDevices 回调发送）
    ws.on('kicked_out', _handleKickedOut);
    // 离线后重连时被踢（后端在 WS 认证阶段检测到 session 被替换）
    ws.on('kickout', _handleKickout);
  }

  /// 移除被踢下线的监听
  void _unregisterKickoutHandlers() {
    final ws = WebSocketService.instance;
    ws.off('kicked_out', _handleKickedOut);
    ws.off('kickout', _handleKickout);
  }

  /// 处理 kicked_out 消息（在线时被踢）
  void _handleKickedOut(Map<String, dynamic> message) {
    final content = message['content'] ?? '您的账号已在其他设备登录';
    final reason = content is String ? content : '您的账号已在其他设备登录';
    debugPrint('[Auth] ⚠️ 收到 kicked_out 消息: $reason');
    _performKickout(reason);
  }

  /// 处理 kickout 消息（离线后重连被踢）
  void _handleKickout(Map<String, dynamic> message) {
    String reason = '您的账号已在其他设备登录';
    final content = message['content'];
    if (content is Map<String, dynamic>) {
      reason = (content['message'] as String?) ?? reason;
    } else if (content is String) {
      reason = content;
    }
    debugPrint('[Auth] ⚠️ 收到 kickout 消息: $reason');
    _performKickout(reason);
  }

  /// 执行被踢下线逻辑：清除本地状态，跳转登录页
  Future<void> _performKickout(String reason) async {
    if (_isKickedOut) return; // 防止重复处理
    _isKickedOut = true;
    _kickoutMessage = reason;

    // 断开 WebSocket（不再自动重连）
    WebSocketService.instance.disconnect();

    // 清除本地认证数据
    final storage = await StorageService.getInstance();
    await storage.clearAll();
    _user = null;
    _isAuthenticated = false;
    notifyListeners();

    // 跳转到登录页并显示提示
    final nav = navigatorKey.currentState;
    if (nav != null) {
      nav.pushNamedAndRemoveUntil('/login', (_) => false);
      // 延迟显示提示，等页面切换完成
      Future.delayed(const Duration(milliseconds: 300), () {
        final context = navigatorKey.currentContext;
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(reason),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    }
  }

  Future<bool> login(String username, String password, {
    String? captchaTicket,
    String? captchaRandstr,
    String? simpleCaptchaId,
    String? simpleCaptchaAnswer,
  }) async {
    _isLoading = true;
    _error = null;
    _isKickedOut = false;
    _kickoutMessage = null;
    notifyListeners();

    try {
      // IP check first
      try {
        final ipResp = await ApiService.instance.checkIp(username);
        if (ipResp.data['allowed'] == false) {
          _error = ipResp.data['message'] ?? '当前IP不允许登录';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      } catch (e) {
        // IP check failure doesn't block login
      }

      final response = await ApiService.instance.login(
        username, password,
        captchaTicket: captchaTicket,
        captchaRandstr: captchaRandstr,
        simpleCaptchaId: simpleCaptchaId,
        simpleCaptchaAnswer: simpleCaptchaAnswer,
      );
      final data = response.data;
      if (data['success'] == true) {
        final result = data['data'];
        final token = result['token'] as String;
        final user = result['user'] as Map<String, dynamic>;

        final storage = await StorageService.getInstance();
        await storage.setToken(token);
        await storage.setUser(user);

        _user = user;
        _isAuthenticated = true;
        _isLoading = false;
        notifyListeners();

        // Connect WebSocket and register kickout handlers
        _registerKickoutHandlers();
        WebSocketService.instance.connect();
        // 注册推送 token 并清除角标
        PushService.setAuthToken(token);
        PushService.clearBadge();
        // 通知原生层（JPush 上报）
        try { _nativeChannel.invokeMethod('onLogin', {'token': token}); } catch (_) {}
        return true;
      } else {
        _error = data['message'] ?? '登录失败';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      if (e is DioException && e.response != null) {
        _error = e.response?.data?['message'] ?? '登录失败';
      } else {
        _error = '网络错误，请稍后重试';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String username, String password, String nickname, {
    String? captchaTicket,
    String? captchaRandstr,
    String? simpleCaptchaId,
    String? simpleCaptchaAnswer,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = <String, dynamic>{
        'username': username,
        'password': password,
        'nickname': nickname,
      };
      if (captchaTicket != null) data['captcha_ticket'] = captchaTicket;
      if (captchaRandstr != null) data['captcha_randstr'] = captchaRandstr;
      if (simpleCaptchaId != null) data['simple_captcha_id'] = simpleCaptchaId;
      if (simpleCaptchaAnswer != null) data['simple_captcha_answer'] = simpleCaptchaAnswer;

      final response = await ApiService.instance.register(data);
      final respData = response.data;
      if (respData['success'] == true) {
        // 注册成功后自动登录（如果后端返回了 token）
        if (respData['data'] != null && respData['data']['token'] != null) {
          final token = respData['data']['token'] as String;
          final user = respData['data']['user'] as Map<String, dynamic>;
          final storage = await StorageService.getInstance();
          await storage.setToken(token);
          await storage.setUser(user);
          _user = user;
          _isAuthenticated = true;
          _registerKickoutHandlers();
          WebSocketService.instance.connect();
          PushService.setAuthToken(token);
          PushService.clearBadge();
        }
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = respData['message'] ?? '注册失败';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      if (e is DioException && e.response != null) {
        _error = e.response?.data?['message'] ?? '注册失败';
      } else {
        _error = '网络错误，请稍后重试';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshProfile() async {
    try {
      final response = await ApiService.instance.getProfile();
      if (response.data['success'] == true) {
        _user = response.data['data'] as Map<String, dynamic>;
        final storage = await StorageService.getInstance();
        await storage.setUser(_user!);
        notifyListeners();
      }
    } catch (e) {
      // 如果是 401 错误，说明 token 已失效（可能是离线时被踢）
      if (e is DioException && e.response?.statusCode == 401) {
        _performKickout('登录已过期，请重新登录');
      }
    }
  }

  Future<void> logout() async {
    _unregisterKickoutHandlers();
    WebSocketService.instance.disconnect();
    await PushService.unregister();
    // 通知原生层
    try { _nativeChannel.invokeMethod('onLogout'); } catch (_) {}
    final storage = await StorageService.getInstance();
    await storage.clearAll();
    _user = null;
    _isAuthenticated = false;
    _isKickedOut = false;
    _kickoutMessage = null;
    notifyListeners();
  }
}
