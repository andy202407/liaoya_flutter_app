import '../services/websocket_service.dart';
import '../repositories/message_repository.dart';
import '../repositories/conversation_repository.dart';

typedef MessageCallback = void Function(Map<String, dynamic> message);
typedef ConversationCallback = void Function();

/// WebSocket 消息处理器
/// 负责接收 WS 消息并分发到对应的业务逻辑
class MessageHandler {
  final WebSocketService _ws = WebSocketService.instance;
  final MessageRepository _messageRepo = MessageRepository();
  final ConversationRepository _conversationRepo = ConversationRepository();

  // 回调
  final List<MessageCallback> _privateMessageCallbacks = [];
  final List<MessageCallback> _groupMessageCallbacks = [];
  final List<MessageCallback> _systemMessageCallbacks = [];
  final List<ConversationCallback> _conversationUpdateCallbacks = [];
  final List<MessageCallback> _typingCallbacks = [];
  final List<MessageCallback> _recallCallbacks = [];

  MessageHandler() {
    _registerHandlers();
  }

  void _registerHandlers() {
    _ws.on('message', _handlePrivateMessage);
    _ws.on('group_message', _handleGroupMessage);
    _ws.on('system_message', _handleSystemMessage);
    _ws.on('conversation_last_message', _handleConversationUpdate);
    _ws.on('typing', _handleTyping);
    _ws.on('message_recalled', _handleRecall);
    _ws.on('group_message_recalled', _handleGroupRecall);
    _ws.on('friend_request', _handleFriendRequest);
    _ws.on('friend_accepted', _handleFriendAccepted);
    _ws.on('online_status', _handleOnlineStatus);
    _ws.on('read_receipt', _handleReadReceipt);
  }

  // ===== 私聊消息 =====
  void _handlePrivateMessage(Map<String, dynamic> data) {
    final fromId = data['from'] as int? ?? data['from_id'] as int?;
    if (fromId == null) return;

    // 缓存到本地
    _messageRepo.saveMessage(data, friendId: fromId);

    // 通知监听者
    for (final cb in _privateMessageCallbacks) {
      cb(data);
    }
    _notifyConversationUpdate();
  }

  // ===== 群消息 =====
  void _handleGroupMessage(Map<String, dynamic> data) {
    final groupId = data['group_id'] as int? ?? data['to'] as int?;
    if (groupId == null) return;

    // 缓存到本地
    _messageRepo.saveMessage(data, groupId: groupId);

    // 通知监听者
    for (final cb in _groupMessageCallbacks) {
      cb(data);
    }
    _notifyConversationUpdate();
  }

  // ===== 系统消息 =====
  void _handleSystemMessage(Map<String, dynamic> data) {
    for (final cb in _systemMessageCallbacks) {
      cb(data);
    }
    _notifyConversationUpdate();
  }

  // ===== 会话更新 =====
  void _handleConversationUpdate(Map<String, dynamic> data) {
    _notifyConversationUpdate();
  }

  // ===== 输入中 =====
  void _handleTyping(Map<String, dynamic> data) {
    for (final cb in _typingCallbacks) {
      cb(data);
    }
  }

  // ===== 消息撤回 =====
  void _handleRecall(Map<String, dynamic> data) {
    for (final cb in _recallCallbacks) {
      cb(data);
    }
    _notifyConversationUpdate();
  }

  void _handleGroupRecall(Map<String, dynamic> data) {
    for (final cb in _recallCallbacks) {
      cb(data);
    }
    _notifyConversationUpdate();
  }

  // ===== 好友请求 =====
  void _handleFriendRequest(Map<String, dynamic> data) {
    for (final cb in _systemMessageCallbacks) {
      cb({'type': 'friend_request', ...data});
    }
  }

  void _handleFriendAccepted(Map<String, dynamic> data) {
    for (final cb in _systemMessageCallbacks) {
      cb({'type': 'friend_accepted', ...data});
    }
    _notifyConversationUpdate();
  }

  // ===== 在线状态 =====
  void _handleOnlineStatus(Map<String, dynamic> data) {
    // 可以通过单独的回调处理
  }

  // ===== 已读回执 =====
  void _handleReadReceipt(Map<String, dynamic> data) {
    // 更新消息的已读状态
  }

  void _notifyConversationUpdate() {
    for (final cb in _conversationUpdateCallbacks) {
      cb();
    }
  }

  // ===== 注册/注销回调 =====

  void onPrivateMessage(MessageCallback cb) => _privateMessageCallbacks.add(cb);
  void offPrivateMessage(MessageCallback cb) => _privateMessageCallbacks.remove(cb);

  void onGroupMessage(MessageCallback cb) => _groupMessageCallbacks.add(cb);
  void offGroupMessage(MessageCallback cb) => _groupMessageCallbacks.remove(cb);

  void onSystemMessage(MessageCallback cb) => _systemMessageCallbacks.add(cb);
  void offSystemMessage(MessageCallback cb) => _systemMessageCallbacks.remove(cb);

  void onConversationUpdate(ConversationCallback cb) => _conversationUpdateCallbacks.add(cb);
  void offConversationUpdate(ConversationCallback cb) => _conversationUpdateCallbacks.remove(cb);

  void onTyping(MessageCallback cb) => _typingCallbacks.add(cb);
  void offTyping(MessageCallback cb) => _typingCallbacks.remove(cb);

  void onRecall(MessageCallback cb) => _recallCallbacks.add(cb);
  void offRecall(MessageCallback cb) => _recallCallbacks.remove(cb);

  void dispose() {
    _ws.off('message', _handlePrivateMessage);
    _ws.off('group_message', _handleGroupMessage);
    _ws.off('system_message', _handleSystemMessage);
    _ws.off('conversation_last_message', _handleConversationUpdate);
    _ws.off('typing', _handleTyping);
    _ws.off('message_recalled', _handleRecall);
    _ws.off('group_message_recalled', _handleGroupRecall);
    _ws.off('friend_request', _handleFriendRequest);
    _ws.off('friend_accepted', _handleFriendAccepted);
    _ws.off('online_status', _handleOnlineStatus);
    _ws.off('read_receipt', _handleReadReceipt);
    _privateMessageCallbacks.clear();
    _groupMessageCallbacks.clear();
    _systemMessageCallbacks.clear();
    _conversationUpdateCallbacks.clear();
    _typingCallbacks.clear();
    _recallCallbacks.clear();
  }
}
