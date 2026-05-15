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
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
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

  Future<void> _addPolice() async {
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
      _successMessage = null;
    });

    // Clean phone number
    final cleanPhone = _cleanPhoneNumber(_phoneController.text);

    try {
      print('📱 Creating police officer with phone: $cleanPhone');
      print('📱 Name: ${_fullNameController.text}');

      final response =
          await _apiService.post('${AppConstants.users}create_police/', {
        'phone': cleanPhone,
        'first_name': _fullNameController.text,
        'email': _emailController.text,
        'location': _locationController.text,
        'password': _passwordController.text,
        'confirm_password': _confirmPasswordController.text,
        'role': 'POLICE',
      });

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response data: ${response.data}');

      if (response.statusCode == 201) {
        setState(() {
          _successMessage = context.tr('police_added_success');
        });

        // Clear form
        _phoneController.clear();
        _fullNameController.clear();
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
          _errorMessage =
              response.data['error'] ?? context.tr('police_add_failed');
        });
      }
    } catch (e) {
      print('❌ Error: $e');
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
      selectedIndex: 7, // Index for Police in menu (Ag Officer)
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
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Full Name
                    TextField(
                      controller: _fullNameController,
                      decoration: InputDecoration(
                        labelText: languageService.translate('full_name'),
                        prefixIcon:
                            const Icon(Icons.person, color: Colors.deepPurple),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Phone Number
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: languageService.translate('phone_number'),
                        prefixIcon:
                            const Icon(Icons.phone, color: Colors.deepPurple),
                        border: const OutlineInputBorder(),
                        helperText: languageService.translate('phone_helper'),
                        helperStyle: const TextStyle(fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Email
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText:
                            '${languageService.translate('email')} (${languageService.translate('optional')})',
                        prefixIcon:
                            const Icon(Icons.email, color: Colors.deepPurple),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Location
                    TextField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        labelText: languageService.translate('work_location'),
                        prefixIcon: const Icon(Icons.location_on,
                            color: Colors.deepPurple),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: languageService.translate('password'),
                        prefixIcon:
                            const Icon(Icons.lock, color: Colors.deepPurple),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.deepPurple,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: const OutlineInputBorder(),
                        helperText:
                            languageService.translate('password_min_length'),
                        helperStyle: const TextStyle(fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Confirm Password
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText:
                            languageService.translate('confirm_password'),
                        prefixIcon: const Icon(Icons.lock_outline,
                            color: Colors.deepPurple),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.deepPurple,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

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
                        child: Icon(Icons.close,
                            size: 18, color: Colors.red.shade400),
                      ),
                    ],
                  ),
                ),
              ),

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
                        child: Icon(Icons.close,
                            size: 18, color: Colors.green.shade400),
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
}
