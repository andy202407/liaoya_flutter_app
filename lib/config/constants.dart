class AppConstants {
  static const String appName = '洽聊';
  // iOS 逻辑版本号：因为 TestFlight 不能随意改版本号（只能 build number +1），
  // 所以 iOS 用这个硬编码的版本号做更新检测，和 pubspec.yaml 的 version 解耦。
  // 每次发布新功能时手动更新此值，保持和 Android 功能版本一致。
  static const String iosLogicalVersion = '2.0.3';

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
