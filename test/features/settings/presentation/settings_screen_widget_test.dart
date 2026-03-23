import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qr_scanner/features/settings/presentation/screens/settings_screen.dart';
import 'package:qr_scanner/features/students/domain/entities/student.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveTempDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    hiveTempDir = await Directory.systemTemp.createTemp('qr_scanner_test_hive');
    Hive.init(hiveTempDir.path);
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(StudentAdapter());
    }
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
    if (hiveTempDir.existsSync()) {
      hiveTempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('renders settings screen with analytics and import action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsScreen(),
      ),
    );

    await tester.pumpAndSettle();

    // UI copy changed from "Department Settings" to "Departments".
    expect(find.text('Departments'), findsOneWidget);
    expect(find.text('Scan Analytics'), findsOneWidget);
    expect(find.text('Import Students CSV/Excel'), findsOneWidget);
  });
}
