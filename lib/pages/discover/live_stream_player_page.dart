import 'dart:async';
import 'dart:convert';
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
  String? _currentPlaybackUrl;

  int get _streamId => widget.stream['id'] as int? ?? 0;
  int get _status => _streamDetail?['status'] ?? widget.stream['status'] ?? 0;

  @override
  void initState() {
    super.initState();
    _loadStreamDetail();
    _loadChatMessages();
    _joinChatRoom();
    WebSocketService.instance.on('live_chat', _onChatMessage);
    WebSocketService.instance.on('live_chat_delete', _onChatDelete);
    WebSocketService.instance.on('live_chat_error', _onChatError);
    WebSocketService.instance.on('live_stream_update', _onStreamUpdate);
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _videoController?.removeListener(_onVideoError);
    _videoController?.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    _chatPollTimer?.cancel();
    _leaveChatRoom();
    WebSocketService.instance.off('live_chat', _onChatMessage);
    WebSocketService.instance.off('live_chat_delete', _onChatDelete);
    WebSocketService.instance.off('live_chat_error', _onChatError);
    WebSocketService.instance.off('live_stream_update', _onStreamUpdate);
    super.dispose();
  }

  Future<void> _loadStreamDetail() async {
    try {
      final res = await ApiClient.instance.dio.get('/user/live-streams/$_streamId');
      if (res.data['success'] == true && res.data['data'] != null) {
        final oldStatus = _status;
        final isFirstLoad = _streamDetail == null;
        setState(() => _streamDetail = res.data['data']);
        final newPlaybackUrl = _streamDetail?['playback_url'] as String?;

        // 播放链接变了，重新初始化
        if (!isFirstLoad && newPlaybackUrl != null && newPlaybackUrl.isNotEmpty && newPlaybackUrl != _currentPlaybackUrl && _videoController != null) {
          _videoController?.removeListener(_onVideoError);
          _videoController?.dispose();
          _videoController = null;
          _currentPlaybackUrl = null;
          setState(() {
            _isVideoLoading = true;
            _videoError = false;
          });
          _initVideo();
          return;
        }

        // 首次加载，初始化播放
        if (_videoController == null && newPlaybackUrl != null && newPlaybackUrl.isNotEmpty) {
          setState(() {
            _isVideoLoading = true;
            _videoError = false;
          });
          _initVideo();
        }
        // 状态变为非直播中，停止播放
        if (_status != 1 && oldStatus == 1 && _videoController != null) {
          _videoController?.pause();
        }
      }
    } catch (e) {
      debugPrint('[LiveStream] detail error: $e');
    }
  }

  int _retryCount = 0;
  static const int _maxRetries = 5;
  Timer? _retryTimer;

  void _initVideo() {
    final playbackUrl = _streamDetail?['playback_url'] as String?;
    if (playbackUrl == null || playbackUrl.isEmpty) {
      setState(() {
        _isVideoLoading = false;
        _videoError = true;
      });
      return;
    }

    String fullUrl = playbackUrl.startsWith('http') ? playbackUrl : '${ApiConfig.baseUrl}$playbackUrl';
    _currentPlaybackUrl = playbackUrl;

    _videoController?.removeListener(_onVideoError);
    _videoController?.dispose();
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(fullUrl),
      formatHint: VideoFormat.hls,
      httpHeaders: const {'Connection': 'keep-alive'},
    )
      ..initialize().then((_) {
        if (mounted) {
          _retryCount = 0;
          setState(() {
            _isVideoLoading = false;
            _videoError = false;
          });
          _videoController!.play();
          _videoController!.addListener(_onVideoError);
        }
      }).catchError((e) {
        debugPrint('[LiveStream] video init error: $e');
        if (mounted) {
          _scheduleRetry();
        }
      });
  }

  void _onVideoError() {
    if (_videoController == null) return;
    if (_videoController!.value.hasError) {
      debugPrint('[LiveStream] playback error, retrying...');
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    if (_retryCount >= _maxRetries) {
      if (mounted) {
        setState(() {
          _isVideoLoading = false;
          _videoError = true;
        });
      }
      return;
    }
    _retryCount++;
    _retryTimer?.cancel();
    final delay = Duration(milliseconds: 800 + (_retryCount * 500));
    _retryTimer = Timer(delay, () {
      if (mounted && _status == 1) {
        debugPrint('[LiveStream] retry #$_retryCount');
        setState(() {
          _isVideoLoading = true;
          _videoError = false;
        });
        _initVideo();
      }
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
      'content': '$_streamId',
    });
  }

  void _leaveChatRoom() {
    WebSocketService.instance.send({
      'type': 'live_chat_leave',
      'content': '$_streamId',
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

  void _onStreamUpdate(Map<String, dynamic> msg) {
    final content = msg['content'];
    Map<String, dynamic>? data;
    if (content is String) {
      try { data = Map<String, dynamic>.from(const JsonDecoder().convert(content)); } catch (_) {}
    } else if (content is Map) {
      data = Map<String, dynamic>.from(content);
    }
    final streamId = data?['stream_id'];
    if (streamId != null && streamId.toString() == '$_streamId') {
      _loadStreamDetail();
    } else {
      _loadStreamDetail();
    }
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

  void _sendEmoji(String emoji) {
    if (_isMuted || _status != 1) return;
    WebSocketService.instance.send({
      'type': 'live_chat',
      'content': {'stream_id': '$_streamId', 'content': emoji},
    });
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
    final title = (_streamDetail?['title'] as String?)?.isNotEmpty == true
        ? _streamDetail!['title']
        : (widget.stream['title'] as String?)?.isNotEmpty == true
            ? widget.stream['title']
            : (_streamDetail?['league'] ?? widget.stream['league'] ?? '直播');
    final homeTeam = _streamDetail?['home_team'] ?? widget.stream['home_team'] ?? '主队';
    final awayTeam = _streamDetail?['away_team'] ?? widget.stream['away_team'] ?? '客队';
    final homeScore = _streamDetail?['home_score'] ?? widget.stream['home_score'];
    final awayScore = _streamDetail?['away_score'] ?? widget.stream['away_score'];
    final homeLogo = (_streamDetail?['home_logo'] ?? widget.stream['home_logo']) as String?;
    final awayLogo = (_streamDetail?['away_logo'] ?? widget.stream['away_logo']) as String?;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        foregroundColor: isDark ? Colors.white : AppColors.lightText,
        elevation: 0,
        title: Text(
          title,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.lightText),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: const [],
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: _buildVideoPlayer(),
            ),
          ),
          _buildMatchBar(homeTeam, awayTeam, homeScore, awayScore, homeLogo, awayLogo, isDark),
          Expanded(child: _buildChatSection(isDark)),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_isVideoLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            if (_retryCount > 0) ...[
              const SizedBox(height: 8),
              Text('连接中... ($_retryCount)', style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ],
        ),
      );
    }
    if (_videoError || _videoController == null) {
      return GestureDetector(
        onTap: () {
          _retryCount = 0;
          setState(() {
            _isVideoLoading = true;
            _videoError = false;
          });
          _initVideo();
        },
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _status == 0 ? CupertinoIcons.clock : (_status == 2 ? CupertinoIcons.flag : CupertinoIcons.refresh),
                size: 36,
                color: Colors.white38,
              ),
              const SizedBox(height: 10),
              Text(
                _status == 0 ? '⏳ 比赛尚未开始' : (_status == 2 ? '🏁 比赛已结束' : '点击重试播放'),
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        VideoPlayer(_videoController!),
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

  Widget _buildMatchBar(String home, String away, dynamic homeScore, dynamic awayScore, String? homeLogo, String? awayLogo, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(child: Text(home, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkText : AppColors.lightText), maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (homeLogo != null && homeLogo.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  ClipRRect(borderRadius: BorderRadius.circular(3), child: Image.network(homeLogo, width: 20, height: 20, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
                ],
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: isDark ? AppColors.darkBg : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
            child: homeScore != null && awayScore != null
                ? Text('$homeScore - $awayScore', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _status == 1 ? AppColors.error : (isDark ? AppColors.darkText : AppColors.lightText)))
                : Text('VS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.systemGray)),
          ),
          Expanded(
            child: Row(
              children: [
                if (awayLogo != null && awayLogo.isNotEmpty) ...[
                  ClipRRect(borderRadius: BorderRadius.circular(3), child: Image.network(awayLogo, width: 20, height: 20, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
                  const SizedBox(width: 6),
                ],
                Flexible(child: Text(away, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkText : AppColors.lightText), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatSection(bool isDark) {
    final currentUserId = context.read<AuthProvider>().userId;
    return Column(
      children: [
        Expanded(
          child: _chatMessages.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(CupertinoIcons.chat_bubble_2, size: 36, color: AppColors.systemGray3), const SizedBox(height: 8), Text('暂无消息', style: TextStyle(fontSize: 13, color: AppColors.systemGray))]))
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
        if (_isMuted) Container(padding: const EdgeInsets.all(8), color: AppColors.warning.withAlpha(20), child: const Text('🔇 你已被禁言', style: TextStyle(fontSize: 12, color: AppColors.warning), textAlign: TextAlign.center)),
        if (_status != 1) Container(padding: const EdgeInsets.all(12), color: isDark ? AppColors.darkCard : AppColors.lightInputBg, child: Text(_status == 0 ? '⏳ 比赛尚未开始，聊天室暂未开放' : '🏁 比赛已结束，聊天室已关闭', style: TextStyle(fontSize: 13, color: AppColors.systemGray), textAlign: TextAlign.center)),
        if (!_isMuted && _status == 1)
          Container(
            padding: EdgeInsets.fromLTRB(12, 6, 12, MediaQuery.of(context).padding.bottom + 6),
            decoration: BoxDecoration(color: isDark ? AppColors.darkCard : Colors.white, border: Border(top: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider, width: 0.5))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 32, child: ListView(scrollDirection: Axis.horizontal, children: ['⚽', '🔥', '👏', '😍', '🎉', '💪', '😂', '❤️', '👍', '😱', '🏆', '🙏'].map((emoji) => GestureDetector(onTap: () => _sendEmoji(emoji), child: Container(width: 32, alignment: Alignment.center, child: Text(emoji, style: const TextStyle(fontSize: 18))))).toList())),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: TextField(controller: _chatController, decoration: InputDecoration(hintText: '说点什么...', hintStyle: TextStyle(color: AppColors.systemGray, fontSize: 14), filled: true, fillColor: isDark ? AppColors.darkInputBg : AppColors.lightInputBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)), maxLength: 200, maxLines: 1, buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null, onSubmitted: (_) => _sendChat())),
                  const SizedBox(width: 8),
                  GestureDetector(onTap: _sendChat, child: Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle), child: const Icon(Icons.send_rounded, color: Colors.white, size: 18))),
                ]),
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
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 28, height: 28, decoration: BoxDecoration(color: AppColors.primary.withAlpha(40), shape: BoxShape.circle), child: Center(child: Text(nickname.isNotEmpty ? nickname[0].toUpperCase() : '?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)))),
        const SizedBox(width: 8),
        Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(nickname, style: TextStyle(fontSize: 11, color: AppColors.systemGray, fontWeight: FontWeight.w500)), const SizedBox(height: 2), Text(content, style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkText : AppColors.lightText))])),
      ]),
    );
  }
}
