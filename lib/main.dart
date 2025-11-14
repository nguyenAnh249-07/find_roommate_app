import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/auth_provider.dart';
import 'screens/common/auth/login_screen.dart';
import 'screens/user/home_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/owner/owner_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(themeProvider);
    final authState = ref.watch(authStateProvider);
    final currentUserAsync = ref.watch(currentUserProvider);

    return MaterialApp(
      title: 'Find Roommate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: authState.when(
        data: (user) {
          if (user == null) {
            return const LoginScreen();
          }
          
          // Wait for user data to load to determine role
          return currentUserAsync.when(
            data: (userModel) {
              if (userModel == null) {
                // User data not loaded yet, show loading
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              
              // Route based on user role
              switch (userModel.role) {
                case 'admin':
                  return const AdminDashboardScreen();
                case 'owner':
                  // Owner goes directly to Owner Dashboard
                  return const OwnerDashboardScreen();
                case 'user':
                default:
                  return const HomeScreen();
              }
            },
            loading: () => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => Scaffold(
              body: Center(child: Text('Error loading user: $error')),
            ),
          );
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stack) => Scaffold(
          body: Center(child: Text('Error: $error')),
        ),
      ),
    );
  }
}
