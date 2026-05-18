import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:jpush_flutter/jpush_flutter.dart';
import 'package:dio/dio.dart';
import '../config/api_config.dart';

/// 推送服务
/// - Android: 使用 JPush，token 上报到 /user/tpns/register
/// - iOS: 获取 APNs device token，上报到 /user/apns/register
class PushService {
  static final JPush _jpush = JPush();
  static String? _registrationId;
  static String? _apnsDeviceToken;
  static String? _authToken;

  static String? get registrationId => _registrationId;

  /// 初始化推送
  static Future<void> init() async {
    if (kIsWeb) return;

    _jpush.setup(
      appKey: '3d906a6c5cea9851c961db1d',
      channel: 'developer-default',
      production: true,
      debug: !kReleaseMode,
    );

    // Android: 获取 JPush Registration ID
    if (defaultTargetPlatform == TargetPlatform.android) {
      _jpush.getRegistrationID().then((rid) {
        if (rid.isNotEmpty) {
          _registrationId = rid;
          debugPrint('[Push] Android Registration ID: $rid');
          _tryRegisterAndroid();
        } else {
          Future.delayed(const Duration(seconds: 3), () {
            _jpush.getRegistrationID().then((rid2) {
              if (rid2.isNotEmpty) {
                _registrationId = rid2;
                debugPrint('[Push] Android Registration ID (delayed): $rid2');
                _tryRegisterAndroid();
              }
            });
          });
        }
      });
    }

    // iOS: 通过 JPush 获取 APNs device token
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _jpush.applyPushAuthority(
        const NotificationSettingsIOS(sound: true, alert: true, badge: true),
      );

      // JPush 会自动注册 APNs，通过 platform channel 获取 device token
      // 延迟获取，等 APNs 注册完成
      Future.delayed(const Duration(seconds: 2), () {
        _getAPNsToken();
      });
    }

    _jpush.addEventHandler(
      onReceiveNotification: (message) async {
        debugPrint('[Push] 收到通知: $message');
      },
      onOpenNotification: (message) async {
        debugPrint('[Push] 点击通知: $message');
      },
      onReceiveMessage: (message) async {
        debugPrint('[Push] 自定义消息: $message');
      },
    );
  }

  /// iOS: 获取 APNs device token
  static Future<void> _getAPNsToken() async {
    try {
      // jpush_flutter 内部会注册 APNs，通过 getLaunchAppNotification 或直接获取
      // 使用 MethodChannel 获取原生 APNs token
      const channel = MethodChannel('com.qialiao.app/apns');
      final token = await channel.invokeMethod<String>('getDeviceToken');
      if (token != null && token.isNotEmpty) {
        _apnsDeviceToken = token;
        debugPrint('[Push] iOS APNs device token: ${token.substring(0, 20)}...');
        _tryRegisterIOS();
      } else {
        debugPrint('[Push] iOS APNs device token 为空，5秒后重试');
        Future.delayed(const Duration(seconds: 5), () => _getAPNsToken());
      }
    } catch (e) {
      debugPrint('[Push] 获取 APNs token 异常: $e');
      // fallback: 用 JPush registration ID 注册到 tpns
      _jpush.getRegistrationID().then((rid) {
        if (rid.isNotEmpty) {
          _registrationId = rid;
          _tryRegisterIOSFallback();
        }
      });
    }
  }

  /// 登录后设置 auth token
  static void setAuthToken(String token) {
    _authToken = token;
    if (defaultTargetPlatform == TargetPlatform.android) {
      _tryRegisterAndroid();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (_apnsDeviceToken != null) {
        _tryRegisterIOS();
      } else {
        _tryRegisterIOSFallback();
      }
    }
  }

  /// Android: 上报 JPush registration ID
  static Future<void> _tryRegisterAndroid() async {
    if (_registrationId == null || _authToken == null) return;
    try {
      final dio = Dio();
      final response = await dio.post(
        '${ApiConfig.apiUrl}/user/tpns/register',
        options: Options(headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        }),
        data: {'token': _registrationId, 'device_type': 'android'},
      );
      if (response.statusCode == 200) {
        debugPrint('[Push] Android token 注册成功');
      }
    } catch (e) {
      debugPrint('[Push] Android token 注册异常: $e');
    }
  }

  /// iOS: 上报 APNs device token 到原生 APNs 接口
  static Future<void> _tryRegisterIOS() async {
    if (_apnsDeviceToken == null || _authToken == null) return;
    try {
      final dio = Dio();
      final response = await dio.post(
        '${ApiConfig.apiUrl}/user/apns/register',
        options: Options(headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        }),
        data: {'token': _apnsDeviceToken},
      );
      if (response.statusCode == 200) {
        debugPrint('[Push] iOS APNs token 注册成功');
      } else {
        debugPrint('[Push] iOS APNs token 注册失败: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[Push] iOS APNs token 注册异常: $e');
    }
  }

  /// iOS fallback: 用 JPush registration ID 注册到 tpns
  static Future<void> _tryRegisterIOSFallback() async {
    if (_registrationId == null || _authToken == null) return;
    try {
      final dio = Dio();
      await dio.post(
        '${ApiConfig.apiUrl}/user/tpns/register',
        options: Options(headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        }),
        data: {'token': _registrationId, 'device_type': 'ios'},
      );
      debugPrint('[Push] iOS fallback (JPush) token 注册成功');
    } catch (e) {
      debugPrint('[Push] iOS fallback token 注册异常: $e');
    }
  }

  /// 登出时注销推送 token
  static Future<void> unregister() async {
    if (_authToken == null) return;
    try {
      final dio = Dio();
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await dio.post(
          '${ApiConfig.apiUrl}/user/apns/unregister',
          options: Options(headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_authToken',
          }),
        );
      } else {
        await dio.post(
          '${ApiConfig.apiUrl}/user/tpns/unregister',
          options: Options(headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_authToken',
          }),
          data: {'device_type': 'android'},
        );
      }
      debugPrint('[Push] token 注销成功');
    } catch (_) {}
    _authToken = null;
  }

  /// 清除角标
  static void clearBadge() {
    _jpush.setBadge(0);
  }
}
