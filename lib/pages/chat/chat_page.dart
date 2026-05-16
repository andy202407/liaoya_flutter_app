import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/avatar_widget.dart';
import '../../services/websocket_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/conversation_provider.dart';
import 'package:provider/provider.dart';

class ChatPage extends StatefulWidget {
  final Map<String, dynamic> conversation;

  const ChatPage({super.key, required this.conversation});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _dio = ApiClient.instance.dio;
  final _inputFocusNode = FocusNode();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _hasMore = true;
  bool _loadingMore = false;
  String? _announcement; // 群公告

  int get _type => widget.conversation['type'] as int? ?? 1;
  bool get _isGroup => _type == 2;
  int? get _friendId => widget.conversation['friend']?['id'] as int?;
  int? get _groupId => _isGroup ? (widget.conversation['target_id'] ?? widget.conversation['group']?['id']) as int? : null;

  String get _chatName {
    if (_isGroup) return widget.conversation['group']?['name'] ?? '群聊';
    return widget.conversation['friend']?['nickname'] ?? widget.conversation['friend']?['username'] ?? '用户';
  }

  String? get _chatAvatar {
    if (_isGroup) return widget.conversation['group']?['avatar'] as String?;
    return widget.conversation['friend']?['avatar'] as String?;
  }

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _markAsRead();
    _scrollController.addListener(_onScroll);
    _inputFocusNode.addListener(_onInputFocus);
    // 监听实时消息
    WebSocketService.instance.on('message', _onWsMessage);
    WebSocketService.instance.on('group_message', _onWsGroupMessage);
    // 监听系统广播
    WebSocketService.instance.on('system_notify', _onSystemNotify);
    // 加载群公告
    if (_isGroup) _loadAnnouncement();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    WebSocketService.instance.off('message', _onWsMessage);
    WebSocketService.instance.off('group_message', _onWsGroupMessage);
    WebSocketService.instance.off('system_notify', _onSystemNotify);
    super.dispose();
  }

  // --- 已读回执 ---
  void _markAsRead() {
    if (_isGroup) {
      // 群聊：发送 clear_group_unread
      if (_groupId != null) {
        WebSocketService.instance.send({
          'type': 'clear_group_unread',
          'content': {'group_id': _groupId},
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    } else {
      // 私聊：发送 message_read
      if (_friendId != null) {
        final userId = context.read<AuthProvider>().userId;
        WebSocketService.instance.send({
          'type': 'message_read',
          'from': userId,
          'to': _friendId,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    }
    // 清除本地未读
    final convId = widget.conversation['id'] as int?;
    if (convId != null && convId > 0) {
      context.read<ConversationProvider>().markAsRead(convId);
    }
  }

  void _onInputFocus() {
    if (_inputFocusNode.hasFocus) {
      _markAsRead();
    }
  }

  // --- 群公告 ---
  Future<void> _loadAnnouncement() async {
    if (_groupId == null) return;
    try {
      final response = await _dio.get('/groups/$_groupId/announcements');
      if (response.data['success'] == true) {
        final List<dynamic> list = response.data['data'] ?? [];
        if (list.isNotEmpty) {
          setState(() => _announcement = list.first['content'] as String?);
        }
      }
    } catch (_) {}
  }

  // --- 系统广播通知 ---
  void _onSystemNotify(Map<String, dynamic> msg) {
    // 把系统广播当作一条系统消息显示在当前聊天中
    final content = msg['content'];
    String text = '';
    if (content is Map) {
      text = content['message'] as String? ?? content['content'] as String? ?? '系统通知';
    } else if (content is String) {
      text = content;
    }
    if (text.isNotEmpty) {
      setState(() => _messages.insert(0, {
        'id': DateTime.now().millisecondsSinceEpoch,
        'content': text,
        'type': 'system',
        'created_at': DateTime.now().toIso8601String(),
      }));
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      _loadMoreMessages();
    }
  }

  void _onWsMessage(Map<String, dynamic> msg) {
    if (!_isGroup) {
      final fromId = msg['from'] ?? msg['from_id'];
      if (fromId == _friendId) {
        setState(() => _messages.insert(0, msg));
        _scrollToBottom();
        _markAsRead();
      }
    }
  }

  void _onWsGroupMessage(Map<String, dynamic> msg) {
    if (_isGroup) {
      final groupId = msg['group_id'] ?? msg['to'];
      if (groupId == _groupId) {
        setState(() => _messages.insert(0, msg));
        _scrollToBottom();
        _markAsRead();
      }
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final Response response;
      if (_isGroup) {
        response = await _dio.get('/groups/$_groupId/messages', queryParameters: {'limit': 50});
      } else {
        response = await _dio.get('/messages/', queryParameters: {'friend_id': _friendId, 'limit': 50});
      }

      if (response.data['success'] == true) {
        final dynamic rawData = response.data['data'];
        List<Map<String, dynamic>> msgList = [];
        if (rawData is List) {
          for (final item in rawData) {
            if (item is Map<String, dynamic>) {
              msgList.add(item);
            } else if (item is Map) {
              msgList.add(Map<String, dynamic>.from(item));
            }
          }
        }
        setState(() {
          _messages = msgList;
          _hasMore = msgList.length >= 50;
        });
      }
    } catch (e) {
      debugPrint('[ChatPage] load error: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadMoreMessages() async {
    if (_loadingMore || !_hasMore || _messages.isEmpty) return;
    _loadingMore = true;

    final lastMsg = _messages.last;
    final beforeId = lastMsg['id'] as int?;
    if (beforeId == null) {
      _loadingMore = false;
      return;
    }

    try {
      final Response response;
      if (_isGroup) {
        response = await _dio.get('/groups/$_groupId/messages', queryParameters: {'limit': 50, 'before_id': beforeId});
      } else {
        response = await _dio.get('/messages/', queryParameters: {'friend_id': _friendId, 'limit': 50, 'before_id': beforeId});
      }

      if (response.data['success'] == true) {
        final dynamic rawData = response.data['data'];
        if (rawData is List) {
          final List<Map<String, dynamic>> moreMessages = [];
          for (final item in rawData) {
            if (item is Map<String, dynamic>) {
              moreMessages.add(item);
            } else if (item is Map) {
              moreMessages.add(Map<String, dynamic>.from(item));
            }
          }
          setState(() {
            _messages.addAll(moreMessages);
            _hasMore = moreMessages.length >= 50;
          });
        }
      }
    } catch (e) {
      debugPrint('[ChatPage] load more error: $e');
    }
    _loadingMore = false;
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      if (_isGroup) {
        final response = await _dio.post('/groups/$_groupId/messages',
          data: FormData.fromMap({'content': text, 'type': 'message'}),
        );
        if (response.data['success'] == true) {
          final msg = response.data['data'] as Map<String, dynamic>;
          setState(() => _messages.insert(0, msg));
          _scrollToBottom();
        }
      } else {
        final currentUser = context.read<AuthProvider>().user;
        WebSocketService.instance.send({
          'type': 'message',
          'to': _friendId,
          'content': text,
          'message_type': 'text',
        });
        setState(() => _messages.insert(0, {
          'id': DateTime.now().millisecondsSinceEpoch,
          'from_id': currentUser?['id'],
          'to_id': _friendId,
          'content': text,
          'type': 'text',
          'created_at': DateTime.now().toIso8601String(),
          'from_user': currentUser,
          'temp': true,
        }));
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('发送失败')));
      }
      _messageController.text = text;
    }
    setState(() => _isSending = false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = context.read<AuthProvider>().userId;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarWidget(url: _chatAvatar, name: _chatName, size: 32, isGroup: _isGroup),
            const SizedBox(width: 10),
            Flexible(child: Text(_chatName, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
      body: Column(
        children: [
          // 群公告
          if (_isGroup && _announcement != null && _announcement!.isNotEmpty)
            _buildAnnouncementBar(isDark),
          // 消息列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(child: Text('暂无消息', style: AppTextStyles.body.copyWith(color: AppColors.lightTextTertiary)))
                    : CustomScrollView(
                        controller: _scrollController,
                        reverse: true,
                        slivers: [
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final msg = _messages[index];
                                final isMe = (msg['from_id'] ?? msg['from']) == currentUserId;
                                return _MessageBubble(message: msg, isMe: isMe, isGroup: _isGroup, isDark: isDark);
                              },
                              childCount: _messages.length,
                            ),
                          ),
                          // 填充剩余空间，让消息靠顶部
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: const SizedBox.shrink(),
                          ),
                        ],
                      ),
          ),
          // 输入框
          _buildInputBar(isDark),
        ],
      ),
    );
  }

  Widget _buildAnnouncementBar(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.primary.withAlpha(25) : AppColors.primary.withAlpha(15),
        border: Border(bottom: BorderSide(color: AppColors.primary.withAlpha(40), width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.campaign_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _announcement!,
              style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkText : AppColors.lightText),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, MediaQuery.of(context).padding.bottom + AppSpacing.sm),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        border: Border(top: BorderSide(color: (isDark ? AppColors.darkDivider : AppColors.lightDivider).withValues(alpha: 0.5), width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkInputBg : AppColors.lightInputBg,
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _inputFocusNode,
                decoration: const InputDecoration(
                  hintText: '输入消息...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: _isSending
                  ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final bool isGroup;
  final bool isDark;

  const _MessageBubble({required this.message, required this.isMe, required this.isGroup, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final content = message['content'] as String? ?? '';
    final type = message['type'] as String? ?? message['message_type'] as String? ?? 'text';
    final fromUser = message['from_user'] as Map<String, dynamic>?;
    final senderName = fromUser?['nickname'] ?? fromUser?['username'] ?? '';
    final time = message['created_at'] ?? message['timestamp'] ?? '';

    // 系统消息
    if (type == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(content, style: AppTextStyles.captionSm.copyWith(color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            AvatarWidget(url: fromUser?['avatar'] as String?, name: senderName, size: 34),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (isGroup && !isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2, left: 4),
                    child: Text(senderName, style: AppTextStyles.captionSm.copyWith(color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.bubbleSent : (isDark ? AppColors.bubbleReceivedDark : AppColors.bubbleReceived),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: _buildContent(content, type),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Text(_formatTime(time), style: AppTextStyles.captionSm.copyWith(color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildContent(String content, String type) {
    if (type == 'image' || type == 'images') {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(Icons.image_rounded, size: 16, color: Colors.white70), SizedBox(width: 4), Text('[图片]', style: TextStyle(color: Colors.white70))],
      );
    }
    if (type == 'video' || type == 'videos') {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(Icons.videocam_rounded, size: 16, color: Colors.white70), SizedBox(width: 4), Text('[视频]', style: TextStyle(color: Colors.white70))],
      );
    }
    if (type == 'audio') {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(Icons.mic_rounded, size: 16, color: Colors.white70), SizedBox(width: 4), Text('[语音]', style: TextStyle(color: Colors.white70))],
      );
    }
    if (type == 'file') {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(Icons.attach_file_rounded, size: 16, color: Colors.white70), SizedBox(width: 4), Text('[文件]', style: TextStyle(color: Colors.white70))],
      );
    }

    return Text(
      content,
      style: AppTextStyles.chatMsg.copyWith(color: isMe ? Colors.white : (isDark ? AppColors.darkText : AppColors.lightText)),
    );
  }

  String _formatTime(String timeStr) {
    if (timeStr.isEmpty) return '';
    try {
      final time = DateTime.parse(timeStr);
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }
}
