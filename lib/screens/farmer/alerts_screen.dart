import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/language_service.dart';
import '../../models/alert_model.dart';
import '../../utils/constants.dart';
import '../base_screen.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final ApiService _apiService = ApiService();

  List<AlertModel> _alerts = [];
  bool _isLoading = true;
  String? _errorMessage;

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

      print('Alerts response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['results'] ?? [];
        _alerts = data.map((json) => AlertModel.fromJson(json)).toList();
        print(' Loaded ${_alerts.length} alerts');
      }
    } catch (e) {
      print('Error loading alerts: $e');
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(int alertId) async {
    try {
      await _apiService.post('${AppConstants.alerts}$alertId/mark_read/', {});
      setState(() {
        final index = _alerts.indexWhere((a) => a.id == alertId);
        if (index != -1) {
          _alerts[index].isRead = true;
        }
      });
    } catch (e) {
      print('Error marking alert as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);

    return BaseScreen(
      title: 'Alerts',
      selectedIndex: 4, 
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
              : _alerts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.notifications_none,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            languageService.translate('no_alerts'),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _alerts.length,
                      itemBuilder: (context, index) {
                        final alert = _alerts[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color:
                              alert.isRead ? Colors.white : Colors.blue.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: !alert.isRead
                                ? BorderSide(
                                    color: Colors.blue.shade300, width: 1)
                                : BorderSide.none,
                          ),
                          child: InkWell(
                            onTap: () {
                              if (!alert.isRead) {
                                _markAsRead(alert.id);
                              }
                              _showAlertDialog(alert);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _getAlertIcon(alert.alertType),
                                        color: _getAlertColor(alert.alertType),
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
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            languageService.translate('new'),
                                            style: const TextStyle(
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
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
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
                          ),
                        );
                      },
                    ),
    );
  }

  void _showAlertDialog(AlertModel alert) {
    final languageService =
        Provider.of<LanguageService>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(_getAlertIcon(alert.alertType),
                color: _getAlertColor(alert.alertType)),
            const SizedBox(width: 12),
            Expanded(child: Text(alert.title)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alert.message),
            const SizedBox(height: 16),
            Text(
              _formatDateTime(alert.createdAt),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(languageService.translate('close')),
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
