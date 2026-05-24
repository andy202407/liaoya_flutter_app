import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// @消息导航提示条组件
/// 显示在群聊输入框上方，提示用户有未读@消息，支持上下切换导航
///
/// Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6
class MentionNavWidget extends StatelessWidget {
  /// 未读@消息数量
  final int unreadCount;

  /// 当前导航索引（从0开始）
  final int currentIndex;

  /// 点击导航到下一条@消息
  final VoidCallback? onNext;

  /// 点击导航到上一条@消息
  final VoidCallback? onPrev;

  /// 点击关闭提示条
  final VoidCallback? onClose;

  /// 点击提示条本身（等同于 onNext）
  final VoidCallback? onTap;

  const MentionNavWidget({
    super.key,
    required this.unreadCount,
    this.currentIndex = 0,
    this.onNext,
    this.onPrev,
    this.onClose,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 无未读@消息时不显示 (Requirement 5.5)
    if (unreadCount <= 0) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E23) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withAlpha(15),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 60 : 12),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? onNext,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // 左侧：@ 图标（红色圆形背景）
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      '@',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // 中间：提示文字
                Expanded(
                  child: Text(
                    '有$unreadCount条@你的消息',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ),
                // 右侧：上/下导航箭头 + 关闭按钮
                _buildNavButton(
                  icon: Icons.keyboard_arrow_up_rounded,
                  onTap: onPrev,
                  isDark: isDark,
                ),
                const SizedBox(width: 2),
                _buildNavButton(
                  icon: Icons.keyboard_arrow_down_rounded,
                  onTap: onNext,
                  isDark: isDark,
                ),
                const SizedBox(width: 6),
                // 关闭按钮 (Requirement 5.6)
                _buildNavButton(
                  icon: Icons.close_rounded,
                  onTap: onClose,
                  isDark: isDark,
                  isClose: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback? onTap,
    required bool isDark,
    bool isClose = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: isClose
              ? (isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(8))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isDark ? Colors.white60 : Colors.black54,
        ),
      ),
    );
  }
}
