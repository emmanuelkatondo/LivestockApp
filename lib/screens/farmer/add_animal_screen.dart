import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../services/language_service.dart';
import '../../utils/constants.dart';
import '../base_screen.dart';

class AddAnimalScreen extends StatefulWidget {
  const AddAnimalScreen({super.key});



  @override
  State<AddAnimalScreen> createState() => _AddAnimalScreenState();
}

class _AddAnimalScreenState extends State<AddAnimalScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _selectedType = 'CATTLE';
  File? _selectedImage;
  bool _isLoading = false;
  String? _errorMessage;
  int? _ownerId;

  final List<Map<String, String>> _animalTypes = [
    {'value': 'CATTLE', 'labelKey': 'cattle'},
    {'value': 'GOAT', 'labelKey': 'goat'},
    {'value': 'SHEEP', 'labelKey': 'sheep'},
    {'value': 'OTHER', 'labelKey': 'other'},
  ];

  @override
  void initState() {
    super.initState();
    _loadOwnerProfile();
  }

  Future<void> _loadOwnerProfile() async {
    try {
      final response = await _apiService.get(AppConstants.ownerMe);
      if (response.statusCode == 200) {
        _ownerId = response.data['id'];
        print('Owner ID loaded: $_ownerId');
      }
    } catch (e) {
      print('Failed to load owner profile: $e');
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _submit() async {
    if (_nameController.text.isEmpty) {
      setState(() {
        _errorMessage = context.tr('animal_name_required');
      });
      return;
    }

    if (_ownerId == null) {
      setState(() {
        _errorMessage = 'Please wait, loading your profile...';
      });
      await _loadOwnerProfile();
      if (_ownerId == null) {
        setState(() {
          _errorMessage = 'Failed to load your profile. Please try again.';
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final formData = FormData.fromMap({
        'name': _nameController.text.trim(),
        'type': _selectedType,
        'color': _colorController.text.trim(),
        'notes': _notesController.text.trim(),
        'owner': _ownerId!.toString(), 
      });

      if (_selectedImage != null) {
        final fileName = _selectedImage!.path.split('/').last;
        final fileSize = await _selectedImage!.length();
        print('Uploading image: $fileName, Size: $fileSize bytes');

        formData.files.add(
          MapEntry(
            'photo',
            await MultipartFile.fromFile(
              _selectedImage!.path,
              filename: fileName,
            ),
          ),
        );
      }

      final response =
          await _apiService.postMultipart(AppConstants.animals, formData);

      print('Response status: ${response.statusCode}');
      print('Response data: ${response.data}');

      if (response.statusCode == 201 && mounted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('animal_added_success')),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _errorMessage = context.tr('animal_add_failed');
        });
      }
    } on DioException catch (e) {
      print('Dio error: ${e.message}');
      print('Response data: ${e.response?.data}');
      setState(() {
        if (e.response?.data is Map) {
          final errorData = e.response?.data as Map;
          if (errorData.containsKey('photo')) {
            _errorMessage =
                '${context.tr('image_error')}: ${errorData['photo']}';
          } else if (errorData.containsKey('name')) {
            _errorMessage = '${context.tr('name_error')}: ${errorData['name']}';
          } else if (errorData.containsKey('owner')) {
            _errorMessage = 'Owner field is required. Please try again.';
          } else {
            _errorMessage = context.tr('animal_add_failed');
          }
        } else {
          _errorMessage = context.tr('animal_add_failed');
        }
      });
    } catch (e) {
      print('Error: $e');
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return BaseScreen(
      title: 'Add Animal',
      selectedIndex: 2,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
      
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(60),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: _selectedImage != null
                      ? ClipOval(
                          child: Image.file(
                            _selectedImage!,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt,
                                size: 40, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text(
                              languageService.translate('add_photo'),
                              style: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 12),
                            ),
                          ],
                        ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Animal Name
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: languageService.translate('animal_name'),
                prefixIcon: const Icon(Icons.pets),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: InputDecoration(
                labelText: languageService.translate('animal_type'),
                prefixIcon: const Icon(Icons.category),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              items: _animalTypes.map((type) {
                return DropdownMenuItem<String>(
                  value: type['value'],
                  child: Row(
                    children: [
                      const Icon(Icons.pets, size: 18),
                      const SizedBox(width: 8),
                      Text(languageService
                          .translate(type['labelKey'] ?? 'other')),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedType = value ?? 'CATTLE';
                });
              },
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _colorController,
              decoration: InputDecoration(
                labelText: languageService.translate('animal_color'),
                prefixIcon: const Icon(Icons.color_lens),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: languageService.translate('notes'),
                prefixIcon: const Icon(Icons.note),
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
                filled: true,
                fillColor: Colors.grey.shade50,
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
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        languageService.translate('add_animal'),
                        style: const TextStyle(color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
