import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qr_scanner/features/attendance/domain/services/attendance_flow_service.dart';
import 'package:qr_scanner/features/attendance/domain/services/scan_policy_service.dart';
import 'package:qr_scanner/features/events/domain/entities/event.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('scan policy mode checks work in integration environment', (tester) async {
    final entryAllowed = isActionAllowed(ScanMode.entryOnly, AttendanceAction.entry);
    final exitBlocked = isActionAllowed(ScanMode.entryOnly, AttendanceAction.exit);

    expect(entryAllowed, isTrue);
    expect(exitBlocked, isFalse);
  });
}
