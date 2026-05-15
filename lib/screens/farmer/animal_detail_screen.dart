import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import '../../models/animal_model.dart';
import '../../services/api_service.dart';
import '../../services/language_service.dart';
import '../../utils/constants.dart';
import 'location_history_screen.dart';
import 'transfer_ownership_screen.dart';
import 'link_device_screen.dart';

class AnimalDetailScreen extends StatefulWidget {
  final AnimalModel animal;

  const AnimalDetailScreen({
    super.key,
    required this.animal,
  });

  @override
  State<AnimalDetailScreen> createState() => _AnimalDetailScreenState();
}

class _AnimalDetailScreenState extends State<AnimalDetailScreen> {
  final ApiService _apiService = ApiService();
  bool _isUpdating = false;
  bool _isEditing = false;
  String? _selectedStatus;
  File? _selectedImage;

  // Controllers for editing
  late TextEditingController _nameController;
  late TextEditingController _colorController;
  late TextEditingController _notesController;
  late String _selectedType;

  final List<Map<String, String>> _statusOptions = [
    {'value': 'ACTIVE', 'labelKey': 'active', 'color': 'green'},
    {'value': 'SOLD', 'labelKey': 'sold', 'color': 'blue'},
    {'value': 'SLAUGHTERED', 'labelKey': 'slaughtered', 'color': 'orange'},
    {'value': 'DEAD', 'labelKey': 'dead', 'color': 'red'},
    {'value': 'STOLEN', 'labelKey': 'stolen', 'color': 'red'},
  ];

