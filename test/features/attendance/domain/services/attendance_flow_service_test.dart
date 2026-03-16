import 'package:flutter_test/flutter_test.dart';
import 'package:qr_scanner/features/attendance/domain/entities/attendee.dart';
import 'package:qr_scanner/features/attendance/domain/services/attendance_flow_service.dart';

class InMemoryAttendeeStore implements AttendeeStore {
  final List<Attendee> _records = [];

  @override
  Future<void> add(Attendee attendee) async {
    _records.add(attendee);
  }

  @override
  Iterable<Attendee> all() => _records;

  @override
  Future<void> save(Attendee attendee) async {}
}

void main() {
  group('AttendanceFlowService', () {
    test('records entry for valid roll number', () async {
      final store = InMemoryAttendeeStore();
      final service = AttendanceFlowService(store: store);

      final result = await service.recordAttendance(
        eventName: 'Tech Fest',
        scannedValue: '23ALR109',
        action: AttendanceAction.entry,
        departments: {'ALR': 'AIML'},
        timestamp: DateTime(2026, 3, 14, 9, 0, 0),
      );

      expect(result.success, isTrue);
      expect(store.all().length, 1);
      final first = store.all().first;
      expect(first.id, '23ALR109');
      expect(first.outTime, isNull);
    });

    test('prevents duplicate active entry', () async {
      final store = InMemoryAttendeeStore();
      final service = AttendanceFlowService(store: store);

      await service.recordAttendance(
        eventName: 'Tech Fest',
        scannedValue: '23ALR109',
        action: AttendanceAction.entry,
        departments: {'ALR': 'AIML'},
      );

      final second = await service.recordAttendance(
        eventName: 'Tech Fest',
        scannedValue: '23ALR109',
        action: AttendanceAction.entry,
        departments: {'ALR': 'AIML'},
      );

      expect(second.success, isFalse);
      expect(second.message, contains('Entry already active'));
      expect(store.all().length, 1);
    });

    test('records exit for active entry', () async {
      final store = InMemoryAttendeeStore();
      final service = AttendanceFlowService(store: store);

      await service.recordAttendance(
        eventName: 'Tech Fest',
        scannedValue: '23ALR109',
        action: AttendanceAction.entry,
        departments: {'ALR': 'AIML'},
        timestamp: DateTime(2026, 3, 14, 9, 0, 0),
      );

      final exit = await service.recordAttendance(
        eventName: 'Tech Fest',
        scannedValue: '23ALR109',
        action: AttendanceAction.exit,
        departments: {'ALR': 'AIML'},
        timestamp: DateTime(2026, 3, 14, 10, 0, 0),
      );

      expect(exit.success, isTrue);
      expect(store.all().first.outTime, DateTime(2026, 3, 14, 10, 0, 0));
    });

    test('rejects exit when no active entry exists', () async {
      final store = InMemoryAttendeeStore();
      final service = AttendanceFlowService(store: store);

      final result = await service.recordAttendance(
        eventName: 'Tech Fest',
        scannedValue: '23ALR109',
        action: AttendanceAction.exit,
        departments: {'ALR': 'AIML'},
      );

      expect(result.success, isFalse);
      expect(result.message, contains('No active entry found'));
    });

    test('rejects invalid barcode value', () async {
      final store = InMemoryAttendeeStore();
      final service = AttendanceFlowService(store: store);

      final result = await service.recordAttendance(
        eventName: 'Tech Fest',
        scannedValue: 'bad-code',
        action: AttendanceAction.entry,
        departments: {'ALR': 'AIML'},
      );

      expect(result.success, isFalse);
      expect(result.message, contains('Invalid barcode format'));
    });
  });
}
