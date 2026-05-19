import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  // 开发环境（使用公网地址，方便手机真机调试）
  static const String devBaseUrl = 'https://aapi.ql52.com';
  static const String devWsUrl = 'wss://aapi.ql52.com';

  // 生产环境
  static const String prodBaseUrl = 'https://aapi.ql52.com';
  static const String prodWsUrl = 'wss://aapi.ql52.com';

  // 当前使用的环境（开发和生产都指向公网，打包时无需切换）
  static const bool isProduction = true;

  // Web 端用相对路径（nginx 代理），App 端用完整域名直连
  static String get baseUrl {
    if (kIsWeb) return '';  // Web: 相对路径，由 nginx 代理
    return isProduction ? prodBaseUrl : devBaseUrl;
  }

  static String get wsUrl {
    if (kIsWeb) return '';  // Web: 由浏览器自动拼接当前域名
    return isProduction ? prodWsUrl : devWsUrl;
  }

  static String get apiUrl => '$baseUrl/api/v1';

  static String get wsEndpoint {
    if (kIsWeb) {
      // Web: 需要完整的 wss:// URL，浏览器会根据当前页面协议自动选择
      // 使用 Uri.base 获取当前页面的 host
      final uri = Uri.base;
      final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
      return '$scheme://${uri.host}${uri.port != 80 && uri.port != 443 ? ':${uri.port}' : ''}/ws';
    }
    return '$wsUrl/ws';
  }
}
