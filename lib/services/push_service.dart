import 'package:flutter/foundation.dart';
import 'package:jpush_flutter/jpush_flutter.dart';
import 'package:dio/dio.dart';
import '../config/api_config.dart';

/// JPush 推送服务（Android）
class PushService {
  static final JPush _jpush = JPush();
  static String? _registrationId;
  static String? _authToken;

  static String? get registrationId => _registrationId;

  /// 初始化 JPush
  static Future<void> init() async {
    if (kIsWeb) return;

    _jpush.setup(
      appKey: '3d906a6c5cea9851c961db1d',
      channel: 'developer-default',
      production: true,
      debug: !kReleaseMode,
    );

    _jpush.getRegistrationID().then((rid) {
      if (rid.isNotEmpty) {
        _registrationId = rid;
        debugPrint('[JPush] Registration ID: $rid');
        _tryRegisterToken();
      } else {
        // SDK 可能还没注册完成，延迟重试
        Future.delayed(const Duration(seconds: 3), () {
          _jpush.getRegistrationID().then((rid2) {
            if (rid2.isNotEmpty) {
              _registrationId = rid2;
              debugPrint('[JPush] Registration ID (delayed): $rid2');
              _tryRegisterToken();
            } else {
              debugPrint('[JPush] Registration ID still empty after retry');
            }
          });
        });
      }
    });

    _jpush.addEventHandler(
      onReceiveNotification: (message) async {
        debugPrint('[JPush] 收到通知: $message');
      },
      onOpenNotification: (message) async {
        debugPrint('[JPush] 点击通知: $message');
      },
      onReceiveMessage: (message) async {
        debugPrint('[JPush] 自定义消息: $message');
      },
    );

    _jpush.applyPushAuthority(
      const NotificationSettingsIOS(sound: true, alert: true, badge: true),
    );
  }

  /// 登录后设置 token 并上报 registrationId
  static void setAuthToken(String token) {
    _authToken = token;
    _tryRegisterToken();
  }

  /// 尝试向后端注册推送 token
  static Future<void> _tryRegisterToken() async {
    if (_registrationId == null || _authToken == null) return;

    final deviceType = defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios';

    try {
      final dio = Dio();
      final response = await dio.post(
        '${ApiConfig.apiUrl}/user/tpns/register',
        options: Options(headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        }),
        data: {'token': _registrationId, 'device_type': deviceType},
      );
      if (response.statusCode == 200) {
        debugPrint('[JPush] $deviceType token 注册成功');
      } else {
        debugPrint('[JPush] $deviceType token 注册失败: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[JPush] token 注册异常: $e');
    }
  }

  /// 登出时注销推送 token
  static Future<void> unregister() async {
    if (_authToken == null) return;
    final deviceType = defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios';
    try {
      final dio = Dio();
      await dio.post(
        '${ApiConfig.apiUrl}/user/tpns/unregister',
        options: Options(headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        }),
        data: {'device_type': deviceType},
      );
      debugPrint('[JPush] token 注销成功');
    } catch (_) {}
    _authToken = null;
  }

  /// 清除角标
  static void clearBadge() {
    _jpush.setBadge(0);
  }
}
