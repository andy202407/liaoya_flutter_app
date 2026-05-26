import 'package:dio/dio.dart';
import 'api_client.dart';

/// ç¾¤ç»„ç›¸å…³ API
class GroupApi {
  final Dio _dio = ApiClient.instance.dio;

  Future<Response> getGroups() => _dio.get('/groups/');

  Future<Response> getGroupInfo(int groupId) => _dio.get('/groups/$groupId');

  Future<Response> getGroupMembers(int groupId) => _dio.get('/groups/$groupId/members');

  Future<Response> getGroupMessages(int groupId, {int limit = 50, int? beforeId}) {
    final params = <String, dynamic>{'limit': limit};
    if (beforeId != null) params['before_id'] = beforeId;
    return _dio.get('/groups/$groupId/messages', queryParameters: params);
  }

  Future<Response> sendGroupMessage(int groupId, String content, {String type = 'message'}) {
    return _dio.post('/groups/$groupId/messages', data: FormData.fromMap({
      'content': content,
      'type': type,
    }));
  }

  Future<Response> joinGroup(int groupId) => _dio.post('/groups/$groupId/join');

  Future<Response> leaveGroup(int groupId) => _dio.post('/groups/$groupId/leave');

  Future<Response> joinByInviteCode(String code) {
    return _dio.post('/groups/join-by-code', data: {'code': code});
  }

  Future<Response> joinByLink(String token, {String? code}) {
    final data = <String, dynamic>{'token': token};
    if (code != null && code.isNotEmpty) data['code'] = code;
    return _dio.post('/groups/join-by-link', data: data);
  }

  /// 按分类获取群聊消息
  Future<Response> getGroupMessagesByCategory(
    int groupId, 
    String category, {
    int limit = 20,
    int? beforeId,
    Map<String, dynamic>? extraParams,
  }) {
    final params = <String, dynamic>{
      'limit': limit,
      'category': category,
    };
    if (beforeId != null) params['before_id'] = beforeId;
    if (extraParams != null) params.addAll(extraParams);
    return _dio.get('/groups/$groupId/messages/category', queryParameters: params);
  }
}
