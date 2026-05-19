import 'dart:async';
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
              size: 20,
            ),
          ),
        ),
        leadingWidth: 44,
        title: const Text('消息'),
        actions: [
          CupertinoButton(
            padding: const EdgeInsets.only(right: 16),
            onPressed: () => _showAddMenu(context),
            child: const Icon(CupertinoIcons.plus_circle, size: 24),
          ),
        ],
      ),
      body: Consumer<ConversationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.conversations.isEmpty) {
            return const Center(child: CupertinoActivityIndicator());
          }
          if (provider.conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.chat_bubble_2, size: 48, color: AppColors.systemGray3),
                  const SizedBox(height: 12),
                  Text('暂无会话', style: TextStyle(fontSize: 15, color: AppColors.systemGray)),
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
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                CupertinoSliverRefreshControl(
                  onRefresh: () => provider.loadConversations(),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= provider.conversations.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CupertinoActivityIndicator()),
                        );
                      }
                      final conv = provider.conversations[index];
                      return RepaintBoundary(
                        child: _ConversationTile(conversation: conv),
                      );
                    },
                    childCount: provider.conversations.length + (provider.hasMore ? 1 : 0),
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: false, // 我们手动加了 RepaintBoundary
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddMenu(BuildContext context) {
    HapticFeedback.mediumImpact();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, CupertinoPageRoute(builder: (_) => const AddFriendPage()));
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.person_add, size: 20),
                SizedBox(width: 8),
                Text('添加好友'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, CupertinoPageRoute(builder: (_) => const ScanJoinGroupPage()));
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.qrcode_viewfinder, size: 20),
                SizedBox(width: 8),
                Text('扫一扫进群'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          isDestructiveAction: false,
          child: const Text('取消'),
        ),
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

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showContextMenu(context, conversation, isGroup, isSystemNotification, pinned, muted, friendId);
      },
      child: Container(
        color: pinned
            ? (isDark ? Colors.white.withAlpha(5) : AppColors.systemGray6)
            : Colors.transparent,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
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
          child: Padding(
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

  void _showContextMenu(BuildContext context, Map<String, dynamic> conversation, bool isGroup, bool isSystemNotification, bool pinned, bool muted, int friendId) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          if (!isSystemNotification)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                context.read<ConversationProvider>().togglePin(conversation);
              },
              child: Text(pinned ? '取消置顶' : '置顶'),
            ),
          if (!isSystemNotification)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                context.read<ConversationProvider>().toggleMute(conversation);
              },
              child: Text(muted ? '取消静音' : '静音'),
            ),
          if (!isGroup && !isSystemNotification)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                _showRemarkDialog(context, conversation, friendId);
              },
              child: const Text('设置备注'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
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
