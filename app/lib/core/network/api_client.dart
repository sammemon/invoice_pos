import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class ApiClient {
  static ApiClient? _instance;
  late Dio _dio;
  final _storage = const FlutterSecureStorage();

  ApiClient._() {
    _dio = _buildDio(AppConstants.baseUrl);
  }

  static ApiClient get instance => _instance ??= ApiClient._();

  Dio _buildDio(String baseUrl) {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: AppConstants.tokenKey);
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (error, handler) => handler.next(error),
    ));
    return dio;
  }

  /// Call this after the user saves a new server URL in settings.
  Future<void> updateBaseUrl(String newUrl) async {
    await _storage.write(key: AppConstants.serverUrlKey, value: newUrl);
    _dio = _buildDio(newUrl);
  }

  /// Load persisted server URL (falls back to compile-time default).
  static Future<void> init() async {
    const storage = FlutterSecureStorage();
    final saved = await storage.read(key: AppConstants.serverUrlKey);
    if (saved != null && saved.isNotEmpty) {
      instance._dio = instance._buildDio(saved);
    }
  }

  Future<Response> get(String path, {Map<String, dynamic>? params}) =>
      _dio.get(path, queryParameters: params);
  Future<Response> post(String path, {dynamic data}) =>
      _dio.post(path, data: data);
  Future<Response> put(String path, {dynamic data}) =>
      _dio.put(path, data: data);
  Future<Response> delete(String path) => _dio.delete(path);
  Future<Response> patch(String path, {dynamic data}) =>
      _dio.patch(path, data: data);

  String get currentBaseUrl => _dio.options.baseUrl;
}
