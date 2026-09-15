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

  // ==================== LOGIN ====================
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

        print('✅ Login successful');
        print('📦 User JSON: $userJson');

        return true;
      } else {
        // Handle login errors
        final errorData = response.data;
        String errorMessage = 'Invalid phone number or password';

        if (errorData is Map) {
          if (errorData.containsKey('error')) {
            errorMessage = errorData['error'].toString();
          } else if (errorData.containsKey('message')) {
            errorMessage = errorData['message'].toString();
          } else if (errorData.containsKey('detail')) {
            errorMessage = errorData['detail'].toString();
          }
        }

        print('❌ Login failed: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ Login error: $e');
      rethrow;
    }
  }

  // ==================== REGISTER (Updated with Error Handling) ====================
  Future<bool> register({
    required String phoneNumber,
    required String firstName,
    String? middleName,
    required String lastName,
    required String password,
    required String confirmPassword,
    String? email,
    String? location,
  }) async {
    await _ensureInitialized();

    try {
      print('📝 Registering user:');
      print('   Phone: $phoneNumber');
      print('   First: $firstName');
      print('   Middle: $middleName');
      print('   Last: $lastName');
      print('   Email: $email');
      print('   Location: $location');

      final response = await _apiService.post(
        AppConstants.register,
        {
          'phone': phoneNumber,
          'first_name': firstName,
          'middle_name': middleName ?? '',
          'last_name': lastName,
          'password': password,
          'confirm_password': confirmPassword,
          'email': email ?? '',
          'location': location ?? '',
        },
      );

      print('📨 Register response status: ${response.statusCode}');
      print('📨 Register response data: ${response.data}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data;
        final prefs = await SharedPreferences.getInstance();

        // Save tokens if returned
        if (data['access'] != null) {
          await prefs.setString(AppConstants.tokenKey, data['access']);
        }
        if (data['refresh'] != null) {
          await prefs.setString(AppConstants.refreshTokenKey, data['refresh']);
        }

        // Save user data if returned
        if (data['user'] != null) {
          final userJson = jsonEncode(data['user']);
          await prefs.setString(AppConstants.userDataKey, userJson);
          print('✅ Registration successful');
          print('📦 User JSON: $userJson');
        } else {
          print('✅ Registration successful (no user data returned)');
        }

        return true;
      } else {
        // ========== HANDLE REGISTRATION ERRORS ==========
        final errorData = response.data;
        String errorMessage = 'Registration failed';

        if (errorData is Map) {
          // Collect all error messages from the response
          List<String> errors = [];

          errorData.forEach((key, value) {
            if (value is List) {
              // Handle list of errors (e.g., {"phone": ["already exists"]})
              errors.add('$key: ${value.join(', ')}');
            } else if (value is String) {
              errors.add('$key: $value');
            } else if (value is Map) {
              // Handle nested errors
              value.forEach((subKey, subValue) {
                if (subValue is List) {
                  errors.add('$key.$subKey: ${subValue.join(', ')}');
                } else {
                  errors.add('$key.$subKey: $subValue');
                }
              });
            } else {
              errors.add('$key: $value');
            }
          });

          if (errors.isNotEmpty) {
            errorMessage = errors.join('\n');
          }
        } else if (errorData is String) {
          errorMessage = errorData;
        }

        print('❌ Registration failed: $errorMessage');
        throw Exception(errorMessage);
        // ================================================
      }
    } catch (e) {
      print('❌ Register error: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    await _ensureInitialized();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.refreshTokenKey);
    await prefs.remove(AppConstants.userDataKey);
    print('User logged out');
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);
    return token != null && token.isNotEmpty;
  }

  Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString(AppConstants.userDataKey);

    print(' Raw user string: $userString');

    if (userString != null && userString.isNotEmpty) {
      try {
        final Map<String, dynamic> userMap = jsonDecode(userString);
        print(' Parsed user map: $userMap');
        print(' User role: ${userMap['role']}');
        return UserModel.fromJson(userMap);
      } catch (e) {
        print(' Error parsing user: $e');
        return null;
      }
    }
    return null;
  }


  Map<String, String?> _splitFullName(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();

    String? firstName;
    String? middleName;
    String? lastName;

    if (parts.length == 1) {
      firstName = parts[0];
    } else if (parts.length == 2) {
      firstName = parts[0];
      lastName = parts[1];
    } else if (parts.length >= 3) {
      firstName = parts[0];
      lastName = parts.last;
      middleName = parts.sublist(1, parts.length - 1).join(' ');
    }

    return {
      'firstName': firstName,
      'middleName': middleName,
      'lastName': lastName,
    };
  }


  Future<bool> registerWithFullName({
    required String phoneNumber,
    required String fullName,
    required String password,
    required String confirmPassword,
    String? email,
    String? location,
  }) async {

    final nameParts = _splitFullName(fullName);

    return register(
      phoneNumber: phoneNumber,
      firstName: nameParts['firstName'] ?? '',
      middleName: nameParts['middleName'],
      lastName: nameParts['lastName'] ?? '',
      password: password,
      confirmPassword: confirmPassword,
      email: email,
      location: location,
    );
  }
}
