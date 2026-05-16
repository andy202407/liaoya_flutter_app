import 'package:flutter/foundation.dart';
import '../services/api/api_client.dart';

/// 会话数据仓库
class ConversationRepository {
  final _dio = ApiClient.instance.dio;

  // 获取会话列表
  Future<Map<String, dynamic>> getConversations({int limit = 20, int? beforeId}) async {
    // 直接从网络获取（Web 不支持 SQLite）
    return _fetchAndCache(limit: limit, beforeId: beforeId);
  }

  Future<Map<String, dynamic>> _fetchAndCache({int limit = 20, int? beforeId}) async {
    try {
      final params = <String, dynamic>{'limit': limit, 'filterType': 'all'};
      if (beforeId != null) params['before_id'] = beforeId;
      final response = await _dio.get('/conversations/', queryParameters: params);
      final data = response.data;
      if (data is Map<String, dynamic> && data['success'] == true) {
        final List<dynamic> list = data['data'] ?? [];
        final conversations = list.whereType<Map<String, dynamic>>().toList();
        final List<dynamic> onlineRaw = data['online_users'] ?? [];
        final onlineUsers = onlineRaw.whereType<int>().toList();
        return {
          'data': conversations,
          'has_more': data['has_more'] ?? false,
          'online_users': onlineUsers,
        };
      }
    } catch (e) {
      debugPrint('[ConversationRepo] fetch error: $e');
    }
    return {'data': <Map<String, dynamic>>[], 'has_more': false, 'online_users': <int>[]};
  }
}
