import 'package:flutter/material.dart';
import 'package:phoneapp/screens/splash_screen.dart';
import 'package:phoneapp/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Home Security',
      theme: AppTheme.theme,
      home: const SplashScreen(),
    );
  }
}

