import 'package:flutter/material.dart';

/// 全局文本样式 - 更精致的字体层级
class AppTextStyles {
  // 标题 - 更紧凑的行高
  static const TextStyle h1 = TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -0.5);
  static const TextStyle h2 = TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.25, letterSpacing: -0.3);
  static const TextStyle h3 = TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.3);
  static const TextStyle h4 = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.35);

  // 正文
  static const TextStyle bodyLg = TextStyle(fontSize: 16, fontWeight: FontWeight.normal, height: 1.5);
  static const TextStyle body = TextStyle(fontSize: 14, fontWeight: FontWeight.normal, height: 1.5);
  static const TextStyle bodySm = TextStyle(fontSize: 13, fontWeight: FontWeight.normal, height: 1.45);

  // 辅助文字
  static const TextStyle caption = TextStyle(fontSize: 12, fontWeight: FontWeight.normal, height: 1.4, letterSpacing: 0.1);
  static const TextStyle captionSm = TextStyle(fontSize: 11, fontWeight: FontWeight.normal, height: 1.3, letterSpacing: 0.2);

  // 按钮
  static const TextStyle button = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.2, letterSpacing: 0.2);
  static const TextStyle buttonSm = TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.2);

  // 导航标题
  static const TextStyle navTitle = TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2);

  // 会话列表
  static const TextStyle convName = TextStyle(fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: -0.1);
  static const TextStyle convMsg = TextStyle(fontSize: 13, fontWeight: FontWeight.normal);
  static const TextStyle convTime = TextStyle(fontSize: 11, fontWeight: FontWeight.w400);

  // 聊天
  static const TextStyle chatMsg = TextStyle(fontSize: 15, fontWeight: FontWeight.normal, height: 1.45);
  static const TextStyle chatTime = TextStyle(fontSize: 11, fontWeight: FontWeight.w400, letterSpacing: 0.2);
  static const TextStyle chatName = TextStyle(fontSize: 12, fontWeight: FontWeight.w500);
}
