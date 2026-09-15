// lib/screens/ag_officer/add_police_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/language_service.dart';
import '../../utils/constants.dart';
import '../base_screen.dart';

class AddPoliceScreen extends StatefulWidget {
  const AddPoliceScreen({super.key});

  @override
  State<AddPoliceScreen> createState() => _AddPoliceScreenState();
}

class _AddPoliceScreenState extends State<AddPoliceScreen> {
  final ApiService _apiService = ApiService();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  String? _successMessage;

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

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }

    String cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleaned.startsWith('255')) {
      cleaned = cleaned.substring(3);
    } else if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }

    if (cleaned.length != 9) {
      return 'Phone number must be 9 digits';
    }


    final validPrefixes = [
      '71', '74', '75', '76', // Vodacom
      '78', '79', // Airtel
      '65', '66', '67', '68', '69', '70', // Tigo (yas)
      '61', '62', // Halotel
    ];

    final prefix = cleaned.substring(0, 2);
    if (!validPrefixes.contains(prefix)) {
      return 'Invalid network prefix. Use Vodacom, Airtel, Tigo (yas), or Halotel';
    }

    return null;
  }


  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; 
    }
    final email = value.trim();
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validateLocation(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; 
    }
    if (value.trim().length < 3) {
      return 'Location must be at least 3 characters';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Password must contain at least one special character (!@#\$%^&*(),.?":{}|<>)';
    }
    return null;
  }


  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  String _cleanPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.startsWith('0')) {
      cleaned = '255${cleaned.substring(1)}';
    } else if (cleaned.startsWith('7') || cleaned.startsWith('6')) {
      cleaned = '255$cleaned';
    } else if (!cleaned.startsWith('255')) {
      if (cleaned.length == 9) {
        cleaned = '255$cleaned';
      }
    }
    if (cleaned.length > 12) {
      cleaned = cleaned.substring(0, 12);
    }
    return cleaned;
  }


  Future<void> _addPolice() async {

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
            context.tr('all_required_fields');
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
      print('Creating police officer:');
      print('   Phone: $cleanPhone');
      print('   First: ${_firstNameController.text}');
      print('   Middle: $middleName');
      print('   Last: ${_lastNameController.text}');

      final response = await _apiService.post(
        '${AppConstants.users}create_police/',
        {
          'phone': cleanPhone,
          'first_name': _firstNameController.text.trim(),
          'middle_name': middleName,
          'last_name': _lastNameController.text.trim(),
          'email': _emailController.text.trim().isNotEmpty
              ? _emailController.text.trim()
              : null,
          'location': _locationController.text.trim().isNotEmpty
              ? _locationController.text.trim()
              : null,
          'password': _passwordController.text,
          'confirm_password': _confirmPasswordController.text,
          'role': 'POLICE',
        },
      );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response data: ${response.data}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        setState(() {
          _successMessage = context.tr('police_added_success');
        });

        // Clear form
        _firstNameController.clear();
        _middleNameController.clear();
        _lastNameController.clear();
        _phoneController.clear();
        _emailController.clear();
        _locationController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context, true);
          }
        });
      } else {
        setState(() {
          _errorMessage = response.data['message'] ??
              response.data['error'] ??
              context.tr('police_add_failed');
        });
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        _errorMessage = '${context.tr('error')}: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return BaseScreen(
      title: 'Add Police Officer',
      selectedIndex: 7, 
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Icon
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.security,
                  size: isSmallScreen ? 50 : 60,
                  color: Colors.deepPurple,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                languageService.translate('add_new_police_officer'),
                style: TextStyle(
                  fontSize: isSmallScreen ? 20 : 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                languageService.translate('add_police_subtitle'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 24),

            // Form Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // First Name
                    _buildTextField(
                      controller: _firstNameController,
                      icon: Icons.person,
                      label: 'First Name *',
                      hint: 'Enter first name',
                    ),
                    const SizedBox(height: 16),

                    // Middle Name (Optional)
                    _buildTextField(
                      controller: _middleNameController,
                      icon: Icons.person_outline,
                      label: 'Middle Name (Optional)',
                      hint: 'Enter middle name (optional)',
                    ),
                    const SizedBox(height: 16),

                    // Last Name
                    _buildTextField(
                      controller: _lastNameController,
                      icon: Icons.person_add,
                      label: 'Last Name *',
                      hint: 'Enter last name',
                    ),
                    const SizedBox(height: 16),

                    // Phone Number
                    _buildTextField(
                      controller: _phoneController,
                      icon: Icons.phone,
                      label: 'Phone Number *',
                      hint: 'Enter phone number',
                      keyboardType: TextInputType.phone,
                      helperText: 'Example: 255712345678 or 0712345678',
                    ),
                    const SizedBox(height: 16),

                    // Email (Optional)
                    _buildTextField(
                      controller: _emailController,
                      icon: Icons.email,
                      label: 'Email (Optional)',
                      hint: 'Enter email address (optional)',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),

                    // Location (Optional)
                    _buildTextField(
                      controller: _locationController,
                      icon: Icons.location_on,
                      label: 'Work Location (Optional)',
                      hint: 'Enter work location (optional)',
                    ),
                    const SizedBox(height: 16),

                    // Password
                    _buildTextField(
                      controller: _passwordController,
                      icon: Icons.lock,
                      label: 'Password *',
                      hint: 'Enter password (min 8 chars)',
                      obscureText: _obscurePassword,
                      isPassword: true,
                      onSuffixTap: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      helperText: '8+ chars: A-Z, a-z, 0-9, !@#',
                    ),
                    const SizedBox(height: 16),

                    // Confirm Password
                    _buildTextField(
                      controller: _confirmPasswordController,
                      icon: Icons.lock_outline,
                      label: 'Confirm Password *',
                      hint: 'Confirm your password',
                      obscureText: _obscureConfirmPassword,
                      isPassword: true,
                      onSuffixTap: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Error Message
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
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
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: const TextStyle(color: Colors.green),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _successMessage = null;
                          });
                        },
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.green.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _addPolice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        languageService
                            .translate('add_police_button')
                            .toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== CUSTOM TEXT FIELD WIDGET ====================

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    bool isPassword = false,
    VoidCallback? onSuffixTap,
    String? helperText,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.deepPurple),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off : Icons.visibility,
                  color: Colors.deepPurple,
                ),
                onPressed: onSuffixTap,
              )
            : null,
        border: const OutlineInputBorder(),
        helperText: helperText,
        helperStyle: const TextStyle(fontSize: 11),
      ),
    );
  }
}
