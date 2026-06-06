import 'dart:async';

import 'package:qr_scanner/core/config/college_config.dart';
import 'package:qr_scanner/core/errors/result.dart';
import 'package:qr_scanner/core/errors/scan_error.dart';

import '../../../students/data/firebase_student_repository.dart';
import '../../../students/domain/entities/student.dart';
import '../../../students/domain/repositories/student_repository.dart';
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
  const AttendanceFlowService({
    required this.store,
    required this.studentRepository,
    required this.remoteStudentRepository,
    required this.collegeConfig,
  });

  final AttendeeStore store;
  final StudentRepository studentRepository;
  final FirebaseStudentRepository remoteStudentRepository;
  final CollegeConfig collegeConfig;

  Future<Result<Attendee, ScanError>> recordAttendance({
    required String eventName,
    required String scannedValue,
    required AttendanceAction action,
    required Map<String, String> departments,
    String? studentName,
    String? studentYearOfStudy,
    DateTime? timestamp,
    bool isOnline = true,
  }) async {
    final now = timestamp ?? DateTime.now();
    final normalized = scannedValue.trim().toUpperCase();

    final rollPattern = RegExp(collegeConfig.idCardFormat.rollPattern);
    if (!rollPattern.hasMatch(normalized)) {
      return Err(MalformedInput(rawValue: scannedValue));
    }

    final rollInfo = parseRollNumber(normalized, departments);

    // Resolve student profile from offline cache first.
    Student? student = studentRepository.getByRollNumber(rollInfo.normalizedRollNumber);

    if (student == null && isOnline) {
      // Best-effort remote lookup when online and cache miss.
      student = await remoteStudentRepository.getByRollNumber(rollInfo.normalizedRollNumber);
      if (student != null) {
        await studentRepository.upsertAll([student]);
      }
    }

    if (student == null && !isOnline) {
      return Err(OfflineLookupMiss(rollNo: rollInfo.normalizedRollNumber));
    }

    if (student == null) {
      return Err(UnknownRoll(rollNo: rollInfo.normalizedRollNumber));
    }

    if (action == AttendanceAction.entry) {
      final alreadyInside = store.all().any(
            (a) =>
                a.eventName == eventName &&
                a.id == rollInfo.normalizedRollNumber &&
                a.outTime == null,
          );

      if (alreadyInside) {
        return Err(DuplicateExit(rollNo: rollInfo.normalizedRollNumber));
      }

      final attendee = Attendee(
        id: rollInfo.normalizedRollNumber,
        name: studentName != null && studentName.trim().isNotEmpty
            ? studentName.trim()
            : (student.name.isNotEmpty ? student.name : 'Unknown'),
        batch: rollInfo.batchYear,
        department: rollInfo.department,
        inTime: now,
        outTime: null,
        eventName: eventName,
        yearOfStudy: studentYearOfStudy ?? student.yearOfStudy,
      );

      await store.add(attendee);
      return Ok(attendee);
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
      return Err(DuplicateExit(rollNo: rollInfo.normalizedRollNumber));
    }

    final attendee = activeRecord.first;
    attendee.outTime = now;
    await store.save(attendee);

    return Ok(attendee);
  }
}
