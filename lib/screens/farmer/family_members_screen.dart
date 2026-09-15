// lib/screens/farmer/family_members_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/language_service.dart';
import '../../models/user_model.dart';
import '../base_screen.dart';
import '../../utils/constants.dart';

class FamilyMembersScreen extends StatefulWidget {
  const FamilyMembersScreen({super.key});

  @override
  State<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends State<FamilyMembersScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  List<UserModel> _familyMembers = [];
  UserModel? _currentUser;
  UserModel? _primaryOwner;
  bool _isLoading = true;
  bool _isAdding = false;
  bool _isRefreshing = false;
  String? _errorMessage;
  String? _successMessage;
  int? _ownerId;
  bool _isPrimaryOwner = false;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _locationController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

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

  String? _validatePhoneNumber(String? value) {
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
      return 'Phone number must be 9 digits (e.g., 0712345678)';
    }

    final validPrefixes = [
      '71', '74', '75', '76', // Vodacom
      '78', '79', // Airtel
      '65', '66', '67', '68', '69', '70', // Tigo (yas)
      '61', '62', // Halotel
    ];

    final prefix = cleaned.substring(0, 2);
    if (!validPrefixes.contains(prefix)) {
      return 'Invalid network. Use Vodacom, Airtel, Tigo (yas), or Halotel';
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
      return 'Password must contain at least one special character';
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
    } else if (!cleaned.startsWith('255') && cleaned.length == 9) {
      cleaned = '255$cleaned';
    }
    if (cleaned.length > 12) {
      cleaned = cleaned.substring(0, 12);
    }
    return cleaned;
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isPrimaryOwner = false;
    });

    try {
      _currentUser = await _authService.getCurrentUser();

      if (_currentUser == null) {
        setState(() {
          _errorMessage = 'Please login again';
          _isLoading = false;
        });
        return;
      }

      await _loadFamilyMembers();
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _errorMessage = 'Failed to load family members. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });

    try {
      await _loadFamilyMembers();
    } catch (e) {
      print(' Error refreshing: $e');
      setState(() {
        _errorMessage = 'Failed to refresh. Please try again.';
      });
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  Future<void> _loadFamilyMembers() async {
    try {
      final ownerResponse = await _apiService.get(AppConstants.ownerMe);

      if (ownerResponse.statusCode == 200) {
        final ownerData = ownerResponse.data;
        _ownerId = ownerData['id'];

        UserModel? primaryOwner;

        if (ownerData['primary_owner_info'] != null) {
          primaryOwner = UserModel.fromJson(ownerData['primary_owner_info']);
        } else if (ownerData['primary_owner'] != null) {
          final primaryOwnerId = ownerData['primary_owner'];
          final membersResponse =
              await _apiService.get(AppConstants.getFamilyMembers(_ownerId!));

          if (membersResponse.statusCode == 200) {
            final data = membersResponse.data;
            final members = data['members'] as List? ?? [];

            for (var member in members) {
              if (member['id'] == primaryOwnerId) {
                primaryOwner = UserModel.fromJson(member);
                break;
              }
            }
          }
        }

        if (primaryOwner == null) {
          primaryOwner = _currentUser;
        }

        _primaryOwner = primaryOwner;
        _isPrimaryOwner = _currentUser?.id == _primaryOwner?.id;

        final membersResponse =
            await _apiService.get(AppConstants.getFamilyMembers(_ownerId!));

        if (membersResponse.statusCode == 200) {
          final data = membersResponse.data;
          final members = data['members'] as List? ?? [];

          setState(() {
            _familyMembers =
                members.map((json) => UserModel.fromJson(json)).toList();
          });
        }
      } else if (ownerResponse.statusCode == 404) {
        setState(() {
          _errorMessage =
              'You need to create a farm profile first. Please contact support.';
          _isLoading = false;
        });

        _showCreateProfileDialog();
      }
    } catch (e) {
      print('Error loading family members: $e');
      rethrow;
    }
  }

  void _showCreateProfileDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Farm Profile Not Found'),
        content: const Text(
          'You don\'t have a farm profile yet. Please contact the administrator to create one, or try registering again.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Go Back'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _refreshData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Future<void> _registerAndAddFamilyMember() async {

    final firstNameError =
        _validateName(_firstNameController.text, 'First name');
    final lastNameError = _validateName(_lastNameController.text, 'Last name');
    final phoneError = _validatePhoneNumber(_phoneController.text);
    final passwordError = _validatePassword(_passwordController.text);
    final confirmPasswordError =
        _validateConfirmPassword(_confirmPasswordController.text);

    if (firstNameError != null ||
        lastNameError != null ||
        phoneError != null ||
        passwordError != null ||
        confirmPasswordError != null) {
      setState(() {
        _errorMessage = firstNameError ??
            lastNameError ??
            phoneError ??
            passwordError ??
            confirmPasswordError ??
            'Please fill all required fields';
      });
      return;
    }

    setState(() {
      _isAdding = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final cleanPhone = _cleanPhoneNumber(_phoneController.text.trim());

      if (_ownerId == null) {
        final ownerResponse = await _apiService.get(AppConstants.ownerMe);
        if (ownerResponse.statusCode == 200) {
          _ownerId = ownerResponse.data['id'];
        } else {
          throw Exception('Failed to get owner profile');
        }
      }

      final response = await _apiService.post(
        AppConstants.getRegisterFamilyMember(_ownerId!),
        {
          'phone': cleanPhone,
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'email': _emailController.text.trim().isNotEmpty
              ? _emailController.text.trim()
              : null,
          'location': _locationController.text.trim().isNotEmpty
              ? _locationController.text.trim()
              : null,
          'password': _passwordController.text,
          'confirm_password': _confirmPasswordController.text,
        },
      );

      if (response.statusCode == 201) {
        setState(() {
          _successMessage =
              ' Family member registered and added successfully!';
        });

        _clearForm();

        await _loadFamilyMembers();

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _successMessage = null;
            });
          }
        });
      } else {
        String errorMsg = '';
        final data = response.data;
        if (data is Map) {
          errorMsg = data['error'] ?? data['message'] ?? data.toString();
        }

        setState(() {
          _errorMessage = errorMsg.isNotEmpty
              ? errorMsg
              : 'Failed to register family member';
        });
      }
    } catch (e) {
      print(' Error: $e');
      setState(() {
        _errorMessage = 'Network error. Please try again.';
      });
    } finally {
      setState(() {
        _isAdding = false;
      });
    }
  }

  void _clearForm() {
    _firstNameController.clear();
    _lastNameController.clear();
    _phoneController.clear();
    _emailController.clear();
    _locationController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
  }


  Future<void> _removeFamilyMember(UserModel user) async {
    final languageService =
        Provider.of<LanguageService>(context, listen: false);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Family Member'),
        content: Text(
            'Are you sure you want to remove ${user.fullName} from your family members?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(languageService.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      if (_ownerId == null) {
        final ownerResponse = await _apiService.get(AppConstants.ownerMe);
        if (ownerResponse.statusCode == 200) {
          _ownerId = ownerResponse.data['id'];
        } else {
          throw Exception('Failed to get owner profile');
        }
      }

      final response = await _apiService
          .post(AppConstants.getRemoveMember(_ownerId!), {'user_id': user.id});

      if (response.statusCode == 200) {
        setState(() {
          _successMessage = 'Family member removed successfully!';
        });

        await _loadFamilyMembers();

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _successMessage = null;
            });
          }
        });
      } else {
        setState(() {
          _errorMessage = response.data['message'] ??
              response.data['error'] ??
              'Failed to remove family member';
        });
      }
    } catch (e) {
      print(' Error removing family member: $e');
      setState(() {
        _errorMessage = 'Network error. Please check your connection.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  void _showAddMemberDialog() {
    _clearForm();
    _errorMessage = null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.person_add_alt_1, color: Colors.green),
                const SizedBox(width: 8),
                const Text('Register Family Member'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create an account for a family member and add them to your farm.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'First Name *',
                      hintText: 'Enter first name',
                      prefixIcon: Icon(Icons.person, color: Colors.green),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Last Name *',
                      hintText: 'Enter last name',
                      prefixIcon: Icon(Icons.person_add, color: Colors.green),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number *',
                      hintText: 'e.g., 0712345678',
                      prefixIcon: Icon(Icons.phone, color: Colors.green),
                      border: OutlineInputBorder(),
                      helperText:
                          'Supported: Vodacom, Airtel, Tigo (yas), Halotel',
                      helperStyle: TextStyle(fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 12),


                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email (Optional)',
                      hintText: 'Enter email address',
                      prefixIcon: Icon(Icons.email, color: Colors.green),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

     
                  TextField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Location (Optional)',
                      hintText: 'Enter location',
                      prefixIcon: Icon(Icons.location_on, color: Colors.green),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password *',
                      hintText: 'Min 8 chars: A-Z, a-z, 0-9, !@#',
                      prefixIcon: Icon(Icons.lock, color: Colors.green),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

              
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password *',
                      hintText: 'Confirm your password',
                      prefixIcon: Icon(Icons.lock_outline, color: Colors.green),
                      border: OutlineInputBorder(),
                    ),
                  ),

                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
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
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _clearForm();
                  setState(() {
                    _errorMessage = null;
                  });
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _isAdding
                    ? null
                    : () {
     
                        final firstNameError = _validateName(
                            _firstNameController.text, 'First name');
                        final lastNameError = _validateName(
                            _lastNameController.text, 'Last name');
                        final phoneError =
                            _validatePhoneNumber(_phoneController.text);
                        final passwordError =
                            _validatePassword(_passwordController.text);
                        final confirmError = _validateConfirmPassword(
                            _confirmPasswordController.text);

                        if (firstNameError != null ||
                            lastNameError != null ||
                            phoneError != null ||
                            passwordError != null ||
                            confirmError != null) {
                          setState(() {
                            _errorMessage = firstNameError ??
                                lastNameError ??
                                phoneError ??
                                passwordError ??
                                confirmError ??
                                'Please fill all required fields';
                          });
                          return;
                        }

                        Navigator.pop(context);
                        _registerAndAddFamilyMember();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: _isAdding
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Register & Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Family Members',
      selectedIndex: 5,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        floatingActionButton: _isPrimaryOwner && !_isLoading
            ? FloatingActionButton.extended(
                onPressed: _showAddMemberDialog,
                backgroundColor: Colors.green,
                icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
                label: const Text(
                  'Add Member',
                  style: TextStyle(color: Colors.white),
                ),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        // ==========================================================
        body: RefreshIndicator(
          onRefresh: _refreshData,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // Header Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(30),
                          bottomRight: Radius.circular(30),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.family_restroom,
                            color: Colors.white,
                            size: 50,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Family Members',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_familyMembers.length} members',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                          if (_primaryOwner != null)
                            Text(
                              _isPrimaryOwner
                                  ? 'Farm: ${_primaryOwner!.fullName}'
                                  : 'You are a member of ${_primaryOwner!.fullName}\'s farm',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _isPrimaryOwner
                                  ? Colors.yellow.shade700
                                  : Colors.blue.shade400,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _isPrimaryOwner
                                  ? '👑 Primary Owner'
                                  : '👤 Family Member',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Error Message
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Colors.red),
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
                        padding: const EdgeInsets.all(16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  color: Colors.green),
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

                    // Family Members List
                    Expanded(
                      child: _familyMembers.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.family_restroom,
                                    size: 80,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No family members yet',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Add family members to share your farm dashboard',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  if (_isPrimaryOwner)
                                    ElevatedButton.icon(
                                      onPressed: _showAddMemberDialog,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add Member'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _familyMembers.length,
                              itemBuilder: (context, index) {
                                final member = _familyMembers[index];
                                final isPrimary =
                                    member.id == _primaryOwner?.id;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isPrimary
                                          ? Colors.green.shade100
                                          : Colors.blue.shade100,
                                      child: Text(
                                        member.initials,
                                        style: TextStyle(
                                          color: isPrimary
                                              ? Colors.green
                                              : Colors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      member.fullName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(member.phoneNumber),
                                        if (isPrimary)
                                          Container(
                                            margin:
                                                const EdgeInsets.only(top: 4),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '👑 Primary Owner',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.green.shade700,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: isPrimary
                                        ? null
                                        : IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.red,
                                            ),
                                            onPressed: () =>
                                                _removeFamilyMember(member),
                                          ),
                                  ),
                                );
                              },
                            ),
                    ),

                  ],
                ),
        ),
      ),
    );
  }
}
