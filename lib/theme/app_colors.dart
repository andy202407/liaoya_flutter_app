import 'package:flutter/material.dart';

/// 全局颜色定义 - iOS 风格配色
class AppColors {
  // 品牌色（iOS 风格蓝色调）
  static const Color primary = Color(0xFF007AFF);
  static const Color primaryLight = Color(0xFF5AC8FA);
  static const Color primaryDark = Color(0xFF0051D5);
  static const Color primarySurface = Color(0xFFE8F4FD);
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // 功能色 - iOS 系统色
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9500);
  static const Color error = Color(0xFFFF3B30);
  static const Color info = Color(0xFF5AC8FA);

  // 亮色模式 - iOS 风格
  static const Color lightBg = Color(0xFFF2F2F7);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF000000);
  static const Color lightTextSecondary = Color(0xFF3C3C43);
  static const Color lightTextTertiary = Color(0xFFC7C7CC);
  static const Color lightDivider = Color(0xFFC6C6C8);
  static const Color lightInputBg = Color(0xFFE5E5EA);
  static const Color lightHover = Color(0xFFD1D1D6);

  // 暗色模式 - iOS 风格
  static const Color darkBg = Color(0xFF000000);
  static const Color darkCard = Color(0xFF1C1C1E);
  static const Color darkCardElevated = Color(0xFF2C2C2E);
  static const Color darkText = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFEBEBF5);
  static const Color darkTextTertiary = Color(0xFF48484A);
  static const Color darkDivider = Color(0xFF38383A);
  static const Color darkInputBg = Color(0xFF2C2C2E);

  // 在线状态
  static const Color online = Color(0xFF34C759);
  static const Color offline = Color(0xFF8E8E93);
  static const Color busy = Color(0xFFFF9500);

  // 消息气泡 - iOS iMessage 风格
  static const Color bubbleSent = Color(0xFF007AFF);
  static const Color bubbleReceived = Color(0xFFE9E9EB);
  static const Color bubbleReceivedDark = Color(0xFF26252A);

  // iOS 系统灰色
  static const Color systemGray = Color(0xFF8E8E93);
  static const Color systemGray2 = Color(0xFFAEAEB2);
  static const Color systemGray3 = Color(0xFFC7C7CC);
  static const Color systemGray4 = Color(0xFFD1D1D6);
  static const Color systemGray5 = Color(0xFFE5E5EA);
  static const Color systemGray6 = Color(0xFFF2F2F7);
}
