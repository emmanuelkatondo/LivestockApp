import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'login_screen.dart';
import '../screens/farmer/farmer_dashboard.dart';
import '../screens/ag_officer/officer_dashboard.dart';
import '../screens/police/police_dashboard.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    await Future.delayed(const Duration(seconds: 3));

    final isLoggedIn = await _authService.isLoggedIn();

    if (!mounted) return;

    if (isLoggedIn) {
      final user = await _authService.getCurrentUser();

      if (user != null) {
        if (user.isFarmer) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const FarmerDashboard()),
          );
        } else if (user.isAgOfficer) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const OfficerDashboard()),
          );
        } else if (user.isPolice) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const PoliceDashboard()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Logo
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipOval(
                  child: Image.asset(
                'assets/images/logo tracker.jpg',
                fit: BoxFit.cover,
              )),
            ).animate().scale(duration: 800.ms, curve: Curves.easeOut).fadeIn(),

            const SizedBox(height: 40),

            // App Name
            Column(
              children: [
                Text(
                  'LIVESTOCK',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'TRACKING SYSTEM',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.9),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ).animate().slideY(begin: 0.5, end: 0, duration: 800.ms),

            const SizedBox(height: 80),

            // Loading indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),

            const SizedBox(height: 20),

            Text(
              languageService.translate('loading'),
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ).animate().fadeIn(delay: 500.ms),
          ],
        ),
      ),
    );
  }
}
