import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 未读角标组件
class AppBadge extends StatelessWidget {
  final int count;
  final double size;
  final bool dot; // 只显示红点，不显示数字

  const AppBadge({super.key, this.count = 0, this.size = 18, this.dot = false});

  @override
  Widget build(BuildContext context) {
    if (count <= 0 && !dot) return const SizedBox.shrink();

    if (dot) {
      return Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
      );
    }

    final text = count > 99 ? '99+' : '$count';
    final width = text.length > 2 ? size + 8 : size;

    return Container(
      height: size,
      constraints: BoxConstraints(minWidth: width),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(color: Colors.white, fontSize: size * 0.6, fontWeight: FontWeight.w600),
      ),
    );
  }
}
