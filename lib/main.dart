import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const MoniApp());
}

class MoniApp extends StatelessWidget {
  const MoniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Moni',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF4361EE),
      ),
      home: const SplashScreen(),
    );
  }
}
