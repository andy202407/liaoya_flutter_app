import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/friend_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/avatar_widget.dart';

class FriendRequestsPage extends StatelessWidget {
  const FriendRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FriendProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('新朋友')),
      body: provider.friendRequests.isEmpty
          ? Center(child: Text('暂无好友请求', style: AppTextStyles.body.copyWith(color: AppColors.lightTextTertiary)))
          : ListView.builder(
              itemCount: provider.friendRequests.length,
              itemBuilder: (context, index) {
                final req = provider.friendRequests[index];
                final fromUser = req['from_user'] as Map<String, dynamic>?;
                final name = (fromUser?['nickname'] ?? fromUser?['username'] ?? '用户').toString();
                final avatar = fromUser?['avatar']?.toString();
                final message = (req['message'] ?? '').toString();
                final status = (req['status'] ?? 'pending').toString();
                final requestId = (req['id'] is int) ? req['id'] as int : int.tryParse(req['id'].toString()) ?? 0;

                return ListTile(
                  leading: AvatarWidget(url: avatar, name: name as String, size: AppSpacing.avatarMd),
                  title: Text(name, style: AppTextStyles.convName.copyWith(color: isDark ? AppColors.darkText : AppColors.lightText)),
                  subtitle: message.isNotEmpty ? Text(message, style: AppTextStyles.caption.copyWith(color: AppColors.lightTextSecondary)) : null,
                  trailing: status == 'pending'
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () => provider.rejectRequest(requestId),
                              child: const Text('拒绝', style: TextStyle(color: AppColors.lightTextTertiary)),
                            ),
                            const SizedBox(width: 4),
                            ElevatedButton(
                              onPressed: () => provider.acceptRequest(requestId),
                              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                              child: const Text('接受', style: TextStyle(fontSize: 13)),
                            ),
                          ],
                        )
                      : Text(
                          status == 'accepted' ? '已添加' : '已拒绝',
                          style: AppTextStyles.caption.copyWith(color: AppColors.lightTextTertiary),
                        ),
                );
              },
            ),
    );
  }
}