  final List<Map<String, String>> _animalTypes = [
    {'value': 'CATTLE', 'labelKey': 'cattle'},
    {'value': 'GOAT', 'labelKey': 'goat'},
    {'value': 'SHEEP', 'labelKey': 'sheep'},
    {'value': 'OTHER', 'labelKey': 'other'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.animal.name);
    _colorController = TextEditingController(text: widget.animal.color ?? '');
    _notesController = TextEditingController(text: widget.animal.notes ?? '');
    _selectedType = widget.animal.type;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _colorController.dispose();
    _notesController.dispose();
    super.dispose();
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

  Future<void> _updateAnimal() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('animal_name_required'))),
      );
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      // ========== FIXED: Create FormData correctly ==========
      final formData = FormData();

      // Add text fields
      formData.fields.add(MapEntry('name', _nameController.text.trim()));
      formData.fields.add(MapEntry('type', _selectedType));
      formData.fields.add(MapEntry('color', _colorController.text.trim()));
      formData.fields.add(MapEntry('notes', _notesController.text.trim()));

      // Add image if selected
      if (_selectedImage != null) {
        final fileName = _selectedImage!.path.split('/').last;
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
      // ======================================================

      final response = await _apiService.putMultipart(
        '${AppConstants.animals}${widget.animal.id}/',
        formData,
      );

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('animal_update_success')),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _isEditing = false;
        });
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Update error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.tr('animal_update_failed')}: $e')),
      );
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  Future<void> _updateStatus() async {
    if (_selectedStatus == null || _selectedStatus == widget.animal.status)
      return;

    setState(() {
      _isUpdating = true;
    });

    try {
      final response = await _apiService.patch(
        '${AppConstants.animals}${widget.animal.id}/update_status/',
        {'status': _selectedStatus},
      );

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('status_update_success')),
            backgroundColor: Color.fromARGB(255, 32, 112, 35),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.tr('status_update_failed')}: $e')),
      );
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  Future<void> _deleteAnimal() async {
    // Confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('confirm_delete')),
        content: Text(context.tr('animal_delete_confirm')),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(context.tr('delete')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      final response = await _apiService
          .delete('${AppConstants.animals}${widget.animal.id}/');

      if (response.statusCode == 204 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('animal_deleted_success')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.tr('delete_failed')}: $e')),
      );
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final statusColor = widget.animal.statusColor;

    return Scaffold(
      appBar: AppBar(
        title: _isEditing
            ? Text(languageService.translate('edit_livestock'))
            : Text(widget.animal.name),
        actions: [
          if (!_isEditing)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  setState(() {
                    _isEditing = true;
                  });
                } else if (value == 'delete') {
                  _deleteAnimal();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(Icons.edit, size: 20),
                      const SizedBox(width: 8),
                      Text(languageService.translate('edit')),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete, size: 20, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(languageService.translate('delete'),
                          style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isEditing ? _buildEditForm() : _buildViewForm(statusColor),
    );
  }

  Widget _buildViewForm(Color statusColor) {
    final languageService = Provider.of<LanguageService>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Animal Photo
          Center(
            child: GestureDetector(
              onTap: () {
                if (widget.animal.photoUrl.isNotEmpty) {
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      child: Image.network(
                        widget.animal.photoUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 200,
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Icon(Icons.error,
                                  size: 50, color: Colors.grey),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }
              },
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(75),
                  border: Border.all(color: statusColor, width: 3),
                ),
                child: ClipOval(
                  child: widget.animal.photoUrl.isNotEmpty
                      ? Image.network(
                          widget.animal.photoUrl,
                          width: 150,
                          height: 150,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Icon(
                                Icons.pets,
                                size: 60,
                                color: statusColor,
                              ),
                            );
                          },
                        )
                      : Center(
                          child: Icon(
                            Icons.pets,
                            size: 60,
                            color: statusColor,
                          ),
                        ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Animal Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInfoRow(
                    icon: Icons.tag,
                    label: languageService.translate('livestock_number'),
                    value: widget.animal.animalId,
                  ),
                  const Divider(),
                  _buildInfoRow(
                    icon: Icons.category,
                    label: languageService.translate('type'),
                    value: _getTypeName(widget.animal.type),
                  ),
                  if (widget.animal.color != null &&
                      widget.animal.color!.isNotEmpty)
                    const Divider(),
                  if (widget.animal.color != null &&
                      widget.animal.color!.isNotEmpty)
                    _buildInfoRow(
                      icon: Icons.color_lens,
                      label: languageService.translate('color'),
                      value: widget.animal.color!,
                    ),
                  const Divider(),
                  _buildInfoRow(
                    icon: Icons.info,
                    label: languageService.translate('status'),
                    value: languageService
                        .translate(widget.animal.status.toLowerCase()),
                    valueColor: statusColor,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Status Update
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    languageService.translate('change_status'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedStatus ?? widget.animal.status,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    items: _statusOptions.map((status) {
                      return DropdownMenuItem<String>(
                        value: status['value'],
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _getStatusColor(status['value']!),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                                languageService.translate(status['labelKey']!)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_selectedStatus != null &&
                      _selectedStatus != widget.animal.status)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isUpdating ? null : _updateStatus,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: _isUpdating
                            ? const CircularProgressIndicator()
                            : Text(languageService.translate('change_status')),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            LocationHistoryScreen(animal: widget.animal),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history),
                  label: Text(languageService.translate('location_history')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            TransferOwnershipScreen(animal: widget.animal),
                      ),
                    );
                  },
                  icon: const Icon(Icons.swap_horiz),
                  label: Text(languageService.translate('transfer_ownership')),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            LinkDeviceScreen(animalId: widget.animal.id),
                      ),
                    ).then((_) => setState(() {}));
                  },
                  icon: const Icon(Icons.gps_fixed),
                  label: Text(languageService.translate('link_gps_device')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            LocationHistoryScreen(animal: widget.animal),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history),
                  label: Text(languageService.translate('history')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    final languageService = Provider.of<LanguageService>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo picker
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(75),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _selectedImage != null
                    ? ClipOval(
                        child: Image.file(
                          _selectedImage!,
                          width: 150,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                      )
                    : widget.animal.photoUrl.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              widget.animal.photoUrl,
                              width: 150,
                              height: 150,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.camera_alt,
                                    size: 50, color: Colors.grey);
                              },
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.camera_alt,
                                  size: 50, color: Colors.grey),
                              const SizedBox(height: 8),
                              Text(languageService.translate('change_picture')),
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
              labelText: languageService.translate('name_of_livestock'),
              prefixIcon: const Icon(Icons.pets),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Animal Type
          DropdownButtonFormField<String>(
            value: _selectedType,
            decoration: InputDecoration(
              labelText: languageService.translate('type_of_livestock'),
              prefixIcon: const Icon(Icons.category),
              border: const OutlineInputBorder(),
            ),
            items: _animalTypes.map((type) {
              return DropdownMenuItem<String>(
                value: type['value'],
                child: Text(languageService.translate(type['labelKey']!)),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedType = value!;
              });
            },
          ),
          const SizedBox(height: 16),

          // Color
          TextField(
            controller: _colorController,
            decoration: InputDecoration(
              labelText: languageService.translate('color'),
              prefixIcon: const Icon(Icons.color_lens),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Notes
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: languageService.translate('description'),
              prefixIcon: const Icon(Icons.note),
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isEditing = false;
                    });
                  },
                  child: Text(languageService.translate('cancel')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isUpdating ? null : _updateAnimal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                  ),
                  child: _isUpdating
                      ? const CircularProgressIndicator()
                      : Text(languageService.translate('save_changes')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTypeName(String type) {
    return context.tr(type.toLowerCase());
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ACTIVE':
        return Colors.green;
      case 'SOLD':
        return Colors.blue;
      case 'SLAUGHTERED':
        return Colors.orange;
      case 'DEAD':
        return Colors.red;
      case 'STOLEN':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
