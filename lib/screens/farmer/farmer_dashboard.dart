// lib/screens/farmer/farmer_dashboard.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/language_service.dart';
import '../../models/animal_model.dart';
import '../../models/location_model.dart';
import '../../models/user_model.dart';
import '../../utils/constants.dart';
import '../base_screen.dart';
import 'add_animal_screen.dart';
import 'animal_list_screen.dart';
import 'alerts_screen.dart';
import 'transfer_ownership_screen.dart';
import 'animal_detail_screen.dart';
import 'transfer_requests_screen.dart';

class FarmerDashboard extends StatefulWidget {
  const FarmerDashboard({super.key});

  @override
  State<FarmerDashboard> createState() => _FarmerDashboardState();
}

class _FarmerDashboardState extends State<FarmerDashboard> {
  final ApiService _apiService = ApiService();

  List<AnimalModel> _animals = [];
  List<LocationModel> _recentLocations = [];
  List<dynamic> _alerts = [];
  Map<int, LatLng> _animalLocations = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final animalsResponse = await _apiService.get(AppConstants.animals);
      if (animalsResponse.statusCode == 200) {
        final List<dynamic> animalsData = animalsResponse.data['results'] ?? [];
        _animals =
            animalsData.map((json) => AnimalModel.fromJson(json)).toList();
      }

      final alertsResponse =
          await _apiService.get('${AppConstants.alerts}?is_read=false');
      if (alertsResponse.statusCode == 200) {
        _alerts = alertsResponse.data['results'] ?? [];
      }

      _animalLocations.clear();
      _recentLocations.clear();

