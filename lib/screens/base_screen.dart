
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';
import '../services/animal_proximity_alarm_service.dart';
import '../models/user_model.dart';
import '../widgets/language_selector.dart';
import 'login_screen.dart';
import 'farmer/profile_screen.dart';
import 'farmer/animal_list_screen.dart';
import 'farmer/family_members_screen.dart';
import 'farmer/add_animal_screen.dart';
import 'farmer/transfer_requests_screen.dart';
import 'farmer/alerts_screen.dart';

class BaseScreen extends StatefulWidget {
  final Widget child;
  final String title;
  final int selectedIndex;

  const BaseScreen({
    super.key,
    required this.child,
    required this.title,
    this.selectedIndex = 0,
  });

  @override
  State<BaseScreen> createState() => _BaseScreenState();
}

class _BaseScreenState extends State<BaseScreen> {
  UserModel? _currentUser;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    _currentUser = await _authService.getCurrentUser();
    setState(() {});
  }

  void _navigateToAnimalsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AnimalListScreen(),
      ),
    );
  }

  void _navigateToFamilyMembers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FamilyMembersScreen(),
      ),
    );
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfileScreen(),
      ),
    );
  }

  Future<void> _logout() async {
    final languageService =
        Provider.of<LanguageService>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageService.translate('confirm_logout')),
        content: Text(languageService.translate('confirm_logout_message')),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(languageService.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(languageService.translate('logout')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await AnimalProximityAlarmService.instance.stop();
    await _authService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _navigateToDashboard() {
    final isFarmer = _currentUser?.role == 'FARMER';
    final isAgOfficer = _currentUser?.role == 'AG_OFFICER';
    final isPolice = _currentUser?.role == 'POLICE';

    if (isFarmer) {
      Navigator.pushReplacementNamed(context, '/farmer');
    } else if (isAgOfficer) {
      Navigator.pushReplacementNamed(context, '/officer');
    } else if (isPolice) {
      Navigator.pushReplacementNamed(context, '/police');
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isFarmer = _currentUser?.role == 'FARMER';
    final isAgOfficer = _currentUser?.role == 'AG_OFFICER';
    final isPolice = _currentUser?.role == 'POLICE';

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      drawer: Drawer(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
            ),
          ),
          child: Column(
            children: [
              // Drawer Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo tracker.jpg',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _currentUser?.fullName ?? 'User',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentUser?.phoneNumber ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, thickness: 1),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // Dashboard
                    _buildDrawerItem(
                      icon: Icons.dashboard,
                      title: 'Dashboard',
                      titleKey: 'dashboard',
                      isSelected: widget.selectedIndex == 0,
                      onTap: () {
                        Navigator.pop(context);
                        _navigateToDashboard();
                      },
                    ),

                    if (isFarmer) ...[
                      _buildDrawerItem(
                        icon: Icons.pets,
                        title: 'My Animals',
                        titleKey: 'my_animals_menu',
                        isSelected: widget.selectedIndex == 1,
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToAnimalsScreen();
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.add_box,
                        title: 'Add Animal',
                        titleKey: 'add_animal_menu',
                        isSelected: widget.selectedIndex == 2,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddAnimalScreen(),
                            ),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.swap_horiz,
                        title: 'Transfer Requests',
                        titleKey: 'transfer_requests_menu',
                        isSelected: widget.selectedIndex == 3,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const TransferRequestsScreen(),
                            ),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.notifications,
                        title: 'Alerts',
                        titleKey: 'alerts_menu',
                        isSelected: widget.selectedIndex == 4,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AlertsScreen(),
                            ),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.family_restroom,
                        title: 'Family Members',
                        titleKey: 'family_members_menu',
                        isSelected: widget.selectedIndex == 5,
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToFamilyMembers();
                        },
                      ),
                    ],

                    // ========== AG OFFICER MENU ITEMS ==========
                    if (isAgOfficer) ...[
                      _buildDrawerItem(
                        icon: Icons.people,
                        title: 'Farmers',
                        titleKey: 'farmers_menu',
                        isSelected: widget.selectedIndex == 1,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushReplacementNamed(
                              context, '/officer/farmers');
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.pets,
                        title: 'All Animals',
                        titleKey: 'all_animals_menu',
                        isSelected: widget.selectedIndex == 2,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushReplacementNamed(
                              context, '/officer/animals');
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.broadcast_on_home,
                        title: 'Broadcast',
                        titleKey: 'broadcast_menu',
                        isSelected: widget.selectedIndex == 3,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushReplacementNamed(
                              context, '/officer/broadcast');
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.bar_chart,
                        title: 'Reports',
                        titleKey: 'reports_menu',
                        isSelected: widget.selectedIndex == 4,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushReplacementNamed(
                              context, '/officer/reports');
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.notifications,
                        title: 'Alerts',
                        titleKey: 'alerts_menu',
                        isSelected: widget.selectedIndex == 5,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushReplacementNamed(
                              context, '/officer/alerts');
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.security,
                        title: 'Law Enforcement',
                        titleKey: 'police_menu',
                        isSelected: widget.selectedIndex == 7,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushReplacementNamed(
                              context, '/officer/police');
                        },
                      ),
                    ],

       
                    if (isPolice) ...[
                      _buildDrawerItem(
                        icon: Icons.warning,
                        title: 'Stolen Animals',
                        titleKey: 'stolen_animals_menu',
                        isSelected: widget.selectedIndex == 1,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushReplacementNamed(
                              context, '/police/stolen');
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.notifications,
                        title: 'Theft Alerts',
                        titleKey: 'theft_alerts_menu',
                        isSelected: widget.selectedIndex == 2,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushReplacementNamed(
                              context, '/police/alerts');
                        },
                      ),
                    ],

                    const Divider(color: Colors.white24),

                    // Profile
                    _buildDrawerItem(
                      icon: Icons.person_outline,
                      title: 'My Profile',
                      titleKey: 'profile_menu',
                      isSelected: false,
                      onTap: () {
                        Navigator.pop(context);
                        _navigateToProfile();
                      },
                    ),

                    // Logout
                    _buildDrawerItem(
                      icon: Icons.logout,
                      title: 'Logout',
                      titleKey: 'logout_menu',
                      isSelected: false,
                      isRed: true,
                      onTap: () {
                        Navigator.pop(context);
                        _logout();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              languageService.translate('habari'),
              style:
                  TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
            ),
            Text(
              _currentUser?.fullName ?? 'User',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          LanguageSelector(
            onLanguageChanged: (code) => languageService.setLanguage(code),
          ),
          PopupMenuButton<String>(
            offset: const Offset(0, 10),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                child: Text(
                  _currentUser?.initials ?? 'U',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),
            ),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  _navigateToProfile();
                  break;
                case 'family':
                  _navigateToFamilyMembers();
                  break;
                case 'logout':
                  _logout();
                  break;
              }
            },
            itemBuilder: (context) {
              final isFarmer = _currentUser?.role == 'FARMER';
              final items = <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentUser?.fullName ?? 'User',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _currentUser?.phoneNumber ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: _getRoleColor(_currentUser?.role)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getRoleName(_currentUser?.role),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: _getRoleColor(_currentUser?.role),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, color: Colors.green, size: 20),
                      SizedBox(width: 12),
                      Text('My Profile'),
                    ],
                  ),
                ),
                if (isFarmer)
                  const PopupMenuItem<String>(
                    value: 'family',
                    child: Row(
                      children: [
                        Icon(Icons.family_restroom,
                            color: Colors.green, size: 20),
                        SizedBox(width: 12),
                        Text('Family Members'),
                      ],
                    ),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red, size: 20),
                      SizedBox(width: 12),
                      Text(
                        'Logout',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ];
              return items;
            },
          ),
        ],
        elevation: 0,
      ),
      body: widget.child,
    );
  }

  String _getRoleName(String? role) {
    switch (role) {
      case 'FARMER':
        return '👨‍🌾 Farmer';
      case 'AG_OFFICER':
        return '👨‍💼 Admin';
      case 'POLICE':
        return '👮 Police Officer';
      default:
        return 'User';
    }
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'FARMER':
        return Colors.green;
      case 'AG_OFFICER':
        return Colors.blue;
      case 'POLICE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    String? titleKey,
    required VoidCallback onTap,
    bool isSelected = false,
    bool isRed = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? Colors.white.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        leading: Icon(icon, color: isRed ? Colors.red : Colors.white, size: 22),
        title: Text(
          titleKey == null
              ? title
              : Provider.of<LanguageService>(context).translate(titleKey),
          style: TextStyle(
            color: isRed ? Colors.red : Colors.white,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : null,
        onTap: onTap,
      ),
    );
  }
}
