import 'package:flutter_test/flutter_test.dart';
import 'package:qr_scanner/features/attendance/domain/services/attendance_flow_service.dart';
import 'package:qr_scanner/features/attendance/domain/services/scan_policy_service.dart';
import 'package:qr_scanner/features/events/domain/entities/event.dart';

void main() {
  group('scan policy service', () {
    test('isActionAllowed respects scan mode', () {
      expect(isActionAllowed(ScanMode.both, AttendanceAction.entry), isTrue);
      expect(isActionAllowed(ScanMode.both, AttendanceAction.exit), isTrue);
      expect(isActionAllowed(ScanMode.entryOnly, AttendanceAction.entry), isTrue);
      expect(isActionAllowed(ScanMode.entryOnly, AttendanceAction.exit), isFalse);
      expect(isActionAllowed(ScanMode.exitOnly, AttendanceAction.entry), isFalse);
      expect(isActionAllowed(ScanMode.exitOnly, AttendanceAction.exit), isTrue);
    });

    test('isCooldownActive detects active window', () {
      final last = DateTime(2026, 3, 14, 10, 0, 0);
      final nowInside = DateTime(2026, 3, 14, 10, 0, 2);
      final nowOutside = DateTime(2026, 3, 14, 10, 0, 5);

      expect(
        isCooldownActive(lastScanAt: last, now: nowInside, cooldownSeconds: 3),
        isTrue,
      );
      expect(
        isCooldownActive(lastScanAt: last, now: nowOutside, cooldownSeconds: 3),
        isFalse,
      );
    });
  });
}
