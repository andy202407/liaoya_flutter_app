import 'package:dio/dio.dart';
import 'api_client.dart';

/// 认证相关 API
class AuthApi {
  final Dio _dio = ApiClient.instance.dio;

  Future<Response> login(String username, String password, {
    String? captchaTicket,
    String? captchaRandstr,
    String? simpleCaptchaId,
    String? simpleCaptchaAnswer,
  }) {
    final data = <String, dynamic>{
      'username': username,
      'password': password,
      'device_fingerprint': 'flutter_app_${DateTime.now().millisecondsSinceEpoch}',
    };
    if (captchaTicket != null) data['captcha_ticket'] = captchaTicket;
    if (captchaRandstr != null) data['captcha_randstr'] = captchaRandstr;
    if (simpleCaptchaId != null) data['simple_captcha_id'] = simpleCaptchaId;
    if (simpleCaptchaAnswer != null) data['simple_captcha_answer'] = simpleCaptchaAnswer;
    return _dio.post('/auth/login', data: data);
  }

  Future<Response> register(Map<String, dynamic> data) {
    data['device_fingerprint'] = 'flutter_app_${DateTime.now().millisecondsSinceEpoch}';
    return _dio.post('/auth/register', data: data);
  }

  Future<Response> getCaptchaStatus() {
    return _dio.get('/captcha-status', queryParameters: {'type': 'frontend'});
  }

  Future<Response> checkIp(String username) {
    return _dio.get('/ip-check', queryParameters: {'username': username});
  }
}
