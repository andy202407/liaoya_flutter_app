import 'package:flutter/material.dart';

/// 全局颜色定义 - 现代化配色
class AppColors {
  // 品牌色（更饱和的紫色渐变）
  static const Color primary = Color(0xFF7C5CFC);
  static const Color primaryLight = Color(0xFF9B7FFF);
  static const Color primaryDark = Color(0xFF5B3FD9);
  static const Color primarySurface = Color(0xFFF0EBFF); // 品牌色浅底
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF9B7FFF), Color(0xFF7C5CFC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF7C5CFC), Color(0xFF5B3FD9), Color(0xFF4527A0)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // 功能色
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // 亮色模式 - 更柔和的灰阶
  static const Color lightBg = Color(0xFFF8F9FA);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF111827);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color lightTextTertiary = Color(0xFF9CA3AF);
  static const Color lightDivider = Color(0xFFF3F4F6);
  static const Color lightInputBg = Color(0xFFF3F4F6);
  static const Color lightHover = Color(0xFFF9FAFB);

  // 暗色模式 - 更深邃的暗色
  static const Color darkBg = Color(0xFF0F0F14);
  static const Color darkCard = Color(0xFF1A1A24);
  static const Color darkCardElevated = Color(0xFF22222E);
  static const Color darkText = Color(0xFFF3F4F6);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);
  static const Color darkTextTertiary = Color(0xFF6B7280);
  static const Color darkDivider = Color(0xFF2D2D3A);
  static const Color darkInputBg = Color(0xFF22222E);

  // 在线状态
  static const Color online = Color(0xFF10B981);
  static const Color offline = Color(0xFF9CA3AF);
  static const Color busy = Color(0xFFF59E0B);

  // 消息气泡
  static const Color bubbleSent = Color(0xFF7C5CFC);
  static const Color bubbleReceived = Color(0xFFFFFFFF);
  static const Color bubbleReceivedDark = Color(0xFF22222E);

  // iOS 系统灰色（兼容新页面引用）
  static const Color systemGray = Color(0xFF8E8E93);
  static const Color systemGray2 = Color(0xFFAEAEB2);
  static const Color systemGray3 = Color(0xFFC7C7CC);
  static const Color systemGray6 = Color(0xFFF2F2F7);
}
