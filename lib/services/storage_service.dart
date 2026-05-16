import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';

class StorageService {
  static StorageService? _instance;
  late SharedPreferences _prefs;

  StorageService._();

  static Future<StorageService> getInstance() async {
    if (_instance == null) {
      _instance = StorageService._();
      _instance!._prefs = await SharedPreferences.getInstance();
    }
    return _instance!;
  }

  // Token
  Future<void> setToken(String token) async {
    await _prefs.setString(AppConstants.tokenKey, token);
  }

  String? getToken() {
    return _prefs.getString(AppConstants.tokenKey);
  }

  Future<void> removeToken() async {
    await _prefs.remove(AppConstants.tokenKey);
  }

  // User
  Future<void> setUser(Map<String, dynamic> user) async {
    await _prefs.setString(AppConstants.userKey, jsonEncode(user));
  }

  Map<String, dynamic>? getUser() {
    final str = _prefs.getString(AppConstants.userKey);
    if (str == null) return null;
    return jsonDecode(str) as Map<String, dynamic>;
  }

  Future<void> removeUser() async {
    await _prefs.remove(AppConstants.userKey);
  }

  // Credentials (remember me)
  Future<void> saveCredentials(String username, String password) async {
    await _prefs.setString('saved_username', username);
    await _prefs.setString('saved_password', password);
  }

  Map<String, String>? getSavedCredentials() {
    final username = _prefs.getString('saved_username');
    final password = _prefs.getString('saved_password');
    if (username != null && password != null) {
      return {'username': username, 'password': password};
    }
    return null;
  }

  Future<void> clearCredentials() async {
    await _prefs.remove('saved_username');
    await _prefs.remove('saved_password');
  }

  // Clear all
  Future<void> clearAll() async {
    // 保留记住的凭据
    final creds = getSavedCredentials();
    await _prefs.clear();
    if (creds != null) {
      await saveCredentials(creds['username']!, creds['password']!);
    }
  }
}
