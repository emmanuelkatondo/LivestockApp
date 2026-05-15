import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/language_service.dart';
import '../../models/animal_model.dart';
import '../../utils/constants.dart';
import '../base_screen.dart';

class AllAnimalsScreen extends StatefulWidget {
  const AllAnimalsScreen({super.key});

  @override
  State<AllAnimalsScreen> createState() => _AllAnimalsScreenState();
}

class _AllAnimalsScreenState extends State<AllAnimalsScreen> {
  final ApiService _apiService = ApiService();

  List<AnimalModel> _animals = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedFilter = 'ALL';

  final List<Map<String, String>> _filters = [
    {'value': 'ALL', 'labelKey': 'all'},
    {'value': 'ACTIVE', 'labelKey': 'active'},
    {'value': 'STOLEN', 'labelKey': 'stolen'},
    {'value': 'SOLD', 'labelKey': 'sold'},
    {'value': 'DEAD', 'labelKey': 'dead'},
  ];

  @override
  void initState() {
    super.initState();
    _loadAnimals();
  }

  Future<void> _loadAnimals() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.get(AppConstants.animals);

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response data type: ${response.data.runtimeType}');

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

        print('✅ Found ${data.length} animals');

        _animals = data.map((json) => AnimalModel.fromJson(json)).toList();

        print('✅ Successfully parsed ${_animals.length} animals');
      }
    } catch (e) {
      print('❌ Error loading animals: $e');
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<AnimalModel> get _filteredAnimals {
    var filtered = _animals;

    if (_selectedFilter != 'ALL') {
      filtered = filtered.where((a) => a.status == _selectedFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((a) =>
              a.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              a.animalId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              a.ownerfullName
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()))
          .toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    return BaseScreen(
      title: 'All Animals',
      selectedIndex: 2, // Index for All Animals in menu
      child: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: languageService.translate('search_animal'),
                  prefixIcon: const Icon(Icons.search, color: Colors.green),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: _filters.map((filter) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      languageService
                          .translate(filter['labelKey']!)
                          .toUpperCase(),
                      style: TextStyle(
                        color: _selectedFilter == filter['value']
                            ? Colors.white
                            : Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    selected: _selectedFilter == filter['value'],
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = filter['value']!;
                      });
                    },
                    backgroundColor: Colors.grey.shade100,
                    selectedColor: const Color(0xFF2E7D32),
                    checkmarkColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

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
                              onPressed: _loadAnimals,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                              ),
                              child: Text(languageService.translate('retry')),
                            ),
                          ],
                        ),
                      )
                    : _filteredAnimals.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.pets,
                                    size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                Text(
                                  languageService.translate('no_animals_found'),
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  languageService
                                      .translate('try_changing_filter'),
                                  style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _filteredAnimals.length,
                            itemBuilder: (context, index) {
                              final animal = _filteredAnimals[index];
                              return _buildAnimalCard(animal);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimalCard(AnimalModel animal) {
    final languageService = Provider.of<LanguageService>(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              // Navigate to animal detail
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Animal Image/Photo
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade100,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildAnimalImage(animal),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Animal Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          animal.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          animal.animalId,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.person,
                                size: 12, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                animal.ownerfullName,
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Status Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: animal.statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: animal.statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      languageService.translate(animal.status.toLowerCase()),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: animal.statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimalImage(AnimalModel animal) {
    final photoUrl = animal.photoUrl;

    if (photoUrl.isNotEmpty) {
      return Image.network(
        photoUrl,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey.shade200,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: animal.statusColor.withOpacity(0.1),
            child: Center(
              child: Text(
                _getAnimalIcon(animal.type),
                style: TextStyle(fontSize: 30, color: animal.statusColor),
              ),
            ),
          );
        },
      );
    } else {
      return Container(
        color: animal.statusColor.withOpacity(0.1),
        child: Center(
          child: Text(
            _getAnimalIcon(animal.type),
            style: TextStyle(fontSize: 30, color: animal.statusColor),
          ),
        ),
      );
    }
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
}
