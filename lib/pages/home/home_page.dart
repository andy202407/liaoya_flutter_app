import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart' as dio_pkg;
import 'package:open_filex/open_filex.dart';

import '../../providers/conversation_provider.dart';
import '../../services/websocket_service.dart';
import '../../services/notification_sound.dart';
import '../../services/api/api_client.dart';
import '../../config/api_config.dart';
import '../../theme/app_colors.dart';
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
      WebSocketService.instance.connect();
      context.read<ConversationProvider>().init();
      _wsConnectionSub = WebSocketService.instance.connectionStream.listen((connected) {
        if (!mounted) return;
        if (connected) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (!mounted) return;
            try {
              context.read<ConversationProvider>().loadConversations();
            } catch (_) {}
          });
        }
      });
      WebSocketService.instance.on('message', _showMessageNotification);
      WebSocketService.instance.on('image', _showMessageNotification);
      WebSocketService.instance.on('images', _showMessageNotification);
      WebSocketService.instance.on('video', _showMessageNotification);
      WebSocketService.instance.on('videos', _showMessageNotification);
      WebSocketService.instance.on('audio', _showMessageNotification);
      WebSocketService.instance.on('file', _showMessageNotification);
      WebSocketService.instance.on('group_message', _showGroupMessageNotification);
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
    if (provider.activeFriendId == fromId) return;
    if (provider.isConversationMuted(fromId as int)) return;

    final senderName = msg['fromName'] ?? msg['from_name'] ?? '新消息';
    final content = _getMessagePreview(msg);
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
    NotificationSound.instance.play();
  }

  void _showGroupMessageNotification(Map<String, dynamic> msg) {
    if (!mounted) return;
    final provider = context.read<ConversationProvider>();
    final groupId = msg['group_id'] ?? msg['to'];
    if (groupId == null) return;
    if (provider.activeGroupId == groupId) return;
    if (provider.isConversationMuted(groupId as int)) return;

    final groupName = msg['group_name'] ?? '群聊';
    final senderName = msg['fromName'] ?? msg['from_name'] ?? '';
    final content = _getMessagePreview(msg);
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

  Future<void> _checkForUpdate() async {
    try {
      final dio = ApiClient.instance.dio;
      // 根据平台选择不同的配置接口
      final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
      final configPath = isIOS ? '/app/version/ios' : '/app/version/android';
      final res = await dio.get(configPath);
      if (res.data?['success'] == true && res.data?['data'] != null) {
        final data = res.data['data'];
        final latestVersion = data['version']?.toString() ?? '';
        // 根据平台选择下载链接
        final downloadUrl = isIOS
            ? (data['download_url']?.toString() ?? '')
            : (data['apk_url']?.toString() ?? '');
        final updateMessage = data['update_message']?.toString() ?? '';
        final forceUpdate = data['force_update'] == true;

        if (latestVersion.isEmpty || downloadUrl.isEmpty) return;

        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;
        if (_compareVersions(latestVersion, currentVersion) > 0) {
          if (!mounted) return;
          setState(() => _hasUpdate = true);

          final prefs = await SharedPreferences.getInstance();
          final dismissedVersion = prefs.getString('dismissed_update_version') ?? '';
          if (dismissedVersion != latestVersion) {
            if (!mounted) return;
            _showUpdateDialog(latestVersion, downloadUrl, updateMessage, forceUpdate);
          }
        }
      }
    } catch (e) {
      debugPrint('[Update] Error: $e');
    }
  }

  void _showUpdateDialog(String latestVersion, String apkUrl, String updateMessage, bool forceUpdate) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('发现新版本'),
        content: Column(
          children: [
            const SizedBox(height: 8),
            Text('最新版本: $latestVersion'),
            if (updateMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(updateMessage, style: const TextStyle(fontSize: 13)),
            ],
          ],
        ),
        actions: [
          if (!forceUpdate)
            CupertinoDialogAction(
              onPressed: () async {
                Navigator.pop(ctx);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('dismissed_update_version', latestVersion);
              },
              child: const Text('稍后'),
            ),
          CupertinoDialogAction(
            isDefaultAction: true,
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
    // iOS 或非 APK 链接：直接打开浏览器
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    if (isIOS || (!apkUrl.endsWith('.apk') && !apkUrl.contains('/apk'))) {
      String fullUrl = apkUrl;
      if (!apkUrl.startsWith('http')) {
        fullUrl = '${ApiConfig.baseUrl}$apkUrl';
      }
      final uri = Uri.parse(fullUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    // Android APK：应用内下载并安装
    String fullUrl = apkUrl;
    if (!apkUrl.startsWith('http')) {
      fullUrl = '${ApiConfig.baseUrl}$apkUrl';
    }

    try {
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/update.apk';

      if (!mounted) return;
      // 显示下载进度对话框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _ApkDownloadDialog(url: fullUrl, savePath: savePath),
      );
    } catch (e) {
      debugPrint('[Update] Download error: $e');
      // 降级到浏览器下载
      final uri = Uri.parse(fullUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        color: isDark
            ? AppColors.darkBg.withValues(alpha: 0.70)
            : AppColors.lightBg.withValues(alpha: 0.70),
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.of(context).padding.bottom + 6,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: Container(
              height: 56,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                // 多层渐变模拟玻璃内部光影
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          const Color(0xFF3A3A3C).withValues(alpha: 0.55),
                          const Color(0xFF2C2C2E).withValues(alpha: 0.50),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.72),
                          const Color(0xFFF0F0F0).withValues(alpha: 0.58),
                        ],
                ),
                // 白色边框 = 玻璃边缘高光
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.90),
                  width: 1.5,
                ),
                boxShadow: [
                  // 外阴影 - 悬浮感
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.07),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                    spreadRadius: -4,
                  ),
                  // 底部柔和阴影
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 顶部高光条
                  Positioned(
                    top: 0,
                    left: 20,
                    right: 20,
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: isDark ? 0.15 : 0.50),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // 水珠背景层 - 精确等分定位
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final totalWidth = constraints.maxWidth;
                      final itemWidth = totalWidth / 4;
                      const dropPadding = 8.0;
                      final dropWidth = itemWidth - dropPadding * 2;
                      final left = _currentIndex * itemWidth + dropPadding;

                      return Stack(
                        children: [
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            left: left,
                            top: 5,
                            child: Container(
                              width: dropWidth,
                              height: 42,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : const Color(0xFFE4E4E4).withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(23),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  // Tab 内容
                  Row(
                    children: [
                      _buildTabItem(
                        index: 0,
                        icon: Badge(
                          isLabelVisible: unread > 0,
                          label: Text(unread > 99 ? '99+' : '$unread',
                              style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600)),
                          backgroundColor: AppColors.error,
                          child: const Icon(CupertinoIcons.chat_bubble),
                        ),
                        activeIcon: Badge(
                          isLabelVisible: unread > 0,
                          label: Text(unread > 99 ? '99+' : '$unread',
                              style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600)),
                          backgroundColor: AppColors.error,
                          child: const Icon(CupertinoIcons.chat_bubble_fill),
                        ),
                        label: '消息',
                      ),
                      _buildTabItem(
                        index: 1,
                        icon: const Icon(CupertinoIcons.person_2),
                        activeIcon: const Icon(CupertinoIcons.person_2_fill),
                        label: '通讯录',
                      ),
                      _buildTabItem(
                        index: 2,
                        icon: const Icon(CupertinoIcons.compass),
                        activeIcon: const Icon(CupertinoIcons.compass_fill),
                        label: '发现',
                      ),
                      _buildTabItem(
                        index: 3,
                        icon: Badge(
                          isLabelVisible: _hasUpdate,
                          smallSize: 8,
                          backgroundColor: AppColors.error,
                          child: const Icon(CupertinoIcons.person),
                        ),
                        activeIcon: Badge(
                          isLabelVisible: _hasUpdate,
                          smallSize: 8,
                          backgroundColor: AppColors.error,
                          child: const Icon(CupertinoIcons.person_fill),
                        ),
                        label: '我的',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 切换 tab
  void _switchTab(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  Widget _buildTabItem({
    required int index,
    required Widget icon,
    required Widget activeIcon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _switchTab(index),
        child: SizedBox(
          height: 56,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconTheme(
                data: IconThemeData(
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF1A1A1A))
                      : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                  size: 24,
                ),
                child: isSelected ? activeIcon : icon,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF1A1A1A))
                      : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// APK 下载进度对话框
class _ApkDownloadDialog extends StatefulWidget {
  final String url;
  final String savePath;

  const _ApkDownloadDialog({required this.url, required this.savePath});

  @override
  State<_ApkDownloadDialog> createState() => _ApkDownloadDialogState();
}

class _ApkDownloadDialogState extends State<_ApkDownloadDialog> {
  double _progress = 0;
  bool _downloading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      final d = dio_pkg.Dio();
      await d.download(
        widget.url,
        widget.savePath,
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _progress = received / total);
          }
        },
      );
      if (!mounted) return;
      setState(() => _downloading = false);
      // 安装 APK
      final result = await OpenFilex.open(widget.savePath, type: 'application/vnd.android.package-archive');
      if (result.type != ResultType.done && mounted) {
        setState(() => _error = '安装失败: ${result.message}');
      } else if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = '下载失败: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_error != null ? '更新失败' : '正在下载更新'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))
          else ...[
            LinearProgressIndicator(value: _downloading ? _progress : 1.0),
            const SizedBox(height: 12),
            Text('${(_progress * 100).toStringAsFixed(0)}%'),
          ],
        ],
      ),
      actions: [
        if (_error != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
      ],
    );
  }
}
