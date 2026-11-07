import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/dashboard/presentation/screens/home_dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: Integra3DApp(),
    ),
  );
}

class Integra3DApp extends StatelessWidget {
  const Integra3DApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Integra3D',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.academicDarkTheme,
      home: const HomeDashboardScreen(),
    );
  }
}
