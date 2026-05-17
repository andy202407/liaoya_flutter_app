import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../providers/conversation_provider.dart';
import '../../services/websocket_service.dart';
import '../../services/notification_sound.dart';
import '../../services/api/api_client.dart';
import '../../widgets/in_app_notification.dart';
import '../chat/conversation_list_page.dart';
import '../contacts/contacts_page.dart';
import '../discover/discover_page.dart';
import '../profile/profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _wsConnected = true;
  bool _hasUpdate = false;

  final _pages = const [
    ConversationListPage(),
    ContactsPage(),
    DiscoverPage(),
    ProfilePage(),
  ];

  StreamSubscription<bool>? _wsConnectionSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 确保 WebSocket 连接
      WebSocketService.instance.connect();
      _wsConnected = WebSocketService.instance.isConnected;
      // 加载会话列表
      context.read<ConversationProvider>().init();
      // 监听 WebSocket 重连，重连后刷新数据
      _wsConnectionSub = WebSocketService.instance.connectionStream.listen((connected) {
        if (!mounted) return;
        setState(() => _wsConnected = connected);
        if (connected) {
          // 重连成功，刷新会话列表
          Future.delayed(const Duration(milliseconds: 500), () {
            if (!mounted) return;
            try {
              context.read<ConversationProvider>().loadConversations();
            } catch (_) {}
          });
        }
      });
      // 监听新消息弹窗通知
      WebSocketService.instance.on('message', _showMessageNotification);
      WebSocketService.instance.on('image', _showMessageNotification);
      WebSocketService.instance.on('images', _showMessageNotification);
      WebSocketService.instance.on('video', _showMessageNotification);
      WebSocketService.instance.on('videos', _showMessageNotification);
      WebSocketService.instance.on('audio', _showMessageNotification);
      WebSocketService.instance.on('file', _showMessageNotification);
      WebSocketService.instance.on('group_message', _showGroupMessageNotification);

      // 检查 Android 版本更新
      _checkForUpdate();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wsConnectionSub?.cancel();
    WebSocketService.instance.off('message', _showMessageNotification);
    WebSocketService.instance.off('image', _showMessageNotification);
    WebSocketService.instance.off('images', _showMessageNotification);
    WebSocketService.instance.off('video', _showMessageNotification);
    WebSocketService.instance.off('videos', _showMessageNotification);
    WebSocketService.instance.off('audio', _showMessageNotification);
    WebSocketService.instance.off('file', _showMessageNotification);
    WebSocketService.instance.off('group_message', _showGroupMessageNotification);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 从后台恢复，重新连接 WebSocket
      if (!WebSocketService.instance.isConnected) {
        WebSocketService.instance.connect();
      }
    }
  }

  void _showMessageNotification(Map<String, dynamic> msg) {
    if (!mounted) return;
    final provider = context.read<ConversationProvider>();
    final fromId = msg['from'] ?? msg['from_id'];
    if (fromId == null) return;

    // 如果正在查看这个会话，不弹通知
    if (provider.activeFriendId == fromId) return;

    // 静音会话不弹通知
    if (provider.isConversationMuted(fromId as int)) return;

    final senderName = msg['fromName'] ?? msg['from_name'] ?? '新消息';
    final content = _getMessagePreview(msg);
    // 头像：优先用 WebSocket 消息里的，fallback 到会话列表里的好友头像
    String? avatar = msg['fromAvatar']?.toString() ?? msg['from_avatar']?.toString();
    if (avatar == null || avatar.isEmpty) {
      final conv = provider.conversations.firstWhere(
        (c) => c['type'] == 1 && (c['friend_id'] ?? c['friend']?['id']) == fromId,
        orElse: () => <String, dynamic>{},
      );
      avatar = conv['friend']?['avatar']?.toString();
    }

    InAppNotification.show(
      context: context,
      title: senderName.toString(),
      body: content,
      avatar: avatar,
      isGroup: false,
      onTap: () {
        final conv = provider.conversations.firstWhere(
          (c) {
            final fId = c['friend_id'] ?? c['friend']?['id'];
            return c['type'] == 1 && fId == fromId;
          },
          orElse: () => <String, dynamic>{},
        );
        if (conv.isNotEmpty) {
          Navigator.of(context).pushNamed('/chat', arguments: conv);
        }
      },
    );
    // 播放提示音
    NotificationSound.instance.play();
  }

  void _showGroupMessageNotification(Map<String, dynamic> msg) {
    if (!mounted) return;
    final provider = context.read<ConversationProvider>();
    final groupId = msg['group_id'] ?? msg['to'];
    if (groupId == null) return;

    // 如果正在查看这个群，不弹通知
    if (provider.activeGroupId == groupId) return;

    // 静音会话不弹通知
    if (provider.isConversationMuted(groupId as int)) return;

    final groupName = msg['group_name'] ?? '群聊';
    final senderName = msg['fromName'] ?? msg['from_name'] ?? '';
    final content = _getMessagePreview(msg);
    // 群头像：优先用 WebSocket 消息里的，fallback 到会话列表里的群头像
    String? avatar = msg['group_avatar']?.toString();
    if (avatar == null || avatar.isEmpty) {
      final conv = provider.conversations.firstWhere(
        (c) => c['type'] == 2 && (c['target_id'] ?? c['group']?['id']) == groupId,
        orElse: () => <String, dynamic>{},
      );
      avatar = conv['group']?['avatar']?.toString();
    }
    final displayBody = senderName.toString().isNotEmpty ? '$senderName: $content' : content;

    InAppNotification.show(
      context: context,
      title: groupName.toString(),
      body: displayBody,
      avatar: avatar,
      isGroup: true,
      onTap: () {
        final conv = provider.conversations.firstWhere(
          (c) {
            final gId = c['target_id'] ?? c['group']?['id'];
            return c['type'] == 2 && gId == groupId;
          },
          orElse: () => <String, dynamic>{},
        );
        if (conv.isNotEmpty) {
          Navigator.of(context).pushNamed('/chat', arguments: conv);
        }
      },
    );
    // 播放提示音
    NotificationSound.instance.play();
  }

  String _getMessagePreview(Map<String, dynamic> msg) {
    final msgType = msg['message_type'] ?? msg['type'] ?? 'text';
    final content = msg['content'];
    switch (msgType) {
      case 'image': return '[图片]';
      case 'images': return '[图片]';
      case 'video': return '[视频]';
      case 'videos': return '[视频]';
      case 'audio': return '[语音]';
      case 'file': return '[文件]';
      case 'message':
      case 'text':
        if (content is String && content.isNotEmpty) {
          return content.length > 30 ? '${content.substring(0, 30)}...' : content;
        }
        return '新消息';
      default:
        if (content is String && content.isNotEmpty) {
          return content.length > 30 ? '${content.substring(0, 30)}...' : content;
        }
        return '新消息';
    }
  }

  /// Check for Android app update silently on startup
  Future<void> _checkForUpdate() async {
    try {
      final dio = ApiClient.instance.dio;
      final res = await dio.get('/android/config');
      if (res.data?['success'] == true && res.data?['data'] != null) {
        final data = res.data['data'];
        final latestVersion = data['version']?.toString() ?? '';
        final apkUrl = data['apk_url']?.toString() ?? '';
        final updateMessage = data['update_message']?.toString() ?? '';
        final forceUpdate = data['force_update'] == true;

        if (latestVersion.isEmpty || apkUrl.isEmpty) return;

        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;
        if (_compareVersions(latestVersion, currentVersion) > 0) {
          if (!mounted) return;
          setState(() => _hasUpdate = true);

          // Show update dialog only once per version (store dismissed version)
          final prefs = await SharedPreferences.getInstance();
          final dismissedVersion = prefs.getString('dismissed_update_version') ?? '';
          if (dismissedVersion != latestVersion) {
            if (!mounted) return;
            _showUpdateDialog(latestVersion, apkUrl, updateMessage, forceUpdate);
          }
        }
      }
    } catch (_) {
      // Silently fail - don't disturb user on network errors
    }
  }

  void _showUpdateDialog(String latestVersion, String apkUrl, String updateMessage, bool forceUpdate) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (ctx) => AlertDialog(
        title: const Text('发现新版本'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('最新版本: $latestVersion'),
            const Text('当前版本: 1.0.0'),
            if (updateMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('更新内容:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(updateMessage),
            ],
          ],
        ),
        actions: [
          if (!forceUpdate)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                // Mark this version as dismissed
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('dismissed_update_version', latestVersion);
              },
              child: const Text('稍后'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _launchApkUrl(apkUrl);
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchApkUrl(String apkUrl) async {
    final uri = Uri.parse(apkUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Compare two version strings (e.g. "1.0.1" vs "1.0.0")
  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final len = parts1.length > parts2.length ? parts1.length : parts2.length;
    for (int i = 0; i < len; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 != p2) return p1 - p2;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final convProvider = context.watch<ConversationProvider>();
    final unread = convProvider.totalUnread;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedFontSize: 11,
          unselectedFontSize: 11,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text(unread > 99 ? '99+' : '$unread', style: const TextStyle(fontSize: 10)),
                child: const Icon(Icons.chat_bubble_outline_rounded),
              ),
              activeIcon: Badge(
                isLabelVisible: unread > 0,
                label: Text(unread > 99 ? '99+' : '$unread', style: const TextStyle(fontSize: 10)),
                child: const Icon(Icons.chat_bubble_rounded),
              ),
              label: '消息',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.people_outline_rounded),
              activeIcon: Icon(Icons.people_rounded),
              label: '通讯录',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore_rounded),
              label: '发现',
            ),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: _hasUpdate,
                smallSize: 8,
                child: const Icon(Icons.person_outline_rounded),
              ),
              activeIcon: Badge(
                isLabelVisible: _hasUpdate,
                smallSize: 8,
                child: const Icon(Icons.person_rounded),
              ),
              label: '我的',
            ),
          ],
        ),
    );
  }
}
