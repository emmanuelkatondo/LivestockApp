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
      _reportData = null;
    });

    try {
      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 30));

      final payload = {
        'start_date': startDate.toIso8601String(),
        'end_date': now.toIso8601String(),
      };
 
      print(' Generating report with: $payload');

      final response = await _apiService.post(
        '${AppConstants.reports}generate_population/',
        payload,
      );

      print('Report response status: ${response.statusCode}');
      print('Report response data: ${response.data}');

      if (response.statusCode == 200) {

        final data = response.data;

        final report = {
          'report_type': data['report_type'] ?? 'POPULATION',
          'start_date': data['start_date'] ?? startDate.toIso8601String(),
          'end_date': data['end_date'] ?? now.toIso8601String(),
          'total_animals': data['total_animals'] ?? 0,
          'animals_by_type': data['animals_by_type'] ?? {},
          'animals_by_status': data['animals_by_status'] ?? {},
          'stolen_reported': data['stolen_reported'] ?? 0,
          'generated_at': data['generated_at'] ?? now.toIso8601String(),
        };
        setState(() {
          _reportData = report;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('report_generated_success')),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _errorMessage = response.data['error'] ??
              response.data['message'] ??
              context.tr('report_generate_failed');
        });
      }
    } catch (e) {
      print('Report error: $e');
      setState(() {
        _errorMessage = '${context.tr('error')}: $e';
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
      selectedIndex: 4,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bar_chart,
                        size: 48,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      languageService.translate('population_report'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      languageService
                          .translate('generate_population_report_desc'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isGenerating ? null : _generateReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isGenerating
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                languageService.translate('generate_report'),
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
            ),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.all(14),
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
                          style: TextStyle(color: Colors.red.shade700),
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

            if (_reportData != null) ...[
              const SizedBox(height: 24),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.insert_chart,
                              color: Color(0xFF2E7D32),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            languageService.translate('report_results'),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // Total Animals
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _buildReportRow(
                          languageService.translate('total_animals'),
                          _reportData!['total_animals']?.toString() ?? '0',
                          isBold: true,
                          valueColor: Colors.green.shade700,
                        ),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        languageService.translate('animals_by_type'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_reportData!['animals_by_type'] != null &&
                          (_reportData!['animals_by_type'] as Map).isNotEmpty)
                        ...(_reportData!['animals_by_type']
                                as Map<String, dynamic>)
                            .entries
                            .map((entry) {
                          return _buildReportRow(
                            _getTypeName(entry.key),
                            entry.value.toString(),
                          );
                        }).toList()
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No animals by type',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13,
                            ),
                          ),
                        ),

                      const SizedBox(height: 16),

                      Text(
                        languageService.translate('animals_by_status'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_reportData!['animals_by_status'] != null &&
                          (_reportData!['animals_by_status'] as Map).isNotEmpty)
                        ...(_reportData!['animals_by_status']
                                as Map<String, dynamic>)
                            .entries
                            .map((entry) {
                          return _buildReportRow(
                            _getStatusName(entry.key),
                            entry.value.toString(),
                            status: entry.key,
                          );
                        }).toList()
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No animals by status',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13,
                            ),
                          ),
                        ),

                      const Divider(height: 24),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: _buildReportRow(
                          languageService.translate('stolen_animals'),
                          _reportData!['stolen_reported']?.toString() ?? '0',
                          isBold: true,
                          valueColor: Colors.red.shade700,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Generated At
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${languageService.translate('generated_at')}: ${_formatDateTime(_reportData!['generated_at'] != null ? DateTime.parse(_reportData!['generated_at']) : DateTime.now())}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
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
      {String? status, bool isBold = false, Color? valueColor}) {
    // Determine color if not explicitly passed
    if (valueColor == null && status != null) {
      switch (status) {
        case 'STOLEN':
          valueColor = Colors.red;
          break;
        case 'ACTIVE':
          valueColor = Colors.green;
          break;
        case 'SOLD':
          valueColor = Colors.blue;
          break;
        case 'DEAD':
          valueColor = Colors.red.shade900;
          break;
        default:
          valueColor = Colors.black;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              fontSize: isBold ? 15 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              color: valueColor ?? Colors.black,
              fontSize: isBold ? 15 : 14,
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
