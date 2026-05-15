// lib/screens/farmer/transfer_ownership_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../models/animal_model.dart';
import '../../services/api_service.dart';
import '../../services/language_service.dart';
import '../../utils/constants.dart';

class TransferOwnershipScreen extends StatefulWidget {
  final AnimalModel animal;

  const TransferOwnershipScreen({
    super.key,
    required this.animal,
  });

  @override
  State<TransferOwnershipScreen> createState() =>
      _TransferOwnershipScreenState();
}

class _TransferOwnershipScreenState extends State<TransferOwnershipScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // ========== HELPER METHOD - Get Current User ID ==========
  Future<int?> _getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString(AppConstants.userDataKey);
    if (userString != null && userString.isNotEmpty) {
      try {
        final Map<String, dynamic> userData = jsonDecode(userString);
        return userData['id'] as int?;
      } catch (e) {
        print('Error getting user ID: $e');
        return null;
      }
    }
    return null;
  }
  // ==========================================================

  Future<void> _initiateTransfer() async {
    print('========== TRANSFER DEBUG START ==========');
    print('📱 Phone entered: "${_phoneController.text}"');

    if (_phoneController.text.isEmpty) {
      setState(() {
        _errorMessage = context.tr('recipient_phone_required');
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Clean the phone number
      String phoneNumber = _phoneController.text.trim();
      phoneNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');

      print('📱 Cleaned phone: $phoneNumber');

      // Format the phone number to start with 255
      if (phoneNumber.startsWith('0')) {
        phoneNumber = '255${phoneNumber.substring(1)}';
        print('📱 Converted from 0... to: $phoneNumber');
      } else if (phoneNumber.startsWith('+')) {
        phoneNumber = phoneNumber.substring(1);
        print('📱 Removed + to: $phoneNumber');
      } else if (phoneNumber.startsWith('7') || phoneNumber.startsWith('6')) {
        phoneNumber = '255$phoneNumber';
        print('📱 Added 255 to: $phoneNumber');
      }

      // Get current user
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString(AppConstants.userDataKey);
      Map<String, dynamic>? currentUser;

      if (userString != null) {
        currentUser = jsonDecode(userString);
        print('👤 CURRENT USER:');
        print('   ID: ${currentUser?['id']}');
        print('   Phone: ${currentUser?['phone']}');
        print('   Name: ${currentUser?['first_name']}');
      }

      // Find recipient user
      print('Searching for recipient with phone: $phoneNumber');

      final usersResponse =
          await _apiService.get('${AppConstants.users}?phone=$phoneNumber');

      print('API Response status: ${usersResponse.statusCode}');

      List<dynamic> users = [];
      if (usersResponse.data is List) {
        users = usersResponse.data;
        print('Data is List, length: ${users.length}');
      } else if (usersResponse.data is Map &&
          usersResponse.data.containsKey('results')) {
        users = usersResponse.data['results'];
        print('Data has results, length: ${users.length}');
      }

      if (users.isEmpty) {
        print(' No user found with phone: $phoneNumber');
        setState(() {
          _errorMessage = context.tr('recipient_not_found');
        });
        setState(() => _isLoading = false);
        return;
      }

      final recipientUser = users.first;
      final toUserId = recipientUser['id'] as int?;
      final recipientPhone = recipientUser['phone'] as String?;
      final recipientName = recipientUser['first_name'] as String?;

      final currentUserId = currentUser?['id'] as int?;

      print('RECIPIENT FOUND:');
      print('   ID: $toUserId');
      print('   Phone: $recipientPhone');
      print('   Name: $recipientName');
      print('Current user ID: $currentUserId');

      // Check if trying to transfer to self
      if (toUserId != null &&
          currentUserId != null &&
          toUserId == currentUserId) {
        print('SELF TRANSFER DETECTED!');
        setState(() {
          _errorMessage = context.tr('self_transfer_error');
        });
        setState(() => _isLoading = false);
        return;
      }

      if (toUserId == null) {
        print('Recipient ID is null!');
        setState(() {
          _errorMessage = context.tr('invalid_recipient_phone');
        });
        setState(() => _isLoading = false);
        return;
      }

      print('Self transfer check passed. Proceeding...');

      // Create transfer request
      final transferData = {
        'animal': widget.animal.id,
        'to_user': toUserId,
        'notes': _notesController.text.trim(),
      };

      print('Sending transfer data: $transferData');

      final response =
          await _apiService.post(AppConstants.transfers, transferData);

      print('Transfer response status: ${response.statusCode}');
      print('Transfer response data: ${response.data}');

      if (response.statusCode == 201) {
        print(' Transfer initiated successfully!');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('request_sent_success')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        print('Transfer failed with status ${response.statusCode}');
        setState(() {
          _errorMessage =
              response.data['error'] ?? context.tr('transfer_failed');
        });
      }
    } catch (e) {
      print('Transfer error: $e');
      setState(() {
        _errorMessage = '${context.tr('error')}: $e';
      });
    } finally {
      print('========== TRANSFER DEBUG END ==========');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${languageService.translate('transfer_ownership')} - ${widget.animal.name}'),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Animal Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Center(
                        child: Text(
                          _getAnimalIcon(widget.animal.type),
                          style: const TextStyle(fontSize: 30),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.animal.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(widget.animal.animalId),
                          Chip(
                            label: Text(languageService
                                .translate(widget.animal.status.toLowerCase())),
                            backgroundColor:
                                widget.animal.statusColor.withOpacity(0.1),
                            labelStyle:
                                TextStyle(color: widget.animal.statusColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Transfer Form
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      languageService
                          .translate('transfer_details_upper')
                          .toUpperCase(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Recipient Phone
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText:
                            languageService.translate('recipient_phone_number'),
                        hintText: languageService.translate('phone_hint'),
                        prefixIcon: const Icon(Icons.person_add),
                        border: const OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Notes
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: languageService.translate('notes_optional'),
                        prefixIcon: const Icon(Icons.note),
                        border: const OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Info Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              languageService.translate('transfer_notice'),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
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
                              const Icon(Icons.check_circle,
                                  color: Colors.green),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _successMessage!,
                                  style: const TextStyle(color: Colors.green),
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
                        onPressed: _isLoading ? null : _initiateTransfer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : Text(languageService
                                .translate('start_transfer')
                                .toUpperCase()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getAnimalIcon(String type) {
    switch (type) {
      case 'CATTLE':
        return '🐄';
      case 'GOAT':
        return '🐐';
      case 'SHEEP':
        return '🐑';
      default:
        return '🐾';
    }
  }
}
