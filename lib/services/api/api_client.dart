import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../config/api_config.dart';
import '../../config/app_secrets.dart';
import '../storage_service.dart';
import '../../main.dart' show navigatorKey;

/// 底层 HTTP 客户端，只负责网络请求配置
/// 所有业务 API 模块共享这个 Dio 实例
class ApiClient {
  static ApiClient? _instance;
  late Dio dio;
  StorageService? _storage;
  bool _isHandling401 = false;

  ApiClient._() {
    dio = Dio(BaseOptions(
      baseUrl: ApiConfig.apiUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': '${AppSecrets.appClientId}/1.0',
        'X-App-Client': AppSecrets.appClientId,
        'X-App-Secret': AppSecrets.appSecret,
      },
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        _storage ??= await StorageService.getInstance();
        final token = _storage!.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 && !_isHandling401) {
          _isHandling401 = true;
          debugPrint('[ApiClient] 收到 401，token 已失效，执行登出');
          // 清除本地数据并跳转登录页
          _storage ??= await StorageService.getInstance();
          await _storage!.clearAll();
          final nav = navigatorKey.currentState;
          if (nav != null) {
            nav.pushNamedAndRemoveUntil('/login', (_) => false);
          }
          // 延迟重置标志，避免短时间内多个 401 重复处理
          Future.delayed(const Duration(seconds: 2), () {
            _isHandling401 = false;
          });
        }
        return handler.next(error);
      },
    ));
  }

  static ApiClient get instance {
    _instance ??= ApiClient._();
    return _instance!;
  }
}
