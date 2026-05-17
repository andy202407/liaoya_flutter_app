import 'package:flutter/material.dart';
import '../services/api/api_client.dart';

class FriendProvider extends ChangeNotifier {
  final _dio = ApiClient.instance.dio;

  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _friendRequests = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get friends => _friends;
  List<Map<String, dynamic>> get groups => _groups;
  List<Map<String, dynamic>> get friendRequests => _friendRequests;
  bool get isLoading => _isLoading;
  int get pendingRequestCount => _friendRequests.where((r) => r['status'] == 'pending').length;

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();
    await Future.wait([loadFriends(), loadGroups(), loadFriendRequests()]);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadFriends() async {
    try {
      final response = await _dio.get('/friends/', queryParameters: {'limit': 200});
      if (response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        _friends = data.cast<Map<String, dynamic>>();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[FriendProvider] loadFriends error: $e');
    }
  }

  Future<void> loadGroups() async {
    try {
      final response = await _dio.get('/groups/');
      if (response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        _groups = data.cast<Map<String, dynamic>>();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[FriendProvider] loadGroups error: $e');
    }
  }

  Future<void> loadFriendRequests() async {
    try {
      final response = await _dio.get('/friends/requests', queryParameters: {'limit': 50});
      if (response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        _friendRequests = data.cast<Map<String, dynamic>>();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[FriendProvider] loadFriendRequests error: $e');
    }
  }

  Future<bool> acceptRequest(int requestId) async {
    try {
      final response = await _dio.put('/friends/request/$requestId', data: {'status': 'accepted'});
      if (response.data['success'] == true) {
        await loadFriendRequests();
        await loadFriends();
        return true;
      }
    } catch (e) {
      debugPrint('[FriendProvider] acceptRequest error: $e');
    }
    return false;
  }

  Future<bool> rejectRequest(int requestId) async {
    try {
      final response = await _dio.put('/friends/request/$requestId', data: {'status': 'rejected'});
      if (response.data['success'] == true) {
        await loadFriendRequests();
        return true;
      }
    } catch (e) {
      debugPrint('[FriendProvider] rejectRequest error: $e');
    }
    return false;
  }

  Future<bool> sendFriendRequest(int userId, String message) async {
    try {
      final response = await _dio.post('/friends/request', data: {'to_user_id': userId, 'message': message});
      // 后端可能返回 success:true 或直接添加成功（不同场景返回不同消息）
      return response.data['success'] == true || response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('[FriendProvider] sendRequest error: $e');
    }
    return false;
  }

  /// 通过用户名发送好友请求
  Future<bool> sendFriendRequestByUsername(String username, String message) async {
    try {
      final response = await _dio.post('/friends/request/by-username', data: {'username': username, 'message': message});
      return response.data['success'] == true;
    } catch (e) {
      debugPrint('[FriendProvider] sendRequestByUsername error: $e');
      rethrow;
    }
  }

  /// 搜索用户
  Future<List<Map<String, dynamic>>> searchUsers(String keyword) async {
    try {
      final response = await _dio.get('/friends/search', queryParameters: {'keyword': keyword});
      if (response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('[FriendProvider] searchUsers error: $e');
    }
    return [];
  }
}
