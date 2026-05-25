import 'package:flutter/material.dart';
import '../services/api/api_client.dart';
import '../services/websocket_service.dart';
import '../pages/discover/live_stream_list_page.dart';
import 'dart:async';

class LiveStreamWidget extends StatefulWidget {
  const LiveStreamWidget({super.key});

  @override
  State<LiveStreamWidget> createState() => _LiveStreamWidgetState();
}

class _LiveStreamWidgetState extends State<LiveStreamWidget> {
  bool _visible = false;
  int _liveCount = 0;
  Offset _position = const Offset(-1, -1);
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _loadLiveCount();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadLiveCount());
    WebSocketService.instance.on('live_stream_update', _onUpdate);
    // 恢复保存的位置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restorePosition();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WebSocketService.instance.off('live_stream_update', _onUpdate);
    super.dispose();
  }

  void _onUpdate(Map<String, dynamic> msg) {
    _loadLiveCount();
  }

  Future<void> _loadConfig() async {
    try {
      final res = await ApiClient.instance.dio.get('/live-stream-config');
      if (res.data['success'] == true) {
        setState(() {
          _visible = res.data['data']?['widget_enabled'] != false;
        });
      }
    } catch (_) {
      setState(() => _visible = true);
    }
  }

  Future<void> _loadLiveCount() async {
    try {
      final res = await ApiClient.instance.dio.get('/user/live-streams');
      if (res.data['success'] == true) {
        final List<dynamic> data = res.data['data'] ?? [];
        final count = data.where((s) => s['status'] == 1).length;
        if (mounted) setState(() => _liveCount = count);
      }
    } catch (_) {}
  }

  void _restorePosition() {
    // 默认右下角
    final size = MediaQuery.of(context).size;
    setState(() {
      _position = Offset(size.width - 70, size.height - 200);
    });
  }

  void _savePosition() {
    // 位置记忆（简单存内存，重启后恢复默认）
  }

  void _openLiveList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LiveStreamListPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible || _position.dx < 0) return const SizedBox.shrink();

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            final size = MediaQuery.of(context).size;
            _position = Offset(
              (_position.dx + details.delta.dx).clamp(0, size.width - 52),
              (_position.dy + details.delta.dy).clamp(0, size.height - 52),
            );
          });
        },
        onPanEnd: (_) => _savePosition(),
        onTap: _openLiveList,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: _liveCount > 0
                ? const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFF97316)])
                : const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
            boxShadow: [
              BoxShadow(
                color: (_liveCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF6366F1)).withAlpha(100),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.live_tv_rounded, color: Colors.white, size: 14),
              const SizedBox(width: 3),
              const Text('直播', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, decoration: TextDecoration.none, height: 1)),
              if (_liveCount > 0) ...[
                const SizedBox(width: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(60),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$_liveCount',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700, decoration: TextDecoration.none, height: 1),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
