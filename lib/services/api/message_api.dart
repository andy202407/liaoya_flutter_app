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

  /// 按分类获取私聊消息
  /// GET /messages/category?friend_id=&category=&limit=&before_id=
  Future<Response> getMessagesByCategory(
    int friendId, 
    String category, {
    int limit = 20,
    int? beforeId,
    Map<String, dynamic>? extraParams,
  }) {
    final params = <String, dynamic>{
      'friend_id': friendId,
      'limit': limit,
      'category': category,
    };
    if (beforeId != null) params['before_id'] = beforeId;
    if (extraParams != null) params.addAll(extraParams);
    return _dio.get('/messages/category', queryParameters: params);
  }
}
