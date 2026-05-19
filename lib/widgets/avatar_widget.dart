import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/api_config.dart';
import '../theme/app_colors.dart';

/// 头像组件 - 支持网络图片、占位符、在线状态指示器、头像框
class AvatarWidget extends StatelessWidget {
  final String? url;
  final String name;
  final double size;
  final bool isGroup;
  final bool showOnline;
  final bool isOnline;
  final String? avatarFrame;

  const AvatarWidget({
    super.key,
    this.url,
    required this.name,
    this.size = 44,
    this.isGroup = false,
    this.showOnline = false,
    this.isOnline = false,
    this.avatarFrame,
  });

  bool get _hasFrame => avatarFrame != null && avatarFrame!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    Widget avatar = _buildAvatar(context);

    // 如果有头像框，叠加头像框（溢出显示，不影响布局占位）
    if (_hasFrame) {
      avatar = _buildWithFrame(context, avatar);
    }

    if (!showOnline) return avatar;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: isOnline ? AppColors.online : AppColors.offline,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建头像
  Widget _buildAvatar(BuildContext context) {
    String? fullUrl = url;
    if (fullUrl != null && fullUrl.isNotEmpty && !fullUrl.startsWith('http')) {
      fullUrl = '${ApiConfig.baseUrl}$fullUrl';
    }

    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    // SVG 格式不支持解码，直接用占位符
    if (fullUrl != null && fullUrl.isNotEmpty && !fullUrl.toLowerCase().endsWith('.svg')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: fullUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: (_, __) => _buildPlaceholder(),
            errorWidget: (_, __, ___) => _buildPlaceholder(),
          ),
        ),
      );
    }
    return _buildPlaceholder();
  }

  /// 解析头像框URL和缩放比例，支持 url#scale=1.6 格式
  ({String url, double scale}) _parseFrame() {
    final frame = avatarFrame!;
    final hashIdx = frame.indexOf('#scale=');
    if (hashIdx != -1) {
      final frameUrl = frame.substring(0, hashIdx);
      final scale = double.tryParse(frame.substring(hashIdx + 7)) ?? 1.4;
      return (url: frameUrl, scale: scale);
    }
    return (url: frame, scale: 1.4);
  }

  /// 头像框：布局占位=size，头像=size，头像框居中溢出(size*scale)
  Widget _buildWithFrame(BuildContext context, Widget avatarChild) {
    final parsed = _parseFrame();
    String frameUrl = parsed.url;
    final scale = parsed.scale;

    if (frameUrl.isNotEmpty && !frameUrl.startsWith('http')) {
      frameUrl = '${ApiConfig.baseUrl}$frameUrl';
    }

    final frameSize = size * scale;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // 头像保持原始 size
          avatarChild,
          // 头像框居中溢出显示
          Positioned(
            top: -(frameSize - size) / 2,
            left: -(frameSize - size) / 2,
            width: frameSize,
            height: frameSize,
            child: IgnorePointer(
              child: CachedNetworkImage(
                imageUrl: frameUrl,
                width: frameSize,
                height: frameSize,
                fit: BoxFit.contain,
                placeholder: (_, __) => const SizedBox.shrink(),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    final colors = [
      const Color(0xFF007AFF), // iOS Blue
      const Color(0xFFFF3B30), // iOS Red
      const Color(0xFF34C759), // iOS Green
      const Color(0xFFFF9500), // iOS Orange
      const Color(0xFF5856D6), // iOS Purple
      const Color(0xFFAF52DE), // iOS Violet
      const Color(0xFF5AC8FA), // iOS Teal
      const Color(0xFFFF2D55), // iOS Pink
    ];
    final colorIndex = name.codeUnits.fold<int>(0, (prev, c) => prev + c) % colors.length;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors[colorIndex], colors[colorIndex].withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: isGroup
            ? Icon(Icons.group_rounded, color: Colors.white, size: size * 0.45)
            : Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
