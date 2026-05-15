import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import 'dart:math';

class ApiService {
  late Dio _dio;
  bool _isInitialized = false;

  ApiService();

  Future<void> init() async {
    if (_isInitialized) return;

    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(AppConstants.tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
          print(
              ' Token added: ${token.substring(0, min(20, token.length))}');
        } else {
          print(' No token found');
        }
        print('${options.method} ${options.path}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        print(
            ' Response: ${response.statusCode} for ${response.requestOptions.path}');
        return handler.next(response);
      },
      onError: (error, handler) async {
        print(' Error: ${error.message}');
        if (error.response?.statusCode == 401) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(AppConstants.tokenKey);
          await prefs.remove(AppConstants.userDataKey);
          print('token removed due to 401');
        }
        return handler.next(error);
      },
    ));

    _isInitialized = true;
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await init();
    }
  }

  Future<Response> post(String endpoint, dynamic data) async {
    await _ensureInitialized();
    try {
      return await _dio.post(endpoint, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> postMultipart(String endpoint, FormData data) async {
    await _ensureInitialized();
    try {
      final response = await _dio.post(
        endpoint,
        data: data,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> putMultipart(String endpoint, FormData data) async {
    await _ensureInitialized();
    try {
      final response = await _dio.put(
        endpoint,
        data: data,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> get(String endpoint) async {
    await _ensureInitialized();
    try {
      return await _dio.get(endpoint);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> patch(String endpoint, dynamic data) async {
    await _ensureInitialized();
    try {
      return await _dio.patch(endpoint, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> put(String endpoint, dynamic data) async {
    await _ensureInitialized();
    try {
      return await _dio.put(endpoint, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  
  Future<Response> delete(String endpoint) async {
    await _ensureInitialized();
    try {
      return await _dio.delete(endpoint);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException error) {
    if (error.response != null) {
      final data = error.response!.data;
      if (data is Map && data.containsKey('error')) {
        return data['error'];
      }
      if (data is Map && data.containsKey('detail')) {
        return data['detail'];
      }
      if (data is Map && data.containsKey('message')) {
        return data['message'];
      }
      return 'Server error: ${error.response?.statusCode}';
    } else if (error.type == DioExceptionType.connectionTimeout) {
      return 'Connection timeout. Please check your internet.';
    } else if (error.type == DioExceptionType.receiveTimeout) {
      return 'Receive timeout. Server is taking too long.';
    } else if (error.type == DioExceptionType.connectionError) {
      return 'No internet connection. Please check your network.';
    } else if (error.type == DioExceptionType.cancel) {
      return 'Request was cancelled.';
    }
    return 'Unknown error occurred: ${error.message}';
  }
}

