import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/friend_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
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
          CupertinoButton(
            padding: const EdgeInsets.only(right: 16),
            onPressed: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const AddFriendPage())),
            child: const Icon(CupertinoIcons.person_add, size: 22),
          ),
        ],
      ),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          CupertinoSliverRefreshControl(
            onRefresh: () => provider.loadAll(),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 8),
                // 功能入口 - iOS 分组列表风格
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      _buildEntry(
                        context,
                        '新朋友',
                        CupertinoIcons.person_add,
                        AppColors.warning,
                        badge: provider.pendingRequestCount,
                        onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const FriendRequestsPage())),
                        showDivider: true,
                      ),
                      _buildEntry(
                        context,
                        '群聊',
                        CupertinoIcons.person_3,
                        AppColors.success,
                        badge: provider.groups.length,
                        onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const GroupListPage())),
                        showDivider: false,
                      ),
                    ],
                  ),
                ),
                // 好友列表标题
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 24, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '好友 (${provider.friends.length})',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.systemGray,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (provider.isLoading && provider.friends.isEmpty)
            const SliverFillRemaining(
              child: Center(child: CupertinoActivityIndicator()),
            )
          else if (provider.friends.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.person_2, size: 48, color: AppColors.systemGray3),
                    const SizedBox(height: 12),
                    Text('暂无好友', style: TextStyle(fontSize: 15, color: AppColors.systemGray)),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final friend = provider.friends[index];
                  return _buildFriendTile(context, friend, isDark, index == 0, index == provider.friends.length - 1);
                },
                childCount: provider.friends.length,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEntry(BuildContext context, String title, IconData icon, Color color, {int badge = 0, VoidCallback? onTap, bool showDivider = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ),
                if (badge > 0)
                  Text(
                    '$badge',
                    style: TextStyle(fontSize: 14, color: AppColors.systemGray),
                  ),
                const SizedBox(width: 4),
                Icon(CupertinoIcons.chevron_right, size: 14, color: AppColors.systemGray3),
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 60),
            child: Divider(height: 0.33, color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
          ),
      ],
    );
  }

  Widget _buildFriendTile(BuildContext context, Map<String, dynamic> friend, bool isDark, bool isFirst, bool isLast) {
    final friendInfo = friend['friend'] as Map<String, dynamic>?;
    final name = (friendInfo?['nickname'] ?? friendInfo?['username'] ?? '用户').toString();
    final avatar = friendInfo?['avatar']?.toString();
    final avatarFrame = friendInfo?['avatar_frame']?.toString();
    final remark = friend['remark']?.toString();

    return Container(
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        top: isFirst ? 0 : 0,
        bottom: isLast ? 16 : 0,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(10) : Radius.zero,
          bottom: isLast ? const Radius.circular(10) : Radius.zero,
        ),
      ),
      child: Column(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              final conversation = {
                'type': 1,
                'friend_id': friendInfo?['id'],
                'friend': friendInfo,
                'target_id': friendInfo?['id'],
              };
              Navigator.of(context).pushNamed('/chat', arguments: conversation);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  AvatarWidget(url: avatar, name: name, size: AppSpacing.avatarMd, avatarFrame: avatarFrame),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      (remark != null && remark.isNotEmpty) ? remark : name,
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isLast)
            Padding(
              padding: const EdgeInsets.only(left: 72),
              child: Divider(height: 0.33, color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
            ),
        ],
      ),
    );
  }
}
