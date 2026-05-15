import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/language_service.dart';

class ImagePickerWidget extends StatefulWidget {
  final Function(File?) onImageSelected;
  final String? initialImageUrl;
  final double size;

  const ImagePickerWidget({
    super.key,
    required this.onImageSelected,
    this.initialImageUrl,
    this.size = 120,
  });

  @override
  State<ImagePickerWidget> createState() => _ImagePickerWidgetState();
}

class _ImagePickerWidgetState extends State<ImagePickerWidget> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
        widget.onImageSelected(_selectedImage);
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  void _showImageSourceDialog() {
    final languageService =
        Provider.of<LanguageService>(context, listen: false);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(languageService.translate('take_photo')),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(languageService.translate('choose_from_gallery')),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showImageSourceDialog,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ClipOval(
          child: _selectedImage != null
              ? Image.file(
                  _selectedImage!,
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.cover,
                )
              : widget.initialImageUrl != null
                  ? Image.network(
                      widget.initialImageUrl!,
                      width: widget.size,
                      height: widget.size,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholder();
                      },
                    )
                  : _buildPlaceholder(),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    final languageService = Provider.of<LanguageService>(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.camera_alt,
          size: widget.size * 0.3,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 4),
        Text(
          languageService.translate('add_photo'),
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
