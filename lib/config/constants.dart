class AppConstants {
  static const String appName = '洽聊';
  // static const String appVersion = '2.0.1'; // 仅供参考，实际版本以 pubspec.yaml 的 version 字段为准

  // Storage keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'auth_user';
  static const String themeKey = 'app_theme';

  // WebSocket
  static const int wsReconnectDelay = 3; // seconds
  static const int wsMaxReconnectAttempts = 10;
  static const int wsPingInterval = 30; // seconds

  // Pagination
  static const int pageSize = 20;
  static const int messageFetchLimit = 50;
}
