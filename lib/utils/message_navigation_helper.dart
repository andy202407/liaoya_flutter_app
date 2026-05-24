import 'package:flutter/material.dart';
import '../services/api/api_client.dart';
import '../theme/app_colors.dart';

/// 消息导航结果
enum NavigationResult {
  /// 成功定位到消息
  success,
  /// 消息已被删除/撤回
  messageDeleted,
  /// 网络错误
  networkError,
  /// 消息未找到（加载后仍未找到）
  notFound,
}

/// 消息导航辅助工具
/// 提供统一的消息跳转定位逻辑，供@导航和引用消息点击共用
///
/// Requirements: 6.1, 6.2, 6.4, 9.3
class MessageNavigationHelper {
  final _dio = ApiClient.instance.dio;

  /// 当前高亮的消息ID，使用 ValueNotifier 实现响应式更新
  /// 外部可监听此值来决定是否对某条消息应用高亮动画
  final ValueNotifier<int?> highlightedMessageId = ValueNotifier(null);

  /// 消息 GlobalKey 映射，用于精确滚动定位
  final Map<int, GlobalKey> _messageKeys = {};

  /// 高亮动画持续时间（2秒渐隐）
  static const Duration highlightDuration = Duration(seconds: 2);

  /// 获取或创建消息对应的 GlobalKey
  GlobalKey getKeyForMessage(int messageId) {
    return _messageKeys.putIfAbsent(messageId, () => GlobalKey());
  }

  /// 清理不再需要的 keys（当消息列表被替换时调用）
  void clearKeys() {
    _messageKeys.clear();
  }

  /// 滚动到指定消息并高亮
  ///
  /// [messageId] - 目标消息ID
  /// [groupId] - 群聊ID（群聊时为群ID，私聊时为好友ID）
  /// [isGroup] - 是否为群聊
  /// [scrollController] - 消息列表的 ScrollController
  /// [messages] - 当前已加载的消息列表
  /// [onLoadMore] - 加载更多历史消息的回调，返回是否还有更多
  /// [onShowToast] - 显示 Toast 提示的回调
  ///
  /// 返回导航结果
  Future<NavigationResult> scrollToMessage({
    required int messageId,
    required int groupId,
    bool isGroup = true,
    required ScrollController scrollController,
    required List<Map<String, dynamic>> messages,
    Future<void> Function(List<Map<String, dynamic>> newMessages)? onMessagesLoaded,
    Future<bool> Function()? onLoadMore,
    void Function(String message)? onShowToast,
  }) async {
    // Step 1: 检查消息是否在当前加载范围内
    final index = _findMessageIndex(messageId, messages);

    if (index >= 0) {
      // 消息已加载，使用 GlobalKey 精确滚动
      // 等一帧确保 key 已经绑定到 widget
      await Future.delayed(const Duration(milliseconds: 50));
      final scrolled = await _scrollToMessageByKey(messageId);
      if (scrolled) {
        _applyHighlight(messageId);
        return NavigationResult.success;
      }
      // 再等一帧重试
      await Future.delayed(const Duration(milliseconds: 100));
      final retryScrolled = await _scrollToMessageByKey(messageId);
      if (retryScrolled) {
        _applyHighlight(messageId);
        return NavigationResult.success;
      }
      // 最终 fallback: 估算位置
      await _scrollToIndexEstimate(index, scrollController, messages.length);
      _applyHighlight(messageId);
      return NavigationResult.success;
    }

    // Step 2: 消息不在当前范围
    // 策略：尝试加载更多历史消息（最多3次），看能否找到目标消息
    if (onLoadMore != null) {
      for (int attempt = 0; attempt < 3; attempt++) {
        final hasMore = await onLoadMore();
        // 等待 UI 更新
        await Future.delayed(const Duration(milliseconds: 200));

        // 重新检查消息是否已加载
        final newIndex = _findMessageIndex(messageId, messages);
        if (newIndex >= 0) {
          await Future.delayed(const Duration(milliseconds: 100));
          final scrolled = await _scrollToMessageByKey(messageId);
          if (scrolled) {
            _applyHighlight(messageId);
            return NavigationResult.success;
          }
          await _scrollToIndexEstimate(newIndex, scrollController, messages.length);
          _applyHighlight(messageId);
          return NavigationResult.success;
        }

        if (!hasMore) break;
      }
    }

    // Step 3: 加载更多后仍未找到，尝试通过 API 验证消息是否存在
    try {
      if (isGroup) {
        final response = await _dio.get(
          '/groups/$groupId/messages',
          queryParameters: {
            'before_id': messageId + 1,
            'limit': 1,
          },
        );

        if (response.data['success'] == true) {
          final dynamic rawData = response.data['data'];
          final dynamic messageData = rawData is Map ? rawData['messages'] : rawData;

          if (messageData is List && messageData.isNotEmpty) {
            // 检查返回的第一条消息是否就是目标
            final firstMsg = messageData[0] is Map<String, dynamic>
                ? messageData[0]
                : Map<String, dynamic>.from(messageData[0] as Map);
            final firstId = firstMsg['id'] as int? ?? 0;

            if (firstId == messageId) {
              // 消息存在但距离太远，提示用户
              if (firstMsg['recalled'] == true) {
                onShowToast?.call('原始消息已被撤回');
                return NavigationResult.messageDeleted;
              }
              onShowToast?.call('消息距离较远，请向上滚动查找');
              return NavigationResult.notFound;
            }
          }
          // 消息不存在
          onShowToast?.call('原始消息不存在或已被撤回');
          return NavigationResult.messageDeleted;
        }
      } else {
        final response = await _dio.get(
          '/messages/',
          queryParameters: {
            'friend_id': groupId,
            'before_id': messageId + 1,
            'limit': 1,
          },
        );

        if (response.data['success'] == true) {
          final dynamic rawData = response.data['data'];
          final dynamic messageData = rawData is Map ? (rawData['messages'] ?? rawData) : rawData;

          if (messageData is List && messageData.isNotEmpty) {
            final firstMsg = messageData[0] is Map<String, dynamic>
                ? messageData[0]
                : Map<String, dynamic>.from(messageData[0] as Map);
            final firstId = firstMsg['id'] as int? ?? 0;

            if (firstId == messageId) {
              if (firstMsg['recalled'] == true) {
                onShowToast?.call('原始消息已被撤回');
                return NavigationResult.messageDeleted;
              }
              onShowToast?.call('消息距离较远，请向上滚动查找');
              return NavigationResult.notFound;
            }
          }
          onShowToast?.call('原始消息不存在或已被撤回');
          return NavigationResult.messageDeleted;
        }
      }
    } catch (e) {
      debugPrint('[MessageNavigationHelper] verify message error: $e');
    }

    onShowToast?.call('原始消息不存在或已被撤回');
    return NavigationResult.messageDeleted;
  }

