import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../config/api_config.dart';
import 'avatar_widget.dart';

/// iOS 风格应用内消息通知弹窗
class InAppNotification {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  /// 显示通知
  static void show({
    required BuildContext context,
    required String title,
    required String body,
    String? avatar,
    bool isGroup = false,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 3),
  }) {
    dismiss(); // 移除旧的

    final overlayState = Overlay.maybeOf(context, rootOverlay: true);
    if (overlayState == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;

    _currentEntry = OverlayEntry(
      builder: (_) => _NotificationBanner(
        title: title,
        body: body,
        avatar: avatar,
        isGroup: isGroup,
        isDark: isDark,
        topPadding: topPadding,
        onTap: () {
          dismiss();
          onTap?.call();
        },
        onDismiss: dismiss,
      ),
    );

    overlayState.insert(_currentEntry!);

    _dismissTimer = Timer(duration, dismiss);
  }

  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    try {
      _currentEntry?.remove();
    } catch (_) {}
    _currentEntry = null;
  }
}

class _NotificationBanner extends StatefulWidget {
  final String title;
  final String body;
  final String? avatar;
  final bool isGroup;
  final bool isDark;
  final double topPadding;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const _NotificationBanner({
    required this.title,
    required this.body,
    this.avatar,
    this.isGroup = false,
    required this.isDark,
    required this.topPadding,
    this.onTap,
    this.onDismiss,
  });

  @override
  State<_NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<_NotificationBanner> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDismiss() {
    _controller.reverse().then((_) => widget.onDismiss?.call());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final topPadding = widget.topPadding;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: GestureDetector(
          onTap: widget.onTap,
          onVerticalDragUpdate: (details) {
            setState(() => _dragOffset += details.delta.dy);
          },
          onVerticalDragEnd: (details) {
            if (_dragOffset < -30) {
              _handleDismiss();
            } else {
              setState(() => _dragOffset = 0);
            }
          },
          child: Transform.translate(
            offset: Offset(0, _dragOffset.clamp(-100.0, 0.0)),
            child: Container(
              margin: EdgeInsets.fromLTRB(12, topPadding + 8, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(30),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 100 : 50),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // 头像 - 复用 AvatarWidget 保持一致
                  AvatarWidget(
                    url: widget.avatar,
                    name: widget.title,
                    size: 38,
                    isGroup: widget.isGroup,
                  ),
                  const SizedBox(width: 10),
                  // 内容
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                  decoration: TextDecoration.none,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: widget.isGroup
                                      ? [const Color(0xFF6366F1), const Color(0xFF4F46E5)]
                                      : [const Color(0xFF10B981), const Color(0xFF059669)],
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.isGroup ? '群聊' : '好友',
                                style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.body,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.black54,
                            decoration: TextDecoration.none,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // 箭头
                  Icon(Iconsax.arrow_right_3, size: 18, color: isDark ? Colors.white38 : Colors.black26),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
