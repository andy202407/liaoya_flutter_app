import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart' show getTemporaryDirectory;

/// 图片全屏预览页 - 带下载和分享
class ImagePreviewPage extends StatelessWidget {
  final String url;
  const ImagePreviewPage({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 48)),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomBar(url: url),
          ),
        ],
      ),
    );
  }
}

/// 视频播放页 - 带下载和分享
class VideoPreviewPage extends StatefulWidget {
  final String url;
  const VideoPreviewPage({super.key, required this.url});

  @override
  State<VideoPreviewPage> createState() => _VideoPreviewPageState();
}

class _VideoPreviewPageState extends State<VideoPreviewPage> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _showControls = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      httpHeaders: const {
        'Accept': '*/*',
        'Connection': 'keep-alive',
      },
    );

    try {
      await _controller.initialize();
      if (mounted) {
        setState(() => _initialized = true);
        _controller.play();
      }
    } catch (e) {
      debugPrint('[VideoPreview] Initialize error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = '视频加载失败，请检查网络或视频格式';
        });
      }
    }

    _controller.addListener(() {
      if (mounted) {
        // 检测播放错误
        if (_controller.value.hasError && !_hasError) {
          setState(() {
            _hasError = true;
            _errorMessage = _controller.value.errorDescription ?? '视频播放出错';
          });
        } else {
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          children: [
            Center(
              child: _hasError
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.white54, size: 48),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _hasError = false;
                              _initialized = false;
                            });
                            _controller.dispose();
                            _initializePlayer();
                          },
                          icon: const Icon(Icons.refresh, color: Colors.white70),
                          label: const Text('重试', style: TextStyle(color: Colors.white70)),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () async {
                            // 尝试用系统播放器打开
                            final uri = Uri.parse(widget.url);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: const Icon(Icons.open_in_new, color: Colors.white70),
                          label: const Text('用系统播放器打开', style: TextStyle(color: Colors.white70)),
                        ),
                      ],
                    )
                  : _initialized
                      ? AspectRatio(
                          aspectRatio: _controller.value.aspectRatio,
                          child: VideoPlayer(_controller),
                        )
                      : const CircularProgressIndicator(color: Colors.white),
            ),
            if (_showControls)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            if (_showControls && _initialized && !_hasError)
              Center(
                child: GestureDetector(
                  onTap: () => _controller.value.isPlaying ? _controller.pause() : _controller.play(),
                  child: Container(
                    width: 60, height: 60,
                    decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                    child: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 36),
                  ),
                ),
              ),
            if (_showControls && !_hasError)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_initialized)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text(_formatDuration(_controller.value.position), style: const TextStyle(color: Colors.white, fontSize: 12)),
                            Expanded(
                              child: Slider(
                                value: _controller.value.duration.inMilliseconds > 0
                                    ? _controller.value.position.inMilliseconds / _controller.value.duration.inMilliseconds
                                    : 0,
                                onChanged: (v) => _controller.seekTo(Duration(milliseconds: (v * _controller.value.duration.inMilliseconds).toInt())),
                                activeColor: Colors.white,
                                inactiveColor: Colors.white24,
                              ),
                            ),
                            Text(_formatDuration(_controller.value.duration), style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                    _BottomBar(url: widget.url),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 底部操作栏
class _BottomBar extends StatelessWidget {
  final String url;
  const _BottomBar({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(0, 12, 0, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black54]),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(icon: Icons.download_rounded, label: '下载', onTap: () => _download(context)),
          _ActionButton(icon: Icons.copy_rounded, label: '复制链接', onTap: () => _copyLink(context)),
          _ActionButton(icon: Icons.share_rounded, label: '分享', onTap: () => _share(context)),
        ],
      ),
    );
  }

  void _download(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在保存...'), duration: Duration(seconds: 1)));
      // 下载文件到临时目录
      final dio = Dio();
      final tempDir = await getTemporaryDirectory();
      final ext = url.contains('.mp4') || url.contains('.mov') ? '.mp4' : '.jpg';
      final filePath = '${tempDir.path}/download_${DateTime.now().millisecondsSinceEpoch}$ext';
      await dio.download(url, filePath);
      // 保存到相册
      if (ext == '.mp4') {
        await Gal.putVideo(filePath);
      } else {
        await Gal.putImage(filePath);
      }
      // 清理临时文件
      try { File(filePath).deleteSync(); } catch (_) {}
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存到相册'), duration: Duration(seconds: 2)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e'), duration: const Duration(seconds: 2)));
      }
    }
  }

  void _copyLink(BuildContext context) async {
    // 尝试用浏览器打开，打不开才复制链接
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Clipboard.setData(ClipboardData(text: url));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('链接已复制'), duration: Duration(seconds: 1)));
      }
    }
  }

  void _share(BuildContext context) {
    Share.share(url);
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}
