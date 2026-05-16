import 'package:dio/dio.dart';
import 'api_client.dart';

/// 用户相关 API
class UserApi {
  final Dio _dio = ApiClient.instance.dio;

  Future<Response> getProfile() => _dio.get('/user/profile');

  Future<Response> updateNickname(String nickname) =>
      _dio.put('/user/nickname', data: {'nickname': nickname});

  Future<Response> updateAvatar(String avatarUrl) =>
      _dio.post('/user/avatar', data: {'avatar': avatarUrl});

  Future<Response> changePassword(Map<String, dynamic> data) =>
      _dio.post('/user/change-password', data: data);
}
