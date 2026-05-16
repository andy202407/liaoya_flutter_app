import 'package:dio/dio.dart';
import 'api_client.dart';

/// 文件上传 API
class FileApi {
  final Dio _dio = ApiClient.instance.dio;

  Future<Response> uploadFile(String filePath, {String? fileName}) {
    return _dio.post('/files/upload', data: FormData.fromMap({
      'file': MultipartFile.fromFileSync(filePath, filename: fileName),
    }));
  }

  Future<Response> uploadImage(String filePath, {String? fileName}) {
    return _dio.post('/files/upload', data: FormData.fromMap({
      'file': MultipartFile.fromFileSync(filePath, filename: fileName ?? 'image.jpg'),
    }));
  }
}
