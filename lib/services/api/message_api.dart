import 'package:dio/dio.dart';
import 'api_client.dart';

/// 消息相关 API（私聊）
class MessageApi {
  final Dio _dio = ApiClient.instance.dio;

  Future<Response> getMessages(int friendId, {int limit = 50, int? beforeId}) {
    final params = <String, dynamic>{'limit': limit};
    if (beforeId != null) params['before_id'] = beforeId;
    return _dio.get('/messages/$friendId', queryParameters: params);
  }

  Future<Response> sendMessage(int friendId, String content, {String type = 'text'}) {
    return _dio.post('/messages/$friendId', data: {
      'content': content,
      'type': type,
    });
  }

  Future<Response> recallMessage(int messageId) =>
      _dio.post('/messages/$messageId/recall');
}