  /// 使用 GlobalKey 精确滚动到目标消息（居中显示）
  Future<bool> _scrollToMessageByKey(int messageId) async {
    final key = _messageKeys[messageId];
    if (key == null) return false;

    final context = key.currentContext;
    if (context == null) return false;

    await Scrollable.ensureVisible(
      context,
      alignment: 0.5, // 居中
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
    return true;
  }

  /// 在消息列表中查找目标消息的索引
  int _findMessageIndex(int messageId, List<Map<String, dynamic>> messages) {
    for (int i = 0; i < messages.length; i++) {
      final rawId = messages[i]['id'] ?? messages[i]['message_id'];
      final msgId = (rawId is num) ? rawId.toInt() : 0;
      if (msgId == messageId) return i;
    }
    return -1;
  }

  /// 估算滚动位置（fallback，当 GlobalKey 不可用时）
  /// 注意：ListView 使用 reverse: true，所以索引0在底部
  Future<void> _scrollToIndexEstimate(
    int index,
    ScrollController scrollController,
    int totalCount,
  ) async {
    if (!scrollController.hasClients) return;

    final estimatedOffset = index * 80.0;
    final viewportHeight = scrollController.position.viewportDimension;
    final centerOffset = (estimatedOffset - viewportHeight / 2 + 40).clamp(
      0.0,
      scrollController.position.maxScrollExtent,
    );

    await scrollController.animateTo(
      centerOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  /// 应用高亮动画（2秒渐隐）
  void _applyHighlight(int messageId) {
    highlightedMessageId.value = messageId;

    // 2秒后清除高亮
    Future.delayed(highlightDuration, () {
      if (highlightedMessageId.value == messageId) {
        highlightedMessageId.value = null;
      }
    });
  }

  /// 释放资源
  void dispose() {
    highlightedMessageId.dispose();
    _messageKeys.clear();
  }
}

/// 消息高亮动画组件
/// 包裹在消息气泡外层，当 messageId 匹配高亮ID时播放渐隐动画
///
/// Requirements: 6.1
class MessageHighlightWrapper extends StatefulWidget {
  final int messageId;
  final ValueNotifier<int?> highlightedMessageId;
  final Widget child;

  const MessageHighlightWrapper({
    super.key,
    required this.messageId,
    required this.highlightedMessageId,
    required this.child,
  });

  @override
  State<MessageHighlightWrapper> createState() =>
      _MessageHighlightWrapperState();
}

class _MessageHighlightWrapperState extends State<MessageHighlightWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _opacityAnimation;
  bool _isHighlighted = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: MessageNavigationHelper.highlightDuration,
    );
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    widget.highlightedMessageId.addListener(_onHighlightChanged);
    _checkHighlight();
  }

  @override
  void dispose() {
    widget.highlightedMessageId.removeListener(_onHighlightChanged);
    _animController.dispose();
    super.dispose();
  }

  void _onHighlightChanged() {
    _checkHighlight();
  }

  void _checkHighlight() {
    final shouldHighlight =
        widget.highlightedMessageId.value == widget.messageId;

    if (shouldHighlight && !_isHighlighted) {
      _isHighlighted = true;
      _animController.reset();
      _animController.forward().then((_) {
        if (mounted) {
          setState(() => _isHighlighted = false);
        }
      });
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isHighlighted) return widget.child;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        final alpha = (_opacityAnimation.value * (isDark ? 60 : 40)).round();
        return Container(
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(alpha),
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
