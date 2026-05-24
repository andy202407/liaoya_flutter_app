import 'dart:convert';
import 'package:flutter/material.dart';

/// @提及输入控制器
/// 检测"@"触发、管理 pendingMentions 列表、构建 mentions JSON
///
/// 使用方式与 MessageNavigationHelper 相同 — 在 ChatPage 中实例化，非 mixin。
///
/// Requirements: Algorithm 1 (Trigger Detection), Algorithm 2 (Mention Insertion),
///               Property 5 (Trigger word boundary), Property 8 (Mention JSON format)
class MentionInputController {
  /// 待发送的 @提及用户列表（int userId 或 "all"）
  final List<dynamic> pendingMentions = [];

  /// 检测用户是否刚在有效词边界处输入了"@"
  ///
  /// [text] - 当前输入框内容
  /// [cursorPosition] - 当前光标偏移量
  ///
  /// 返回 true 表示应显示成员选择器
  bool checkMentionTrigger(String text, int cursorPosition) {
    // 前置条件：cursorPosition > 0 且 text 非空
    if (cursorPosition <= 0 || text.isEmpty) return false;
    if (cursorPosition > text.length) return false;

    final charAtCursor = text[cursorPosition - 1];
    if (charAtCursor != '@') return false;

    // 检查词边界：@ 前面的字符必须是空格、换行或位于行首
    if (cursorPosition > 1) {
      final charBefore = text[cursorPosition - 2];
      if (charBefore != ' ' && charBefore != '\n') return false;
    }

    // 有效触发 → 调用方应显示成员选择器
    return true;
  }

  /// 在成员选择后将 "@nickname " 插入文本框
  /// 同时将 userId 添加到 pendingMentions
  ///
  /// [userId] - 用户ID（int）或 "all"
  /// [nickname] - 用户昵称
  /// [controller] - 文本输入控制器
  void insertMention(
      dynamic userId, String nickname, TextEditingController controller) {
    final text = controller.text;
    final cursorPos = controller.selection.baseOffset;

    // 找到光标前最后一个 "@"（触发字符）
    final beforeCursor = text.substring(0, cursorPos);
    final atIndex = beforeCursor.lastIndexOf('@');

    String newText;
    int newCursorPos;

    if (atIndex >= 0) {
      // 从 @ 到光标之间的内容替换为 @nickname + 不间断空格
      final before = text.substring(0, atIndex + 1); // 包含 @
      final after = text.substring(cursorPos);
      newText = '$before$nickname\u00A0$after';
      newCursorPos = atIndex + 1 + nickname.length + 1;
    } else {
      // 兜底：在末尾追加 @nickname
      newText = '${text}@$nickname\u00A0';
      newCursorPos = newText.length;
    }

    controller.text = newText;
    controller.selection = TextSelection.collapsed(offset: newCursorPos);

    // 记录被提及的用户
    pendingMentions.add(userId);
  }

  /// 构建 mentions JSON 字符串用于 API 提交
  ///
  /// 返回 null 如果 pendingMentions 为空
  /// 格式示例: ["all"] 或 [123, 456] 或 ["all", 123]
  String? buildMentionsJson() {
    if (pendingMentions.isEmpty) return null;
    return jsonEncode(pendingMentions);
  }

  /// 消息发送成功后清除待发送的提及列表
  void clearPendingMentions() {
    pendingMentions.clear();
  }

  /// 释放资源
  void dispose() {
    pendingMentions.clear();
  }
}
