import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/language_service.dart';
import '../../models/animal_model.dart';
import '../../models/location_model.dart';
import '../../models/user_model.dart';
import '../../utils/constants.dart';
import '../base_screen.dart';
import 'stolen_animals_screen.dart';

class PoliceDashboard extends StatefulWidget {
  const PoliceDashboard({super.key});

  @override
  State<PoliceDashboard> createState() => _PoliceDashboardState();
}

class _PoliceDashboardState extends State<PoliceDashboard> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  List<AnimalModel> _stolenAnimals = [];
  bool _isLoading = true;
  String? _errorMessage;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    _currentUser = await _authService.getCurrentUser();
    setState(() {});
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response =
          await _apiService.get('${AppConstants.animals}?status=STOLEN');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['results'] ?? [];
        _stolenAnimals =
            data.map((json) => AnimalModel.fromJson(json)).toList();
      }
    } catch (e) {
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
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return BaseScreen(
      title: 'Police Dashboard',
      selectedIndex: 0,
      child: RefreshIndicator(
        onRefresh: _loadData,
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
                          onPressed: _loadData,
                          child: Text(languageService.translate('retry')),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Stolen Animals Count Card
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  size: 48,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _stolenAnimals.length.toString(),
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                                Text(
                                  languageService
                                      .translate('stolen_animals_reported'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Stolen Animals List Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              languageService.translate('stolen_animals_list'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const StolenAnimalsScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.arrow_forward),
                              label:
                                  Text(languageService.translate('view_all')),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Stolen Animals List
                        if (_stolenAnimals.isEmpty)
                          Center(
                            child: Column(
                              children: [
                                const SizedBox(height: 40),
                                const Icon(Icons.check_circle,
                                    size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                Text(
                                  languageService
                                      .translate('no_stolen_animals'),
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _stolenAnimals.length > 3
                                ? 3
                                : _stolenAnimals.length,
                            itemBuilder: (context, index) {
                              final animal = _stolenAnimals[index];
                              return _buildStolenAnimalCard(animal);
                            },
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildStolenAnimalCard(AnimalModel animal) {
    final languageService = Provider.of<LanguageService>(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.shade300, width: 1),
      ),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.red.shade100,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Center(
            child: Text(
              _getAnimalIcon(animal.type),
              style: const TextStyle(fontSize: 28),
            ),
          ),
        ),
        title: Text(animal.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(animal.animalId),
            Text(
              '${languageService.translate('owner')}: ${animal.ownerfullName}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: const Icon(Icons.warning, color: Colors.red),
        onTap: () {
          _showAnimalDetails(animal);
        },
      ),
    );
  }

  void _showAnimalDetails(AnimalModel animal) {
    final languageService =
        Provider.of<LanguageService>(context, listen: false);

    _getAnimalLocation(animal).then((location) {
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
                Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Center(
                      child: Text(
                        _getAnimalIcon(animal.type),
                        style: const TextStyle(fontSize: 30),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    animal.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(),
                _buildDetailRow(
                    languageService.translate('animal_id'), animal.animalId),
                _buildDetailRow(
                    languageService.translate('owner'), animal.ownerfullName),
                _buildDetailRow(languageService.translate('status'),
                    languageService.translate(animal.status.toLowerCase())),
                _buildDetailRow(languageService.translate('reported_on'),
                    _formatDate(animal.updatedAt)),
                if (location != null) ...[
                  const Divider(),
                  _buildDetailRow(
                    languageService.translate('last_known_location'),
                    '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      if (location != null) {
                        _openMap(location, animal);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(languageService
                                .translate('no_location_data_for_animal')),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.map),
                    label: Text(
                        languageService.translate('view_on_map').toUpperCase()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }

  Future<LocationModel?> _getAnimalLocation(AnimalModel animal) async {
    try {
      final response = await _apiService
          .get('${AppConstants.animals}${animal.id}/locations/');
      if (response.statusCode == 200) {
        final locations = response.data as List;
        if (locations.isNotEmpty) {
          return LocationModel.fromJson(locations.first);
        }
      }
      return null;
    } catch (e) {
      print('Error loading location: $e');
      return null;
    }
  }

  void _openMap(LocationModel location, AnimalModel animal) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenMapPolice(
          latitude: location.latitude,
          longitude: location.longitude,
          animalName: animal.name,
          animalDetails: animal,
        ),
      ),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ========== FULL SCREEN MAP FOR POLICE ==========
class FullScreenMapPolice extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String animalName;
  final AnimalModel animalDetails;

  const FullScreenMapPolice({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.animalName,
    required this.animalDetails,
  });

  @override
  State<FullScreenMapPolice> createState() => _FullScreenMapPoliceState();
}

class _FullScreenMapPoliceState extends State<FullScreenMapPolice> {
  late GoogleMapController _mapController;

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${widget.animalName} - ${languageService.translate('last_known_location')}'),
        backgroundColor: Colors.red.shade800,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(widget.latitude, widget.longitude),
          zoom: 15,
        ),
        markers: {
          Marker(
            markerId: const MarkerId('stolen_animal'),
            position: LatLng(widget.latitude, widget.longitude),
            infoWindow: InfoWindow(
              title: widget.animalName,
              snippet: languageService.translate('last_seen_location'),
            ),
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        },
        onMapCreated: (controller) {
          _mapController = controller;
        },
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: true,
        compassEnabled: true,
      ),
    );
  }
}
