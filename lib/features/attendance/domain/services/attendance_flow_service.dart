import '../entities/attendee.dart';
import '../utils/roll_number_parser.dart';

enum AttendanceAction { entry, exit }

enum AttendanceResultCode {
  successEntry,
  successExit,
  invalidBarcode,
  duplicateEntry,
  noActiveEntry,
}

class AttendanceResult {
  const AttendanceResult({
    required this.success,
    required this.message,
    required this.code,
    this.attendee,
  });

  final bool success;
  final String message;
  final AttendanceResultCode code;
  final Attendee? attendee;
}

abstract class AttendeeStore {
  Iterable<Attendee> all();
  Future<void> add(Attendee attendee);
  Future<void> save(Attendee attendee);
}

class AttendanceFlowService {
  const AttendanceFlowService({required this.store});

  final AttendeeStore store;

  Future<AttendanceResult> recordAttendance({
    required String eventName,
    required String scannedValue,
    required AttendanceAction action,
    required Map<String, String> departments,
    String? studentName,
    DateTime? timestamp,
  }) async {
    final now = timestamp ?? DateTime.now();
    final normalized = scannedValue.trim().toUpperCase();

    if (!isValidRollNumber(normalized)) {
      return const AttendanceResult(
        success: false,
        message: 'Invalid barcode format. Expected: 23ALR109',
        code: AttendanceResultCode.invalidBarcode,
      );
    }

    final rollInfo = parseRollNumber(normalized, departments);

    if (action == AttendanceAction.entry) {
      final alreadyInside = store.all().any(
            (a) =>
                a.eventName == eventName &&
                a.id == rollInfo.normalizedRollNumber &&
                a.outTime == null,
          );

      if (alreadyInside) {
        return AttendanceResult(
          success: false,
          message:
              'Entry already active for ${rollInfo.normalizedRollNumber}. Please record exit first.',
          code: AttendanceResultCode.duplicateEntry,
        );
      }

      final attendee = Attendee(
        id: rollInfo.normalizedRollNumber,
        name: (studentName != null && studentName.trim().isNotEmpty)
            ? studentName.trim()
            : 'Unknown',
        batch: rollInfo.batchYear,
        department: rollInfo.department,
        inTime: now,
        outTime: null,
        eventName: eventName,
      );

      await store.add(attendee);
      return AttendanceResult(
        success: true,
        message: 'Entry recorded for ${rollInfo.normalizedRollNumber}',
        code: AttendanceResultCode.successEntry,
        attendee: attendee,
      );
    }

    final activeRecord = store
        .all()
        .where(
          (a) =>
              a.eventName == eventName &&
              a.id == rollInfo.normalizedRollNumber &&
              a.outTime == null,
        )
        .toList()
      ..sort((a, b) => b.inTime.compareTo(a.inTime));

    if (activeRecord.isEmpty) {
      return AttendanceResult(
        success: false,
        message: 'No active entry found for ${rollInfo.normalizedRollNumber}.',
        code: AttendanceResultCode.noActiveEntry,
      );
    }

    final attendee = activeRecord.first;
    attendee.outTime = now;
    await store.save(attendee);

    return AttendanceResult(
      success: true,
      message: 'Exit recorded for ${rollInfo.normalizedRollNumber}',
      code: AttendanceResultCode.successExit,
      attendee: attendee,
    );
  }
}
