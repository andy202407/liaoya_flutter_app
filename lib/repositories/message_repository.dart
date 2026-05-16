import '../services/api_service.dart';
import '../services/database_service.dart';

/// 消息数据仓库
/// 负责决定从本地缓存还是网络获取数据，对上层透明
class MessageRepository {
  final ApiService _api = ApiService.instance;
  final DatabaseService _db = DatabaseService.instance;

  // 获取私聊消息（优先本地，无缓存则从网络拉取并缓存）
  Future<List<Map<String, dynamic>>> getMessages(int friendId, {int limit = 50, int? beforeId}) async {
    // 1. 尝试从本地数据库读取
    final cached = await _db.getMessages(friendId, limit: limit, beforeId: beforeId);
    if (cached.isNotEmpty && beforeId == null) {
      // 首屏有缓存，直接返回，同时后台刷新
      _refreshMessagesFromNetwork(friendId, limit: limit);
      return cached;
    }

    // 2. 本地无缓存或加载更多，从网络拉取
    return _fetchAndCacheMessages(friendId, limit: limit, beforeId: beforeId);
  }

  // 获取群消息
  Future<List<Map<String, dynamic>>> getGroupMessages(int groupId, {int limit = 50, int? beforeId}) async {
    final cached = await _db.getGroupMessages(groupId, limit: limit, beforeId: beforeId);
    if (cached.isNotEmpty && beforeId == null) {
      _refreshGroupMessagesFromNetwork(groupId, limit: limit);
      return cached;
    }
    return _fetchAndCacheGroupMessages(groupId, limit: limit, beforeId: beforeId);
  }

  // 保存单条消息到本地
  Future<void> saveMessage(Map<String, dynamic> message, {int? friendId, int? groupId}) async {
    if (groupId != null) {
      await _db.insertGroupMessage(groupId, message);
    } else if (friendId != null) {
      await _db.insertMessage(friendId, message);
    }
  }

  // 保存多条消息到本地
  Future<void> saveMessages(List<Map<String, dynamic>> messages, {int? friendId, int? groupId}) async {
    for (final msg in messages) {
      await saveMessage(msg, friendId: friendId, groupId: groupId);
    }
  }

  // 从网络拉取并缓存私聊消息
  Future<List<Map<String, dynamic>>> _fetchAndCacheMessages(int friendId, {int limit = 50, int? beforeId}) async {
    try {
      final response = await _api.getMessages(friendId, limit: limit, beforeId: beforeId);
      if (response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        final messages = data.cast<Map<String, dynamic>>();
        // 缓存到本地
        await saveMessages(messages, friendId: friendId);
        return messages;
      }
    } catch (e) {
      // 网络失败，尝试返回本地缓存
      return _db.getMessages(friendId, limit: limit, beforeId: beforeId);
    }
    return [];
  }

  // 后台刷新私聊消息（不阻塞 UI）
  Future<void> _refreshMessagesFromNetwork(int friendId, {int limit = 50}) async {
    try {
      final response = await _api.getMessages(friendId, limit: limit);
      if (response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        await saveMessages(data.cast<Map<String, dynamic>>(), friendId: friendId);
      }
    } catch (e) {
      // 静默失败
    }
  }

  // 从网络拉取并缓存群消息
  Future<List<Map<String, dynamic>>> _fetchAndCacheGroupMessages(int groupId, {int limit = 50, int? beforeId}) async {
    try {
      final response = await _api.getGroupMessages(groupId, limit: limit, beforeId: beforeId);
      if (response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        final messages = data.cast<Map<String, dynamic>>();
        await saveMessages(messages, groupId: groupId);
        return messages;
      }
    } catch (e) {
      return _db.getGroupMessages(groupId, limit: limit, beforeId: beforeId);
    }
    return [];
  }

  Future<void> _refreshGroupMessagesFromNetwork(int groupId, {int limit = 50}) async {
    try {
      final response = await _api.getGroupMessages(groupId, limit: limit);
      if (response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        await saveMessages(data.cast<Map<String, dynamic>>(), groupId: groupId);
      }
    } catch (e) {
      // 静默失败
    }
  }

  // 清除指定会话的本地消息缓存
  Future<void> clearCache({int? friendId, int? groupId}) async {
    if (friendId != null) {
      await _db.clearMessages(friendId);
    }
    if (groupId != null) {
      await _db.clearGroupMessages(groupId);
    }
  }
}
