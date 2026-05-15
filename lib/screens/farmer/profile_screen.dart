import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/language_service.dart';
import '../../models/user_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    _user = await authService.getCurrentUser();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(languageService.translate('profile')),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: _user == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.green, width: 3),
                    ),
                    child: const Center(
                      child: Icon(Icons.person, size: 60, color: Colors.green),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(languageService.translate('full_name')),
                      subtitle: Text(_user!.fullName),
                    ),
                  ),

                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.phone),
                      title: Text(languageService.translate('phone_number')),
                      subtitle: Text(_user!.phoneNumber),
                    ),
                  ),
                  // Email
                  if (_user!.email != null && _user!.email!.isNotEmpty)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.email),
                        title: Text(languageService.translate('email')),
                        subtitle: Text(_user!.email!),
                      ),
                    ),

                  if (_user!.location != null && _user!.location!.isNotEmpty)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.location_on),
                        title: Text(languageService.translate('location')),
                        subtitle: Text(_user!.location!),
                      ),
                    ),

                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.badge),
                      title: Text(languageService.translate('role')),
                      subtitle: Text(_user!.role),
                    ),
                  ),

                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: Text(languageService.translate('joined_date')),
                      subtitle: Text(_user!.formattedDateJoined),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
