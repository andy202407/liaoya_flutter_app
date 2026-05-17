import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/friend_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/avatar_widget.dart';

class GroupListPage extends StatelessWidget {
  const GroupListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FriendProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('群聊')),
      body: provider.groups.isEmpty
          ? Center(child: Text('暂无群聊', style: AppTextStyles.body.copyWith(color: AppColors.lightTextTertiary)))
          : ListView.builder(
              itemCount: provider.groups.length,
              itemBuilder: (context, index) {
                final group = provider.groups[index];
                final name = group['name'] as String? ?? '群聊';
                final avatar = group['avatar'] as String?;
                final memberCount = group['member_count'] as int? ?? 0;

                return ListTile(
                  leading: AvatarWidget(url: avatar, name: name, size: AppSpacing.avatarMd, isGroup: true),
                  title: Text(name, style: AppTextStyles.convName.copyWith(color: isDark ? AppColors.darkText : AppColors.lightText)),
                  subtitle: Text('$memberCount 人', style: AppTextStyles.caption.copyWith(color: AppColors.lightTextSecondary)),
                  trailing: Icon(Iconsax.arrow_right_3, size: 16, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                  onTap: () {
                    // 构造会话数据跳转到群聊
                    final conversation = {
                      'type': 2,
                      'target_id': group['id'],
                      'group': group,
                    };
                    Navigator.of(context).pushNamed('/chat', arguments: conversation);
                  },
                );
              },
            ),
    );
  }
}
