import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/language_service.dart';
import '../../models/animal_model.dart';
import '../../models/user_model.dart';
import '../../utils/constants.dart';
import '../base_screen.dart';
import 'farmers_list_screen.dart';
import 'all_animals_screen.dart';
import 'broadcast_screen.dart';
import 'reports_screen.dart';
import 'all_alerts_screen.dart';
import 'add_police_screen.dart';

class OfficerDashboard extends StatefulWidget {
  const OfficerDashboard({super.key});

  @override
  State<OfficerDashboard> createState() => _OfficerDashboardState();
}

class _OfficerDashboardState extends State<OfficerDashboard> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  int _totalFarmers = 0;
  int _totalAnimals = 0;
  int _stolenAnimals = 0;
  int _unreadAlerts = 0;
  int _totalPolice = 0;
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

      final farmersResponse =
          await _apiService.get('${AppConstants.users}farmers/');
      if (farmersResponse.statusCode == 200) {
        _totalFarmers = (farmersResponse.data as List).length;
      }

      final policeResponse =
          await _apiService.get('${AppConstants.users}police/');
      if (policeResponse.statusCode == 200) {
        _totalPolice = (policeResponse.data as List).length;
      }

      final animalsResponse = await _apiService.get(AppConstants.animals);
      if (animalsResponse.statusCode == 200) {
        final List<dynamic> animalsData = animalsResponse.data['results'] ?? [];
        _totalAnimals = animalsData.length;
        _stolenAnimals =
            animalsData.where((a) => a['status'] == 'STOLEN').length;
      }

      final alertsResponse =
          await _apiService.get('${AppConstants.alerts}?is_read=false');
      if (alertsResponse.statusCode == 200) {
        _unreadAlerts = (alertsResponse.data['results'] as List).length;
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
      title: 'Officer Dashboard',
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

                        isSmallScreen
                            ? Column(
                                children: [
                                  Row(
                                    children: [
                                      _buildStatCard(
                                        icon: Icons.people,
                                        title: languageService
                                            .translate('farmers'),
                                        value: _totalFarmers.toString(),
                                        color: Colors.blue,
                                      ),
                                      const SizedBox(width: 12),
                                      _buildStatCard(
                                        icon: Icons.pets,
                                        title: languageService
                                            .translate('animals'),
                                        value: _totalAnimals.toString(),
                                        color: Colors.green,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      _buildStatCard(
                                        icon: Icons.warning,
                                        title: languageService
                                            .translate('stolen_animals'),
                                        value: _stolenAnimals.toString(),
                                        color: Colors.red,
                                      ),
                                      const SizedBox(width: 12),
                                      _buildStatCard(
                                        icon: Icons.notifications,
                                        title:
                                            languageService.translate('alerts'),
                                        value: _unreadAlerts.toString(),
                                        color: Colors.orange,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      _buildStatCard(
                                        icon: Icons.security,
                                        title:
                                            languageService.translate('police'),
                                        value: _totalPolice.toString(),
                                        color: Colors.purple,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(child: Container()),
                                    ],
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  _buildStatCard(
                                    icon: Icons.people,
                                    title: languageService
                                        .translate('total_farmers'),
                                    value: _totalFarmers.toString(),
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 12),
                                  _buildStatCard(
                                    icon: Icons.pets,
                                    title: languageService
                                        .translate('total_animals'),
                                    value: _totalAnimals.toString(),
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 12),
                                  _buildStatCard(
                                    icon: Icons.warning,
                                    title: languageService
                                        .translate('stolen_animals'),
                                    value: _stolenAnimals.toString(),
                                    color: Colors.red,
                                  ),
                                  const SizedBox(width: 12),
                                  _buildStatCard(
                                    icon: Icons.notifications,
                                    title:
                                        languageService.translate('new_alerts'),
                                    value: _unreadAlerts.toString(),
                                    color: Colors.orange,
                                  ),
                                ],
                              ),

                        const SizedBox(height: 24),

                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: isSmallScreen ? 2 : 3,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 1.1,
                          children: [
                            _buildMenuCard(
                              icon: Icons.people,
                              title: languageService
                                  .translate('farmers')
                                  .toUpperCase(),
                              color: Colors.blue,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const FarmersListScreen(),
                                  ),
                                ).then((_) => _loadData());
                              },
                            ),
                            _buildMenuCard(
                              icon: Icons.pets,
                              title: languageService
                                  .translate('animals')
                                  .toUpperCase(),
                              color: Colors.green,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AllAnimalsScreen(),
                                  ),
                                );
                              },
                            ),
                            _buildMenuCard(
                              icon: Icons.broadcast_on_home,
                              title: languageService
                                  .translate('send_broadcast')
                                  .toUpperCase(),
                              color: Colors.purple,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const BroadcastScreen(),
                                  ),
                                );
                              },
                            ),
                            _buildMenuCard(
                              icon: Icons.bar_chart,
                              title: languageService
                                  .translate('reports')
                                  .toUpperCase(),
                              color: Colors.orange,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ReportsScreen(),
                                  ),
                                );
                              },
                            ),
                            _buildMenuCard(
                              icon: Icons.notifications,
                              title: languageService
                                  .translate('alerts')
                                  .toUpperCase(),
                              color: Colors.red,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AllAlertsScreen(),
                                  ),
                                );
                              },
                            ),
                            _buildMenuCard(
                              icon: Icons.security,
                              title: languageService
                                  .translate('police')
                                  .toUpperCase(),
                              color: Colors.deepPurple,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AddPoliceScreen(),
                                  ),
                                ).then((_) => _loadData());
                              },
                            ),
                          ],
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
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
