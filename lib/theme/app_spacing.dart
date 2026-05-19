import 'package:flutter/material.dart';

/// 全局间距和尺寸 - 更宽松的现代布局
class AppSpacing {
  // 间距
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double xxxxl = 48;

  // 圆角 - 更大的圆角更现代
  static const double radiusXs = 6;
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 18;
  static const double radiusXl = 24;
  static const double radiusXxl = 32;
  static const double radiusFull = 999;

  // 图标大小
  static const double iconXs = 14;
  static const double iconSm = 18;
  static const double iconMd = 22;
  static const double iconLg = 26;
  static const double iconXl = 32;

  // 头像大小
  static const double avatarXs = 28;
  static const double avatarSm = 36;
  static const double avatarMd = 44;
  static const double avatarLg = 52;
  static const double avatarXl = 68;
  static const double avatarXxl = 88;

  // 页面内边距
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);
  static const EdgeInsets sectionPadding = EdgeInsets.symmetric(horizontal: lg, vertical: md);
}
