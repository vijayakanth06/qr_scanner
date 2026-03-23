import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qr_scanner/features/settings/presentation/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders settings screen with export and departments sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsScreen(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Export Settings'), findsOneWidget);
    expect(find.text('Change Save Location'), findsOneWidget);
    expect(find.text('Departments'), findsOneWidget);

    expect(find.text('Scan Analytics'), findsNothing);
    expect(find.text('Import CSV/Excel'), findsNothing);
    expect(find.text('Import Students CSV/Excel'), findsNothing);
  });
}
