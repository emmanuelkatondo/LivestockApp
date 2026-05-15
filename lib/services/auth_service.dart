import 'dart:convert'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../utils/constants.dart';
import '../models/user_model.dart';

class AuthService {
  late ApiService _apiService;
  bool _isInitialized = false;

  AuthService() {
    _init();
  }

  Future<void> _init() async {
    _apiService = ApiService();
    await _apiService.init(); 
    _isInitialized = true;
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _init();
    }
  }

  Future<bool> login(String phoneNumber, String password) async {
    await _ensureInitialized();

    try {
      final response = await _apiService.post(AppConstants.login, {
        'phone': phoneNumber,
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        final prefs = await SharedPreferences.getInstance();

        await prefs.setString(AppConstants.tokenKey, data['access']);
        await prefs.setString(AppConstants.refreshTokenKey, data['refresh']);

        final userJson = jsonEncode(data['user']);
        await prefs.setString(AppConstants.userDataKey, userJson);

        print('Login successful');
        print('User JSON: $userJson');

        return true;
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  Future<bool> register({
    required String phoneNumber,
    required String fullName,
    required String password,
    required String confirmPassword,
    String? email,
    String? location,
  }) async {
    await _ensureInitialized();

    try {
      print('Registering user: $phoneNumber, $fullName');

      final response = await _apiService.post(AppConstants.register, {
        'phone': phoneNumber,
        'first_name': fullName, 
        'password': password,
        'confirm_password': confirmPassword,
        'email': email,
        'location': location,
      });
      print('Register response status: ${response.statusCode}');
      print('Register response data: ${response.data}');

      if (response.statusCode == 201) {
        final data = response.data;
        final prefs = await SharedPreferences.getInstance();

        await prefs.setString(AppConstants.tokenKey, data['access']);
        await prefs.setString(AppConstants.refreshTokenKey, data['refresh']);

        final userJson = jsonEncode(data['user']);
        await prefs.setString(AppConstants.userDataKey, userJson);

        print('Registration successful');
        print(' User JSON: $userJson');

        return true;
      }
      return false;
    } catch (e) {
      print('Register error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    await _ensureInitialized();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.refreshTokenKey);
    await prefs.remove(AppConstants.userDataKey);
    print(' User logged out');
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);
    return token != null && token.isNotEmpty;
  }

  Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString(AppConstants.userDataKey);

    print('Raw user string: $userString');

    if (userString != null && userString.isNotEmpty) {
      try {
        final Map<String, dynamic> userMap = jsonDecode(userString);
        print('Parsed user map: $userMap');
        print('User role: ${userMap['role']}');
        return UserModel.fromJson(userMap);
      } catch (e) {
        print('Error parsing user: $e');
        return null;
      }
    }
    return null;
  }
}
