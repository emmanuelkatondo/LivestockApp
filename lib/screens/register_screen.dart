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
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
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

  // Background image moja tu
  final String _backgroundImage = 'assets/images/live.jpg';

  // Function to clean phone number
  String _cleanPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.startsWith('0')) {
      cleaned = '255${cleaned.substring(1)}';
    } else if (cleaned.startsWith('7') || cleaned.startsWith('6')) {
      cleaned = '255$cleaned';
    }
    if (cleaned.length > 12) {
      cleaned = cleaned.substring(0, 12);
    }
    return cleaned;
  }

  Future<void> _handleRegister() async {
    if (_phoneController.text.isEmpty ||
        _fullNameController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      setState(() {
        _errorMessage = context.tr('all_required_fields');
      });
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = context.tr('passwords_do_not_match');
      });
      return;
    }

    if (_passwordController.text.length < 6) {
      setState(() {
        _errorMessage = context.tr('password_min_length');
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final cleanPhone = _cleanPhoneNumber(_phoneController.text);

    final success = await _authService.register(
      phoneNumber: cleanPhone,
      fullName: _fullNameController.text,
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
      email: _emailController.text.isNotEmpty ? _emailController.text : null,
      location:
          _locationController.text.isNotEmpty ? _locationController.text : null,
    );

    setState(() {
      _isLoading = false;
    });

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('registration_success')),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      setState(() {
        _errorMessage = context.tr('registration_failed_try_again');
      });
    }
  }

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

                                TextField(
                                  controller: _fullNameController,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.person,
                                        color: Colors.white70, size: 20),
                                    hintText:
                                        languageService.translate('full_name'),
                                    hintStyle: const TextStyle(
                                        color: Colors.white54, fontSize: 13),
                                    labelText:
                                        languageService.translate('full_name'),
                                    labelStyle: const TextStyle(
                                        color: Colors.white70, fontSize: 13),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                          color: Colors.white.withOpacity(0.3)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Colors.white, width: 2),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.08),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.phone,
                                        color: Colors.white70, size: 20),
                                    hintText: languageService
                                        .translate('phone_number'),
                                    hintStyle: const TextStyle(
                                        color: Colors.white54, fontSize: 13),
                                    labelText: languageService
                                        .translate('phone_number'),
                                    labelStyle: const TextStyle(
                                        color: Colors.white70, fontSize: 13),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                          color: Colors.white.withOpacity(0.3)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Colors.white, width: 2),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.08),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                TextField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.email,
                                        color: Colors.white70, size: 20),
                                    hintText:
                                        '${languageService.translate('email')} (${languageService.translate('optional')})',
                                    hintStyle: const TextStyle(
                                        color: Colors.white54, fontSize: 13),
                                    labelText:
                                        languageService.translate('email'),
                                    labelStyle: const TextStyle(
                                        color: Colors.white70, fontSize: 13),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                          color: Colors.white.withOpacity(0.3)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Colors.white, width: 2),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.08),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                TextField(
                                  controller: _locationController,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.location_on,
                                        color: Colors.white70, size: 20),
                                    hintText:
                                        '${languageService.translate('location')} (${languageService.translate('optional')})',
                                    hintStyle: const TextStyle(
                                        color: Colors.white54, fontSize: 13),
                                    labelText:
                                        languageService.translate('address'),
                                    labelStyle: const TextStyle(
                                        color: Colors.white70, fontSize: 13),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                          color: Colors.white.withOpacity(0.3)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Colors.white, width: 2),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.08),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                TextField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.lock,
                                        color: Colors.white70, size: 20),
                                    hintText:
                                        languageService.translate('password'),
                                    hintStyle: const TextStyle(
                                        color: Colors.white54, fontSize: 13),
                                    labelText:
                                        languageService.translate('password'),
                                    labelStyle: const TextStyle(
                                        color: Colors.white70, fontSize: 13),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: Colors.white70,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                          color: Colors.white.withOpacity(0.3)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Colors.white, width: 2),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.08),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                TextField(
                                  controller: _confirmPasswordController,
                                  obscureText: _obscureConfirmPassword,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.lock_outline,
                                        color: Colors.white70, size: 20),
                                    hintText: languageService
                                        .translate('confirm_password'),
                                    hintStyle: const TextStyle(
                                        color: Colors.white54, fontSize: 13),
                                    labelText: languageService
                                        .translate('confirm_password'),
                                    labelStyle: const TextStyle(
                                        color: Colors.white70, fontSize: 13),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureConfirmPassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: Colors.white70,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscureConfirmPassword =
                                              !_obscureConfirmPassword;
                                        });
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                          color: Colors.white.withOpacity(0.3)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Colors.white, width: 2),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.08),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                  ),
                                ),

                                if (_errorMessage != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Colors.red.withOpacity(0.5)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error,
                                              color: Colors.red, size: 16),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _errorMessage!,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                const SizedBox(height: 20),

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
                                              builder: (_) =>
                                                  const LoginScreen()),
                                        );
                                      },
                                      style: TextButton.styleFrom(
                                        minimumSize: Size.zero,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
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

              // ========== LANGUAGE SELECTOR - MWISHO KABISA (JUU YA YOTE) ==========
              Positioned(
                top: topPadding + 10,
                right: 16,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(30),
                  child: LanguageSelector(
                    onLanguageChanged: (languageCode) async {
                      print('🔵 Language selector clicked: $languageCode');
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
}
