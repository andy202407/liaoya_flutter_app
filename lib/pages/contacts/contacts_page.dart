import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/friend_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/avatar_widget.dart';
import 'add_friend_page.dart';
import 'friend_requests_page.dart';
import 'group_list_page.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FriendProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FriendProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('通讯录'),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.user_add),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddFriendPage())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.loadAll(),
        child: ListView(
          children: [
            const SizedBox(height: AppSpacing.sm),
            // 功能入口
            _buildEntry(context, '新朋友', Iconsax.user_add, AppColors.warning,
              badge: provider.pendingRequestCount,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendRequestsPage())),
            ),
            _buildEntry(context, '群聊', Iconsax.people_copy, AppColors.success,
              badge: provider.groups.length,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupListPage())),
            ),

            // 好友列表
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.sm),
              child: Text('好友 (${provider.friends.length})',
                style: AppTextStyles.caption.copyWith(color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
            ),

            if (provider.isLoading && provider.friends.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (provider.friends.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    children: [
                      Icon(Iconsax.people, size: 48, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                      const SizedBox(height: 12),
                      Text('暂无好友', style: AppTextStyles.body.copyWith(color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
                    ],
                  ),
                ),
              )
            else
              ...provider.friends.map((friend) => _buildFriendTile(context, friend, isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildEntry(BuildContext context, String title, IconData icon, Color color, {int badge = 0, VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: ListTile(
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: AppTextStyles.body),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge > 0) Text('$badge', style: AppTextStyles.caption.copyWith(color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
            const SizedBox(width: 4),
            Icon(Iconsax.arrow_right_3, size: 16, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildFriendTile(BuildContext context, Map<String, dynamic> friend, bool isDark) {
    final friendInfo = friend['friend'] as Map<String, dynamic>?;
    final name = (friendInfo?['nickname'] ?? friendInfo?['username'] ?? '用户').toString();
    final avatar = friendInfo?['avatar']?.toString();
    final avatarFrame = friendInfo?['avatar_frame']?.toString();
    final remark = friend['remark']?.toString();

    return ListTile(
      leading: AvatarWidget(url: avatar, name: name, size: AppSpacing.avatarMd, avatarFrame: avatarFrame),
      title: Text((remark != null && remark.isNotEmpty) ? remark : name, style: AppTextStyles.convName.copyWith(color: isDark ? AppColors.darkText : AppColors.lightText)),
      onTap: () {
        // 构造会话数据跳转到聊天
        final conversation = {
          'type': 1,
          'friend_id': friendInfo?['id'],
          'friend': friendInfo,
          'target_id': friendInfo?['id'],
        };
        Navigator.of(context).pushNamed('/chat', arguments: conversation);
      },
    );
  }
}
