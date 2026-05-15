import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/language_service.dart';
import 'services/api_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/farmer/farmer_dashboard.dart';
import 'screens/ag_officer/officer_dashboard.dart';
import 'screens/police/police_dashboard.dart';
import 'screens/farmer/animal_list_screen.dart';
import 'screens/farmer/add_animal_screen.dart';
import 'screens/farmer/alerts_screen.dart';
import 'screens/farmer/transfer_requests_screen.dart';
import 'screens/ag_officer/farmers_list_screen.dart';
import 'screens/ag_officer/all_animals_screen.dart';
import 'screens/ag_officer/broadcast_screen.dart';
import 'screens/ag_officer/reports_screen.dart';
import 'screens/ag_officer/all_alerts_screen.dart';
import 'screens/ag_officer/add_police_screen.dart';
import 'screens/police/stolen_animals_screen.dart';
import 'screens/farmer/profile_screen.dart';
import 'models/animal_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final apiService = ApiService();
  await apiService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageService()),
        Provider(create: (_) => AuthService()),
      ],
      child: Consumer<LanguageService>(
        builder: (context, languageService, child) {
          return MaterialApp(
            title: 'Livestock Tracking System',
            debugShowCheckedModeBanner: false,
            locale: languageService.currentLocale,
            supportedLocales: const [
              Locale('en', ''),
              Locale('sw', ''),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: _buildLightTheme(),
            initialRoute: '/',
            routes: {
              '/': (context) => const SplashScreen(),
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),

              // Farmer Routes
              '/farmer': (context) => const FarmerDashboard(),
              '/farmer/add_animal': (context) => const AddAnimalScreen(),
              '/farmer/alerts': (context) => const AlertsScreen(),
              '/farmer/transfers': (context) => const TransferRequestsScreen(),

              // Ag Officer Routes
              '/officer': (context) => const OfficerDashboard(),
              '/officer/farmers': (context) => const FarmersListScreen(),
              '/officer/animals': (context) => const AllAnimalsScreen(),
              '/officer/broadcast': (context) => const BroadcastScreen(),
              '/officer/reports': (context) => const ReportsScreen(),
              '/officer/alerts': (context) => const AllAlertsScreen(),
              '/officer/police': (context) => const AddPoliceScreen(),

              // Police Routes
              '/police': (context) => const PoliceDashboard(),
              '/police/stolen': (context) => const StolenAnimalsScreen(),
              '/police/alerts': (context) => const AlertsScreen(),

              // Profile
              '/profile': (context) => const ProfileScreen(),
            },
          );
        },
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      primaryColor: const Color(0xFF2E7D32),
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color.fromARGB(255, 49, 122, 52),
        primary: const Color.fromARGB(255, 41, 120, 45),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF2E7D32),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
