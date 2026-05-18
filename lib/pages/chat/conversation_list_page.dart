import 'dart:async';
import 'package:flutter/material.dart';
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
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: GestureDetector(
            onTap: () {
              if (!_wsConnected) {
                WebSocketService.instance.connect();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在连接...'), duration: Duration(seconds: 1)));
              }
            },
            child: Icon(
              _wsConnected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              color: _wsConnected ? AppColors.online : AppColors.error,
              size: 22,
            ),
          ),
        ),
        leadingWidth: 40,
        title: const Text('消息'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_circle_outline_rounded),
            onSelected: (value) {
              if (value == 'add_friend') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AddFriendPage()));
              } else if (value == 'scan_group') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanJoinGroupPage()));
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'add_friend',
                child: Row(
                  children: [
                    Icon(Icons.person_add_alt_1_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('添加好友'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'scan_group',
                child: Row(
                  children: [
                    Icon(Icons.qr_code_scanner_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('扫一扫进群'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<ConversationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.conversations.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_outlined, size: 56, color: AppColors.lightTextTertiary),
                  const SizedBox(height: 16),
                  Text('暂无会话', style: AppTextStyles.body.copyWith(color: AppColors.lightTextTertiary)),
                ],
              ),
            );
          }
          return NotificationListener<ScrollNotification>(
            onNotification: (scrollInfo) {
              if (scrollInfo is ScrollEndNotification &&
                  scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200 &&
                  provider.hasMore &&
                  !provider.isLoading) {
                provider.loadConversations(loadMore: true);
              }
              return false;
            },
            child: RefreshIndicator(
              onRefresh: () => provider.loadConversations(),
              child: ListView.builder(
                itemCount: provider.conversations.length + (provider.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= provider.conversations.length) {
                    // 底部加载指示器
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                    );
                  }
                  final conv = provider.conversations[index];
                  return _ConversationTile(conversation: conv);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Map<String, dynamic> conversation;
  const _ConversationTile({required this.conversation});

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
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

    // 构建滑动操作按钮
    final List<Widget> actions = [];

    // 静音按钮（群聊和私聊都有，系统通知除外）
    if (!isSystemNotification) {
      actions.add(
        _SwipeAction(
          color: muted ? const Color(0xFF34C759) : const Color(0xFFFF9500),
          icon: muted ? Icons.notifications_active : Icons.notifications_off,
          label: muted ? '取消静音' : '静音',
          onTap: () => context.read<ConversationProvider>().toggleMute(conversation),
        ),
      );
    }

    // 置顶按钮（所有会话都有）
    actions.add(
      _SwipeAction(
        color: const Color(0xFF007AFF),
        icon: pinned ? Icons.push_pin_outlined : Icons.push_pin,
        label: pinned ? '取消置顶' : '置顶',
        onTap: () => context.read<ConversationProvider>().togglePin(conversation),
      ),
    );

    // 备注按钮（私聊才有）
    if (!isGroup && !isSystemNotification) {
      actions.add(
        _SwipeAction(
          color: const Color(0xFF5856D6),
          icon: Icons.edit_note_rounded,
          label: '备注',
          onTap: () => _showRemarkDialog(context, conversation, friendId),
        ),
      );
    }

    final tile = Container(
      color: pinned
          ? (isDark ? Colors.white.withAlpha(8) : const Color(0xFFF8F6FF))
          : Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isOA) {
            // 公众号：清除未读 + 打开公众号详情
            final targetId = conversation['target_id'];
            if (targetId != null) {
              context.read<ConversationProvider>().markAsRead(conversation['id'] as int? ?? 0);
              ApiClient.instance.dio.put('/conversations/oa/$targetId/unread').catchError((e) => null);
            }
            final oa = conversation['official_account'];
            final oaMap = oa is Map<String, dynamic> ? oa : (oa is Map ? Map<String, dynamic>.from(oa) : <String, dynamic>{'id': conversation['target_id'], 'name': displayName, 'avatar': avatar});
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => OfficialAccountDetailPage(account: oaMap),
            ));
          } else {
            Navigator.of(context).pushNamed('/chat', arguments: conversation);
          }
        },
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
              child: Row(
                children: [
                  // 头像
                  Stack(
                    children: [
                      AvatarWidget(url: avatar, name: avatarName, size: AppSpacing.avatarLg, isGroup: isGroup, showOnline: !isGroup && !isOA && !isSystemNotification, isOnline: isOnline, avatarFrame: avatarFrame),
                      if (isGroup)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkBg : AppColors.lightBg,
                              shape: BoxShape.circle,
                            ),
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                              child: const Icon(Icons.group_rounded, size: 9, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.md),
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
                                    child: Text(displayName, style: AppTextStyles.convName.copyWith(
                                      color: isDark ? AppColors.darkText : AppColors.lightText,
                                    ), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                  if (isGroup || isSystemNotification || isOA)
                                    Container(
                                      margin: const EdgeInsets.only(left: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: isSystemNotification ? AppColors.primary.withAlpha(30) : isOA ? const Color(0xFF10B981).withAlpha(30) : Colors.orange.withAlpha(30),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        isSystemNotification ? '通知' : isOA ? '公众号' : '群',
                                        style: TextStyle(fontSize: 10, color: isSystemNotification ? AppColors.primary : isOA ? const Color(0xFF10B981) : Colors.orange, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  if (muted)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Icon(Icons.notifications_off, size: 13, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(_formatTime(lastTime), style: AppTextStyles.convTime.copyWith(
                              color: unread > 0 && !muted ? AppColors.primary : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                            )),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  // 检查是否正在输入（仅私聊）
                                  final isTyping = !isGroup && !isOA && !isSystemNotification && friendId > 0 &&
                                      context.watch<ConversationProvider>().isUserTyping(friendId);
                                  return Text(
                                    isTyping ? '正在输入...' : lastMessage,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.convMsg.copyWith(
                                      color: isTyping ? Colors.green[600] : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (unread > 0 && !muted)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(10)),
                                child: Text(unread > 99 ? '99+' : '$unread', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                              )
                            else if (unread > 0 && muted)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(10)),
                                child: Text(unread > 99 ? '99+' : '$unread', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 置顶角标（右上角三角形 + "顶"字）
            if (pinned)
              Positioned(
                top: 0,
                right: 0,
                child: CustomPaint(
                  size: const Size(28, 28),
                  painter: _PinCornerPainter(isDark: isDark),
                ),
              ),
          ],
        ),
      ),
    );

    // 系统通知不需要滑动操作
    if (isSystemNotification) return tile;

    return ClipRect(
      child: _SlidableConversation(
        actions: actions,
        child: tile,
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

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设置备注'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入备注名'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final remark = controller.text.trim();
              Navigator.pop(ctx);
              final success = await context.read<ConversationProvider>().updateRemark(friendId, remark);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(remark.isEmpty ? '已清除备注' : '备注已更新')));
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

class _SwipeAction extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SwipeAction({required this.color, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        color: color,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

/// 右上角置顶三角形角标 + "顶"字
class _PinCornerPainter extends CustomPainter {
  final bool isDark;
  _PinCornerPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withAlpha(isDark ? 180 : 200)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, 0)
      ..close();

    canvas.drawPath(path, paint);

    // 画"顶"字
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '顶',
        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(size.width - textPainter.width - 2, 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 自定义左滑操作面板
class _SlidableConversation extends StatefulWidget {
  final List<Widget> actions;
  final Widget child;

  const _SlidableConversation({required this.actions, required this.child});

  @override
  State<_SlidableConversation> createState() => _SlidableConversationState();
}

class _SlidableConversationState extends State<_SlidableConversation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragExtent = 0;
  double get _maxSlide => widget.actions.length * 72.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragExtent += details.primaryDelta!;
      _dragExtent = _dragExtent.clamp(-_maxSlide, 0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_dragExtent.abs() > _maxSlide * 0.4) {
      // 打开
      setState(() => _dragExtent = -_maxSlide);
    } else {
      // 关闭
      setState(() => _dragExtent = 0);
    }
  }

  void _close() {
    setState(() => _dragExtent = 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: Stack(
        children: [
          // 操作按钮（右侧）
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: widget.actions.map((action) {
                if (action is _SwipeAction) {
                  return _SwipeAction(
                    color: action.color,
                    icon: action.icon,
                    label: action.label,
                    onTap: () {
                      _close();
                      action.onTap();
                    },
                  );
                }
                return action;
              }).toList(),
            ),
          ),
          // 内容（可滑动）
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_dragExtent, 0, 0),
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
