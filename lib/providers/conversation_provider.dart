import 'dart:async';
import 'package:flutter/material.dart';
import '../repositories/conversation_repository.dart';
import '../services/api/api_client.dart';
import '../services/websocket_service.dart';

class ConversationProvider extends ChangeNotifier {
  final ConversationRepository _repo = ConversationRepository();

  List<Map<String, dynamic>> _conversations = [];
  List<int> _onlineUsers = [];
  bool _isLoading = false;
  bool _hasMore = true;
  bool _initialized = false;
  bool _pendingRefresh = false; // 有待处理的刷新请求
  int? _activeConversationId; // 当前正在查看的会话ID（不恢复其未读数）
  int? _activeFriendId; // 当前正在查看的好友ID
  int? _activeGroupId; // 当前正在查看的群ID
  final Map<int, bool> _typingUsers = {}; // 正在输入的用户 {userId: true}
  final Map<int, Timer> _typingTimers = {}; // 输入状态超时定时器

  int? get activeFriendId => _activeFriendId;
  int? get activeGroupId => _activeGroupId;

  /// 检查某个用户是否正在输入
  bool isUserTyping(int userId) => _typingUsers[userId] == true;

  List<Map<String, dynamic>> get conversations => _conversations;
  List<int> get onlineUsers => _onlineUsers;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  bool isUserOnline(int userId) => _onlineUsers.contains(userId);

  int get totalUnread {
    int count = 0;
    for (final conv in _conversations) {
      if (conv['muted'] == true) continue; // 静音会话不计入总未读
      count += (conv['unread_count'] as int?) ?? 0;
    }
    return count;
  }

  void init() {
    if (_initialized) return;
    _initialized = true;

    // 监听 WebSocket 消息更新会话
    WebSocketService.instance.on('message', _onNewMessage);
    WebSocketService.instance.on('image', _onNewMessage);
    WebSocketService.instance.on('images', _onNewMessage);
    WebSocketService.instance.on('video', _onNewMessage);
    WebSocketService.instance.on('videos', _onNewMessage);
    WebSocketService.instance.on('audio', _onNewMessage);
    WebSocketService.instance.on('file', _onNewMessage);
    WebSocketService.instance.on('group_message', _onNewMessage);
    WebSocketService.instance.on('system', _onNewMessage); // 系统用户私聊消息（type=system）
    WebSocketService.instance.on('conversation_last_message', _onConversationUpdate);
    // 监听好友在线状态变化
    WebSocketService.instance.on('status', _onStatusChange);
    // 监听系统广播通知
    WebSocketService.instance.on('system_notify', _onSystemNotify);
    // 监听好友请求被接受（自动通过或手动接受），刷新会话列表
    WebSocketService.instance.on('friend_accepted', _onFriendAccepted);
    // 监听好友请求（更新系统通知会话未读数）
    WebSocketService.instance.on('friend_request', _onNewMessage);
    // 监听公众号新文章（更新会话列表）
    WebSocketService.instance.on('official_account_article', _onNewMessage);
    // 监听消息撤回（更新会话列表预览，不全量刷新避免会话消失）
    WebSocketService.instance.on('message_recalled', _onMessageRecalledConv);
    WebSocketService.instance.on('group_message_recalled', _onMessageRecalledConv);
    // 监听输入状态
    WebSocketService.instance.on('typing', _onTypingStatus);
    WebSocketService.instance.on('typing_stop', _onTypingStopStatus);

    loadConversations();
  }

  /// 强制刷新，即使正在加载中也会等待完成后重新加载
  Future<void> forceRefresh() async {
    if (_isLoading) {
      _pendingRefresh = true;
      // 等待当前加载完成
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return;
    }
    await loadConversations();
  }

  Future<void> loadConversations({bool loadMore = false}) async {
    if (_isLoading) {
      _pendingRefresh = true;
      return;
    }
    _isLoading = true;
    _pendingRefresh = false;
    if (!loadMore) notifyListeners();

    try {
      int? beforeId;
      if (loadMore && _conversations.isNotEmpty) {
        // 使用 offset 模式：传已加载的数量作为偏移量
        beforeId = _conversations.length;
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
        // 保持当前正在查看的会话未读数为0
        if (_activeConversationId != null || _activeFriendId != null || _activeGroupId != null) {
          for (int i = 0; i < _conversations.length; i++) {
            final c = _conversations[i];
            bool isActive = false;
            if (_activeConversationId != null && c['id'] == _activeConversationId) {
              isActive = true;
            } else if (_activeFriendId != null && c['type'] == 1) {
              final fId = c['friend_id'] ?? c['friend']?['id'];
              if (fId == _activeFriendId) isActive = true;
            } else if (_activeGroupId != null && c['type'] == 2) {
              final gId = c['target_id'] ?? c['group']?['id'];
              if (gId == _activeGroupId) isActive = true;
            }
            if (isActive) {
              _conversations[i] = {..._conversations[i], 'unread_count': 0};
            }
          }
        }
      }
      _hasMore = result['has_more'] == true;
    } catch (e) {
      // Handle error
    }

    _isLoading = false;
    notifyListeners();

    // 如果加载期间有新的刷新请求，再刷一次
    if (_pendingRefresh) {
      _pendingRefresh = false;
      loadConversations();
    }
  }

