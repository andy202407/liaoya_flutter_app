import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'storage_service.dart';

class ApiService {
  static ApiService? _instance;
  late Dio _dio;
  StorageService? _storage;

  ApiService._() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.apiUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'LiaoyaFlutterApp/1.0',
        'X-App-Client': 'LiaoyaFlutterApp',
        'X-App-Secret': 'ly_f8k2m9x4p7q1w3',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        _storage ??= await StorageService.getInstance();
        final token = _storage!.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          // Token expired, handle logout
        }
        return handler.next(error);
      },
    ));
  }

  static ApiService get instance {
    _instance ??= ApiService._();
    return _instance!;
  }

  Dio get dio => _dio;

  // Auth
  Future<Response> login(String username, String password, {
    String? captchaTicket,
    String? captchaRandstr,
    String? simpleCaptchaId,
    String? simpleCaptchaAnswer,
  }) {
    final data = <String, dynamic>{
      'username': username,
      'password': password,
      'device_fingerprint': 'flutter_app_${DateTime.now().millisecondsSinceEpoch}',
    };
    if (captchaTicket != null) data['captcha_ticket'] = captchaTicket;
    if (captchaRandstr != null) data['captcha_randstr'] = captchaRandstr;
    if (simpleCaptchaId != null) data['simple_captcha_id'] = simpleCaptchaId;
    if (simpleCaptchaAnswer != null) data['simple_captcha_answer'] = simpleCaptchaAnswer;
    return _dio.post('/auth/login', data: data);
  }

  Future<Response> register(Map<String, dynamic> data) {
    data['device_fingerprint'] = 'flutter_app_${DateTime.now().millisecondsSinceEpoch}';
    return _dio.post('/auth/register', data: data);
  }

  // Captcha status
  Future<Response> getCaptchaStatus() {
    return _dio.get('/captcha-status', queryParameters: {'type': 'frontend'});
  }

  // IP check (for login)
  Future<Response> checkIp(String username) {
    return _dio.get('/ip-check', queryParameters: {'username': username});
  }

  // User
  Future<Response> getProfile() => _dio.get('/user/profile');
  Future<Response> updateNickname(String nickname) =>
      _dio.put('/user/nickname', data: {'nickname': nickname});
  Future<Response> updateAvatar(String avatarUrl) =>
      _dio.post('/user/avatar', data: {'avatar': avatarUrl});

  // Conversations
  Future<Response> getConversations({int limit = 20, int? beforeId, String filterType = 'all'}) {
    final params = <String, dynamic>{'limit': limit, 'filterType': filterType};
    if (beforeId != null) params['before_id'] = beforeId;
    return _dio.get('/conversations/', queryParameters: params);
  }

  // Friends
  Future<Response> getFriends({int limit = 50}) =>
      _dio.get('/friends/', queryParameters: {'limit': limit});
  Future<Response> searchUsers(String keyword) =>
      _dio.get('/friends/search', queryParameters: {'keyword': keyword});
  Future<Response> sendFriendRequest(int toUserId, String message) =>
      _dio.post('/friends/request', data: {'to_user_id': toUserId, 'message': message});
  Future<Response> getFriendRequests() => _dio.get('/friends/requests');
  Future<Response> handleFriendRequest(int requestId, String status) =>
      _dio.put('/friends/request/$requestId', data: {'status': status});

  // Messages (private)
  Future<Response> getMessages(int friendId, {int limit = 50, int? beforeId}) {
    final params = <String, dynamic>{'limit': limit};
    if (beforeId != null) params['before_id'] = beforeId;
    return _dio.get('/messages/$friendId', queryParameters: params);
  }

  Future<Response> sendMessage(int friendId, String content, {String type = 'text'}) {
    return _dio.post('/messages/$friendId', data: {
      'content': content,
      'type': type,
    });
  }

  // Groups
  Future<Response> getGroups() => _dio.get('/groups/');
  Future<Response> getGroupInfo(int groupId) => _dio.get('/groups/$groupId');
  Future<Response> getGroupMessages(int groupId, {int limit = 50, int? beforeId}) {
    final params = <String, dynamic>{'limit': limit};
    if (beforeId != null) params['before_id'] = beforeId;
    return _dio.get('/groups/$groupId/messages', queryParameters: params);
  }
  Future<Response> sendGroupMessage(int groupId, String content, {String type = 'message'}) {
    return _dio.post('/groups/$groupId/messages', data: FormData.fromMap({
      'content': content,
      'type': type,
    }));
  }

  // File upload
  Future<Response> uploadFile(String filePath, {String? fileName}) {
    return _dio.post('/files/upload', data: FormData.fromMap({
      'file': MultipartFile.fromFileSync(filePath, filename: fileName),
    }));
  }
}
