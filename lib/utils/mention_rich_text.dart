import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Parses message content to identify @username patterns and renders them
/// as highlighted, tappable spans.
class MentionRichText {
  /// Regex: matches @username (Chinese/English/digits/underscore, 1-20 chars).
  /// Compiled once as a static final for performance.
  static final _mentionRegex = RegExp(r'@([\w\u4e00-\u9fff]{1,20})');

  /// Parse message content and return a list of InlineSpans.
  ///
  /// @mentions are highlighted with [mentionStyle] (defaults to blue, w500)
  /// and optionally tappable via [onMentionTap].
  ///
  /// - Empty [content] returns an empty list.
  /// - Content with no @mentions returns a single TextSpan with [baseStyle].
  static List<InlineSpan> parse({
    required String content,
    required TextStyle baseStyle,
    TextStyle? mentionStyle,
    void Function(String username)? onMentionTap,
  }) {
    if (content.isEmpty) return [];

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in _mentionRegex.allMatches(content)) {
      // Add text before this match
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: content.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }

      // Add highlighted @mention span
      final mentionText = match.group(0)!; // e.g. "@张三"
      final username = match.group(1)!; // e.g. "张三"

      final effectiveStyle = mentionStyle ??
          baseStyle.copyWith(
            color: Colors.blue,
            fontWeight: FontWeight.w500,
          );

      spans.add(TextSpan(
        text: mentionText,
        style: effectiveStyle,
        recognizer: onMentionTap != null
            ? (TapGestureRecognizer()..onTap = () => onMentionTap(username))
            : null,
      ));

      lastEnd = match.end;
    }

    // Add remaining text after last match
    if (lastEnd < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastEnd),
        style: baseStyle,
      ));
    }

    return spans;
  }
}
