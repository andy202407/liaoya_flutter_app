import 'package:dio/dio.dart';
import 'api_client.dart';

/// 好友相关 API
class FriendApi {
  final Dio _dio = ApiClient.instance.dio;

  Future<Response> getFriends({int limit = 50}) =>
      _dio.get('/friends/', queryParameters: {'limit': limit});

  Future<Response> searchUsers(String keyword) =>
      _dio.get('/friends/search', queryParameters: {'keyword': keyword});

  Future<Response> sendFriendRequest(int toUserId, String message) =>
      _dio.post('/friends/request', data: {'to_user_id': toUserId, 'message': message});

  Future<Response> getFriendRequests() => _dio.get('/friends/requests');

  Future<Response> handleFriendRequest(int requestId, String status) =>
      _dio.put('/friends/request/$requestId', data: {'status': status});

  Future<Response> deleteFriend(int friendId) =>
      _dio.delete('/friends/$friendId');
}
