import 'package:audioplayers/audioplayers.dart';

/// 消息提示音服务
class NotificationSound {
  static final NotificationSound _instance = NotificationSound._();
  static NotificationSound get instance => _instance;

  final AudioPlayer _player = AudioPlayer();
  DateTime? _lastPlayTime;

  NotificationSound._() {
    _player.setVolume(0.5);
  }

  /// 播放提示音（节流：500ms 内不重复播放）
  Future<void> play() async {
    final now = DateTime.now();
    if (_lastPlayTime != null && now.difference(_lastPlayTime!).inMilliseconds < 500) {
      return; // 节流
    }
    _lastPlayTime = now;

    try {
      // 使用系统默认的短提示音（data URI 方式，兼容 Web）
      await _player.play(UrlSource(
        'data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQoGAACBhYqFbF1fdH2LkZeYl5OQi4V/eXR0eH+Fio6QkpGPjImFgX15d3h7gIWJjI6PjoyKh4N/e3l5e3+DiIuNjo6NjIqHhIB9e3t8f4OHiouMjIuKiIWCf3x7fH6BhYiKi4uKiYeFgn98fHx+gYSHiYqKiYiGhIJ/fXx8foGEh4mKiomIhoSBf3x8fH6BhIeJioqJiIaEgX98fHx+gYSHiYqKiYiGhIB9fHx8foGEh4mKiomIhoSBf3x8fH6BhIeJioqJiIaEgX98fHx+gYSHiYqKiYiGhIB9fHx8foGEh4mKiomIhoSBf3x8fH6BhIeJioqJiIaEgX98fHx+gYSHiYqKiYiGhIB9fHx8foGEh4mKiomIhoSBf3x8fH6BhIeJioqJiIaEgX98fHx+gQ=='
      ));
    } catch (_) {
      // 静默失败
    }
  }

  void dispose() {
    _player.dispose();
  }
}
