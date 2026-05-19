import 'package:flutter/material.dart';

/// 全局文本样式 - iOS SF Pro 风格字体层级
class AppTextStyles {
  // iOS 使用 -apple-system / SF Pro 字体
  // Flutter 在 iOS 上默认使用 SF Pro，无需额外指定

  // 标题 - iOS Large Title / Title 风格
  static const TextStyle h1 = TextStyle(fontSize: 34, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: 0.37);
  static const TextStyle h2 = TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.27, letterSpacing: 0.35);
  static const TextStyle h3 = TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.25, letterSpacing: 0.38);
  static const TextStyle h4 = TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.29, letterSpacing: -0.41);

  // 正文 - iOS Body 风格
  static const TextStyle bodyLg = TextStyle(fontSize: 17, fontWeight: FontWeight.normal, height: 1.29, letterSpacing: -0.41);
  static const TextStyle body = TextStyle(fontSize: 15, fontWeight: FontWeight.normal, height: 1.33, letterSpacing: -0.24);
  static const TextStyle bodySm = TextStyle(fontSize: 13, fontWeight: FontWeight.normal, height: 1.38, letterSpacing: -0.08);

  // 辅助文字 - iOS Caption / Footnote
  static const TextStyle caption = TextStyle(fontSize: 12, fontWeight: FontWeight.normal, height: 1.33, letterSpacing: 0);
  static const TextStyle captionSm = TextStyle(fontSize: 11, fontWeight: FontWeight.normal, height: 1.27, letterSpacing: 0.07);

  // 按钮
  static const TextStyle button = TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.2, letterSpacing: -0.41);
  static const TextStyle buttonSm = TextStyle(fontSize: 15, fontWeight: FontWeight.w500, height: 1.2, letterSpacing: -0.24);

  // 导航标题 - iOS Navigation Bar Title
  static const TextStyle navTitle = TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.41);

  // 会话列表
  static const TextStyle convName = TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: -0.32);
  static const TextStyle convMsg = TextStyle(fontSize: 14, fontWeight: FontWeight.normal, letterSpacing: -0.15);
  static const TextStyle convTime = TextStyle(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0);

  // 聊天
  static const TextStyle chatMsg = TextStyle(fontSize: 16, fontWeight: FontWeight.normal, height: 1.35, letterSpacing: -0.32);
  static const TextStyle chatTime = TextStyle(fontSize: 11, fontWeight: FontWeight.w400, letterSpacing: 0.07);
  static const TextStyle chatName = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0);
}
