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
  Map<int, int> _animalCounts = {};
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
      final response = await _apiService.get('${AppConstants.users}farmers/');

      print('Response status: ${response.statusCode}');
      print(' Response data: ${response.data}');

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

        print('Extracted ${data.length} farmers from response');

        _farmers = data.map((json) => UserModel.fromJson(json)).toList();
        print(' Successfully parsed ${_farmers.length} farmers');

        await _loadAnimalCounts();

        print(' Animal Counts after load: $_animalCounts');
        for (var farmer in _farmers) {
          print(
              'Farmer: ${farmer.fullName} (ID: ${farmer.id}) - Animals: ${_animalCounts[farmer.id] ?? 0}');
        }
      } else {
        setState(() {
          _errorMessage = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      print('Error loading farmers: $e');
      setState(() {
        _errorMessage = '${context.tr('network_error')}: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAnimalCounts() async {
    try {
      final animalsData = await _loadAllAnimalsData();
      final animals =
          animalsData.map((json) => AnimalModel.fromJson(json)).toList();

      _animalCounts.clear();
      _farmerAnimals.clear();

      print('Total animals from API: ${animals.length}');

      for (var i = 0; i < animals.length; i++) {
        final animal = animals[i];
        final ownerId = _getOwnerId(animalsData[i], animal) ??
            _findFarmerIdByOwnerName(animal);

        print(
            'Animal: ${animal.name}, Owner ID: $ownerId, Owner Name: ${animal.ownerfullName}');

        if (ownerId == null || ownerId == 0) {
          print('Skipped animal ${animal.name}: owner id not found');
          continue;
        }

        _animalCounts[ownerId] = (_animalCounts[ownerId] ?? 0) + 1;
        _farmerAnimals.putIfAbsent(ownerId, () => []).add(animal);
      }

      print(
          'Loaded ${animals.length} animals for ${_animalCounts.length} farmers');
      print('Animal Counts Map: $_animalCounts');
    } catch (e) {
      print('Error loading animal counts: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _loadAllAnimalsData() async {
    final allAnimals = <Map<String, dynamic>>[];
    String? endpoint = AppConstants.animals;

    while (endpoint != null) {
      final response = await _apiService.get(endpoint);
      if (response.statusCode != 200) break;

      allAnimals.addAll(_extractAnimalData(response.data));
      endpoint = _extractNextPage(response.data);
    }

    return allAnimals;
  }

  List<Map<String, dynamic>> _extractAnimalData(dynamic responseData) {
    final dynamic data;

    if (responseData is List) {
      data = responseData;
    } else if (responseData is Map && responseData.containsKey('results')) {
      data = responseData['results'];
    } else {
      data = [];
    }

    return (data as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String? _extractNextPage(dynamic responseData) {
    if (responseData is Map && responseData['next'] != null) {
      return responseData['next'].toString();
    }
    return null;
  }

  int? _getOwnerId(Map<String, dynamic> json, AnimalModel animal) {
    return _readId(
          json,
          [
            'owner',
            'owner_id',
            'owner_details',
            'owner_detail',
            'farmer',
            'farmer_id',
            'farmer_details',
            'farmer_detail',
            'user',
            'user_id',
            'created_by',
          ],
        ) ??
        (animal.owner == 0 ? null : animal.owner);
  }

  int? _findFarmerIdByOwnerName(AnimalModel animal) {
    final ownerName = _normalizeName(animal.ownerfullName);
    if (ownerName.isEmpty) return null;

    for (final farmer in _farmers) {
      if (_normalizeName(farmer.fullName) == ownerName) {
        return farmer.id;
      }
    }

    return null;
  }

  int? _readId(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final id = _parseIdValue(json[key]);
      if (id != null) return id;
    }
    return null;
  }

  int? _parseIdValue(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is Map) {
      for (final key in ['id', 'pk', 'user_id', 'owner_id', 'farmer_id']) {
        final id = _parseIdValue(value[key]);
        if (id != null) return id;
      }
    }
    return null;
  }

  String _normalizeName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

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
                    'full_name': nameController.text,
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

    setState(() {
      _isLoading = true;
    });

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
      setState(() {
        _isLoading = false;
      });
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
          // Search Bar with Refresh Button
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
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
                              final animalCount = _animalCounts[farmer.id] ??
                                  _farmerAnimals[farmer.id]?.length ??
                                  0;
                              final farmerAnimals =
                                  _farmerAnimals[farmer.id] ?? [];

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 2,
                                child: Column(
                                  children: [
                                    // Header with actions
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
                                          Text(farmer.phoneNumber.isNotEmpty
                                              ? farmer.phoneNumber
                                              : languageService.translate(
                                                  'phone_not_available')),
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
                                                        color: Colors.red)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Expandable details
                                    ExpansionTile(
                                      iconColor: Colors.blue,
                                      collapsedIconColor: Colors.blue,
                                      title: Text(
                                        languageService
                                            .translate('full_details')
                                            .toUpperCase(),
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
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
