import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/language_service.dart';
import '../../models/alert_model.dart';
import '../../utils/constants.dart';
import '../base_screen.dart';

class AllAlertsScreen extends StatefulWidget {
  const AllAlertsScreen({super.key});

  @override
  State<AllAlertsScreen> createState() => _AllAlertsScreenState();
}

class _AllAlertsScreenState extends State<AllAlertsScreen> {
  final ApiService _apiService = ApiService();

  List<AlertModel> _alerts = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'ALL';

  final List<Map<String, String>> _filters = [
    {'value': 'ALL', 'label': 'All'},
    {'value': 'THEFT', 'label': 'Theft'},
    {'value': 'LOST', 'label': 'Lost'},
    {'value': 'GENERAL', 'label': 'General'},
  ];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.get(AppConstants.alerts);

      print('📥 Alerts response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['results'] ?? [];
        _alerts = data.map((json) => AlertModel.fromJson(json)).toList();
        print('✅ Loaded ${_alerts.length} alerts');
      }
    } catch (e) {
      print('❌ Error loading alerts: $e');
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<AlertModel> get _filteredAlerts {
    if (_selectedFilter == 'ALL') return _alerts;
    return _alerts.where((a) => a.alertType == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);

    return BaseScreen(
      title: 'All Alerts',
      selectedIndex: 5, // Index for Alerts in menu (Ag Officer)
      child: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: _filters.map((filter) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter['label']!),
                    selected: _selectedFilter == filter['value'],
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = filter['value']!;
                      });
                    },
                    selectedColor: const Color(0xFF2E7D32).withOpacity(0.2),
                    checkmarkColor: const Color(0xFF2E7D32),
                  ),
                );
              }).toList(),
            ),
          ),

          // Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(_errorMessage!),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadAlerts,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                              ),
                              child: Text(languageService.translate('retry')),
                            ),
                          ],
                        ),
                      )
                    : _filteredAlerts.isEmpty
                        ? Center(
                            child: Text(
                              languageService.translate('no_alerts'),
                              style: const TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _filteredAlerts.length,
                            itemBuilder: (context, index) {
                              final alert = _filteredAlerts[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                color: alert.isRead
                                    ? Colors.white
                                    : Colors.blue.shade50,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: !alert.isRead
                                      ? BorderSide(
                                          color: Colors.blue.shade300, width: 1)
                                      : BorderSide.none,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            _getAlertIcon(alert.alertType),
                                            color:
                                                _getAlertColor(alert.alertType),
                                            size: 24,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              alert.title,
                                              style: TextStyle(
                                                fontWeight: !alert.isRead
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          if (!alert.isRead)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.blue,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Text(
                                                'NEW',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        alert.message,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          if (alert.animalName != null)
                                            Chip(
                                              label: Text(alert.animalName!),
                                              backgroundColor:
                                                  Colors.grey.shade200,
                                              labelStyle:
                                                  const TextStyle(fontSize: 11),
                                            ),
                                          const SizedBox(width: 8),
                                          if (alert.userName != null)
                                            Chip(
                                              label: Text(alert.userName!),
                                              backgroundColor:
                                                  Colors.grey.shade200,
                                              labelStyle:
                                                  const TextStyle(fontSize: 11),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _formatDateTime(alert.createdAt),
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  IconData _getAlertIcon(String type) {
    switch (type) {
      case 'LOST':
        return Icons.location_off;
      case 'THEFT':
        return Icons.warning;
      case 'GENERAL':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }

  Color _getAlertColor(String type) {
    switch (type) {
      case 'LOST':
        return Colors.orange;
      case 'THEFT':
        return Colors.red;
      case 'GENERAL':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }
}
