import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:video_player/video_player.dart';
import '../../services/api/api_client.dart';
import '../../services/websocket_service.dart';
import '../../config/api_config.dart';
import '../../theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';

class LiveStreamPlayerPage extends StatefulWidget {
  final Map<String, dynamic> stream;

  const LiveStreamPlayerPage({super.key, required this.stream});

  @override
  State<LiveStreamPlayerPage> createState() => _LiveStreamPlayerPageState();
}

class _LiveStreamPlayerPageState extends State<LiveStreamPlayerPage> {
  VideoPlayerController? _videoController;
  bool _isVideoLoading = true;
  bool _videoError = false;
  Map<String, dynamic>? _streamDetail;
  List<Map<String, dynamic>> _chatMessages = [];
  final _chatController = TextEditingController();
  final _chatScrollController = ScrollController();
  bool _isMuted = false;
  Timer? _chatPollTimer;

  int get _streamId => widget.stream['id'] as int? ?? 0;
  int get _status => _streamDetail?['status'] ?? widget.stream['status'] ?? 0;

  @override
  void initState() {
    super.initState();
    _loadStreamDetail();
    _loadChatMessages();
    _joinChatRoom();
    // 监听聊天消息
    WebSocketService.instance.on('live_chat', _onChatMessage);
    WebSocketService.instance.on('live_chat_delete', _onChatDelete);
    WebSocketService.instance.on('live_chat_error', _onChatError);
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    _chatPollTimer?.cancel();
    _leaveChatRoom();
    WebSocketService.instance.off('live_chat', _onChatMessage);
    WebSocketService.instance.off('live_chat_delete', _onChatDelete);
    WebSocketService.instance.off('live_chat_error', _onChatError);
    super.dispose();
  }

  Future<void> _loadStreamDetail() async {
    try {
      final res = await ApiClient.instance.dio.get('/user/live-streams/$_streamId');
      if (res.data['success'] == true && res.data['data'] != null) {
        setState(() => _streamDetail = res.data['data']);
        _initVideo();
      }
    } catch (e) {
      debugPrint('[LiveStream] detail error: $e');
    }
  }

  void _initVideo() {
    final playbackUrl = _streamDetail?['playback_url'] as String?;
    if (playbackUrl == null || playbackUrl.isEmpty) {
      setState(() {
        _isVideoLoading = false;
        _videoError = true;
      });
      return;
    }

    final fullUrl = playbackUrl.startsWith('http') ? playbackUrl : '${ApiConfig.baseUrl}$playbackUrl';
    _videoController = VideoPlayerController.networkUrl(Uri.parse(fullUrl))
      ..initialize().then((_) {
        setState(() => _isVideoLoading = false);
        _videoController!.play();
      }).catchError((e) {
        setState(() {
          _isVideoLoading = false;
          _videoError = true;
        });
      });
  }

