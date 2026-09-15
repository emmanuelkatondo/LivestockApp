import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';
import '../screens/login_screen.dart';
import '../widgets/language_selector.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controllers
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  String? _successMessage;

  // Background image
  final String _backgroundImage = 'assets/images/live.jpg';

  // ==================== VALIDATION FUNCTIONS ====================

  /// Validate name (3-10 characters, letters only)
  String? _validateName(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    final trimmed = value.trim();
    if (trimmed.length < 3) {
      return '$fieldName must be at least 3 characters';
    }
    if (trimmed.length > 10) {
      return '$fieldName must be less than 10 characters';
    }
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(trimmed)) {
      return '$fieldName can only contain letters';
    }
    return null;
  }

  /// Validate Tanzania phone number (10 digits starting with 0)
  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }

    // Remove all non-digit characters
    String cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');

    // Must start with 0 and have exactly 10 digits
    if (!cleaned.startsWith('0')) {
      return 'Phone number must start with 0 (e.g., 0712345678)';
    }

    if (cleaned.length != 10) {
      return 'Phone number must be exactly 10 digits (e.g., 0712345678)';
    }

    // Get the 9 digits after the leading 0 to check network prefix
    final numberPart = cleaned.substring(1);

    // Valid Tanzania network prefixes (after removing leading 0)
    // Vodacom: 71, 74, 75, 76
    // Airtel: 78, 79
    // Tigo (yas): 65, 66, 67, 68, 69, 70
    // Halotel: 61, 62
    final validPrefixes = [
      '71', '74', '75', '76', // Vodacom
      '78', '79', // Airtel
      '65', '66', '67', '68', '69', '70', // Tigo (yas)
      '61', '62', // Halotel
    ];

    final prefix = numberPart.substring(0, 2);
    if (!validPrefixes.contains(prefix)) {
      return 'Invalid network. Use Vodacom, Airtel, Tigo (yas), or Halotel';
    }

    return null;
  }

  /// Validate email (optional but if provided must be valid)
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }
    final email = value.trim();
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validate location (optional)
  String? _validateLocation(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }
    if (value.trim().length < 3) {
      return 'Location must be at least 3 characters';
    }
    return null;
  }

  /// Validate password (min 8 characters)
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  /// Validate confirm password
  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  // ==================== PHONE CLEANING ====================

  String _cleanPhoneNumber(String phone) {
    // Remove all non-digit characters
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');

    // If it starts with 0, convert to 255 format
    if (cleaned.startsWith('0') && cleaned.length == 10) {
      cleaned = '255${cleaned.substring(1)}';
    }

    return cleaned;
  }

  // ==================== REGISTER HANDLER ====================

  Future<void> _handleRegister() async {
    // Validate all fields
    final firstNameError =
        _validateName(_firstNameController.text, 'First name');
    final lastNameError = _validateName(_lastNameController.text, 'Last name');
    final middleNameError = _middleNameController.text.isNotEmpty
        ? _validateName(_middleNameController.text, 'Middle name')
        : null;
    final phoneError = _validatePhone(_phoneController.text);
    final emailError = _validateEmail(_emailController.text);
    final locationError = _validateLocation(_locationController.text);
    final passwordError = _validatePassword(_passwordController.text);
    final confirmPasswordError =
        _validateConfirmPassword(_confirmPasswordController.text);

    // Check for errors
    if (firstNameError != null ||
        lastNameError != null ||
        middleNameError != null ||
        phoneError != null ||
        emailError != null ||
        locationError != null ||
        passwordError != null ||
        confirmPasswordError != null) {
      setState(() {
        _errorMessage = firstNameError ??
            lastNameError ??
            middleNameError ??
            phoneError ??
            emailError ??
            locationError ??
            passwordError ??
            confirmPasswordError ??
            'Please fill all required fields';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final cleanPhone = _cleanPhoneNumber(_phoneController.text);
    final middleName = _middleNameController.text.trim().isNotEmpty
        ? _middleNameController.text.trim()
        : null;

    try {
      final success = await _authService.register(
        phoneNumber: cleanPhone,
        firstName: _firstNameController.text.trim(),
        middleName: middleName,
        lastName: _lastNameController.text.trim(),
        password: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
        email: _emailController.text.isNotEmpty ? _emailController.text : null,
        location: _locationController.text.isNotEmpty
            ? _locationController.text
            : null,
      );

      setState(() {
        _isLoading = false;
      });

      if (success && mounted) {
        setState(() {
          _successMessage = context.tr('registration_success');
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('registration_success')),
            backgroundColor: Colors.green,
          ),
        );

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          }
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      // Handle server errors
      final errorMsg = e.toString();

      if (errorMsg.contains('phone') && errorMsg.contains('already exists')) {
        setState(() {
          _errorMessage =
              '❌ This phone number is already registered. Please use a different number or login.';
        });
      } else if (errorMsg.contains('email') &&
          errorMsg.contains('already exists')) {
        setState(() {
          _errorMessage =
              '❌ This email is already registered. Please use a different email or login.';
        });
      } else if (errorMsg.contains('password')) {
        setState(() {
          _errorMessage = '❌ Password error: ${_extractErrorMessage(errorMsg)}';
        });
      } else if (errorMsg.contains('phone')) {
        setState(() {
          _errorMessage =
              '❌ Phone number error: ${_extractErrorMessage(errorMsg)}';
        });
      } else if (errorMsg.contains('first_name') ||
          errorMsg.contains('last_name')) {
        setState(() {
          _errorMessage = '❌ Name error: ${_extractErrorMessage(errorMsg)}';
        });
      } else if (errorMsg.contains('Connection') ||
          errorMsg.contains('timeout')) {
        setState(() {
          _errorMessage =
              '🌐 Network error. Please check your internet connection.';
        });
      } else {
        setState(() {
          _errorMessage =
              '❌ Registration failed: ${_extractErrorMessage(errorMsg)}';
        });
      }
    }
  }

  String _extractErrorMessage(String error) {
    // Try to extract meaningful message from server response
    if (error.contains('[')) {
      final start = error.indexOf('[');
      final end = error.indexOf(']');
      if (start != -1 && end != -1 && end > start) {
        return error.substring(start + 1, end);
      }
    }
    if (error.contains('{')) {
      try {
        final regex = RegExp(r'"error":\s*"([^"]+)"');
        final match = regex.firstMatch(error);
        if (match != null) {
          return match.group(1) ?? error;
        }
      } catch (_) {}
    }
    return error;
  }

  // ==================== BUILD UI ====================

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final topPadding = MediaQuery.of(context).padding.top;

    return Consumer<LanguageService>(
      builder: (context, languageService, child) {
        return Scaffold(
          body: Stack(
            children: [
              // Background Image
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(_backgroundImage),
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              // Dark overlay
              Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black.withOpacity(0.45),
              ),

              // Register Form
              SafeArea(
                child: SingleChildScrollView(
                  child: SizedBox(
                    height: screenHeight,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.07,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(flex: 1),

                          // Logo
                          Container(
                            width: isSmallScreen ? 80 : 100,
                            height: isSmallScreen ? 80 : 100,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 25,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/logo tracker.jpg',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // App Name
                          const Text(
                            'LIVESTOCK TRACKER',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Register Card
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  languageService
                                      .translate('register')
                                      .toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  languageService.translate('create_account'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // FIRST NAME
                                _buildTextField(
                                  controller: _firstNameController,
                                  icon: Icons.person,
                                  hint: 'First Name * (3-10 letters)',
                                  label: 'First Name',
                                  isRequired: true,
                                  obscureText: false,
                                ),
                                const SizedBox(height: 12),

                                // MIDDLE NAME (Optional)
                                _buildTextField(
                                  controller: _middleNameController,
                                  icon: Icons.person_outline,
                                  hint: 'Middle Name (Optional)',
                                  label: 'Middle Name',
                                  isRequired: false,
                                  obscureText: false,
                                ),
                                const SizedBox(height: 12),

                                // LAST NAME
                                _buildTextField(
                                  controller: _lastNameController,
                                  icon: Icons.person_add,
                                  hint: 'Last Name * (3-10 letters)',
                                  label: 'Last Name',
                                  isRequired: true,
                                  obscureText: false,
                                ),
                                const SizedBox(height: 12),

                                // PHONE
                                _buildTextField(
                                  controller: _phoneController,
                                  icon: Icons.phone,
                                  hint: 'Phone Number * (e.g., 0712345678)',
                                  label: 'Phone Number',
                                  isRequired: true,
                                  obscureText: false,
                                  keyboardType: TextInputType.phone,
                                ),
                                const SizedBox(height: 12),

                                // EMAIL (Optional)
                                _buildTextField(
                                  controller: _emailController,
                                  icon: Icons.email,
                                  hint: 'Email (Optional)',
                                  label: 'Email',
                                  isRequired: false,
                                  obscureText: false,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 12),

                                // LOCATION (Optional)
                                _buildTextField(
                                  controller: _locationController,
                                  icon: Icons.location_on,
                                  hint: 'Location (Optional)',
                                  label: 'Address',
                                  isRequired: false,
                                  obscureText: false,
                                ),
                                const SizedBox(height: 12),

                                // PASSWORD
                                _buildTextField(
                                  controller: _passwordController,
                                  icon: Icons.lock,
                                  hint: 'Password * (min 8 chars)',
                                  label: 'Password',
                                  isRequired: true,
                                  obscureText: _obscurePassword,
                                  isPassword: true,
                                  onSuffixTap: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),

                                // CONFIRM PASSWORD
                                _buildTextField(
                                  controller: _confirmPasswordController,
                                  icon: Icons.lock_outline,
                                  hint: 'Confirm Password *',
                                  label: 'Confirm Password',
                                  isRequired: true,
                                  obscureText: _obscureConfirmPassword,
                                  isPassword: true,
                                  onSuffixTap: () {
                                    setState(() {
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
                                    });
                                  },
                                ),

                                // Error Message
                                if (_errorMessage != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.red.withOpacity(0.5),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.error_outline,
                                            color: Colors.red,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              _errorMessage!,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _errorMessage = null;
                                              });
                                            },
                                            child: Icon(
                                              Icons.close,
                                              size: 18,
                                              color: Colors.red.shade400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                // Success Message
                                if (_successMessage != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.green.withOpacity(0.5),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.check_circle,
                                            color: Colors.green,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              _successMessage!,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                const SizedBox(height: 20),

                                // Register Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 46,
                                  child: ElevatedButton(
                                    onPressed:
                                        _isLoading ? null : _handleRegister,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2E7D32),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white),
                                            ),
                                          )
                                        : Text(
                                            languageService
                                                .translate('register')
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      languageService
                                          .translate('already_have_account'),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const LoginScreen(),
                                          ),
                                        );
                                      },
                                      style: TextButton.styleFrom(
                                        minimumSize: Size.zero,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                      ),
                                      child: Text(
                                        languageService
                                            .translate('login')
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const Spacer(flex: 1),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                top: topPadding + 10,
                right: 16,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(30),
                  child: LanguageSelector(
                    onLanguageChanged: (languageCode) async {
                      print(' Language selector clicked: $languageCode');
                      await languageService.setLanguage(languageCode);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required String label,
    required bool isRequired,
    required bool obscureText,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    VoidCallback? onSuffixTap,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(
          icon,
          color: Colors.white70,
          size: 20,
        ),
        hintText: hint,
        hintStyle: const TextStyle(
          color: Colors.white54,
          fontSize: 13,
        ),
        labelText: label,
        labelStyle: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: onSuffixTap,
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Colors.white,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }
}
