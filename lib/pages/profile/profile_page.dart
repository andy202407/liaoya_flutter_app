import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/avatar_widget.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          // 用户信息卡片
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: [
                AvatarWidget(url: auth.avatar, name: auth.nickname ?? '用户', size: AppSpacing.avatarXl),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(auth.nickname ?? '用户', style: AppTextStyles.h3.copyWith(
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      )),
                      const SizedBox(height: 4),
                      Text('ID: ${auth.userId ?? ''}', style: AppTextStyles.caption.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      )),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 16, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // 设置组
          _buildGroup(context, [
            _SettingItem(Icons.dark_mode_rounded, '深色模式', trailing: Switch.adaptive(
              value: theme.isDark,
              onChanged: (_) => theme.toggleTheme(),
              activeColor: AppColors.primary,
            )),
            _SettingItem(Icons.notifications_rounded, '消息通知'),
            _SettingItem(Icons.shield_rounded, '账号安全'),
          ]),

          const SizedBox(height: AppSpacing.sm),

          _buildGroup(context, [
            _SettingItem(Icons.language_rounded, '语言'),
            _SettingItem(Icons.info_rounded, '关于'),
          ]),

          const SizedBox(height: AppSpacing.xxxl),

          // 退出按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () async {
                  await auth.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppColors.error.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                ),
                child: const Text('退出登录'),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  Widget _buildGroup(BuildContext context, List<_SettingItem> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Column(
        children: items.map((item) {
          return ListTile(
            leading: Icon(item.icon, color: AppColors.primary, size: 22),
            title: Text(item.title, style: AppTextStyles.body),
            trailing: item.trailing ?? Icon(Icons.chevron_right_rounded, size: 16,
              color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
            onTap: item.trailing == null ? () {} : null,
          );
        }).toList(),
      ),
    );
  }
}

class _SettingItem {
  final IconData icon;
  final String title;
  final Widget? trailing;
  const _SettingItem(this.icon, this.title, {this.trailing});
}
