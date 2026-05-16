import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/conversation_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/avatar_widget.dart';
import '../contacts/add_friend_page.dart';

class ConversationListPage extends StatelessWidget {
  const ConversationListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('消息'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddFriendPage())),
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
          return RefreshIndicator(
            onRefresh: () => provider.loadConversations(),
            child: ListView.builder(
              itemCount: provider.conversations.length,
              itemBuilder: (context, index) {
                final conv = provider.conversations[index];
                return _ConversationTile(conversation: conv);
              },
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final type = conversation['type'] as int? ?? 1;
    final isGroup = type == 2;
    final friend = conversation['friend'] as Map<String, dynamic>?;
    final group = conversation['group'] as Map<String, dynamic>?;

    final name = (isGroup ? (group?['name'] ?? '群聊') : (friend?['nickname'] ?? friend?['username'] ?? '用户')).toString();
    String? avatar;
    String? avatarFrame;
    if (isGroup) {
      avatar = group?['avatar']?.toString();
    } else {
      avatar = friend?['avatar']?.toString();
      avatarFrame = friend?['avatar_frame']?.toString();
    }
    final lastMessage = (conversation['last_message'] ?? '').toString();
    final unread = conversation['unread_count'] as int? ?? 0;
    final lastTime = conversation['last_time']?.toString();
    final friendId = friend?['id'] as int? ?? 0;
    final isSystemNotification = type == 1 && friendId == 1;
    final isOnline = !isGroup && !isSystemNotification && friend != null && context.read<ConversationProvider>().isUserOnline(friendId);

    return InkWell(
      onTap: () => Navigator.of(context).pushNamed('/chat', arguments: conversation),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            // 头像 + 在线状态 + 群聊标签
            Stack(
              children: [
                AvatarWidget(url: avatar, name: name, size: AppSpacing.avatarLg, isGroup: isGroup, showOnline: !isGroup && !isSystemNotification, isOnline: isOnline, avatarFrame: avatarFrame),
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
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
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
                      Flexible(
                        child: Text(name, style: AppTextStyles.convName.copyWith(
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (isGroup || isSystemNotification)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSystemNotification
                                ? AppColors.primary.withAlpha(30)
                                : Colors.orange.withAlpha(30),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            isSystemNotification ? '通知' : '群',
                            style: TextStyle(
                              fontSize: 10,
                              color: isSystemNotification ? AppColors.primary : Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      const Spacer(),
                      Text(_formatTime(lastTime), style: AppTextStyles.convTime.copyWith(
                        color: unread > 0 ? AppColors.primary : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                      )),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.convMsg.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        )),
                      ),
                      if (unread > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(10)),
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
}
