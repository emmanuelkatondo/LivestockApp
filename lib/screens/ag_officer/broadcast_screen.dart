import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/language_service.dart';
import '../../utils/constants.dart';
import '../base_screen.dart';

class BroadcastScreen extends StatefulWidget {
  const BroadcastScreen({super.key});

  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  bool _isSending = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendBroadcast() async {
    if (_titleController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = context.tr('message_title_required');
      });
      return;
    }

    if (_messageController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = context.tr('message_required');
      });
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final response = await _apiService.post(AppConstants.broadcasts, {
        'title': _titleController.text.trim(),
        'message': _messageController.text.trim(),
      });

      print('Broadcast response status: ${response.statusCode}');
      print('Broadcast response data: ${response.data}');

      if (response.statusCode == 201) {
        setState(() {
          _successMessage = context.tr('broadcast_success_all');
        });
        _titleController.clear();
        _messageController.clear();

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _successMessage = null;
            });
          }
        });
      } else {
        setState(() {
          _errorMessage =
              response.data['error'] ?? context.tr('broadcast_failed');
        });
      }
    } catch (e) {
      print('Broadcast error: $e');
      setState(() {
        _errorMessage = '${context.tr('error')}: $e';
      });
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final languageService = Provider.of<LanguageService>(context);

    return BaseScreen(
      title: 'Broadcast Message',
      selectedIndex: 3, // Index for Broadcast in menu
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.purple.shade50,
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Icon and Title
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.broadcast_on_home,
                        size: isSmallScreen ? 50 : 60,
                        color: Colors.purple.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      languageService
                          .translate('broadcast_header')
                          .toUpperCase(),
                      style: TextStyle(
                        fontSize: isSmallScreen ? 18 : 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      languageService.translate('broadcast_subtitle'),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        languageService.translate('broadcast_description'),
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Title Field
              Text(
                languageService.translate('message_title').toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: languageService.translate('message_title_hint'),
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.title, color: Colors.purple),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Message Field
              Text(
                languageService.translate('your_message').toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _messageController,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: languageService.translate('message_hint'),
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.message, color: Colors.purple),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Preview Section
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Preview Header
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.preview,
                              size: 18, color: Colors.purple.shade700),
                          const SizedBox(width: 8),
                          Text(
                            languageService
                                .translate('message_preview')
                                .toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Preview Content
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_titleController.text.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: Colors.purple.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.title,
                                      size: 16, color: Colors.purple.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _titleController.text,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.purple.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (_titleController.text.isNotEmpty)
                            const SizedBox(height: 12),
                          if (_messageController.text.isNotEmpty)
                            Text(
                              _messageController.text,
                              style: const TextStyle(fontSize: 14, height: 1.5),
                            ),
                          if (_titleController.text.isEmpty &&
                              _messageController.text.isEmpty)
                            Column(
                              children: [
                                Icon(Icons.edit_note,
                                    size: 40, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text(
                                  languageService.translate('preview_empty'),
                                  style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                        ],
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
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 13),
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
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: const TextStyle(
                                color: Colors.green, fontSize: 13),
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

              // Send Button
              Container(
                width: double.infinity,
                height: 55,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.purple.shade600,
                      Colors.purple.shade800,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isSending ? null : _sendBroadcast,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSending
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.send, color: Colors.white),
                            const SizedBox(width: 10),
                            Text(
                              languageService
                                  .translate('send_message')
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Note
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline,
                        size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(
                      languageService.translate('broadcast_footer'),
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
