import 'package:flutter/material.dart';

import '../features/events/presentation/screens/home_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';

class QrScannerApp extends StatelessWidget {
  const QrScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'QR Event Scanner',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
      routes: {
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
