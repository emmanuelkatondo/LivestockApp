// lib/screens/farmer/transfer_requests_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/language_service.dart';
import '../../models/user_model.dart';
import '../../utils/constants.dart';
import '../base_screen.dart';
import 'animal_detail_screen.dart';

class TransferRequestsScreen extends StatefulWidget {
  const TransferRequestsScreen({super.key});

  @override
  State<TransferRequestsScreen> createState() => _TransferRequestsScreenState();
}

class _TransferRequestsScreenState extends State<TransferRequestsScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  List<dynamic> _transfers = [];
  bool _isLoading = true;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    _currentUser = await _authService.getCurrentUser();
    _loadTransferRequests();
  }

  Future<void> _loadTransferRequests() async {
    setState(() => _isLoading = true);

    try {
      final response = await _apiService.get(AppConstants.transfers);
      if (response.statusCode == 200) {
        setState(() {
          _transfers = response.data['results'] ?? [];
        });
        print('📥 Loaded ${_transfers.length} transfers');
      }
    } catch (e) {
      print('Error loading transfers: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmTransfer(int transferId) async {
    try {
      final response = await _apiService.post(
        '${AppConstants.transfers}$transferId/confirm/',
        {},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('transfer_accepted')),
            backgroundColor: Colors.green,
          ),
        );
        _loadTransferRequests();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${context.tr('error')}: ${e.toString()}'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _rejectTransfer(int transferId) async {
    try {
      final response = await _apiService.post(
        '${AppConstants.transfers}$transferId/reject/',
        {},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('transfer_rejected')),
            backgroundColor: Colors.orange,
          ),
        );
        _loadTransferRequests();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${context.tr('error')}: ${e.toString()}'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteTransfer(int transferId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('confirm_delete')),
        content: Text(context.tr('delete_transfer_confirm')),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.tr('delete')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response =
          await _apiService.delete('${AppConstants.transfers}$transferId/');

      if (response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('transfer_deleted')),
            backgroundColor: Colors.green,
          ),
        );
        _loadTransferRequests();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${context.tr('error')}: ${e.toString()}'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _showAnimalDetails(Map<String, dynamic> transfer) {
    final languageService =
        Provider.of<LanguageService>(context, listen: false);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Center(
                      child: Icon(Icons.pets, size: 28, color: Colors.green),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      transfer['animal_name'] ??
                          languageService.translate('animal'),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const Divider(),
              _buildDetailRow(languageService.translate('animal_number'),
                  transfer['animal_id']?.toString() ?? '-'),
              _buildDetailRow(languageService.translate('from'),
                  transfer['from_user_name'] ?? '-'),
              _buildDetailRow(languageService.translate('to'),
                  transfer['to_user_name'] ?? '-'),
              _buildDetailRow(languageService.translate('status'),
                  _translateTransferStatus(transfer['status'] ?? '-')),
              _buildDetailRow(
                languageService.translate('initiated_at'),
                transfer['initiated_at'] != null
                    ? _formatDate(transfer['initiated_at'])
                    : '-',
              ),
              if (transfer['confirmed_at'] != null)
                _buildDetailRow(
                  languageService.translate('confirmed_at'),
                  _formatDate(transfer['confirmed_at']),
                ),
              if (transfer['notes'] != null && transfer['notes'].isNotEmpty)
                _buildDetailRow(
                    languageService.translate('details'), transfer['notes']),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(languageService.translate('close')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);

    return BaseScreen(
      title: 'Transfer Requests',
      selectedIndex: 3, // Index for Transfer Requests in menu (Farmer)
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentUser == null
              ? Center(
                  child: Text(languageService.translate('loading_user_data')))
              : _transfers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.swap_horiz,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(languageService.translate('no_transfers')),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _transfers.length,
                      itemBuilder: (context, index) {
                        final transfer = _transfers[index];
                        final isPending = transfer['status'] == 'PENDING';
                        final isExpired = transfer['status'] == 'EXPIRED';
                        final isConfirmed = transfer['status'] == 'CONFIRMED';
                        final isRejected = transfer['status'] == 'REJECTED';

                        final toUserId = transfer['to_user'];
                        final currentUserId = _currentUser?.id;
                        final isRecipient = currentUserId != null &&
                            toUserId.toString() == currentUserId.toString();

                        final showActions =
                            isPending && !isExpired && isRecipient;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: isPending && isRecipient
                                ? BorderSide(
                                    color: Colors.orange.shade300, width: 1)
                                : BorderSide.none,
                          ),
                          child: InkWell(
                            onTap: () => _showAnimalDetails(transfer),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: isConfirmed
                                              ? Colors.green.shade100
                                              : isRejected
                                                  ? Colors.red.shade100
                                                  : Colors.orange.shade100,
                                          borderRadius:
                                              BorderRadius.circular(25),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            Icons.pets,
                                            size: 28,
                                            color: isConfirmed
                                                ? Colors.green
                                                : isRejected
                                                    ? Colors.red
                                                    : Colors.orange,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              transfer['animal_name'] ??
                                                  languageService
                                                      .translate('animal'),
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              isRecipient
                                                  ? '${languageService.translate('from')}: ${transfer['from_user_name']}'
                                                  : '${languageService.translate('to')}: ${transfer['to_user_name']}',
                                              style:
                                                  const TextStyle(fontSize: 14),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _getStatusChip(transfer['status']),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (transfer['notes'] != null &&
                                      transfer['notes'].isNotEmpty)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: Text(
                                        '${languageService.translate('details')}: ${transfer['notes']}',
                                        style: TextStyle(
                                            color: Colors.grey.shade600),
                                      ),
                                    ),
                                  if (showActions)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () =>
                                                _rejectTransfer(transfer['id']),
                                            icon: const Icon(Icons.close),
                                            label: Text(languageService
                                                .translate('reject')),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red,
                                              side: const BorderSide(
                                                  color: Colors.red),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () => _confirmTransfer(
                                                transfer['id']),
                                            icon: const Icon(Icons.check),
                                            label: Text(languageService
                                                .translate('accept')),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (isExpired)
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.timer_off,
                                              color: Colors.red),
                                          const SizedBox(width: 8),
                                          Text(
                                              languageService
                                                  .translate('request_overdue'),
                                              style: const TextStyle(
                                                  color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () =>
                                          _deleteTransfer(transfer['id']),
                                      icon: const Icon(Icons.delete, size: 18),
                                      label: Text(languageService
                                          .translate('delete_record')),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
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

  Widget _getStatusChip(String status) {
    Color color;
    String key;

    switch (status) {
      case 'PENDING':
        color = Colors.orange;
        key = 'pending';
        break;
      case 'CONFIRMED':
        color = Colors.green;
        key = 'confirmed';
        break;
      case 'REJECTED':
        color = Colors.red;
        key = 'rejected';
        break;
      case 'EXPIRED':
        color = Colors.grey;
        key = 'expired';
        break;
      default:
        color = Colors.grey;
        key = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        context.tr(key).toUpperCase(),
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _translateTransferStatus(String status) {
    switch (status) {
      case 'PENDING':
        return context.tr('pending');
      case 'CONFIRMED':
        return context.tr('confirmed');
      case 'REJECTED':
        return context.tr('rejected');
      case 'EXPIRED':
        return context.tr('expired');
      default:
        return status;
    }
  }
}
