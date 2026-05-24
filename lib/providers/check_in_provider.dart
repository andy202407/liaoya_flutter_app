import 'package:flutter/material.dart';
import '../services/api/api_client.dart';

/// 签到状态 Provider
/// 管理今日是否已签到的状态，用于红点提示
class CheckInProvider extends ChangeNotifier {
  bool _todayChecked = false;
  bool _initialized = false;

  bool get todayChecked => _todayChecked;
  bool get initialized => _initialized;

  /// 是否显示红点（已初始化且今天未签到）
  bool get showBadge => _initialized && !_todayChecked;

  /// 初始化（App启动时调用一次）
  Future<void> init() async {
    if (_initialized) return;
    await fetchStatus();
  }

  /// 从 API 获取签到状态
  Future<void> fetchStatus() async {
    try {
      final res = await ApiClient.instance.dio.get('/user/check-in/stats');
      if (res.data['success'] == true) {
        final data = res.data['data'] as Map<String, dynamic>?;
        _todayChecked = data?['today_checked'] == true;
        _initialized = true;
        notifyListeners();
      }
    } catch (_) {
      // 静默失败，不影响主流程
    }
  }

  /// 签到成功后调用
  void markCheckedIn() {
    _todayChecked = true;
    notifyListeners();
  }
}
