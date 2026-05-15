// lib/screens/farmer/link_device_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/language_service.dart';
import '../../utils/constants.dart';

class LinkDeviceScreen extends StatefulWidget {
  final int animalId;

  const LinkDeviceScreen({super.key, required this.animalId});

  @override
  State<LinkDeviceScreen> createState() => _LinkDeviceScreenState();
}

class _LinkDeviceScreenState extends State<LinkDeviceScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _deviceIdController = TextEditingController();
  final TextEditingController _qrCodeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _linkDevice() async {
    if (_deviceIdController.text.isEmpty) {
      setState(() {
        _errorMessage = context.tr('gps_device_required');
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final deviceId = _deviceIdController.text.trim();

      print('🔍 Step 1: Creating GPS device: $deviceId');

      // STEP 1: Create the GPS device first
      final createResponse = await _apiService.post(AppConstants.devices, {
        'device_id': deviceId,
        'qr_code': _qrCodeController.text.trim().isEmpty
            ? deviceId
            : _qrCodeController.text.trim(),
        'status': 'ACTIVE',
        'battery_level': 100,
      });

      int devicePk;

      if (createResponse.statusCode == 201) {
        // Device created successfully
        devicePk = createResponse.data['id'];
        print('✅ Device created successfully with ID: $devicePk');
      } else if (createResponse.statusCode == 400) {
        // Device might already exist, try to get it
        print('⚠️ Device may already exist, trying to fetch...');

        final getResponse = await _apiService
            .get('${AppConstants.devices}?device_id=$deviceId');

        if (getResponse.statusCode == 200) {
          final devices = getResponse.data['results'] as List;
          if (devices.isNotEmpty) {
            devicePk = devices.first['id'];
            print('✅ Existing device found with ID: $devicePk');
          } else {
            setState(() {
              _errorMessage = '${context.tr('device_not_found')} ($deviceId)';
            });
            setState(() => _isLoading = false);
            return;
          }
        } else {
          throw Exception('Failed to get device');
        }
      } else {
        throw Exception('Failed to create device');
      }

      print('🔗 Step 2: Linking device $devicePk to animal ${widget.animalId}');

      // STEP 2: Link device to animal
      final linkResponse = await _apiService.post(
          '${AppConstants.devices}$devicePk/link_animal/',
          {'animal_id': widget.animalId});

      if (linkResponse.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('gps_linked_success')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        setState(() {
          _errorMessage =
              linkResponse.data['error'] ?? context.tr('gps_link_failed');
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

    return Scaffold(
      appBar: AppBar(
        title: Text(languageService.translate('link_gps_title').toUpperCase()),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.gps_fixed, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            Text(
              languageService.translate('enter_gps_device_id'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              languageService.translate('gps_device_help'),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _deviceIdController,
              decoration: InputDecoration(
                labelText: 'Device ID',
                hintText: languageService.translate('device_id_hint'),
                prefixIcon: const Icon(Icons.gps_fixed),
                border: const OutlineInputBorder(),
                helperText: languageService.translate('device_id_helper'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _qrCodeController,
              decoration: InputDecoration(
                labelText: languageService.translate('qr_code_optional'),
                hintText: languageService.translate('qr_hint'),
                prefixIcon: const Icon(Icons.qr_code),
                border: const OutlineInputBorder(),
              ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
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
                onPressed: _isLoading ? null : _linkDevice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        languageService
                            .translate('link_device_button')
                            .toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
