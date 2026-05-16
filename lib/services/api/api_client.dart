import 'package:dio/dio.dart';
import '../../config/api_config.dart';
import '../../config/app_secrets.dart';
import '../storage_service.dart';

/// 底层 HTTP 客户端，只负责网络请求配置
/// 所有业务 API 模块共享这个 Dio 实例
class ApiClient {
  static ApiClient? _instance;
  late Dio dio;
  StorageService? _storage;

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
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          // TODO: Token expired, trigger logout
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
