import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/websocket_service.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;

  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;
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
      notifyListeners();
      // Connect WebSocket
      WebSocketService.instance.connect();
      // Refresh profile (also fixes missing user data)
      await refreshProfile();
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

        // Connect WebSocket
        WebSocketService.instance.connect();
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
          WebSocketService.instance.connect();
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
      // Ignore
    }
  }

  Future<void> logout() async {
    WebSocketService.instance.disconnect();
    final storage = await StorageService.getInstance();
    await storage.clearAll();
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}