  Future<void> _loadChatMessages() async {
    try {
      final res = await ApiClient.instance.dio.get('/user/live-streams/$_streamId/chat');
      if (res.data['success'] == true) {
        final List<dynamic> msgs = res.data['data'] ?? [];
        setState(() {
          _chatMessages = msgs.map((e) => e as Map<String, dynamic>).toList();
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('[LiveStream] chat load error: $e');
    }
  }

  void _joinChatRoom() {
    WebSocketService.instance.send({
      'type': 'live_chat_join',
      'content': {'stream_id': '$_streamId'},
    });
  }

  void _leaveChatRoom() {
    WebSocketService.instance.send({
      'type': 'live_chat_leave',
      'content': {'stream_id': '$_streamId'},
    });
  }

  void _onChatMessage(Map<String, dynamic> msg) {
    final content = msg['content'];
    if (content is Map<String, dynamic>) {
      final streamId = content['stream_id']?.toString();
      if (streamId == '$_streamId') {
        setState(() => _chatMessages.add(content));
        _scrollToBottom();
      }
    }
  }

  void _onChatDelete(Map<String, dynamic> msg) {
    final content = msg['content'];
    if (content is Map<String, dynamic>) {
      final timestamp = content['timestamp'];
      setState(() {
        _chatMessages.removeWhere((m) => m['timestamp'] == timestamp);
      });
    }
  }

  void _onChatError(Map<String, dynamic> msg) {
    setState(() => _isMuted = true);
  }

  void _sendChat() {
    final text = _chatController.text.trim();
    if (text.isEmpty || _isMuted || _status != 1) return;

    WebSocketService.instance.send({
      'type': 'live_chat',
      'content': {'stream_id': '$_streamId', 'content': text},
    });
    _chatController.clear();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final homeTeam = widget.stream['home_team'] ?? '主队';
    final awayTeam = widget.stream['away_team'] ?? '客队';
    final homeScore = _streamDetail?['home_score'] ?? widget.stream['home_score'];
    final awayScore = _streamDetail?['away_score'] ?? widget.stream['away_score'];
    final league = widget.stream['league'] ?? '';
    final viewCount = _streamDetail?['view_count'] ?? widget.stream['view_count'] ?? 0;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            if (_status == 1)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
              ),
            Expanded(
              child: Text(
                league.isNotEmpty ? '$league · $homeTeam vs $awayTeam' : '$homeTeam vs $awayTeam',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (viewCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.eye, size: 14, color: Colors.white60),
                  const SizedBox(width: 4),
                  Text('$viewCount', style: const TextStyle(fontSize: 12, color: Colors.white60)),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 视频播放器
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: _buildVideoPlayer(),
            ),
          ),
          // 比分条
          _buildScoreBar(homeTeam, awayTeam, homeScore, awayScore, isDark),
          // 聊天区域
          Expanded(child: _buildChatSection(isDark)),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_isVideoLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_videoError || _videoController == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.tv, size: 40, color: Colors.white30),
            const SizedBox(height: 8),
            Text(
              _status == 0 ? '直播尚未开始' : '暂无播放源',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      );
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        VideoPlayer(_videoController!),
        // 播放/暂停按钮
        GestureDetector(
          onTap: () {
            setState(() {
              _videoController!.value.isPlaying
                  ? _videoController!.pause()
                  : _videoController!.play();
            });
          },
          child: Container(color: Colors.transparent),
        ),
      ],
    );
  }

  Widget _buildScoreBar(String home, String away, dynamic homeScore, dynamic awayScore, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: isDark ? AppColors.darkCard : Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Text(home, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkText : AppColors.lightText), textAlign: TextAlign.center),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBg : AppColors.lightBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: homeScore != null && awayScore != null
                ? Text('$homeScore - $awayScore', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _status == 1 ? AppColors.error : (isDark ? AppColors.darkText : AppColors.lightText)))
                : Text('VS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.systemGray)),
          ),
          Expanded(
            child: Text(away, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkText : AppColors.lightText), textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _buildChatSection(bool isDark) {
    final currentUserId = context.read<AuthProvider>().userId;

    return Column(
      children: [
        // 聊天消息列表
        Expanded(
          child: _chatMessages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.chat_bubble_2, size: 36, color: AppColors.systemGray3),
                      const SizedBox(height: 8),
                      Text('暂无消息', style: TextStyle(fontSize: 13, color: AppColors.systemGray)),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _chatScrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _chatMessages.length,
                  itemBuilder: (context, index) {
                    final msg = _chatMessages[index];
                    final isSelf = msg['user_id'] == currentUserId;
                    return _buildChatBubble(msg, isSelf, isDark);
                  },
                ),
        ),
        // 状态提示
        if (_isMuted)
          Container(
            padding: const EdgeInsets.all(8),
            color: AppColors.warning.withAlpha(20),
            child: const Text('🔇 你已被禁言', style: TextStyle(fontSize: 12, color: AppColors.warning), textAlign: TextAlign.center),
          ),
        if (_status != 1)
          Container(
            padding: const EdgeInsets.all(12),
            color: isDark ? AppColors.darkCard : AppColors.lightInputBg,
            child: Text(
              _status == 0 ? '⏳ 比赛尚未开始，聊天室暂未开放' : '🏁 比赛已结束，聊天室已关闭',
              style: TextStyle(fontSize: 13, color: AppColors.systemGray),
              textAlign: TextAlign.center,
            ),
          ),
        // 输入框
        if (!_isMuted && _status == 1)
          Container(
            padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              border: Border(top: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    decoration: InputDecoration(
                      hintText: '说点什么...',
                      hintStyle: TextStyle(color: AppColors.systemGray, fontSize: 14),
                      filled: true,
                      fillColor: isDark ? AppColors.darkInputBg : AppColors.lightInputBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    maxLength: 200,
                    maxLines: 1,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    onSubmitted: (_) => _sendChat(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendChat,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> msg, bool isSelf, bool isDark) {
    final nickname = msg['nickname'] ?? '用户';
    final content = msg['content'] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头像
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(40),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                nickname.isNotEmpty ? nickname[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nickname, style: TextStyle(fontSize: 11, color: AppColors.systemGray, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(content, style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkText : AppColors.lightText)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
