import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../config/api_config.dart';
import '../../services/api/api_client.dart';
import 'media_preview_page.dart';
import 'group_info_page.dart';
import '../../services/storage_service.dart';
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
  Timer? _carouselTimer;
  ConversationProvider? _convProvider;

  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _announcements = []; // 置顶公告列表
  int _announcementIndex = 0; // 当前轮播索引
  bool _announcementExpanded = false; // 公告是否展开
  bool _isLoading = true;
  bool _isSending = false;
  bool _hasMore = true;
  bool _loadingMore = false;
  int _groupMemberCount = 0; // 群成员总数

  int get _type => widget.conversation['type'] as int? ?? 1;
  bool get _isGroup => _type == 2;
  int? get _friendId => widget.conversation['friend']?['id'] as int?;
  bool get _isSystemNotification => !_isGroup && _friendId == 1;
  int? get _groupId => _isGroup ? (widget.conversation['target_id'] ?? widget.conversation['group']?['id']) as int? : null;

  String get _chatName {
    if (_isGroup) return widget.conversation['group']?['name'] ?? '群聊';
    // 优先显示备注
    final remark = widget.conversation['friend_remark'] ?? widget.conversation['friend']?['remark'];
    if (remark != null && remark.toString().isNotEmpty) return remark.toString();
    return widget.conversation['friend']?['nickname'] ?? widget.conversation['friend']?['username'] ?? '用户';
  }

  String? get _chatAvatar {
    if (_isGroup) return widget.conversation['group']?['avatar'] as String?;
    return widget.conversation['friend']?['avatar'] as String?;
  }

  int? _currentUserId; // 缓存当前用户ID

  @override
  void initState() {
    super.initState();
    _convProvider = context.read<ConversationProvider>();
    _initCurrentUserId();
    _loadMessages();
    // 延迟标记已读，避免在 build 过程中触发 notifyListeners
    WidgetsBinding.instance.addPostFrameCallback((_) => _markAsRead());
    _scrollController.addListener(_onScroll);
    _inputFocusNode.addListener(_onInputFocus);
    // 监听实时消息
    WebSocketService.instance.on('message', _onWsMessage);
    WebSocketService.instance.on('image', _onWsMessage);
    WebSocketService.instance.on('images', _onWsMessage);
    WebSocketService.instance.on('video', _onWsMessage);
    WebSocketService.instance.on('videos', _onWsMessage);
    WebSocketService.instance.on('audio', _onWsMessage);
    WebSocketService.instance.on('file', _onWsMessage);
    WebSocketService.instance.on('group_message', _onWsGroupMessage);
    // 监听消息撤回
    WebSocketService.instance.on('message_recalled', _onMessageRecalled);
    WebSocketService.instance.on('group_message_recalled', _onGroupMessageRecalled);
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
    _carouselTimer?.cancel();
    // 清除活跃会话标记（在 dispose 前获取 provider 引用）
    _convProvider?.clearActiveConversation();
    WebSocketService.instance.off('message', _onWsMessage);
    WebSocketService.instance.off('image', _onWsMessage);
    WebSocketService.instance.off('images', _onWsMessage);
    WebSocketService.instance.off('video', _onWsMessage);
    WebSocketService.instance.off('videos', _onWsMessage);
    WebSocketService.instance.off('audio', _onWsMessage);
    WebSocketService.instance.off('file', _onWsMessage);
    WebSocketService.instance.off('group_message', _onWsGroupMessage);
    WebSocketService.instance.off('message_recalled', _onMessageRecalled);
    WebSocketService.instance.off('group_message_recalled', _onGroupMessageRecalled);
    WebSocketService.instance.off('system_notify', _onSystemNotify);
    super.dispose();
  }

  /// 从多个来源获取当前用户ID，确保不为null
  Future<void> _initCurrentUserId() async {
    // 优先从 AuthProvider 获取
    final authId = context.read<AuthProvider>().userId;
    if (authId != null) {
      _currentUserId = authId;
      return;
    }
    // fallback: 从 StorageService 读取
    final storage = await StorageService.getInstance();
    final user = storage.getUser();
    if (user != null && user['id'] != null) {
      _currentUserId = user['id'] as int;
      if (mounted) setState(() {});
    }
  }

  // --- 已读回执 ---
  void _markAsRead() {
    if (_isGroup) {
      // 群聊：发送 clear_group_unread + HTTP API
      if (_groupId != null) {
        WebSocketService.instance.send({
          'type': 'clear_group_unread',
          'content': {'group_id': _groupId},
          'timestamp': DateTime.now().toIso8601String(),
        });
        _dio.post('/groups/$_groupId/read').catchError((e) => null);
      }
    } else {
      // 私聊：发送 message_read + HTTP API 双保险
      if (_friendId != null) {
        final userId = context.read<AuthProvider>().userId ?? _currentUserId;
        WebSocketService.instance.send({
          'type': 'message_read',
          'from': userId,
          'to': _friendId,
          'timestamp': DateTime.now().toIso8601String(),
        });
        // HTTP API 确保后端清除未读（防止 WebSocket 丢失）
        _dio.put('/messages/$_friendId/read').catchError((e) => null);
      }
    }
    // 清除本地未读
    final convId = widget.conversation['id'] as int?;
    debugPrint('[ChatPage] markAsRead convId=$convId, friendId=$_friendId, groupId=$_groupId');
    if (convId != null && convId > 0) {
      context.read<ConversationProvider>().markAsRead(convId);
    }
    // 同时通过 friendId/groupId 匹配清除（双保险）
    if (_friendId != null && !_isGroup) {
      context.read<ConversationProvider>().markAsReadByFriendId(_friendId!);
    } else if (_groupId != null && _isGroup) {
      context.read<ConversationProvider>().markAsReadByGroupId(_groupId!);
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
        final pinned = <Map<String, dynamic>>[];
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            // 只取置顶的公告（如果有 pinned 字段）
            if (item['pinned'] == true || list.length <= 3) {
              pinned.add(item);
            }
          } else if (item is Map) {
            final m = Map<String, dynamic>.from(item);
            if (m['pinned'] == true || list.length <= 3) {
              pinned.add(m);
            }
          }
        }
        setState(() {
          _announcements = pinned;
          _announcementIndex = 0;
          _announcementExpanded = false;
        });
        _startCarousel();
      }
    } catch (_) {}
  }

  void _startCarousel() {
    _carouselTimer?.cancel();
    if (_announcements.length > 1) {
      _carouselTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!_announcementExpanded && mounted) {
          setState(() {
            _announcementIndex = (_announcementIndex + 1) % _announcements.length;
          });
        }
      });
    }
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
    // reverse 模式下，滚动到顶部（maxScrollExtent）加载更多历史消息
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      _loadMoreMessages();
    }
  }

  void _onWsMessage(Map<String, dynamic> msg) {
    if (!_isGroup) {
      final fromId = msg['from'] ?? msg['from_id'];
      debugPrint('[ChatPage] _onWsMessage: type=${msg['type']}, fromId=$fromId (${fromId.runtimeType}), _friendId=$_friendId (${_friendId.runtimeType}), match=${fromId == _friendId}');
      if (fromId != null && _friendId != null && '$fromId' == '$_friendId') {
        setState(() => _messages.insert(0, msg));
        _scrollToBottom();
        _markAsRead();
      }
    }
  }

  void _onWsGroupMessage(Map<String, dynamic> msg) {
    if (_isGroup) {
      final groupId = msg['group_id'] ?? msg['to'];
      if (groupId != null && _groupId != null && '$groupId' == '$_groupId') {
        setState(() => _messages.insert(0, msg));
        _scrollToBottom();
        _markAsRead();
      }
    }
  }

  /// 私聊消息撤回
  void _onMessageRecalled(Map<String, dynamic> msg) {
    if (_isGroup) return;
    final messageId = msg['content'];
    if (messageId == null) return;
    final id = int.tryParse('$messageId');
    if (id == null) return;
    setState(() {
      _messages.removeWhere((m) => m['id'] == id);
    });
  }

  /// 群聊消息撤回
  void _onGroupMessageRecalled(Map<String, dynamic> msg) {
    if (!_isGroup) return;
    final groupId = msg['group_id'] ?? msg['to'];
    if (groupId == null || '$groupId' != '$_groupId') return;
    final messageId = msg['message_id'] ?? msg['content'];
    if (messageId == null) return;
    final id = int.tryParse('$messageId');
    if (id == null) return;
    setState(() {
      _messages.removeWhere((m) => m['id'] == id);
    });
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
        // 群消息返回格式: { messages: [...], has_more: bool }
        // 私聊消息返回格式: [...]
        final dynamic messageData = rawData is Map ? rawData['messages'] : rawData;
        if (messageData is List) {
          for (final item in messageData) {
            if (item is Map<String, dynamic>) {
              if (item['recalled'] == true) continue; // 跳过已撤回的消息
              msgList.add(item);
            } else if (item is Map) {
              final m = Map<String, dynamic>.from(item);
              if (m['recalled'] == true) continue;
              msgList.add(m);
            }
          }
        }
        setState(() {
          _messages = msgList;
          _hasMore = rawData is Map ? (rawData['has_more'] == true) : msgList.length >= 50;
          if (rawData is Map && rawData['total_count'] != null) {
            _groupMemberCount = rawData['total_count'] as int? ?? 0;
          }
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
        final dynamic messageData = rawData is Map ? rawData['messages'] : rawData;
        if (messageData is List) {
          final List<Map<String, dynamic>> moreMessages = [];
          for (final item in messageData) {
            if (item is Map<String, dynamic>) {
              if (item['recalled'] == true) continue;
              moreMessages.add(item);
            } else if (item is Map) {
              final m = Map<String, dynamic>.from(item);
              if (m['recalled'] == true) continue;
              moreMessages.add(m);
            }
          }
          setState(() {
            _messages.addAll(moreMessages);
            _hasMore = rawData is Map ? (rawData['has_more'] == true) : moreMessages.length >= 50;
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
    final quoted = _quotedMessage;
    setState(() => _quotedMessage = null);

    // 构建引用消息（作为对象发送，不是 JSON 字符串）
    Map<String, dynamic>? quotedData;
    if (quoted != null) {
      quotedData = {
        'id': quoted['id'],
        'from': quoted['from_id'] ?? quoted['from'],
        'from_name': quoted['from_user']?['nickname'] ?? quoted['from_name'] ?? quoted['fromName'] ?? '',
        'type': quoted['message_type'] ?? quoted['type'] ?? 'text',
        'content': quoted['content'] ?? '',
        'timestamp': quoted['created_at'] ?? quoted['timestamp'] ?? '',
      };
    }

    try {
      if (_isGroup) {
        final data = <String, dynamic>{'content': text, 'type': 'message'};
        if (quotedData != null) data['quoted_message'] = jsonEncode(quotedData);
        final response = await _dio.post('/groups/$_groupId/messages',
          data: FormData.fromMap(data),
        );
        if (response.data['success'] == true) {
          final msg = response.data['data'] as Map<String, dynamic>;
          setState(() => _messages.insert(0, msg));
          _scrollToBottom();
        }
      } else {
        final currentUser = context.read<AuthProvider>().user;
        final wsData = <String, dynamic>{
          'type': 'message',
          'to': _friendId,
          'content': text,
          'message_type': 'text',
        };
        if (quotedData != null) wsData['quoted_message'] = quotedData;
        WebSocketService.instance.send(wsData);
        setState(() => _messages.insert(0, {
          'id': DateTime.now().millisecondsSinceEpoch,
          'from_id': currentUser?['id'] ?? _currentUserId,
          'to_id': _friendId,
          'content': text,
          'type': 'text',
          'quoted_message': quotedData,
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

  bool _showEmojiPicker = false;
  Map<String, dynamic>? _quotedMessage; // 引用的消息
  int? _selectedMessageId; // 当前选中的消息ID（显示操作按钮）

  Future<void> _pickAndSendImage() async {
    // 先收起键盘，避免选择器返回后键盘区域残留
    FocusScope.of(context).unfocus();
    
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('选择视频'),
              onTap: () => Navigator.pop(ctx, null), // 特殊标记：选视频
            ),
          ],
        ),
      ),
    );

    if (source == null && !mounted) return;

    XFile? file;
    String type;

    if (source == null) {
      // 选择视频
      file = await picker.pickVideo(source: ImageSource.gallery);
      type = 'video';
    } else {
      file = await picker.pickImage(source: source, imageQuality: 80);
      type = 'image';
    }

    if (file == null || !mounted) return;
    final pickedFile = file;

    setState(() => _isSending = true);

    try {
      // 1. 上传文件（兼容 Web 平台）
      final bytes = await pickedFile.readAsBytes();
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: pickedFile.name),
      });
      final uploadResponse = await _dio.post('/files/upload/$type', data: formData);

      if (uploadResponse.data['success'] != true) {
        throw Exception('上传失败');
      }

      final fileData = uploadResponse.data['data'] as Map<String, dynamic>;
      final fileUrl = fileData['url'] as String? ?? '';
      final imageWidth = fileData['width'] as int? ?? 0;
      final imageHeight = fileData['height'] as int? ?? 0;

      // 2. 发送消息
      if (_isGroup) {
        final response = await _dio.post('/groups/$_groupId/messages',
          data: FormData.fromMap({
            'content': '',
            'type': type,
            'file_url': fileUrl,
            'image_width': imageWidth,
            'image_height': imageHeight,
          }),
        );
        if (response.data['success'] == true) {
          final msg = response.data['data'] as Map<String, dynamic>;
          setState(() => _messages.insert(0, msg));
          _scrollToBottom();
        }
      } else {
        WebSocketService.instance.send({
          'type': type,
          'to': _friendId,
          'content': '',
          'message_type': type,
          'file_url': fileUrl,
          'image_width': imageWidth,
          'image_height': imageHeight,
        });
        setState(() => _messages.insert(0, {
          'id': DateTime.now().millisecondsSinceEpoch,
          'from_id': _currentUserId,
          'to_id': _friendId,
          'content': '',
          'type': type,
          'message_type': type,
          'file_url': fileUrl,
          'image_width': imageWidth,
          'image_height': imageHeight,
          'created_at': DateTime.now().toIso8601String(),
          'temp': true,
        }));
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('发送失败: $e')));
      }
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

  DateTime? _parseTime(dynamic timeStr) {
    if (timeStr == null) return null;
    try {
      return DateTime.parse(timeStr.toString());
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();
    final currentUserId = authProvider.userId ?? _currentUserId;
    debugPrint('[ChatPage] authProvider.user=${authProvider.user}, userId=$currentUserId, _currentUserId=$_currentUserId');

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        title: GestureDetector(
          onTap: _isGroup ? () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => GroupInfoPage(groupId: _groupId!, groupName: _chatName, groupAvatar: _chatAvatar),
          )) : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AvatarWidget(url: _chatAvatar, name: _chatName, size: 32, isGroup: _isGroup),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_chatName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    if (_isGroup && _groupMemberCount > 0)
                      Text('群聊 · $_groupMemberCount人', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // 群公告
          if (_isGroup && _announcements.isNotEmpty)
            _buildAnnouncementBar(isDark),
          // 消息列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(child: Text('暂无消息', style: AppTextStyles.body.copyWith(color: AppColors.lightTextTertiary)))
                    : Align(
                        alignment: Alignment.topCenter,
                        child: ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final fromId = msg['from_id'] ?? msg['from_user']?['id'] ?? msg['from'];
                          final isMe = fromId != null && currentUserId != null && '$fromId' == '$currentUserId';
                          // 时间分隔：与上一条消息间隔超过5分钟才显示时间
                          bool showTime = false;
                          if (index == _messages.length - 1) {
                            showTime = true;
                          } else {
                            final nextMsg = _messages[index + 1];
                            final curTime = _parseTime(msg['created_at'] ?? msg['timestamp']);
                            final nextTime = _parseTime(nextMsg['created_at'] ?? nextMsg['timestamp']);
                            if (curTime != null && nextTime != null) {
                              showTime = curTime.difference(nextTime).inMinutes.abs() >= 5;
                            }
                          }
                          return _MessageBubble(
                            message: msg,
                            isMe: isMe,
                            isGroup: _isGroup,
                            isDark: isDark,
                            showTime: showTime,
                            isSelected: _selectedMessageId == msg['id'],
                            onQuote: (m) => setState(() => _quotedMessage = m),
                            onTap: () => setState(() {
                              _selectedMessageId = _selectedMessageId == msg['id'] ? null : msg['id'] as int?;
                            }),
                          );
                        },
                      ),
                    ),
          ),
          // 引用消息预览
          if (_quotedMessage != null && !_isSystemNotification)
            _buildQuotedPreview(isDark),
          // 输入框（系统通知不显示）
          if (!_isSystemNotification)
            _buildInputBar(isDark),
        ],
      ),
    );
  }

  Widget _buildAnnouncementBar(bool isDark) {
    final current = _announcements[_announcementIndex % _announcements.length];
    final content = current['content'] as String? ?? '';
    final bool isOverflow = _isAnnouncementOverflow(content);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E23).withAlpha(230) : Colors.white.withAlpha(184),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: (isDark ? Colors.white : Colors.black).withAlpha(15), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 77 : 15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 主体内容
          GestureDetector(
            onTap: () {
              // 点击切换到下一条（收起状态下）
              if (!_announcementExpanded && _announcements.length > 1) {
                setState(() {
                  _announcementIndex = (_announcementIndex + 1) % _announcements.length;
                });
              }
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 喇叭图标
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(Icons.campaign_rounded, size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(width: 6),
                  // 公告文本
                  Expanded(
                    child: _buildAnnouncementText(content, isDark),
                  ),
                  // 公告计数
                  if (_announcements.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 6, top: 1),
                      child: Text(
                        '${(_announcementIndex % _announcements.length) + 1}/${_announcements.length}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: (isDark ? Colors.white : Colors.black).withAlpha(153)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // 展开/收起按钮
          if (isOverflow || _announcementExpanded)
            GestureDetector(
              onTap: () {
                setState(() {
                  _announcementExpanded = !_announcementExpanded;
                });
                if (_announcementExpanded) {
                  _carouselTimer?.cancel();
                } else {
                  _startCarousel();
                }
              },
              child: Container(
                width: double.infinity,
                alignment: Alignment.center,
                padding: const EdgeInsets.only(bottom: 6, top: 2),
                child: Icon(
                  _announcementExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 18,
                  color: (isDark ? Colors.white : Colors.black).withAlpha(153),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 判断公告内容是否超过3行
  bool _isAnnouncementOverflow(String content) {
    final newlineCount = '\n'.allMatches(content).length;
    if (newlineCount >= 3) return true;
    final lines = content.split('\n');
    int visualLines = 0;
    for (final line in lines) {
      visualLines += (line.length / 30).ceil().clamp(1, 100);
    }
    return visualLines > 3;
  }

  /// 构建公告文本，URL 可点击复制
  Widget _buildAnnouncementText(String content, bool isDark) {
    final textColor = isDark ? Colors.white.withAlpha(235) : Colors.black.withAlpha(217);
    final linkColor = AppColors.primary;

    // 匹配 URL
    final urlRegex = RegExp(r'(https?://[^\s\u4e00-\u9fff]+|(?:[\w-]+\.)+(?:com|cn|net|org|io|co|me|top|xyz|app|dev|cc|vip)(?:[/\w\-.~:/?#\[\]@!$&()*+,;=%]*))');
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in urlRegex.allMatches(content)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: content.substring(lastEnd, match.start), style: TextStyle(fontSize: 13, color: textColor, height: 1.4)));
      }
      final url = match.group(0)!;
      spans.add(WidgetSpan(
        child: GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: url));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('链接已复制: $url'), duration: const Duration(seconds: 2)));
          },
          child: Text(url, style: TextStyle(fontSize: 13, color: linkColor, height: 1.4, decoration: TextDecoration.underline, decorationColor: linkColor)),
        ),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastEnd), style: TextStyle(fontSize: 13, color: textColor, height: 1.4)));
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: _announcementExpanded ? null : 3,
      overflow: _announcementExpanded ? TextOverflow.clip : TextOverflow.ellipsis,
    );
  }

  Widget _buildQuotedPreview(bool isDark) {
    final content = _quotedMessage?['content'] as String? ?? '';
    final fromUser = _quotedMessage?['from_user'] as Map<String, dynamic>?;
    final senderName = fromUser?['nickname'] ?? fromUser?['username'] ?? '';
    final msgType = _quotedMessage?['message_type'] ?? _quotedMessage?['type'] ?? 'text';
    String preview = content;
    if (msgType == 'image' || msgType == 'images') preview = '[图片]';
    if (msgType == 'video' || msgType == 'videos') preview = '[视频]';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.grey[100],
        border: Border(top: BorderSide(color: (isDark ? AppColors.darkDivider : AppColors.lightDivider).withAlpha(128), width: 0.5)),
      ),
      child: Row(
        children: [
          Container(width: 3, height: 32, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (senderName.isNotEmpty)
                  Text(senderName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _quotedMessage = null),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close, size: 18, color: isDark ? Colors.white38 : Colors.black38),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, _showEmojiPicker ? AppSpacing.sm : MediaQuery.of(context).padding.bottom + AppSpacing.sm),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            border: Border(top: BorderSide(color: (isDark ? AppColors.darkDivider : AppColors.lightDivider).withValues(alpha: 0.5), width: 0.5)),
          ),
          child: Row(
            children: [
              // 图片按钮
              GestureDetector(
                onTap: _pickAndSendImage,
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(Icons.image_rounded, size: 26, color: isDark ? Colors.white54 : Colors.black45),
                ),
              ),
              // 表情按钮
              GestureDetector(
                onTap: () {
                  setState(() => _showEmojiPicker = !_showEmojiPicker);
                  if (_showEmojiPicker) _inputFocusNode.unfocus();
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    _showEmojiPicker ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined,
                    size: 26,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ),
              // 输入框
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
                    onTap: () {
                      if (_showEmojiPicker) setState(() => _showEmojiPicker = false);
                    },
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
        ),
        // 表情面板
        if (_showEmojiPicker)
          _buildEmojiPanel(isDark),
      ],
    );
  }

  Widget _buildEmojiPanel(bool isDark) {
    const emojis = [
      '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂',
      '🙂', '😉', '😊', '😇', '🥰', '😍', '🤩', '😘',
      '😗', '😚', '😙', '🥲', '😋', '😛', '😜', '🤪',
      '😝', '🤑', '🤗', '🤭', '🤫', '🤔', '🫡', '🤐',
      '🤨', '😐', '😑', '😶', '🫥', '😏', '😒', '🙄',
      '😬', '🤥', '😌', '😔', '😪', '🤤', '😴', '😷',
      '🤒', '🤕', '🤢', '🤮', '🥵', '🥶', '🥴', '😵',
      '🤯', '🤠', '🥳', '🥸', '😎', '🤓', '🧐', '😕',
      '🫤', '😟', '🙁', '😮', '😯', '😲', '😳', '🥺',
      '🥹', '😦', '😧', '😨', '😰', '😥', '😢', '😭',
      '😱', '😖', '😣', '😞', '😓', '😩', '😫', '🥱',
      '😤', '😡', '😠', '🤬', '👍', '👎', '👌', '🤝',
      '👏', '🙏', '💪', '❤️', '🔥', '💯', '🎉', '🎊',
      '😈', '👻', '💀', '☠️', '👽', '🤖', '💩', '🐶',
      '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐨',
    ];

    return Container(
      height: 250,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: emojis.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              final text = _messageController.text;
              final selection = _messageController.selection;
              final newText = text.replaceRange(
                selection.start < 0 ? text.length : selection.start,
                selection.end < 0 ? text.length : selection.end,
                emojis[index],
              );
              _messageController.text = newText;
              _messageController.selection = TextSelection.collapsed(
                offset: (selection.start < 0 ? text.length : selection.start) + emojis[index].length,
              );
            },
            child: Center(
              child: Text(emojis[index], style: const TextStyle(fontSize: 24)),
            ),
          );
        },
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final bool isGroup;
  final bool isDark;
  final bool showTime;
  final bool isSelected;
  final void Function(Map<String, dynamic>)? onQuote;
  final VoidCallback? onTap;

  const _MessageBubble({required this.message, required this.isMe, required this.isGroup, required this.isDark, this.showTime = true, this.isSelected = false, this.onQuote, this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = message['content'] as String? ?? '';
    final type = message['type'] as String? ?? message['message_type'] as String? ?? 'text';
    // 兼容：群消息 type='group_message'，私聊 type='message'/'text'，都需要看 message_type
    final effectiveType = (type == 'message' || type == 'text' || type == 'group_message') 
        ? (message['message_type'] as String? ?? type) 
        : type;
    final fromUser = message['from_user'] as Map<String, dynamic>?;
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

    // 公告消息
    if (type == 'announcement') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.primary.withAlpha(20) : AppColors.primary.withAlpha(12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withAlpha(40), width: 0.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.campaign_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('群公告', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    const SizedBox(height: 2),
                    Text(content, style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkText : AppColors.lightText)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 获取 WebSocket 消息中的头像和昵称（兼容不同字段名）
    final avatar = fromUser?['avatar'] ?? message['fromAvatar'] ?? message['from_avatar'];
    final name = fromUser?['nickname'] ?? fromUser?['username'] ?? message['fromName'] ?? message['from_name'] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 群聊对方消息显示头像
          if (!isMe && isGroup) ...[
            AvatarWidget(url: avatar as String?, name: name, size: 34),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onTap: onTap,
              onLongPress: () => _showMessageMenu(context, content),
              onDoubleTap: () {
                if (content.isNotEmpty) {
                  Clipboard.setData(ClipboardData(text: content));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)));
                }
              },
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (isGroup && !isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2, left: 4),
                      child: Text(name, style: AppTextStyles.captionSm.copyWith(color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 自己的消息：操作按钮在左侧
                      if (isMe && isSelected) _buildActionButtons(context, content),
                      Flexible(
                        child: Container(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
                          padding: (effectiveType == 'image' || effectiveType == 'video' || effectiveType == 'images' || effectiveType == 'videos' || effectiveType == 'red_packet' || effectiveType == 'red_packet_grab')
                              ? const EdgeInsets.all(3)
                              : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: (effectiveType == 'image' || effectiveType == 'video' || effectiveType == 'images' || effectiveType == 'videos' || effectiveType == 'red_packet' || effectiveType == 'red_packet_grab')
                                ? Colors.transparent
                                : (isMe ? AppColors.bubbleSent : (isDark ? AppColors.bubbleReceivedDark : AppColors.bubbleReceived)),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(isMe ? 18 : 4),
                              bottomRight: Radius.circular(isMe ? 4 : 18),
                            ),
                            boxShadow: (effectiveType == 'image' || effectiveType == 'video' || effectiveType == 'images' || effectiveType == 'videos' || effectiveType == 'red_packet' || effectiveType == 'red_packet_grab') ? null : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_hasQuotedMessage()) _buildQuotedBubble(),
                              _buildContent(content, effectiveType),
                            ],
                          ),
                        ),
                      ),
                      // 对方消息：操作按钮在右侧
                      if (!isMe && isSelected) _buildActionButtons(context, content),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                    child: showTime
                        ? Text(_formatTime(time), style: AppTextStyles.captionSm.copyWith(color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary))
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, String content) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => onQuote?.call(message),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.reply_rounded, size: 16, color: isDark ? Colors.white60 : Colors.black45),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              if (content.isNotEmpty) {
                Clipboard.setData(ClipboardData(text: content));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)));
              }
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.copy_rounded, size: 16, color: isDark ? Colors.white60 : Colors.black45),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageMenu(BuildContext context, String content) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('复制'),
              onTap: () {
                Navigator.pop(ctx);
                if (content.isNotEmpty) {
                  Clipboard.setData(ClipboardData(text: content));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('引用'),
              onTap: () {
                Navigator.pop(ctx);
                onQuote?.call(message);
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _hasQuotedMessage() {
    final quoted = message['quoted_message'];
    if (quoted == null) return false;
    if (quoted is String && quoted.isEmpty) return false;
    return true;
  }

  Widget _buildQuotedBubble() {
    final quoted = message['quoted_message'];
    Map<String, dynamic>? quotedData;
    
    if (quoted is Map<String, dynamic>) {
      quotedData = quoted;
    } else if (quoted is String && quoted.isNotEmpty) {
      try {
        quotedData = jsonDecode(quoted) as Map<String, dynamic>;
      } catch (_) {}
    }
    
    if (quotedData == null) return const SizedBox.shrink();

    final qContent = quotedData['content']?.toString() ?? '';
    final qFromName = quotedData['from_name']?.toString() ?? quotedData['fromName']?.toString() ?? '';
    final qType = quotedData['type']?.toString() ?? 'text';
    
    String displayContent = qContent;
    if (qType == 'image' || qType == 'images') displayContent = '[图片]';
    if (qType == 'video' || qType == 'videos') displayContent = '[视频]';
    if (displayContent.length > 50) displayContent = '${displayContent.substring(0, 50)}...';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: AppColors.primary, width: 2.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (qFromName.isNotEmpty)
            Text(qFromName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
          Text(
            displayContent,
            style: TextStyle(fontSize: 12, color: isMe ? Colors.white70 : (isDark ? Colors.white60 : Colors.black54)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(String content, String type) {
    if (type == 'image') {
      final fileUrl = message['file_url'] as String? ?? '';
      if (fileUrl.isNotEmpty) {
        if (content.isNotEmpty && !_isFileName(content)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Builder(builder: (ctx) => _buildImageContent(ctx, fileUrl)),
              const SizedBox(height: 6),
              Text(content, style: AppTextStyles.chatMsg.copyWith(color: isMe ? Colors.white : (isDark ? AppColors.darkText : AppColors.lightText))),
            ],
          );
        }
        return Builder(builder: (ctx) => _buildImageContent(ctx, fileUrl));
      }
      return Text('[图片]', style: TextStyle(color: isMe ? Colors.white70 : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)));
    }
    if (type == 'images') {
      // 多图消息：从 images JSON 数组取第一张
      final imageUrl = _getFirstImageUrl();
      if (imageUrl.isNotEmpty) {
        if (content.isNotEmpty && !_isFileName(content)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Builder(builder: (ctx) => _buildImageContent(ctx, imageUrl)),
              const SizedBox(height: 6),
              Text(content, style: AppTextStyles.chatMsg.copyWith(color: isMe ? Colors.white : (isDark ? AppColors.darkText : AppColors.lightText))),
            ],
          );
        }
        return Builder(builder: (ctx) => _buildImageContent(ctx, imageUrl));
      }
      return Text('[图片]', style: TextStyle(color: isMe ? Colors.white70 : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)));
    }
    if (type == 'video') {
      final fileUrl = message['file_url'] as String? ?? '';
      if (fileUrl.isNotEmpty) {
        return Builder(builder: (ctx) => _buildVideoContent(ctx, fileUrl));
      }
      return Text('[视频]', style: TextStyle(color: isMe ? Colors.white70 : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)));
    }
    if (type == 'videos') {
      // 多视频消息：从 videos JSON 数组取第一个
      final videoUrl = _getFirstVideoUrl();
      if (videoUrl.isNotEmpty) {
        return Builder(builder: (ctx) => _buildVideoContent(ctx, videoUrl));
      }
      return Text('[视频]', style: TextStyle(color: isMe ? Colors.white70 : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)));
    }
    if (type == 'images') {
      return Text('[图片]', style: TextStyle(color: isMe ? Colors.white70 : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)));
    }
    if (type == 'videos') {
      return Text('[视频]', style: TextStyle(color: isMe ? Colors.white70 : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)));
    }
    if (type == 'red_packet') {
      return Builder(builder: (ctx) => _buildRedPacketCard(ctx, content));
    }
    if (type == 'red_packet_grab') {
      return _buildRedPacketGrabNotice(content);
    }
    if (type == 'audio') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(Icons.mic_rounded, size: 16, color: isMe ? Colors.white70 : Colors.grey), const SizedBox(width: 4), Text('[语音]', style: TextStyle(color: isMe ? Colors.white70 : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)))],
      );
    }
    if (type == 'file') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(Icons.attach_file_rounded, size: 16, color: isMe ? Colors.white70 : Colors.grey), const SizedBox(width: 4), Text('[文件]', style: TextStyle(color: isMe ? Colors.white70 : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)))],
      );
    }

    return Text(
      content,
      style: AppTextStyles.chatMsg.copyWith(color: isMe ? Colors.white : (isDark ? AppColors.darkText : AppColors.lightText)),
    );
  }

  Widget _buildImageContent(BuildContext context, String fileUrl) {
    String fullUrl = fileUrl;
    if (!fullUrl.startsWith('http')) {
      fullUrl = '${ApiConfig.baseUrl}$fullUrl';
    }
    final width = (message['image_width'] as int?) ?? 0;
    final height = (message['image_height'] as int?) ?? 0;

    // 计算显示尺寸，最大 200x200
    double displayWidth = 180;
    double displayHeight = 180;
    if (width > 0 && height > 0) {
      final ratio = width / height;
      if (ratio > 1) {
        displayWidth = 180;
        displayHeight = 180 / ratio;
      } else {
        displayHeight = 180;
        displayWidth = 180 * ratio;
      }
    }

    return GestureDetector(
      onTap: () => _showFullImage(context, fullUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          fullUrl,
          width: displayWidth,
          height: displayHeight,
          fit: BoxFit.cover,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              width: displayWidth,
              height: displayHeight,
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
          errorBuilder: (_, __, ___) => SizedBox(
            width: displayWidth,
            height: displayHeight,
            child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoContent(BuildContext context, String fileUrl) {
    String fullUrl = fileUrl;
    if (!fullUrl.startsWith('http')) {
      fullUrl = '${ApiConfig.baseUrl}$fullUrl';
    }

    return GestureDetector(
      onTap: () => _playVideo(context, fullUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 180,
          height: 120,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 用视频第一帧作为封面
              _VideoThumbnail(url: fullUrl),
              // 播放按钮
              Center(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(120),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 判断 content 是否只是文件名
  bool _isFileName(String content) {
    final lower = content.toLowerCase();
    return lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') ||
           lower.endsWith('.gif') || lower.endsWith('.webp') || lower.endsWith('.mp4') ||
           lower.endsWith('.mov') || lower.endsWith('.avi') || lower.endsWith('.mkv');
  }

  /// 从 images JSON 字段获取第一张图片 URL
  String _getFirstImageUrl() {
    final images = message['images'];
    if (images == null) return '';
    try {
      List<dynamic> list;
      if (images is String) {
        if (images.isEmpty) return '';
        list = jsonDecode(images) as List<dynamic>;
      } else if (images is List) {
        list = images;
      } else {
        return '';
      }
      if (list.isEmpty) return '';
      final first = list.first;
      if (first is Map) {
        return (first['url'] ?? first['file_url'] ?? '').toString();
      }
      if (first is String) return first;
      return '';
    } catch (_) {
      return '';
    }
  }

  /// 从 videos JSON 字段获取第一个视频 URL
  String _getFirstVideoUrl() {
    final videos = message['videos'];
    if (videos == null) return '';
    try {
      List<dynamic> list;
      if (videos is String) {
        if (videos.isEmpty) return '';
        list = jsonDecode(videos) as List<dynamic>;
      } else if (videos is List) {
        list = videos;
      } else {
        return '';
      }
      if (list.isEmpty) return '';
      final first = list.first;
      if (first is Map) {
        return (first['url'] ?? first['file_url'] ?? '').toString();
      }
      if (first is String) return first;
      return '';
    } catch (_) {
      return '';
    }
  }

  Widget _buildRedPacketCard(BuildContext context, String content) {
    Map<String, dynamic> rpData = {};
    try {
      if (content.isNotEmpty) {
        rpData = jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (_) {}

    final greeting = rpData['greeting'] as String? ?? '恭喜发财，大吉大利';
    final rpId = rpData['red_packet_id'] ?? rpData['id'];

    return GestureDetector(
      onTap: () => _openRedPacket(context, rpId),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE84D3D), Color(0xFFC0392B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.redeem, color: Color(0xFFFFD700), size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(greeting, style: const TextStyle(color: Colors.white, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white24, width: 0.5))),
              child: const Text('红包', style: TextStyle(color: Colors.white70, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRedPacketGrabNotice(String content) {
    String text = '';
    try {
      final data = jsonDecode(content) as Map<String, dynamic>;
      final grabber = data['grabber_name'] ?? '';
      final sender = data['sender_name'] ?? '';
      if (grabber.isNotEmpty && sender.isNotEmpty) {
        text = '$grabber 领取了 $sender 的红包';
      }
    } catch (_) {
      text = content;
    }
    if (text.isEmpty) return const SizedBox.shrink();

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withAlpha(15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45)),
      ),
    );
  }

  void _openRedPacket(BuildContext context, dynamic rpId) async {
    if (rpId == null) return;

    // 先查询红包状态
    try {
      final dio = ApiClient.instance.dio;
      final res = await dio.get('/user/red-packet/$rpId');
      if (res.data['success'] != true) return;

      final data = res.data['data'] as Map<String, dynamic>;
      final myGrabAmount = (data['my_grab_amount'] as num?)?.toDouble() ?? 0;
      final status = data['status'] as int? ?? 0;
      final grabbedCount = data['grabbed_count'] as int? ?? 0;
      final totalCount = data['count'] as int? ?? 0;

      if (!context.mounted) return;

      if (myGrabAmount > 0) {
        // 已领取，显示详情
        _showRedPacketDetail(context, data);
      } else if (status == 2) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('红包已过期')));
      } else if (grabbedCount >= totalCount) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('红包已被领完')));
      } else {
        // 可以领取，弹出拆红包弹窗
        _showGrabDialog(context, rpId, data);
      }
    } catch (_) {}
  }

  void _showGrabDialog(BuildContext context, dynamic rpId, Map<String, dynamic> data) {
    final greeting = data['greeting'] as String? ?? '恭喜发财';
    final senderName = data['sender_name'] as String? ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFE84D3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (senderName.isNotEmpty)
              Text('$senderName 的红包', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 12),
            Text(greeting, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  final dio = ApiClient.instance.dio;
                  final res = await dio.post('/user/red-packet/grab', data: {'red_packet_id': rpId});
                  if (res.data['success'] == true && context.mounted) {
                    final amount = res.data['data']?['amount'] ?? 0;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🎉 领取了 $amount 元'), duration: const Duration(seconds: 2)));
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.data['message'] ?? '领取失败')));
                  }
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('领取失败')));
                }
              },
              child: Container(
                width: 64, height: 64,
                decoration: const BoxDecoration(color: Color(0xFFFFD700), shape: BoxShape.circle),
                child: const Center(child: Text('開', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFE84D3D)))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRedPacketDetail(BuildContext context, Map<String, dynamic> data) {
    final greeting = data['greeting'] as String? ?? '';
    final myAmount = (data['my_grab_amount'] as num?)?.toDouble() ?? 0;
    final records = data['records'] as List<dynamic>? ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: Text(greeting, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
            const SizedBox(height: 12),
            Center(child: Text('¥${myAmount.toStringAsFixed(2)}', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary))),
            const SizedBox(height: 4),
            const Center(child: Text('你领取的金额', style: TextStyle(fontSize: 12, color: Colors.grey))),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 8),
            Text('领取记录 (${records.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...records.map((r) {
              final rMap = r as Map<String, dynamic>;
              final name = rMap['nickname'] ?? '用户';
              final amount = (rMap['amount'] as num?)?.toDouble() ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(name.toString(), style: const TextStyle(fontSize: 14))),
                    Text('¥${amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, color: AppColors.primary)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  static void _showFullImage(BuildContext context, String url) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ImagePreviewPage(url: url),
    ));
  }

  static void _playVideo(BuildContext context, String url) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VideoPreviewPage(url: url),
    ));
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

/// 视频缩略图：加载视频第一帧作为封面
class _VideoThumbnail extends StatefulWidget {
  final String url;
  const _VideoThumbnail({required this.url});

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setVolume(0)
      ..initialize().then((_) {
        if (mounted) setState(() => _ready = true);
      }).catchError((_) {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready && _controller != null && _controller!.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.size.width,
          height: _controller!.value.size.height,
          child: VideoPlayer(_controller!),
        ),
      );
    }
    return Container(color: Colors.black12);
  }
}
