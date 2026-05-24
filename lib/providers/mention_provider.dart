import 'package:flutter/foundation.dart';
import '../services/api/api_client.dart';
import '../services/websocket_service.dart';

/// @消息未读状态管理 Provider
/// 管理群聊中@消息的未读列表、计数和导航状态
class MentionProvider extends ChangeNotifier {
  final _dio = ApiClient.instance.dio;

  // groupId → 未读@消息列表
  final Map<int, List<Map<String, dynamic>>> _unreadMentions = {};
  // groupId → 未读@计数
  final Map<int, int> _unreadCounts = {};
  // groupId → 当前导航索引
  final Map<int, int> _navigationIndex = {};

  bool _initialized = false;

  /// 获取某群的未读@消息列表
  List<Map<String, dynamic>> getUnreadMentions(int groupId) {
    return _unreadMentions[groupId] ?? [];
  }

  /// 获取某群的未读@计数
  int getUnreadCount(int groupId) {
    return _unreadCounts[groupId] ?? 0;
  }

  /// 获取某群的当前导航索引
  int getNavigationIndex(int groupId) {
    return _navigationIndex[groupId] ?? 0;
  }

  /// 是否有未读@消息
  bool hasUnreadMentions(int groupId) {
    return (_unreadCounts[groupId] ?? 0) > 0;
  }

  /// 初始化：监听 WebSocket 消息
  void init() {
    if (_initialized) return;
    _initialized = true;
    WebSocketService.instance.on('group_message', _onGroupMessage);
  }

