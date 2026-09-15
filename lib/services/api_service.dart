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
          print(' Token added: ${token.substring(0, min(20, token.length))}');
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

  Exception _handleError(DioException error) {
    print('Dio Error: ${error.message}');
    print(' Response data: ${error.response?.data}');
    print(' Response status: ${error.response?.statusCode}');


    String errorMessage = 'Unknown error occurred';

    if (error.response != null) {
      final data = error.response!.data;

      if (data is Map) {

        if (data.containsKey('error')) {
          errorMessage = data['error'].toString();
        } else if (data.containsKey('message')) {
          errorMessage = data['message'].toString();
        } else if (data.containsKey('detail')) {
          errorMessage = data['detail'].toString();
        } else if (data.containsKey('non_field_errors')) {
          final errors = data['non_field_errors'];
          if (errors is List) {
            errorMessage = errors.join(', ');
          } else {
            errorMessage = errors.toString();
          }
        } else {

          List<String> errors = [];
          data.forEach((key, value) {
            if (value is List) {
              errors.add('$key: ${value.join(', ')}');
            } else if (value is String) {
              errors.add('$key: $value');
            } else {
              errors.add('$key: $value');
            }
          });
          if (errors.isNotEmpty) {
            errorMessage = errors.join('\n');
          }
        }
      } else if (data is String) {
        errorMessage = data;
      } else {
        errorMessage = 'Server error: ${error.response?.statusCode}';
      }
    } else if (error.type == DioExceptionType.connectionTimeout) {
      errorMessage = 'Connection timeout. Please check your internet.';
    } else if (error.type == DioExceptionType.receiveTimeout) {
      errorMessage = 'Receive timeout. Server is taking too long.';
    } else if (error.type == DioExceptionType.connectionError) {
      errorMessage = 'No internet connection. Please check your network.';
    } else if (error.type == DioExceptionType.cancel) {
      errorMessage = 'Request was cancelled.';
    }

    print(' Error message: $errorMessage');
    return Exception(errorMessage);
  }

}
