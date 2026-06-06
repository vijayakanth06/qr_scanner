import 'package:flutter/material.dart';

import '../core/notifications/notification_service.dart';
import '../features/college_picker/college_picker_screen.dart';
import '../features/events/presentation/screens/home_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import 'di.dart';
import 'theme.dart';

bool needsCollegePicker = false;

class QrScannerApp extends StatelessWidget {
  const QrScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'QR Event Scanner',
      navigatorKey: sl<GlobalKey<NavigatorState>>(),
      theme: buildLightTheme(),
      themeMode: ThemeMode.light,
      scaffoldMessengerKey: sl<NotificationService>().messengerKey,
      initialRoute: needsCollegePicker ? '/pick-college' : '/home',
      routes: {
        '/home': (context) => const HomeScreen(),
        '/pick-college': (context) => const CollegePickerScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
