import 'package:flutter/material.dart';
import '../repositories/conversation_repository.dart';
import '../services/websocket_service.dart';

class ConversationProvider extends ChangeNotifier {
  final ConversationRepository _repo = ConversationRepository();

  List<Map<String, dynamic>> _conversations = [];
  List<int> _onlineUsers = [];
  bool _isLoading = false;
  bool _hasMore = true;
  bool _initialized = false;

  List<Map<String, dynamic>> get conversations => _conversations;
  List<int> get onlineUsers => _onlineUsers;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  bool isUserOnline(int userId) => _onlineUsers.contains(userId);

  int get totalUnread {
    int count = 0;
    for (final conv in _conversations) {
      count += (conv['unread_count'] as int?) ?? 0;
    }
    return count;
  }

  void init() {
    if (_initialized) return;
    _initialized = true;

    // 监听 WebSocket 消息更新会话
    WebSocketService.instance.on('message', _onNewMessage);
    WebSocketService.instance.on('group_message', _onNewMessage);
    WebSocketService.instance.on('conversation_last_message', _onConversationUpdate);
    // 监听好友在线状态变化
    WebSocketService.instance.on('status', _onStatusChange);
    // 监听系统广播通知
    WebSocketService.instance.on('system_notify', _onSystemNotify);

    loadConversations();
  }

  Future<void> loadConversations({bool loadMore = false}) async {
    if (_isLoading) return;
    _isLoading = true;
    if (!loadMore) notifyListeners();

    try {
      int? beforeId;
      if (loadMore && _conversations.isNotEmpty) {
        beforeId = _conversations.last['id'] as int?;
      }

      final result = await _repo.getConversations(limit: 20, beforeId: beforeId);
      final data = (result['data'] as List<Map<String, dynamic>>?) ?? [];
      final online = (result['online_users'] as List<int>?) ?? [];

      if (loadMore) {
        _conversations.addAll(data);
      } else {
        _conversations = data;
        _onlineUsers = online;
        // 确保系统通知会话（friend_id=1）始终存在于列表顶部
        _ensureSystemNotification();
      }
      _hasMore = result['has_more'] == true;
    } catch (e) {
      // Handle error
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 确保系统通知会话存在（friend_id=1）并排在列表顶部
  /// 与 Vue 前端的 setConversations 逻辑保持一致
  void _ensureSystemNotification() {
    final systemIndex = _conversations.indexWhere((c) {
      final type = c['type'] as int? ?? 0;
      final friendId = c['friend_id'] as int? ?? (c['friend'] as Map<String, dynamic>?)?['id'] as int? ?? 0;
      return type == 1 && friendId == 1;
    });

    if (systemIndex > 0) {
      // 系统通知存在但不在第一位，移到最前面
      final systemConv = _conversations.removeAt(systemIndex);
      _conversations.insert(0, systemConv);
    } else if (systemIndex == -1) {
      // 系统通知不存在（理论上后端已保证返回，这是兜底逻辑）
      _conversations.insert(0, {
        'id': 0,
        'type': 1,
        'friend_id': 1,
        'friend': {'id': 1, 'nickname': '系统通知', 'username': '系统通知', 'avatar': ''},
        'last_message': '暂无消息',
        'last_time': null,
        'unread_count': 0,
        'pinned': true,
      });
    }
    // systemIndex == 0 时已经在第一位，无需操作
  }

  void _onNewMessage(Map<String, dynamic> msg) {
    // 收到新消息，刷新会话列表
    loadConversations();
  }

  void _onConversationUpdate(Map<String, dynamic> msg) {
    loadConversations();
  }

  /// 处理好友在线状态变化事件
  void _onStatusChange(Map<String, dynamic> msg) {
    final fromId = msg['from'] as int?;
    if (fromId == null) return;

    final content = msg['content'];
    if (content == null) return;

    final isOnline = content is Map ? content['online'] == true : false;

    if (isOnline) {
      if (!_onlineUsers.contains(fromId)) {
        _onlineUsers.add(fromId);
        notifyListeners();
      }
    } else {
      if (_onlineUsers.remove(fromId)) {
        notifyListeners();
      }
    }
  }

  /// 处理系统广播通知 - 更新系统通知会话的最后消息
  void _onSystemNotify(Map<String, dynamic> msg) {
    final content = msg['content'];
    String text = '';
    if (content is Map) {
      text = (content['message'] ?? content['content'] ?? '系统通知').toString();
    } else if (content is String) {
      text = content;
    }
    if (text.isEmpty) return;

    // 更新系统通知会话的最后消息
    final systemIndex = _conversations.indexWhere((c) {
      final type = c['type'] as int? ?? 0;
      final friendId = c['friend_id'] as int? ?? (c['friend'] as Map<String, dynamic>?)?['id'] as int? ?? 0;
      return type == 1 && friendId == 1;
    });

    if (systemIndex != -1) {
      _conversations[systemIndex] = {
        ..._conversations[systemIndex],
        'last_message': text,
        'last_time': DateTime.now().toIso8601String(),
        'unread_count': ((_conversations[systemIndex]['unread_count'] as int?) ?? 0) + 1,
      };
    } else {
      // 系统通知不在列表中，插入一条
      _conversations.insert(0, {
        'id': 0,
        'type': 1,
        'friend_id': 1,
        'friend': {'id': 1, 'nickname': '系统通知', 'username': '系统通知', 'avatar': ''},
        'last_message': text,
        'last_time': DateTime.now().toIso8601String(),
        'unread_count': 1,
        'pinned': true,
      });
    }
    notifyListeners();
  }

  void markAsRead(int conversationId) {
    final index = _conversations.indexWhere((c) => c['id'] == conversationId);
    if (index != -1) {
      _conversations[index] = {..._conversations[index], 'unread_count': 0};
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WebSocketService.instance.off('message', _onNewMessage);
    WebSocketService.instance.off('group_message', _onNewMessage);
    WebSocketService.instance.off('conversation_last_message', _onConversationUpdate);
    WebSocketService.instance.off('status', _onStatusChange);
    WebSocketService.instance.off('system_notify', _onSystemNotify);
    super.dispose();
  }
}
