class ApiConfig {
  // 开发环境（本地后端）
  static const String devBaseUrl = 'http://192.168.0.83:5000';
  static const String devWsUrl = 'ws://192.168.0.83:5000';

  // 生产环境
  static const String prodBaseUrl = 'https://chat.ql52.com';
  static const String prodWsUrl = 'wss://chat.ql52.com';

  // 当前使用的环境
  static const bool isProduction = true;

  static String get baseUrl => isProduction ? prodBaseUrl : devBaseUrl;
  static String get wsUrl => isProduction ? prodWsUrl : devWsUrl;
  static String get apiUrl => '$baseUrl/api/v1';
  static String get wsEndpoint => '$wsUrl/ws';
}
