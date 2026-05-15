import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/language_service.dart';
import '../../models/animal_model.dart';
import '../../utils/constants.dart';
import '../base_screen.dart';
import 'animal_detail_screen.dart';

class AnimalListScreen extends StatefulWidget {
  const AnimalListScreen({super.key});

  @override
  State<AnimalListScreen> createState() => _AnimalListScreenState();
}

class _AnimalListScreenState extends State<AnimalListScreen> {
  final ApiService _apiService = ApiService();
  List<AnimalModel> _animals = [];
  bool _isLoading = true;
  String? _errorMessage;

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
      if (response.statusCode == 200) {
        final List<dynamic> animalsData = response.data['results'] ?? [];
        _animals =
            animalsData.map((json) => AnimalModel.fromJson(json)).toList();
        print('Loaded ${_animals.length} animals');
      }
    } catch (e) {
      print(' Error loading animals: $e');
      setState(() {
        _errorMessage = e.toString();
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

    return BaseScreen(
      title: 'My Animals',
      selectedIndex: 1,
      child: RefreshIndicator(
        onRefresh: _loadAnimals,
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
                : _animals.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.pets,
                                size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              languageService.translate('no_animals'),
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _animals.length,
                        itemBuilder: (context, index) {
                          final animal = _animals[index];
                          return _buildAnimalCard(animal);
                        },
                      ),
      ),
    );
  }

  Widget _buildAnimalCard(AnimalModel animal) {
    final languageService = Provider.of<LanguageService>(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 55,
          height: 55,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey.shade100,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildAnimalImage(animal),
          ),
        ),
        title: Text(
          animal.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
            '${animal.animalId} • ${languageService.translate(animal.status.toLowerCase())}'),
        trailing: Chip(
          label: Text(languageService.translate(animal.status.toLowerCase())),
          backgroundColor: animal.statusColor.withOpacity(0.1),
          labelStyle: TextStyle(
            color: animal.statusColor,
            fontSize: 12,
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AnimalDetailScreen(animal: animal),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnimalImage(AnimalModel animal) {
    final photoUrl = animal.photoUrl;

    if (photoUrl.isNotEmpty) {
      return Image.network(
        photoUrl,
        width: 55,
        height: 55,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print('Error loading image for ${animal.name}: $error');
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
