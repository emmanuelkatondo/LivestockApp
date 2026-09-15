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
  bool _isSearching = false;
  String? _errorMessage;
  String? _successMessage;
  Map<String, dynamic>? _foundUser;

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
      _successMessage = null;
      _foundUser = null;
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

      // ========== TUMIA ENDPOINT YA SEARCH BY PHONE ==========
      print('Searching for recipient with phone: $phoneNumber');

      final searchResponse = await _apiService
          .get('${AppConstants.searchByPhone}?phone=$phoneNumber');

      print('Search response status: ${searchResponse.statusCode}');
      print('Search response data: ${searchResponse.data}');

      if (searchResponse.statusCode == 200) {
        final recipientUser = searchResponse.data;
        final toUserId = recipientUser['id'] as int?;
        final recipientPhone = recipientUser['phone'] as String?;
        final recipientName = recipientUser['first_name'] as String?;

        print('RECIPIENT FOUND:');
        print('   ID: $toUserId');
        print('   Phone: $recipientPhone');
        print('   Name: $recipientName');

        // Set found user for display
        setState(() {
          _foundUser = recipientUser;
        });

        if (toUserId == null) {
          print('Recipient ID is null!');
          setState(() {
            _errorMessage = context.tr('invalid_recipient_phone');
          });
          setState(() => _isLoading = false);
          return;
        }

        // ========== SELF-TRANSFER CHECK ==========
        final currentUserId = currentUser?['id'] as int?;
        if (toUserId == currentUserId) {
          print('SELF TRANSFER DETECTED!');
          setState(() {
            _errorMessage = context.tr('self_transfer_error');
          });
          setState(() => _isLoading = false);
          return;
        }
     
        print('Self transfer check passed. Proceeding...');

        // Create ransfer request
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
          print('Transfer initiated successfully!');
          setState(() {
            _successMessage = context.tr('request_sent_success');
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('request_sent_success')),
              backgroundColor: Colors.green,
            ),
          );

          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.pop(context, true);
            }
          });
        } else {
          print('Transfer failed with status ${response.statusCode}');
          setState(() {
            _errorMessage =
                response.data['error'] ?? context.tr('transfer_failed');
          });
        }
      } else if (searchResponse.statusCode == 400 ||
          searchResponse.statusCode == 404) {
        final errorMsg = searchResponse.data['error'] ?? 'User not found';
        print('Error: $errorMsg');
        setState(() {
          _errorMessage = errorMsg;
        });
      } else {
        setState(() {
          _errorMessage = context.tr('recipient_not_found');
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
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
                          Text(
                            widget.animal.animalId,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Chip(
                            label: Text(
                              languageService.translate(
                                  widget.animal.status.toLowerCase()),
                            ),
                            backgroundColor:
                                widget.animal.statusColor.withOpacity(0.1),
                            labelStyle:
                                TextStyle(color: widget.animal.statusColor),
                            padding: EdgeInsets.zero,
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
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        labelText:
                            languageService.translate('recipient_phone_number'),
                        hintText: languageService.translate('phone_hint'),
                        prefixIcon: const Icon(Icons.person_add),
                        border: const OutlineInputBorder(),
                        suffixIcon: _foundUser != null
                            ? const Icon(Icons.check_circle,
                                color: Colors.green)
                            : null,
                      ),
                      onChanged: (value) {
               
                        if (_foundUser != null) {
                          setState(() {
                            _foundUser = null;
                            _errorMessage = null;
                          });
                        }
                      },
                    ),

                    // Show found user info
                    if (_foundUser != null)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person, color: Colors.green),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _foundUser!['first_name'] ?? 'Unknown',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _foundUser!['phone'] ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.check_circle, color: Colors.green),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Notes
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      enabled: !_isLoading,
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
                        onPressed: _isLoading ? null : _initiateTransfer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                languageService
                                    .translate('start_transfer')
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
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
