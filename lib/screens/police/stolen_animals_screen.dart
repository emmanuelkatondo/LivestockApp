import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/language_service.dart';
import '../../models/animal_model.dart';
import '../../models/location_model.dart';
import '../../utils/constants.dart';
import '../base_screen.dart';
import '../../screens/farmer/animal_detail_screen.dart';

class StolenAnimalsScreen extends StatefulWidget {
  const StolenAnimalsScreen({super.key});

  @override
  State<StolenAnimalsScreen> createState() => _StolenAnimalsScreenState();
}

class _StolenAnimalsScreenState extends State<StolenAnimalsScreen> {
  final ApiService _apiService = ApiService();

  List<AnimalModel> _stolenAnimals = [];
  Map<int, LocationModel?> _lastLocations = {};
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response =
          await _apiService.get('${AppConstants.animals}?status=STOLEN');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['results'] ?? [];
        _stolenAnimals =
            data.map((json) => AnimalModel.fromJson(json)).toList();

        for (var animal in _stolenAnimals) {
          try {
            final locationResponse = await _apiService
                .get('${AppConstants.animals}${animal.id}/locations/');
            if (locationResponse.statusCode == 200) {
              final locations = locationResponse.data as List;
              if (locations.isNotEmpty) {
                _lastLocations[animal.id] =
                    LocationModel.fromJson(locations.first);
              }
            }
          } catch (e) {
            print('Error loading location for animal ${animal.id}: $e');
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<AnimalModel> get _filteredAnimals {
    if (_searchQuery.isEmpty) return _stolenAnimals;
    return _stolenAnimals
        .where((animal) =>
            animal.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            animal.animalId
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            animal.ownerfullName
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);

    return BaseScreen(
      title: languageService.translate('stolen_animals').toUpperCase(),
      selectedIndex: 0, // Police dashboard index
      child: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: languageService.translate('search'),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
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
                              onPressed: _loadData,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
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
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _filteredAnimals.length,
                            itemBuilder: (context, index) {
                              final animal = _filteredAnimals[index];
                              final lastLocation = _lastLocations[animal.id];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                      color: Colors.red.shade300, width: 1),
                                ),
                                child: ExpansionTile(
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
                                  subtitle: Text(animal.animalId),
                                  trailing: const Icon(Icons.warning,
                                      color: Colors.red),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildInfoRow(
                                            Icons.person,
                                            languageService.translate('owner'),
                                            animal.ownerfullName,
                                          ),
                                          _buildInfoRow(
                                            Icons.info,
                                            languageService.translate('status'),
                                            languageService.translate(
                                                animal.status.toLowerCase()),
                                          ),
                                          _buildInfoRow(
                                            Icons.calendar_today,
                                            languageService
                                                .translate('reported_on'),
                                            _formatDate(animal.updatedAt),
                                          ),
                                          if (lastLocation != null) ...[
                                            const Divider(),
                                            _buildInfoRow(
                                              Icons.location_on,
                                              languageService.translate(
                                                  'last_known_location'),
                                              '${lastLocation.latitude.toStringAsFixed(6)}, ${lastLocation.longitude.toStringAsFixed(6)}',
                                            ),
                                            const SizedBox(height: 12),
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton.icon(
                                                onPressed: () {
                                                  _showLocationOnMap(
                                                      lastLocation, animal);
                                                },
                                                icon: const Icon(Icons.map),
                                                label: Text(languageService
                                                    .translate('view_on_map')
                                                    .toUpperCase()),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.red.shade700,
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 12),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
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

  void _showLocationOnMap(LocationModel location, AnimalModel animal) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenMap(
          latitude: location.latitude,
          longitude: location.longitude,
          animalName: animal.name,
          animalDetails: animal,
        ),
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
            width: 100,
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

// ========== FULL SCREEN MAP WITH GOOGLE MAPS ==========
class FullScreenMap extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String animalName;
  final AnimalModel animalDetails;

  const FullScreenMap({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.animalName,
    required this.animalDetails,
  });

  @override
  State<FullScreenMap> createState() => _FullScreenMapState();
}

class _FullScreenMapState extends State<FullScreenMap> {
  late GoogleMapController _mapController;
  bool _showLegend = true;

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${widget.animalName} - ${languageService.translate('last_known_location')}'),
        backgroundColor: Colors.red.shade800,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => setState(() => _showLegend = !_showLegend),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(widget.latitude, widget.longitude),
              zoom: 15,
            ),
            markers: {
              Marker(
                markerId: const MarkerId('stolen animal'),
                position: LatLng(widget.latitude, widget.longitude),
                infoWindow: InfoWindow(
                  title: widget.animalName,
                  snippet: languageService.translate('last_seen_location'),
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed),
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

          // Legend
          if (_showLegend)
            Positioned(
              bottom: 20,
              left: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      languageService.translate('details').toUpperCase(),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                        '${languageService.translate('animal')}: ${widget.animalDetails.name}',
                        style: const TextStyle(fontSize: 11)),
                    Text(
                        '${languageService.translate('animal_number')}: ${widget.animalDetails.animalId}',
                        style: const TextStyle(fontSize: 11)),
                    Text(
                        '${languageService.translate('owner')}: ${widget.animalDetails.ownerfullName}',
                        style: const TextStyle(fontSize: 11)),
                    const Divider(height: 12),
                    Text(languageService.translate('click_marker_details'),
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
            ),

          // Animal details card at bottom
          Positioned(
            bottom: 20,
            right: 20,
            left: 20,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AnimalDetailScreen(animal: widget.animalDetails),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Center(
                        child: Text(
                          widget.animalDetails.type == 'CATTLE'
                              ? '🐄'
                              : widget.animalDetails.type == 'GOAT'
                                  ? '🐐'
                                  : widget.animalDetails.type == 'SHEEP'
                                      ? '🐑'
                                      : '🐾',
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.animalDetails.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${languageService.translate('status')}: ${languageService.translate(widget.animalDetails.status.toLowerCase())}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.red),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}