  /// 重置状态（切换账号时调用）
  void reset() {
    _conversations = [];
    _onlineUsers = [];
    _isLoading = false;
    _hasMore = true;
    _initialized = false;
    _pendingRefresh = false;
    _activeConversationId = null;
    _activeFriendId = null;
    _activeGroupId = null;
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
    // 延迟少许确保后端已更新会话记录
    Future.delayed(const Duration(milliseconds: 300), () {
      loadConversations();
    });
  }

  void _onConversationUpdate(Map<String, dynamic> msg) {
    loadConversations();
  }

  /// 好友请求被接受后，延迟刷新会话列表（等后端异步创建会话完成）
  void _onFriendAccepted(Map<String, dynamic> msg) {
    Future.delayed(const Duration(milliseconds: 800), () {
      loadConversations();
    });
  }

  /// 消息撤回：只更新会话预览，不全量刷新（避免会话消失）
  void _onMessageRecalledConv(Map<String, dynamic> msg) {
    // 不做全量刷新，会话列表保持不变
    // 预览文字会在下次正常刷新时更新
    notifyListeners();
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

  /// 处理输入状态
  void _onTypingStatus(Map<String, dynamic> msg) {
    final fromId = msg['from'] as int? ?? (msg['from_id'] as int?);
    if (fromId == null) return;
    _typingUsers[fromId] = true;
    notifyListeners();
    // 3秒后自动清除
    _typingTimers[fromId]?.cancel();
    _typingTimers[fromId] = Timer(const Duration(seconds: 3), () {
      _typingUsers.remove(fromId);
      _typingTimers.remove(fromId);
      notifyListeners();
    });
  }

  /// 处理停止输入
  void _onTypingStopStatus(Map<String, dynamic> msg) {
    final fromId = msg['from'] as int? ?? (msg['from_id'] as int?);
    if (fromId == null) return;
    _typingTimers[fromId]?.cancel();
    _typingTimers.remove(fromId);
    if (_typingUsers.remove(fromId) != null) {
      notifyListeners();
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
        'last_time': DateTime.now().toUtc().toIso8601String(),
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
        'last_time': DateTime.now().toUtc().toIso8601String(),
        'unread_count': 1,
        'pinned': true,
      });
    }
    notifyListeners();
  }

  void markAsRead(int conversationId) {
    _activeConversationId = conversationId;
    final index = _conversations.indexWhere((c) => c['id'] == conversationId);
    if (index != -1) {
      _conversations[index] = {..._conversations[index], 'unread_count': 0};
      notifyListeners();
    }
  }

  void markAsReadByFriendId(int friendId) {
    _activeFriendId = friendId;
    _activeGroupId = null;
    final index = _conversations.indexWhere((c) {
      final fId = c['friend_id'] ?? c['friend']?['id'];
      return c['type'] == 1 && fId == friendId;
    });
    if (index != -1) {
      _activeConversationId = _conversations[index]['id'] as int?;
      _conversations[index] = {..._conversations[index], 'unread_count': 0};
      notifyListeners();
    }
  }

  void markAsReadByGroupId(int groupId) {
    _activeFriendId = null;
    _activeGroupId = groupId;
    final index = _conversations.indexWhere((c) {
      final gId = c['target_id'] ?? c['group']?['id'];
      return c['type'] == 2 && gId == groupId;
    });
    if (index != -1) {
      _activeConversationId = _conversations[index]['id'] as int?;
      _conversations[index] = {..._conversations[index], 'unread_count': 0};
      notifyListeners();
    }
  }

  void clearActiveConversation() {
    _activeConversationId = null;
    _activeFriendId = null;
    _activeGroupId = null;
  }

  // --- 置顶/静音 ---
  final _dio = ApiClient.instance.dio;

  Future<bool> togglePin(Map<String, dynamic> conversation) async {
    final type = conversation['type'] as int? ?? 1;
    final isGroup = type == 2;
    final pinned = conversation['pinned'] == true;
    final newPinned = !pinned;

    try {
      if (isGroup) {
        final groupId = conversation['target_id'] ?? conversation['group']?['id'];
        await _dio.put('/conversations/groups/$groupId/pin', data: {'pinned': newPinned});
      } else {
        final friendId = conversation['friend_id'] ?? conversation['friend']?['id'];
        await _dio.put('/conversations/$friendId/pin', data: {'pinned': newPinned});
      }
      // 本地更新
      final index = _conversations.indexWhere((c) => c['id'] == conversation['id']);
      if (index != -1) {
        _conversations[index] = {..._conversations[index], 'pinned': newPinned};
        _sortConversations();
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('[ConversationProvider] togglePin error: $e');
      return false;
    }
  }

  Future<bool> toggleMute(Map<String, dynamic> conversation) async {
    final type = conversation['type'] as int? ?? 1;
    final isGroup = type == 2;
    final muted = conversation['muted'] == true;
    final newMuted = !muted;

    try {
      if (isGroup) {
        final groupId = conversation['target_id'] ?? conversation['group']?['id'];
        await _dio.put('/conversations/groups/$groupId/mute', data: {'muted': newMuted});
      } else {
        final friendId = conversation['friend_id'] ?? conversation['friend']?['id'];
        await _dio.put('/conversations/$friendId/mute', data: {'muted': newMuted});
      }
      // 本地更新
      final index = _conversations.indexWhere((c) => c['id'] == conversation['id']);
      if (index != -1) {
        _conversations[index] = {..._conversations[index], 'muted': newMuted};
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('[ConversationProvider] toggleMute error: $e');
      return false;
    }
  }

  /// 排序会话列表：置顶在前，按时间倒序
  void _sortConversations() {
    // 系统通知始终在最前面
    final systemIdx = _conversations.indexWhere((c) {
      final fId = c['friend_id'] ?? c['friend']?['id'];
      return c['type'] == 1 && fId == 1;
    });
    Map<String, dynamic>? systemConv;
    if (systemIdx != -1) {
      systemConv = _conversations.removeAt(systemIdx);
    }

    // 分为置顶和非置顶
    final pinned = _conversations.where((c) => c['pinned'] == true).toList();
    final unpinned = _conversations.where((c) => c['pinned'] != true).toList();

    // 各自按时间排序
    pinned.sort((a, b) => _compareTime(b, a));
    unpinned.sort((a, b) => _compareTime(b, a));

    _conversations = [...pinned, ...unpinned];

    // 系统通知放回最前面
    if (systemConv != null) {
      _conversations.insert(0, systemConv);
    }
  }

  int _compareTime(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aTime = a['last_time']?.toString() ?? '';
    final bTime = b['last_time']?.toString() ?? '';
    return aTime.compareTo(bTime);
  }

  Future<bool> updateRemark(int friendId, String remark) async {
    try {
      await _dio.put('/friends/$friendId/remark', data: {'remark': remark});
      // 本地更新
      for (int i = 0; i < _conversations.length; i++) {
        final c = _conversations[i];
        final fId = c['friend_id'] ?? c['friend']?['id'];
        if (c['type'] == 1 && fId == friendId) {
          _conversations[i] = {..._conversations[i], 'friend_remark': remark};
          if (_conversations[i]['friend'] != null) {
            _conversations[i]['friend'] = {..._conversations[i]['friend'] as Map<String, dynamic>, 'remark': remark};
          }
          notifyListeners();
          break;
        }
      }
      return true;
    } catch (e) {
      debugPrint('[ConversationProvider] updateRemark error: $e');
      return false;
    }
  }

  /// 检查会话是否静音
  bool isConversationMuted(int fromId) {
    final conv = _conversations.firstWhere(
      (c) {
        if (c['type'] == 1) {
          final fId = c['friend_id'] ?? c['friend']?['id'];
          return fId == fromId;
        }
        if (c['type'] == 2) {
          final gId = c['target_id'] ?? c['group']?['id'];
          return gId == fromId;
        }
        return false;
      },
      orElse: () => <String, dynamic>{},
    );
    return conv['muted'] == true;
  }

  @override
  void dispose() {
    WebSocketService.instance.off('message', _onNewMessage);
    WebSocketService.instance.off('image', _onNewMessage);
    WebSocketService.instance.off('images', _onNewMessage);
    WebSocketService.instance.off('video', _onNewMessage);
    WebSocketService.instance.off('videos', _onNewMessage);
    WebSocketService.instance.off('audio', _onNewMessage);
    WebSocketService.instance.off('file', _onNewMessage);
    WebSocketService.instance.off('group_message', _onNewMessage);
    WebSocketService.instance.off('system', _onNewMessage);
    WebSocketService.instance.off('conversation_last_message', _onConversationUpdate);
    WebSocketService.instance.off('status', _onStatusChange);
    WebSocketService.instance.off('system_notify', _onSystemNotify);
    WebSocketService.instance.off('friend_accepted', _onFriendAccepted);
    WebSocketService.instance.off('friend_request', _onNewMessage);
    WebSocketService.instance.off('official_account_article', _onNewMessage);
    WebSocketService.instance.off('message_recalled', _onMessageRecalledConv);
    WebSocketService.instance.off('group_message_recalled', _onMessageRecalledConv);
    WebSocketService.instance.off('typing', _onTypingStatus);
    WebSocketService.instance.off('typing_stop', _onTypingStopStatus);
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();
    super.dispose();
  }
}
