import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('发现')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          _buildGroup(context, [
            _ItemData(Icons.photo_camera_rounded, '朋友圈', const Color(0xFF3B82F6)),
            _ItemData(Icons.live_tv_rounded, '直播', const Color(0xFFEF4444)),
          ]),
          const SizedBox(height: AppSpacing.sm),
          _buildGroup(context, [
            _ItemData(Icons.card_giftcard_rounded, '红包', const Color(0xFFF97316)),
            _ItemData(Icons.check_circle_rounded, '签到', const Color(0xFF10B981)),
            _ItemData(Icons.emoji_events_rounded, '抽奖', const Color(0xFFEC4899)),
          ]),
          const SizedBox(height: AppSpacing.sm),
          _buildGroup(context, [
            _ItemData(Icons.sports_esports_rounded, '游戏', const Color(0xFF8B5CF6)),
          ]),
        ],
      ),
    );
  }

  Widget _buildGroup(BuildContext context, List<_ItemData> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Column(
        children: items.map((item) {
          return ListTile(
            leading: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, color: item.color, size: 20),
            ),
            title: Text(item.title, style: AppTextStyles.body),
            trailing: const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.lightTextTertiary),
            onTap: () {},
          );
        }).toList(),
      ),
    );
  }
}
class _ItemData {
  final IconData icon;
  final String title;
  final Color color;
  const _ItemData(this.icon, this.title, this.color);
}
