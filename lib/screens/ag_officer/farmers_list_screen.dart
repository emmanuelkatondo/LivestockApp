import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/language_service.dart';
import '../../models/user_model.dart';
import '../../models/animal_model.dart';
import '../../utils/constants.dart';
import '../base_screen.dart';

class FarmersListScreen extends StatefulWidget {
  const FarmersListScreen({super.key});

  @override
  State<FarmersListScreen> createState() => _FarmersListScreenState();
}

class _FarmersListScreenState extends State<FarmersListScreen> {
  final ApiService _apiService = ApiService();

  List<UserModel> _farmers = [];
  Map<int, List<AnimalModel>> _farmerAnimals = {};
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadFarmers();
  }

  Future<void> _loadFarmers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Load farmers
      final response = await _apiService.get('${AppConstants.users}farmers/');

      if (response.statusCode == 200) {
        List<dynamic> data;
        if (response.data is List) {
          data = response.data;
        } else if (response.data is Map &&
            response.data.containsKey('results')) {
          data = response.data['results'];
        } else {
          data = [];
        }

        _farmers = data.map((json) => UserModel.fromJson(json)).toList();
        print('✅ Loaded ${_farmers.length} farmers');

        // 2. Load animals for each farmer
        await _loadAnimalsForFarmers();
      } else {
        setState(() {
          _errorMessage = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      print('❌ Error loading farmers: $e');
      setState(() {
        _errorMessage = '${context.tr('network_error')}: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ========== NJIA MPYA RAHISI ==========
  Future<void> _loadAnimalsForFarmers() async {
    _farmerAnimals.clear();

    try {
      // Pata wanyama wote
      final response = await _apiService.get(AppConstants.animals);

      if (response.statusCode == 200) {
        final animalsData = response.data['results'] ?? [];
        final allAnimals =
            animalsData.map((json) => AnimalModel.fromJson(json)).toList();

        print('📊 Total animals from API: ${allAnimals.length}');

        // Kila mnyama, tafuta mkulima wake
        for (final animal in allAnimals) {
          final ownerId = animal.owner;

          if (ownerId > 0) {
            // Tafuta farmer anayeendana na owner huyu
            final farmer = await _findFarmerByOwnerId(ownerId);

            if (farmer != null) {
              _farmerAnimals.putIfAbsent(farmer.id, () => []);
              _farmerAnimals[farmer.id]!.add(animal);
            }
          }
        }

        print('✅ Loaded animals for ${_farmerAnimals.length} farmers');
      }
    } catch (e) {
      print('❌ Error loading animals: $e');
    }
  }


// farmers_list_screen.dart

  List<UserModel> get _filteredFarmers {
    if (_searchQuery.isEmpty) return _farmers;
    return _farmers
        .where((farmer) =>
            farmer.fullName
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            farmer.phoneNumber.contains(_searchQuery) ||
            (farmer.location
                    ?.toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ??
                false))
        .toList();
  }

  Future<UserModel?> _findFarmerByOwnerId(int ownerId) async {
    try {
      final response = await _apiService.get('${AppConstants.owners}$ownerId/');

      if (response.statusCode == 200) {
        final ownerData = response.data;
        print(' Owner data: $ownerData');

        int? userId;
        final userField = ownerData['user'];
        if (userField is Map && userField.containsKey('id')) {
          userId = userField['id'] as int?;
        } else if (userField is int) {
          userId = userField;
        } else if (userField is String) {
          userId = int.tryParse(userField);
        }

        // Kama bado ni null, jaribu 'primary_owner'
        if (userId == null || userId == 0) {
          final primaryOwner = ownerData['primary_owner'];
          if (primaryOwner is Map && primaryOwner.containsKey('id')) {
            userId = primaryOwner['id'] as int?;
          } else if (primaryOwner is int) {
            userId = primaryOwner;
          } else if (primaryOwner is String) {
            userId = int.tryParse(primaryOwner);
          }
        }

        if (userId == null || userId == 0) {
          final users = ownerData['users'] as List?;
          if (users != null && users.isNotEmpty) {
            final firstUser = users.first;
            if (firstUser is Map && firstUser.containsKey('id')) {
              userId = firstUser['id'] as int?;
            } else if (firstUser is int) {
              userId = firstUser;
            } else if (firstUser is String) {
              userId = int.tryParse(firstUser);
            }
          }
        }

        print('🔍 Found userId: $userId');

        if (userId != null && userId > 0) {

          try {
            final farmer = _farmers.firstWhere(
              (f) => f.id == userId,
            );
            print('Found farmer: ${farmer.fullName} (ID: ${farmer.id})');
            return farmer;
          } catch (e) {

            print(' Farmer with ID $userId not found in list');
            return null;
          }
        }
      }
    } catch (e) {
      print(' Could not get owner $ownerId: $e');
    }
    return null;
  }
  Future<void> _editFarmer(UserModel farmer) async {
    final languageService =
        Provider.of<LanguageService>(context, listen: false);
    final nameController = TextEditingController(text: farmer.fullName);
    final phoneController = TextEditingController(text: farmer.phoneNumber);
    final emailController = TextEditingController(text: farmer.email ?? '');
    final locationController =
        TextEditingController(text: farmer.location ?? '');

    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageService.translate('edit_farmer')),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: languageService.translate('full_name'),
                  prefixIcon: const Icon(Icons.person),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: languageService.translate('phone_number'),
                  prefixIcon: const Icon(Icons.phone),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: languageService.translate('email'),
                  prefixIcon: const Icon(Icons.email),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                decoration: InputDecoration(
                  labelText: languageService.translate('location'),
                  prefixIcon: const Icon(Icons.location_on),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(languageService.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final response = await _apiService.patch(
                  '${AppConstants.users}${farmer.id}/',
                  {
                    'first_name': nameController.text,
                    'phone': phoneController.text,
                    'email': emailController.text,
                    'location': locationController.text,
                  },
                );

                if (response.statusCode == 200) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text(languageService.translate('farmer_updated')),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.pop(context, true);
                  _loadFarmers();
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '${languageService.translate('update_failed')}: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(languageService.translate('save')),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFarmer(UserModel farmer) async {
    final languageService =
        Provider.of<LanguageService>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageService.translate('confirm_delete')),
        content: Text(languageService.translate('delete_farmer_confirm')),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(languageService.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(languageService.translate('delete')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final response =
          await _apiService.delete('${AppConstants.users}${farmer.id}/');

      if (response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(languageService.translate('farmer_deleted')),
            backgroundColor: Colors.green,
          ),
        );
        _loadFarmers();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${languageService.translate('delete_failed')}: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);

    return BaseScreen(
      title: 'Farmers List',
      selectedIndex: 1,
      child: Column(
        children: [
  
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: languageService.translate('search_farmer'),
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadFarmers,
                  tooltip: 'Refresh',
                ),
              ],
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
                              onPressed: _loadFarmers,
                              child: Text(languageService.translate('retry')),
                            ),
                          ],
                        ),
                      )
                    : _filteredFarmers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.people_outline,
                                    size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                Text(languageService
                                    .translate('no_farmers_found_title')),
                                const SizedBox(height: 8),
                                Text(
                                  languageService
                                      .translate('try_changing_search'),
                                  style: TextStyle(color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _filteredFarmers.length,
                            itemBuilder: (context, index) {
                              final farmer = _filteredFarmers[index];
                              final farmerAnimals =
                                  _farmerAnimals[farmer.id] ?? [];
                              final animalCount = farmerAnimals.length;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 2,
                                child: Column(
                                  children: [
                                    // Header
                                    ListTile(
                                      leading: CircleAvatar(
                                        radius: 28,
                                        backgroundColor: Colors.blue.shade100,
                                        child: Text(
                                          farmer.fullName.isNotEmpty
                                              ? farmer.fullName[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        farmer.fullName.isNotEmpty
                                            ? farmer.fullName
                                            : languageService.translate(
                                                'name_not_available'),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            farmer.phoneNumber.isNotEmpty
                                                ? farmer.phoneNumber
                                                : languageService.translate(
                                                    'phone_not_available'),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '${languageService.translate('animals')}: $animalCount',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.blue.shade700,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _editFarmer(farmer);
                                          } else if (value == 'delete') {
                                            _deleteFarmer(farmer);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                const Icon(Icons.edit,
                                                    size: 20,
                                                    color: Colors.blue),
                                                const SizedBox(width: 8),
                                                Text(languageService
                                                    .translate('edit')),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                const Icon(Icons.delete,
                                                    size: 20,
                                                    color: Colors.red),
                                                const SizedBox(width: 8),
                                                Text(
                                                  languageService
                                                      .translate('delete'),
                                                  style: const TextStyle(
                                                      color: Colors.red),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Expandable Details
                                    ExpansionTile(
                                      iconColor: Colors.blue,
                                      collapsedIconColor: Colors.blue,
                                      title: Text(
                                        languageService
                                            .translate('full_details')
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Basic Information
                                              Text(
                                                languageService
                                                    .translate(
                                                        'basic_information')
                                                    .toUpperCase(),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              _buildInfoRow(
                                                Icons.phone,
                                                languageService
                                                    .translate('phone'),
                                                farmer.phoneNumber.isNotEmpty
                                                    ? farmer.phoneNumber
                                                    : languageService.translate(
                                                        'not_available'),
                                              ),
                                              if (farmer.email != null &&
                                                  farmer.email!.isNotEmpty)
                                                _buildInfoRow(
                                                  Icons.email,
                                                  languageService
                                                      .translate('email'),
                                                  farmer.email!,
                                                ),
                                              if (farmer.location != null &&
                                                  farmer.location!.isNotEmpty)
                                                _buildInfoRow(
                                                  Icons.location_on,
                                                  languageService
                                                      .translate('location'),
                                                  farmer.location!,
                                                ),
                                              _buildInfoRow(
                                                Icons.calendar_today,
                                                languageService
                                                    .translate('joined'),
                                                _formatDate(farmer.dateJoined),
                                              ),

                                              const Divider(height: 24),

                                              // Animals Section
                                              Row(
                                                children: [
                                                  const Icon(Icons.pets,
                                                      size: 18,
                                                      color: Colors.blue),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '${languageService.translate('animals').toUpperCase()} (${farmerAnimals.length})',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.blue,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),

                                              if (farmerAnimals.isEmpty)
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 8),
                                                  child: Text(
                                                    languageService.translate(
                                                        'no_animals_yet'),
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey),
                                                  ),
                                                )
                                              else
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: farmerAnimals
                                                      .map((animal) {
                                                    return Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 10,
                                                        vertical: 5,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: _getStatusColor(
                                                                animal.status)
                                                            .withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20),
                                                        border: Border.all(
                                                          color: _getStatusColor(
                                                                  animal.status)
                                                              .withOpacity(0.3),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            _getAnimalIcon(
                                                                animal.type),
                                                            style:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        14),
                                                          ),
                                                          const SizedBox(
                                                              width: 4),
                                                          Text(
                                                            animal.name,
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: _getStatusColor(
                                                                  animal
                                                                      .status),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getAnimalIcon(String type) {
    switch (type) {
      case 'CATTLE':
        return '🐄';
      case 'GOAT':
        return '🐐';
      case 'SHEEP':
        return '🐑';
      default:
        return '🐾';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ACTIVE':
        return Colors.green;
      case 'STOLEN':
        return Colors.red;
      case 'SOLD':
        return Colors.blue;
      case 'DEAD':
        return Colors.red.shade900;
      default:
        return Colors.grey;
    }
  }
}