  /// 从后端获取某群的未读@消息列表
  Future<void> fetchUnreadMentions(int groupId) async {
    try {
      final response = await _dio.get('/groups/$groupId/mentions/unread');
      final data = response.data;
      if (data is Map<String, dynamic> && data['success'] == true) {
        final mentionData = data['data'] as Map<String, dynamic>? ?? {};
        final List<dynamic> mentions = mentionData['mentions'] ?? [];
        final int count = mentionData['count'] ?? mentions.length;

        _unreadMentions[groupId] =
            mentions.whereType<Map<String, dynamic>>().toList();
        _unreadCounts[groupId] = count;
        // 重置导航索引
        _navigationIndex[groupId] = 0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[MentionProvider] fetchUnreadMentions error: $e');
    }
  }

  /// 标记单条@消息为已读
  Future<void> markRead(int groupId, int messageId) async {
    try {
      await _dio.post('/groups/$groupId/mentions/$messageId/read');

      // 本地更新：从未读列表移除
      final mentions = _unreadMentions[groupId];
      if (mentions != null) {
        mentions.removeWhere((m) =>
            m['message_id'] == messageId || m['msg_id'] == messageId);
        _unreadMentions[groupId] = mentions;
      }

      // 递减计数
      final currentCount = _unreadCounts[groupId] ?? 0;
      _unreadCounts[groupId] = (currentCount - 1).clamp(0, currentCount);

      // 调整导航索引
      final navIdx = _navigationIndex[groupId] ?? 0;
      final listLen = _unreadMentions[groupId]?.length ?? 0;
      if (listLen > 0 && navIdx >= listLen) {
        _navigationIndex[groupId] = listLen - 1;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('[MentionProvider] markRead error: $e');
    }
  }

  /// 清除某群所有@未读
  Future<void> clearAll(int groupId) async {
    try {
      await _dio.post('/groups/$groupId/mentions/clear');

      // 本地清除
      _unreadMentions.remove(groupId);
      _unreadCounts[groupId] = 0;
      _navigationIndex.remove(groupId);
      notifyListeners();
    } catch (e) {
      debugPrint('[MentionProvider] clearAll error: $e');
    }
  }

  /// 收到新@消息时追加到未读列表
  void addMention(int groupId, Map<String, dynamic> mentionData) {
    _unreadMentions.putIfAbsent(groupId, () => []);

    // Deduplication: check if message_id already exists
    final messageId = mentionData['message_id'];
    if (messageId != null) {
      final exists = _unreadMentions[groupId]!.any((m) =>
          m['message_id'] == messageId || m['msg_id'] == messageId);
      if (exists) return; // Already tracked, skip
    }

    _unreadMentions[groupId]!.add(mentionData);
    final currentCount = _unreadCounts[groupId] ?? 0;
    _unreadCounts[groupId] = currentCount + 1;
    notifyListeners();
  }

  /// 批量更新未读计数（会话列表加载时使用）
  void updateCounts(Map<int, int> countsMap) {
    countsMap.forEach((groupId, count) {
      _unreadCounts[groupId] = count;
    });
    notifyListeners();
  }

  /// 导航到下一条@消息，返回目标消息ID（循环导航）
  int? navigateNext(int groupId) {
    final mentions = _unreadMentions[groupId];
    if (mentions == null || mentions.isEmpty) return null;

    final currentIdx = _navigationIndex[groupId] ?? 0;
    final newIdx = (currentIdx + 1) % mentions.length;
    _navigationIndex[groupId] = newIdx;
    notifyListeners();

    return mentions[newIdx]['message_id'] as int? ??
        mentions[newIdx]['msg_id'] as int?;
  }

  /// 导航到上一条@消息，返回目标消息ID（循环导航）
  int? navigatePrev(int groupId) {
    final mentions = _unreadMentions[groupId];
    if (mentions == null || mentions.isEmpty) return null;

    final currentIdx = _navigationIndex[groupId] ?? 0;
    final newIdx = (currentIdx - 1 + mentions.length) % mentions.length;
    _navigationIndex[groupId] = newIdx;
    notifyListeners();

    return mentions[newIdx]['message_id'] as int? ??
        mentions[newIdx]['msg_id'] as int?;
  }

  /// 获取当前导航位置的消息ID
  int? getCurrentMentionMessageId(int groupId) {
    final mentions = _unreadMentions[groupId];
    if (mentions == null || mentions.isEmpty) return null;

    final idx = _navigationIndex[groupId] ?? 0;
    if (idx >= mentions.length) return null;

    return mentions[idx]['message_id'] as int? ??
        mentions[idx]['msg_id'] as int?;
  }

  /// 处理 WebSocket 群消息：检测 mentioned=true 事件
  void _onGroupMessage(Map<String, dynamic> msg) {
    final mentioned = msg['mentioned'];
    if (mentioned != true) return;

    final groupId = msg['group_id'] as int? ?? msg['to'] as int?;
    if (groupId == null) return;

    // 构建 mention 数据
    final mentionData = <String, dynamic>{
      'message_id': msg['id'] ?? msg['message_id'],
      'from_id': msg['from'] ?? msg['from_id'],
      'from_name': msg['from_name'] ?? msg['sender_name'] ?? '',
      'content': _extractTextContent(msg['content']),
      'timestamp': msg['timestamp'] ?? msg['created_at'] ?? '',
    };

    addMention(groupId, mentionData);

    // 如果消息中包含 mention_unread_count，同步更新计数
    final mentionUnreadCount = msg['mention_unread_count'];
    if (mentionUnreadCount is int) {
      _unreadCounts[groupId] = mentionUnreadCount;
      notifyListeners();
    }
  }

  /// 提取文本内容（支持 String 和 Map 格式）
  String _extractTextContent(dynamic content) {
    if (content is String) return content;
    if (content is Map) return content['text'] as String? ?? '';
    return '';
  }

  /// 重置状态（切换账号时调用）
  void reset() {
    _unreadMentions.clear();
    _unreadCounts.clear();
    _navigationIndex.clear();
    _initialized = false;
    WebSocketService.instance.off('group_message', _onGroupMessage);
    notifyListeners();
  }

  @override
  void dispose() {
    WebSocketService.instance.off('group_message', _onGroupMessage);
    super.dispose();
  }
}
