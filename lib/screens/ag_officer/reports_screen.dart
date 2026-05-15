import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/language_service.dart';
import '../../utils/constants.dart';
import '../base_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ApiService _apiService = ApiService();

  bool _isGenerating = false;
  String? _errorMessage;
  Map<String, dynamic>? _reportData;

  Future<void> _generateReport() async {
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService
          .post('${AppConstants.reports}generate_population/', {});

      print('Report response status: ${response.statusCode}');
      print('Report response data: ${response.data}');

      if (response.statusCode == 200) {
        setState(() {
          _reportData = response.data;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('report_generated_success')),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _errorMessage =
              response.data['error'] ?? context.tr('report_generate_failed');
        });
      }
    } catch (e) {
      print('Report error: $e');
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);

    return BaseScreen(
      title: 'Reports',
      selectedIndex: 4, // Index for Reports in menu
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Generate Button
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.bar_chart,
                        size: 48, color: Color(0xFF2E7D32)),
                    const SizedBox(height: 16),
                    Text(
                      languageService.translate('population_report'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      languageService
                          .translate('generate_population_report_desc'),
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isGenerating ? null : _generateReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                        ),
                        child: _isGenerating
                            ? const CircularProgressIndicator()
                            : Text(
                                languageService.translate('generate_report')),
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
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ),

            if (_reportData != null) ...[
              const SizedBox(height: 24),

              // Report Results
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        languageService.translate('report_results'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(),

                      // Total Animals
                      _buildReportRow(
                        languageService.translate('total_animals'),
                        _reportData!['total_animals'].toString(),
                      ),

                      const SizedBox(height: 12),

                      // By Type
                      Text(
                        languageService.translate('animals_by_type'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_reportData!['animals_by_type'] != null)
                        ...(_reportData!['animals_by_type']
                                as Map<String, dynamic>)
                            .entries
                            .map((entry) {
                          return _buildReportRow(
                            _getTypeName(entry.key),
                            entry.value.toString(),
                          );
                        }).toList(),

                      const SizedBox(height: 12),

                      // By Status
                      Text(
                        languageService.translate('animals_by_status'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_reportData!['animals_by_status'] != null)
                        ...(_reportData!['animals_by_status']
                                as Map<String, dynamic>)
                            .entries
                            .map((entry) {
                          return _buildReportRow(
                            _getStatusName(entry.key),
                            entry.value.toString(),
                            status: entry.key,
                          );
                        }).toList(),

                      const Divider(),

                      // Stolen
                      _buildReportRow(
                        languageService.translate('stolen_animals'),
                        _reportData!['stolen_reported'].toString(),
                        isBold: true,
                      ),

                      const SizedBox(height: 16),

                      // Generated At
                      Text(
                        '${languageService.translate('generated_at')}: ${_formatDateTime(DateTime.parse(_reportData!['generated_at']))}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReportRow(String label, String value,
      {String? status, bool isBold = false}) {
    Color? valueColor;
    if (status == 'STOLEN') {
      valueColor = Colors.red;
    } else if (status == 'ACTIVE') {
      valueColor = Colors.green;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  String _getTypeName(String type) {
    switch (type) {
      case 'CATTLE':
        return 'Ng\'ombe';
      case 'GOAT':
        return 'Mbuzi';
      case 'SHEEP':
        return 'Kondoo';
      default:
        return type;
    }
  }

  String _getStatusName(String status) {
    switch (status) {
      case 'ACTIVE':
        return 'Active';
      case 'STOLEN':
        return 'Stolen';
      case 'SOLD':
        return 'Sold';
      case 'DEAD':
        return 'Dead';
      case 'SLAUGHTERED':
        return 'Slaughtered';
      default:
        return status;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
