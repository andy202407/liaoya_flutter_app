import 'package:dio/dio.dart';
import 'api_client.dart';

/// 会话相关 API
class ConversationApi {
  final Dio _dio = ApiClient.instance.dio;

  Future<Response> getConversations({int limit = 20, int? beforeId, String filterType = 'all'}) {
    final params = <String, dynamic>{'limit': limit, 'filterType': filterType};
    if (beforeId != null) params['before_id'] = beforeId;
    return _dio.get('/conversations/', queryParameters: params);
  }

  Future<Response> markAsRead(int friendId) =>
      _dio.post('/conversations/$friendId/read');

  Future<Response> deleteConversation(int conversationId) =>
      _dio.delete('/conversations/$conversationId');
}
