import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/conversation_provider.dart';
import '../../services/api/api_client.dart';
import '../../services/websocket_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/avatar_widget.dart';
import '../contacts/add_friend_page.dart';
import '../contacts/scan_join_group_page.dart';
import '../discover/official_account_detail_page.dart';

class ConversationListPage extends StatefulWidget {
  const ConversationListPage({super.key});

  @override
  State<ConversationListPage> createState() => _ConversationListPageState();
}

/// 用于通知所有 tile 关闭滑动面板，值为当前打开的 tile 的 key
final ValueNotifier<Key?> _activeSwipeNotifier = ValueNotifier(null);

class _ConversationListPageState extends State<ConversationListPage> {
  bool _wsConnected = true;
  StreamSubscription<bool>? _sub;

  @override
  void initState() {
    super.initState();
    _wsConnected = WebSocketService.instance.isConnected;
    _sub = WebSocketService.instance.connectionStream.listen((connected) {
      if (mounted) setState(() => _wsConnected = connected);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Consumer<ConversationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.conversations.isEmpty) {
            return const Center(child: CupertinoActivityIndicator());
          }

          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollEndNotification &&
                  notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200) {
                if (provider.hasMore && !provider.isLoading) {
                  provider.loadConversations(loadMore: true);
                }
              }
              return false;
            },
            child: RefreshIndicator(
              onRefresh: () => provider.forceRefresh(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // 顶部导航栏
                  SliverAppBar(
                    pinned: true,
                    floating: false,
                    toolbarHeight: 52,
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    flexibleSpace: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(color: Colors.transparent),
                          ),
                        ),
                        Container(
                          color: isDark
                              ? AppColors.darkBg.withValues(alpha: 0.60)
                              : Colors.white.withValues(alpha: 0.65),
                        ),
                      ],
                    ),
                    leading: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: GestureDetector(
                        onTap: () {
                          if (!_wsConnected) {
                            HapticFeedback.lightImpact();
                            WebSocketService.instance.connect();
                          }
                        },
                        child: Icon(
                          _wsConnected ? CupertinoIcons.wifi : CupertinoIcons.wifi_slash,
                          color: _wsConnected ? AppColors.online : AppColors.error,
                          size: 18,
                        ),
                      ),
                    ),
                    leadingWidth: 44,
                    title: Text(
                      '消息',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    centerTitle: true,
                    actions: [
                      CupertinoButton(
                        padding: const EdgeInsets.only(right: 16),
                        onPressed: () => _showAddMenu(context),
                        child: Icon(
                          CupertinoIcons.plus_circle,
                          size: 22,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                      ),
                    ],
                  ),
                  if (provider.conversations.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.chat_bubble_2, size: 48, color: AppColors.systemGray3),
                            const SizedBox(height: 12),
                            Text('暂无会话', style: TextStyle(fontSize: 15, color: AppColors.systemGray)),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final conv = provider.conversations[index];
                          return RepaintBoundary(
                            child: _ConversationTile(
                              key: ValueKey(conv['id'] ?? index),
                              conversation: conv,
                            ),
                          );
                        },
                        childCount: provider.conversations.length,
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: false,
                      ),
                    ),
                    if (provider.hasMore)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CupertinoActivityIndicator()),
                        ),
                      ),
                    const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddMenu(BuildContext context) {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 操作按钮组
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkCard.withValues(alpha: 0.92)
                      : Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _buildMenuItem(
                      ctx,
                      icon: CupertinoIcons.person_add,
                      label: '添加好友',
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(context, CupertinoPageRoute(builder: (_) => const AddFriendPage()));
                      },
                    ),
                    Divider(
                      height: 0.5,
                      color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                      indent: 52,
                    ),
                    _buildMenuItem(
                      ctx,
                      icon: CupertinoIcons.qrcode_viewfinder,
                      label: '扫一扫进群',
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(context, CupertinoPageRoute(builder: (_) => const ScanJoinGroupPage()));
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // 取消按钮
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkCard.withValues(alpha: 0.92)
                      : Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: CupertinoButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(
    BuildContext ctx, {
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: isDark ? AppColors.darkText : AppColors.lightText),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatefulWidget {
  final Map<String, dynamic> conversation;
  const _ConversationTile({super.key, required this.conversation});

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _dragExtent = 0;
  bool _isOpen = false;

  Map<String, dynamic> get conversation => widget.conversation;

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _animation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _activeSwipeNotifier.addListener(_onActiveSwipeChanged);
  }

  @override
  void dispose() {
    _activeSwipeNotifier.removeListener(_onActiveSwipeChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onActiveSwipeChanged() {
    if (_isOpen && _activeSwipeNotifier.value != widget.key) {
      _close();
    }
  }

  void _open() {
    _activeSwipeNotifier.value = widget.key;
    _animation = Tween<double>(begin: _dragExtent, end: -_actionWidth).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward(from: 0).then((_) {
      setState(() {
        _dragExtent = -_actionWidth;
        _isOpen = true;
      });
    });
  }

  void _close() {
    _animation = Tween<double>(begin: _dragExtent, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward(from: 0).then((_) {
      setState(() {
        _dragExtent = 0;
        _isOpen = false;
      });
    });
  }

  double get _actionWidth {
    final type = _toInt(conversation['type']) ?? 1;
    final isSystemNotification = type == 1 && (_toInt(conversation['friend']?['id']) ?? 0) == 1;
    if (isSystemNotification) return 0;
    // 群聊: 置顶 + 静音 = 2个按钮
    // 私聊: 置顶 + 备注 = 2个按钮
    return 140;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final type = _toInt(conversation['type']) ?? 1;
    final isGroup = type == 2;
    final isOA = type == 3;
    final friend = conversation['friend'] as Map<String, dynamic>?;
    final group = conversation['group'] as Map<String, dynamic>?;
    final pinned = conversation['pinned'] == true;
    final muted = conversation['muted'] == true;

    String displayName;
    String avatarName;
    String? avatar;
    String? avatarFrame;

    if (isOA) {
      final oa = conversation['official_account'];
      final oaMap = oa is Map<String, dynamic> ? oa : (oa is Map ? Map<String, dynamic>.from(oa) : null);
      displayName = oaMap?['name'] as String? ?? '公众号';
      avatarName = displayName;
      avatar = oaMap?['avatar']?.toString();
    } else if (isGroup) {
      displayName = (group?['name'] ?? '群聊').toString();
      avatarName = displayName;
      avatar = group?['avatar']?.toString();
    } else {
      final name = (conversation['friend_remark'] ?? friend?['remark'] ?? friend?['nickname'] ?? friend?['username'] ?? '用户').toString();
      displayName = name.isEmpty ? (friend?['nickname'] ?? friend?['username'] ?? '用户').toString() : name;
      avatarName = (friend?['nickname'] ?? friend?['username'] ?? '用户').toString();
      avatar = friend?['avatar']?.toString();
      avatarFrame = friend?['avatar_frame']?.toString();
    }

    final lastMessage = (conversation['last_message'] ?? '').toString();
    final unread = _toInt(conversation['unread_count']) ?? 0;
    final lastTime = conversation['last_time']?.toString();
    final friendId = _toInt(friend?['id']) ?? 0;
    final isSystemNotification = type == 1 && friendId == 1;
    final isOnline = !isGroup && !isOA && !isSystemNotification && friend != null && context.read<ConversationProvider>().isUserOnline(friendId);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final offset = _controller.isAnimating ? _animation.value : _dragExtent;
        return Stack(
          children: [
            // 右侧操作按钮
            if (!isSystemNotification)
              Positioned.fill(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!isSystemNotification) _buildActionBtn(
                      icon: pinned ? CupertinoIcons.pin_slash : CupertinoIcons.pin,
                      label: pinned ? '取消置顶' : '置顶',
                      color: AppColors.warning,
                      onTap: () {
                        _close();
                        context.read<ConversationProvider>().togglePin(conversation);
                      },
                    ),
                    if (isGroup && !isSystemNotification) _buildActionBtn(
                      icon: muted ? CupertinoIcons.bell : CupertinoIcons.bell_slash,
                      label: muted ? '取消静音' : '静音',
                      color: AppColors.primary,
                      onTap: () {
                        _close();
                        context.read<ConversationProvider>().toggleMute(conversation);
                      },
                    ),
                    if (!isGroup && !isSystemNotification) _buildActionBtn(
                      icon: CupertinoIcons.pencil,
                      label: '备注',
                      color: AppColors.info,
                      onTap: () {
                        _close();
                        _showRemarkDialog(context, conversation, friendId);
                      },
                    ),
                  ],
                ),
              ),
            // 前景内容（可滑动）
            GestureDetector(
              onHorizontalDragUpdate: (details) {
                if (isSystemNotification) return;
                setState(() {
                  _dragExtent = (_dragExtent + details.delta.dx).clamp(-_actionWidth, 0.0);
                });
              },
              onHorizontalDragEnd: (details) {
                if (isSystemNotification) return;
                if (_dragExtent < -_actionWidth * 0.4) {
                  _open();
                } else {
                  _close();
                }
              },
              onLongPress: () {
                if (isSystemNotification) return;
                HapticFeedback.mediumImpact();
                if (_isOpen) {
                  _close();
                } else {
                  _open();
                }
              },
              onTap: () {
                if (_isOpen) {
                  _close();
                  return;
                }
                if (isOA) {
                  final targetId = conversation['target_id'];
                  if (targetId != null) {
                    context.read<ConversationProvider>().markAsRead(conversation['id'] as int? ?? 0);
                    ApiClient.instance.dio.put('/conversations/oa/$targetId/unread').catchError((e) => null);
                  }
                  final oa = conversation['official_account'];
                  final oaMap = oa is Map<String, dynamic> ? oa : (oa is Map ? Map<String, dynamic>.from(oa) : <String, dynamic>{'id': conversation['target_id'], 'name': displayName, 'avatar': avatar});
                  Navigator.of(context).push(CupertinoPageRoute(
                    builder: (_) => OfficialAccountDetailPage(account: oaMap),
                  ));
                } else {
                  Navigator.of(context).pushNamed('/chat', arguments: conversation);
                }
              },
              child: Transform.translate(
                offset: Offset(offset, 0),
                child: Container(
                  color: pinned
                      ? (isDark ? const Color(0xFF1A1A24) : AppColors.systemGray6)
                      : (isDark ? AppColors.darkBg : AppColors.lightBg),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            // 头像
                            AvatarWidget(
                              url: avatar,
                              name: avatarName,
                              size: AppSpacing.avatarLg,
                              isGroup: isGroup,
                              showOnline: !isGroup && !isOA && !isSystemNotification,
                              isOnline: isOnline,
                              avatarFrame: avatarFrame,
                            ),
                            const SizedBox(width: 12),
                            // 名称 + 最后消息
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                displayName,
                                                style: AppTextStyles.convName.copyWith(
                                                  color: isDark ? AppColors.darkText : AppColors.lightText,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isGroup || isSystemNotification || isOA)
                                              Container(
                                                margin: const EdgeInsets.only(left: 4),
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: isSystemNotification
                                                      ? AppColors.primary.withAlpha(20)
                                                      : isOA
                                                          ? AppColors.success.withAlpha(20)
                                                          : AppColors.warning.withAlpha(20),
                                                  borderRadius: BorderRadius.circular(3),
                                                ),
                                                child: Text(
                                                  isSystemNotification ? '通知' : isOA ? '公众号' : '群',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: isSystemNotification ? AppColors.primary : isOA ? AppColors.success : AppColors.warning,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            if (muted)
                                              Padding(
                                                padding: const EdgeInsets.only(left: 4),
                                                child: Icon(CupertinoIcons.bell_slash, size: 13, color: AppColors.systemGray),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatTime(lastTime),
                                        style: AppTextStyles.convTime.copyWith(
                                          color: isDark ? AppColors.darkTextTertiary : AppColors.systemGray,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Builder(
                                          builder: (context) {
                                            final isTyping = !isGroup && !isOA && !isSystemNotification && friendId > 0 &&
                                                context.watch<ConversationProvider>().isUserTyping(friendId);
                                            return Text(
                                              isTyping ? '正在输入...' : lastMessage,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTextStyles.convMsg.copyWith(
                                                color: isTyping
                                                    ? AppColors.success
                                                    : (isDark ? AppColors.darkTextSecondary : AppColors.systemGray),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      if (unread > 0 && !muted)
                                        Container(
                                          margin: const EdgeInsets.only(left: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          constraints: const BoxConstraints(minWidth: 18),
                                          decoration: BoxDecoration(
                                            color: AppColors.error,
                                            borderRadius: BorderRadius.circular(9),
                                          ),
                                          child: Text(
                                            unread > 99 ? '99+' : '$unread',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                                          ),
                                        )
                                      else if (unread > 0 && muted)
                                        Container(
                                          margin: const EdgeInsets.only(left: 8),
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: AppColors.systemGray,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 下划线 - 从头像右侧对齐开始
                      Padding(
                        padding: EdgeInsets.only(left: 16 + AppSpacing.avatarLg + 12),
                        child: Divider(
                          height: 1,
                          thickness: 0.8,
                          color: isDark
                              ? Colors.white.withAlpha(20)
                              : Colors.black.withAlpha(15),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 66,
        color: color.withAlpha(230),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return '';
    try {
      final time = DateTime.parse(timeStr);
      final now = DateTime.now();
      final diff = now.difference(time);
      if (diff.inDays == 0) {
        return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      } else if (diff.inDays == 1) {
        return '昨天';
      } else if (diff.inDays < 7) {
        const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
        return weekdays[time.weekday - 1];
      } else {
        return '${time.month}/${time.day}';
      }
    } catch (e) {
      return '';
    }
  }

  void _showRemarkDialog(BuildContext context, Map<String, dynamic> conversation, int friendId) {
    final currentRemark = (conversation['remark'] ?? conversation['friend']?['remark'] ?? '').toString();
    final controller = TextEditingController(text: currentRemark);

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('设置备注'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            autofocus: true,
            placeholder: '输入备注名',
            padding: const EdgeInsets.all(12),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              final remark = controller.text.trim();
              Navigator.pop(ctx);
              final success = await context.read<ConversationProvider>().updateRemark(friendId, remark);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(remark.isEmpty ? '已清除备注' : '备注已更新')),
                );
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
