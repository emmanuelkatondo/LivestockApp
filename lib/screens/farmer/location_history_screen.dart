import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/animal_model.dart';
import '../../models/location_model.dart';
import '../../services/api_service.dart';
import '../../services/language_service.dart';
import '../../utils/constants.dart';

class LocationHistoryScreen extends StatefulWidget {
  final AnimalModel animal;

  const LocationHistoryScreen({
    super.key,
    required this.animal,
  });

  @override
  State<LocationHistoryScreen> createState() => _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends State<LocationHistoryScreen> {
  final ApiService _apiService = ApiService();

  List<LocationModel> _locations = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedDays = 7;

  // Google Maps controller
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLngBounds? _bounds;

  @override
  void initState() {
    super.initState();
    _loadLocationHistory();
  }

  Future<void> _loadLocationHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.get(
          '${AppConstants.animals}${widget.animal.id}/locations/?days=$_selectedDays');

      if (response.statusCode == 200) {
        // Handle response data
        List<dynamic> data;
        if (response.data is List) {
          data = response.data;
        } else if (response.data is Map &&
            response.data.containsKey('results')) {
          data = response.data['results'];
        } else {
          data = [];
        }

        _locations = data.map((json) => LocationModel.fromJson(json)).toList();

        print(
            'Loaded ${_locations.length} locations for ${widget.animal.name}');

        // Build markers and polylines
        _buildMarkersAndPolylines();

        // Center map on first location after loading
        if (_locations.isNotEmpty && _mapController != null) {
          _centerMapOnLocations();
        }
      }
    } catch (e) {
      print('Error loading locations: $e');
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _buildMarkersAndPolylines() {
    if (_locations.isEmpty) return;

    Set<Marker> markers = {};
    Set<Polyline> polylines = {};
    List<LatLng> polylinePoints = [];

    for (int i = 0; i < _locations.length; i++) {
      final location = _locations[i];
      final latLng = LatLng(location.latitude, location.longitude);
      polylinePoints.add(latLng);

      // Add marker for each location with number
      markers.add(
        Marker(
          markerId: MarkerId('location_$i'),
          position: latLng,
          infoWindow: InfoWindow(
            title: '${context.tr('point')} ${i + 1}',
            snippet: _formatDateTime(location.timestamp),
          ),
          icon: i == 0
              ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
              : i == _locations.length - 1
                  ? BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed)
                  : BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueBlue),
        ),
      );
    }

    // Add polyline connecting all points
    polylines.add(
      Polyline(
        polylineId: const PolylineId('path'),
        points: polylinePoints,
        color: const Color(0xFF2E7D32),
        width: 4,
        geodesic: true,
      ),
    );

    // Calculate bounds to fit all points
    double minLat = polylinePoints.first.latitude;
    double maxLat = polylinePoints.first.latitude;
    double minLng = polylinePoints.first.longitude;
    double maxLng = polylinePoints.first.longitude;

    for (var point in polylinePoints) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;

    setState(() {
      _markers = markers;
      _polylines = polylines;
      _bounds = LatLngBounds(
        southwest: LatLng(minLat - latPadding, minLng - lngPadding),
        northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
      );
    });
  }

  void _centerMapOnLocations() {
    if (_bounds != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(_bounds!, 50),
      );
    } else if (_locations.isNotEmpty && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(_locations.first.latitude, _locations.first.longitude),
        ),
      );
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${widget.animal.name} - ${languageService.translate('location_history')}'),
        backgroundColor: const Color(0xFF2E7D32),
        actions: [
          PopupMenuButton<int>(
            onSelected: (days) {
              setState(() {
                _selectedDays = days;
              });
              _loadLocationHistory();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                  value: 1,
                  child: Text(languageService.translate('last_1_day'))),
              PopupMenuItem(
                  value: 7,
                  child: Text(languageService.translate('last_7_days'))),
              PopupMenuItem(
                  value: 14,
                  child: Text(languageService.translate('last_14_days'))),
              PopupMenuItem(
                  value: 30,
                  child: Text(languageService.translate('last_30_days'))),
            ],
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Text('$_selectedDays ${languageService.translate('days')}'),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
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
                        onPressed: _loadLocationHistory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                        ),
                        child: Text(languageService.translate('retry')),
                      ),
                    ],
                  ),
                )
              : _locations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.location_off,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            languageService.translate('no_data_available'),
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            languageService.translate('no_location_data'),
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Map
                        Expanded(
                          flex: 3,
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: LatLng(
                                _locations.first.latitude,
                                _locations.first.longitude,
                              ),
                              zoom: 13,
                            ),
                            markers: _markers,
                            polylines: _polylines,
                            onMapCreated: (controller) {
                              _mapController = controller;
                              _centerMapOnLocations();
                            },
                            myLocationEnabled: true,
                            myLocationButtonEnabled: true,
                            zoomControlsEnabled: true,
                            compassEnabled: true,
                          ),
                        ),

                        // Location List
                        Expanded(
                          flex: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, -5),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    languageService
                                        .translate('location_history')
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: _locations.length,
                                    itemBuilder: (context, index) {
                                      final location = _locations[index];
                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: index == 0
                                              ? Colors.green
                                              : index == _locations.length - 1
                                                  ? Colors.red
                                                  : Colors.grey.shade300,
                                          child: Text(
                                            (index + 1).toString(),
                                            style: TextStyle(
                                              color: index == 0 ||
                                                      index ==
                                                          _locations.length - 1
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                        subtitle: Text(
                                          _formatDateTime(location.timestamp),
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        trailing: location.speed != null
                                            ? Chip(
                                                label: Text(
                                                  '${location.speed!.toStringAsFixed(1)} km/h',
                                                  style: const TextStyle(
                                                      fontSize: 10),
                                                ),
                                                backgroundColor:
                                                    Colors.blue.shade100,
                                                materialTapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              )
                                            : null,
                                        dense: true,
                                        onTap: () {
                                          _mapController?.animateCamera(
                                            CameraUpdate.newLatLng(
                                              LatLng(location.latitude,
                                                  location.longitude),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
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
