import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'services/api_service.dart';
import 'services/auth_provider.dart';
import 'services/house_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/homeowner/homeowner_dashboard.dart';
import 'screens/resident/resident_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();

  final apiService = ApiService();
  final authProvider = AuthProvider(apiService);

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProxyProvider<AuthProvider, HouseProvider>(
          create: (_) => HouseProvider(apiService),
          update: (_, auth, previous) => previous ?? HouseProvider(apiService),
        ),
      ],
      child: const VigilisApp(),
    ),
  );
}

class VigilisApp extends StatelessWidget {
  const VigilisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vigilis — Intelligent House Security',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (!auth.isAuthenticated) {
            return const LoginScreen();
          }

          // Route strictly to role-appropriate dashboard
          switch (auth.currentUser?.role) {
            case 'PLATFORM_ADMIN':
              return const AdminDashboardScreen();
            case 'HOMEOWNER':
              return const HomeownerDashboard();
            case 'RESIDENT':
              return const ResidentDashboard();
            default:
              return const LoginScreen();
          }
        },
      ),
    );
  }
}
