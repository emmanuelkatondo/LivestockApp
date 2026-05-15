import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/animal_model.dart';
import '../../models/location_model.dart';
import '../../services/api_service.dart';
import '../../services/language_service.dart';
import '../../utils/constants.dart';

class MapViewScreen extends StatefulWidget {
  final List<AnimalModel> animals;
  final LocationModel? initialLocation;
  final bool showMarker;

  const MapViewScreen({
    super.key,
    required this.animals,
    this.initialLocation,
    this.showMarker = false,
  });

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  final ApiService _apiService = ApiService();
  GoogleMapController? _mapController;

  Set<Marker> _markers = {};
  Map<int, LatLng> _animalLocations = {};
  Map<int, LocationModel?> _animalLocationData = {};
  bool _isLoading = true;
  String? _errorMessage;
  bool _showLegend = true;

  static const LatLng _defaultCenter =
      LatLng(-6.7924, 39.2083); // Dar es Salaam

  @override
  void initState() {
    super.initState();
    _loadAnimalLocations();
  }

  Future<void> _loadAnimalLocations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    Set<Marker> markers = {};

    for (var animal in widget.animals) {
      try {
        print('Loading location for animal: ${animal.name} (ID: ${animal.id})');

        final response = await _apiService
            .get('${AppConstants.animals}${animal.id}/locations/');

        if (response.statusCode == 200) {
          final locations = response.data as List;
          print('Found ${locations.length} locations for ${animal.name}');

          if (locations.isNotEmpty) {
            final location = LocationModel.fromJson(locations.first);
            final latLng = LatLng(location.latitude, location.longitude);
            _animalLocations[animal.id] = latLng;
            _animalLocationData[animal.id] = location;

            markers.add(
              Marker(
                markerId: MarkerId(animal.id.toString()),
                position: latLng,
                infoWindow: InfoWindow(
                  title: animal.name,
                  snippet:
                      '${animal.animalId}\n${context.tr('status')}: ${context.tr(animal.status.toLowerCase())}',
                  onTap: () => _showAnimalDetails(animal),
                ),
                icon: animal.isStolen
                    ? BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueRed)
                    : BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueGreen),
              ),
            );
          }
        }
      } catch (e) {
        print('Error loading location for animal ${animal.id}: $e');
      }
    }

    setState(() {
      _markers = markers;
      _isLoading = false;
    });
  }

  void _animateToAnimal(int animalId) {
    final position = _animalLocations[animalId];
    if (position != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: position, zoom: 15),
        ),
      );
    }
  }

  void _centerOnAllAnimals() {
    if (_animalLocations.isEmpty) return;

    // Calculate bounds to fit all markers
    double minLat = _animalLocations.values.first.latitude;
    double maxLat = _animalLocations.values.first.latitude;
    double minLng = _animalLocations.values.first.longitude;
    double maxLng = _animalLocations.values.first.longitude;

    for (var loc in _animalLocations.values) {
      minLat = minLat < loc.latitude ? minLat : loc.latitude;
      maxLat = maxLat > loc.latitude ? maxLat : loc.latitude;
      minLng = minLng < loc.longitude ? minLng : loc.longitude;
      maxLng = maxLng > loc.longitude ? maxLng : loc.longitude;
    }

    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;

    final bounds = LatLngBounds(
      southwest: LatLng(minLat - latPadding, minLng - lngPadding),
      northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
    );

    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  void _showAnimalDetails(AnimalModel animal) {
    final languageService =
        Provider.of<LanguageService>(context, listen: false);
    final location = _animalLocationData[animal.id];
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: animal.isStolen
                          ? Colors.red.shade50
                          : Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      animal.isStolen ? Icons.warning : Icons.pets,
                      color: animal.isStolen ? Colors.red : Colors.green,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      animal.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(),
              _buildDetailRow(
                  languageService.translate('animal_id'), animal.animalId),
              _buildDetailRow(languageService.translate('type'),
                  _getAnimalTypeName(animal.type)),
              _buildDetailRow(languageService.translate('status'),
                  languageService.translate(animal.status.toLowerCase())),
              _buildDetailRow(
                  languageService.translate('owner'), animal.ownerfullName),
              if (animal.color != null && animal.color!.isNotEmpty)
                _buildDetailRow(
                    languageService.translate('color'), animal.color!),
              if (location != null)
                _buildDetailRow(
                  languageService.translate('last_seen'),
                  '${location.timestamp.day}/${location.timestamp.month}/${location.timestamp.year} ${location.timestamp.hour}:${location.timestamp.minute.toString().padLeft(2, '0')}',
                ),
              if (location != null && location.speed != null)
                _buildDetailRow(languageService.translate('speed'),
                    '${location.speed!.toStringAsFixed(1)} km/h'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: Text(languageService.translate('close')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _animateToAnimal(animal.id);
                      },
                      icon: const Icon(Icons.center_focus_strong),
                      label: Text(languageService.translate('center_on_map')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                ],
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
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _getAnimalTypeName(String type) {
    return context.tr(type.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('view_on_map')),
        backgroundColor: const Color(0xFF2E7D32),
        actions: [
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            onPressed: _centerOnAllAnimals,
            tooltip: languageService.translate('center_on_animals'),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => setState(() => _showLegend = !_showLegend),
            tooltip: languageService.translate('legend'),
          ),
          if (widget.animals.length > 1)
            PopupMenuButton<int>(
              onSelected: _animateToAnimal,
              itemBuilder: (context) {
                return widget.animals.map((animal) {
                  return PopupMenuItem<int>(
                    value: animal.id,
                    child: Row(
                      children: [
                        Icon(
                          Icons.pets,
                          color: animal.isStolen ? Colors.red : Colors.green,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(animal.name)),
                      ],
                    ),
                  );
                }).toList();
              },
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.list),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
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
                            onPressed: _loadAnimalLocations,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                            ),
                            child: Text(languageService.translate('retry')),
                          ),
                        ],
                      ),
                    )
                  : _markers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.map,
                                  size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(
                                context.tr('no_location_data'),
                                style: const TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                languageService.translate('no_location_data'),
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: _animalLocations.isNotEmpty
                                ? _animalLocations.values.first
                                : _defaultCenter,
                            zoom: 12,
                          ),
                          markers: _markers,
                          onMapCreated: (controller) {
                            _mapController = controller;
                          },
                          myLocationEnabled: true,
                          myLocationButtonEnabled: true,
                          zoomControlsEnabled: true,
                          compassEnabled: true,
                        ),

          // Legend
          if (_showLegend && _markers.isNotEmpty)
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
                      languageService.translate('legend').toUpperCase(),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(languageService.translate('active'),
                            style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(languageService.translate('stolen'),
                            style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      languageService.translate('click_marker_details'),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
