class ApiConfig {
  // 开发环境（使用公网地址，方便手机真机调试）
  static const String devBaseUrl = 'http://192.168.0.83:3001';
  static const String devWsUrl = 'ws://192.168.0.83:3001';

  // 生产环境
  static const String prodBaseUrl = 'http://192.168.0.83:3001';
  static const String prodWsUrl = 'ws://192.168.0.83:3001';

  // 当前使用的环境（开发和生产都指向公网，打包时无需切换）
  static const bool isProduction = true;

  static String get baseUrl => isProduction ? prodBaseUrl : devBaseUrl;
  static String get wsUrl => isProduction ? prodWsUrl : devWsUrl;
  static String get apiUrl => '$baseUrl/api/v1';
  static String get wsEndpoint => '$wsUrl/ws';
}