      for (var animal in _animals.take(5)) {
        try {
          final locationsResponse = await _apiService
              .get('${AppConstants.animals}${animal.id}/locations/');
          if (locationsResponse.statusCode == 200) {
            final locations = locationsResponse.data as List;
            if (locations.isNotEmpty) {
              final location = LocationModel.fromJson(locations.first);
              _recentLocations.add(location);
              _animalLocations[animal.id] =
                  LatLng(location.latitude, location.longitude);
            }
          }
        } catch (e) {
          print('Error loading locations for animal ${animal.id}: $e');
        }
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

  LatLng _getMapCenter() {
    if (_animalLocations.isNotEmpty) {
      return _animalLocations.values.first;
    }
    return const LatLng(-6.8350, 37.6700);
  }

  void _openFullScreenMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenMap(
          animals: _animals,
          animalLocations: _animalLocations,
        ),
      ),
    );
  }

  Set<Marker> _buildPreviewMarkers() {
    Set<Marker> markers = {};
    for (var entry in _animalLocations.entries) {
      final animal = _animals.firstWhere((a) => a.id == entry.key,
          orElse: () => _animals.first);
      markers.add(
        Marker(
          markerId: MarkerId(entry.key.toString()),
          position: entry.value,
          icon: animal.isStolen
              ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)
              : BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen),
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return BaseScreen(
      title: 'Farmer Dashboard',
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
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Stats Cards
                        isSmallScreen
                            ? Column(
                                children: [
                                  Row(
                                    children: [
                                      _buildStatCard(
                                        icon: Icons.pets,
                                        title: languageService
                                            .translate('total_animals'),
                                        value: _animals.length.toString(),
                                        color: Colors.green,
                                      ),
                                      const SizedBox(width: 12),
                                      _buildStatCard(
                                        icon: Icons.gps_fixed,
                                        title: languageService
                                            .translate('active_gps'),
                                        value: _animals
                                            .where((a) => a.isActive)
                                            .length
                                            .toString(),
                                        color: Colors.blue,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      _buildStatCard(
                                        icon: Icons.notifications,
                                        title: languageService
                                            .translate('unread_alerts'),
                                        value: _alerts.length.toString(),
                                        color: Colors.orange,
                                      ),
                                      const SizedBox(width: 12),
                                      _buildStatCard(
                                        icon: Icons.warning,
                                        title: languageService
                                            .translate('stolen_animals'),
                                        value: _animals
                                            .where((a) => a.isStolen)
                                            .length
                                            .toString(),
                                        color: Colors.red,
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  _buildStatCard(
                                    icon: Icons.pets,
                                    title: languageService
                                        .translate('total_animals'),
                                    value: _animals.length.toString(),
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 12),
                                  _buildStatCard(
                                    icon: Icons.gps_fixed,
                                    title:
                                        languageService.translate('active_gps'),
                                    value: _animals
                                        .where((a) => a.isActive)
                                        .length
                                        .toString(),
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 12),
                                  _buildStatCard(
                                    icon: Icons.notifications,
                                    title: languageService
                                        .translate('unread_alerts'),
                                    value: _alerts.length.toString(),
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 12),
                                  _buildStatCard(
                                    icon: Icons.warning,
                                    title: languageService
                                        .translate('stolen_animals'),
                                    value: _animals
                                        .where((a) => a.isStolen)
                                        .length
                                        .toString(),
                                    color: Colors.red,
                                  ),
                                ],
                              ),

                        const SizedBox(height: 20),

                        // Map Preview
                        Container(
                          height: 200,
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: _animalLocations.isEmpty
                                ? GestureDetector(
                                    onTap: _openFullScreenMap,
                                    child: Container(
                                      color: Colors.grey.shade200,
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.map,
                                                size: 50, color: Colors.grey),
                                            const SizedBox(height: 10),
                                            Text(languageService.translate(
                                                'click_to_view_map')),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                : GoogleMap(
                                    initialCameraPosition: CameraPosition(
                                      target: _getMapCenter(),
                                      zoom: 14,
                                    ),
                                    markers: _buildPreviewMarkers(),
                                    zoomControlsEnabled: false,
                                    myLocationButtonEnabled: false,
                                    scrollGesturesEnabled: false,
                                    zoomGesturesEnabled: false,
                                    tiltGesturesEnabled: false,
                                    rotateGesturesEnabled: false,
                                    onTap: (LatLng position) {
                                      _openFullScreenMap();
                                    },
                                  ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              languageService
                                  .translate('my_animals')
                                  .toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AnimalListScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                languageService
                                    .translate('view_all')
                                    .toUpperCase(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Animal List
                        _animals.isEmpty
                            ? _buildEmptyState(languageService)
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount:
                                    _animals.length > 3 ? 3 : _animals.length,
                                itemBuilder: (context, index) =>
                                    _buildAnimalCard(_animals[index]),
                              ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(value,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(LanguageService languageService) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pets, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(languageService.translate('no_animals'),
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AddAnimalScreen()))
                    .then((_) => _loadData());
              },
              icon: const Icon(Icons.add),
              label:
                  Text(languageService.translate('add_animal').toUpperCase()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimalCard(AnimalModel animal) {
    final languageService = Provider.of<LanguageService>(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => AnimalDetailScreen(animal: animal)))
                .then((_) => _loadData());
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade100),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildAnimalImage(animal),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(animal.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(animal.animalId,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(animal.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    languageService.translate(animal.status.toLowerCase()),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _getStatusColor(animal.status)),
                  ),
                ),
              ],
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
        width: 55,
        height: 55,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) => loadingProgress ==
                null
            ? child
            : Container(
                color: Colors.grey.shade200,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
        errorBuilder: (context, error, stackTrace) => Container(
          color: _getStatusColor(animal.status).withOpacity(0.1),
          child:
              Icon(Icons.pets, size: 30, color: _getStatusColor(animal.status)),
        ),
      );
    } else {
      return Container(
        color: _getStatusColor(animal.status).withOpacity(0.1),
        child:
            Icon(Icons.pets, size: 30, color: _getStatusColor(animal.status)),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ACTIVE':
        return Colors.green;
      case 'SOLD':
        return Colors.blue;
      case 'SLAUGHTERED':
        return Colors.orange;
      case 'DEAD':
        return Colors.red;
      case 'STOLEN':
        return Colors.red.shade900;
      default:
        return Colors.grey;
    }
  }
}

// ========== FULL SCREEN MAP WITH GOOGLE MAPS ==========
class FullScreenMap extends StatefulWidget {
  final List<AnimalModel> animals;
  final Map<int, LatLng> animalLocations;

  const FullScreenMap(
      {super.key, required this.animals, required this.animalLocations});

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
            '${languageService.translate('animal_map').toUpperCase()} (${widget.animalLocations.length})',
            style: const TextStyle(fontSize: 16)),
        backgroundColor: const Color(0xFF2E7D32),
        actions: [
          IconButton(
              icon: const Icon(Icons.center_focus_strong),
              onPressed: _centerOnAnimals,
              tooltip: languageService.translate('center_on_animals')),
          IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => setState(() => _showLegend = !_showLegend),
              tooltip: languageService.translate('legend')),
          IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context)),
        ],
      ),
      body: Stack(
        children: [
          widget.animalLocations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.map, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(languageService.translate('no_location_data')),
                    ],
                  ),
                )
              : GoogleMap(
                  initialCameraPosition:
                      CameraPosition(target: _getCenterPoint(), zoom: 15),
                  markers: _buildMarkers(),
                  onMapCreated: (controller) => _mapController = controller,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                  compassEnabled: true,
                ),

          // Zoom Controls
          Positioned(
            bottom: 20,
            right: 20,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 5,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Column(
                    children: [
                      IconButton(
                          icon: const Icon(Icons.add, size: 24),
                          onPressed: () => _mapController
                              .animateCamera(CameraUpdate.zoomIn()),
                          color: const Color(0xFF2E7D32)),
                      const Divider(height: 1),
                      IconButton(
                          icon: const Icon(Icons.remove, size: 24),
                          onPressed: () => _mapController
                              .animateCamera(CameraUpdate.zoomOut()),
                          color: const Color(0xFF2E7D32)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 5,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.center_focus_strong, size: 24),
                    onPressed: _centerOnAnimals,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
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
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(languageService.translate('legend').toUpperCase(),
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                              color: Colors.green, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(languageService.translate('active'))
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(languageService.translate('stolen'))
                    ]),
                    const SizedBox(height: 8),
                    Text(languageService.translate('click_marker_details'),
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
            ),

          // Counter
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Text(
                  ' ${widget.animalLocations.length} ${languageService.translate('animals').toLowerCase()}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Set<Marker> _buildMarkers() {
    Set<Marker> markers = {};
    for (var entry in widget.animalLocations.entries) {
      final animal = widget.animals.firstWhere((a) => a.id == entry.key,
          orElse: () => widget.animals.first);
      markers.add(
        Marker(
          markerId: MarkerId(entry.key.toString()),
          position: entry.value,
          infoWindow: InfoWindow(
            title: animal.name,
            snippet:
                '${context.tr('status')}: ${context.tr(animal.status.toLowerCase())}\n${context.tr('owner')}: ${animal.ownerfullName}',
          ),
          icon: animal.isStolen
              ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)
              : BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen),
        ),
      );
    }
    return markers;
  }

  LatLng _getCenterPoint() {
    if (widget.animalLocations.isEmpty) return const LatLng(-6.8350, 37.6700);
    double sumLat = 0, sumLng = 0;
    for (var loc in widget.animalLocations.values) {
      sumLat += loc.latitude;
      sumLng += loc.longitude;
    }
    return LatLng(sumLat / widget.animalLocations.length,
        sumLng / widget.animalLocations.length);
  }

  void _centerOnAnimals() {
    if (widget.animalLocations.isNotEmpty) {
      _mapController.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: _getCenterPoint(), zoom: 15)));
    }
  }
}
