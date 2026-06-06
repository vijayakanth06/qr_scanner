import 'package:flutter_test/flutter_test.dart';
import 'package:qr_scanner/core/config/college_config.dart';
import 'package:qr_scanner/core/errors/result.dart';
import 'package:qr_scanner/core/errors/scan_error.dart';
import 'package:qr_scanner/features/students/data/firebase_student_repository.dart';
import 'package:qr_scanner/features/students/domain/entities/student.dart';
import 'package:qr_scanner/features/students/domain/repositories/student_repository.dart';
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

class InMemoryStudentRepository implements StudentRepository {
  final Map<String, Student> _studentsByRoll = <String, Student>{};

  @override
  Student? getByRollNumber(String rollNumber) =>
      _studentsByRoll[rollNumber.trim().toUpperCase()];

  @override
  Future<void> upsertAll(List<Student> students) async {
    for (final student in students) {
      _studentsByRoll[student.rollNumber.trim().toUpperCase()] = student;
    }
  }

  @override
  int count() => _studentsByRoll.length;
}

class FakeRemoteStudentRepository extends FirebaseStudentRepository {
  FakeRemoteStudentRepository(this._studentsByRoll) : super(database: null);

  final Map<String, Student> _studentsByRoll;

  @override
  Future<Student?> getByRollNumber(String rollNumber) async {
    return _studentsByRoll[rollNumber.trim().toUpperCase()];
  }
}

CollegeConfig _testCollegeConfig() {
  return CollegeConfig.fromJson(
    {
      'collegeId': 'kec',
      'collegeName': 'Kongu Engineering College',
      'logoUrl': 'https://cdn.example.com/kec-logo.png',
      'firebaseDatabaseURL':
          'https://qr-scanner-app-ca1fb-default-rtdb.asia-southeast1.firebasedatabase.app',
      'idCardFormat': {'rollPattern': r'^[0-9]{2}[A-Z]{3}[0-9]{3}$'},
      'syncPolicy': {'maxIncrementalGap': 3, 'cooldownSeconds': 10},
    },
  );
}

Student _studentFor(String rollNumber) {
  return Student(
    rollNumber: rollNumber,
    name: 'Test Student',
    mobileNumber: '9999999999',
    branch: 'AIML',
    section: 'A',
    residence: 'Day Scholar',
    yearOfStudy: 'II',
  );
}

AttendanceFlowService _buildService(
  InMemoryAttendeeStore store,
  InMemoryStudentRepository localRepo,
  FakeRemoteStudentRepository remoteRepo,
) {
  return AttendanceFlowService(
    store: store,
    studentRepository: localRepo,
    remoteStudentRepository: remoteRepo,
    collegeConfig: _testCollegeConfig(),
  );
}

void main() {
  group('AttendanceFlowService', () {
    test('records entry for valid roll number', () async {
      final store = InMemoryAttendeeStore();
      final localRepo = InMemoryStudentRepository();
      await localRepo.upsertAll([_studentFor('23ALR109')]);
      final service = _buildService(
        store,
        localRepo,
        FakeRemoteStudentRepository(const {}),
      );

      final result = await service.recordAttendance(
        eventName: 'Tech Fest',
        scannedValue: '23ALR109',
        action: AttendanceAction.entry,
        departments: {'ALR': 'AIML'},
        timestamp: DateTime(2026, 3, 14, 9, 0, 0),
      );

      expect(result, isA<Ok<Attendee, ScanError>>());
      expect(store.all().length, 1);
      final first = store.all().first;
      expect(first.id, '23ALR109');
      expect(first.outTime, isNull);
    });

    test('prevents duplicate active entry', () async {
      final store = InMemoryAttendeeStore();
      final localRepo = InMemoryStudentRepository();
      await localRepo.upsertAll([_studentFor('23ALR109')]);
      final service = _buildService(
        store,
        localRepo,
        FakeRemoteStudentRepository(const {}),
      );

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

      expect(second, isA<Err<Attendee, ScanError>>());
      expect((second as Err<Attendee, ScanError>).error, isA<DuplicateExit>());
      expect(store.all().length, 1);
    });

    test('records exit for active entry', () async {
      final store = InMemoryAttendeeStore();
      final localRepo = InMemoryStudentRepository();
      await localRepo.upsertAll([_studentFor('23ALR109')]);
      final service = _buildService(
        store,
        localRepo,
        FakeRemoteStudentRepository(const {}),
      );

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

      expect(exit, isA<Ok<Attendee, ScanError>>());
      expect(store.all().first.outTime, DateTime(2026, 3, 14, 10, 0, 0));
    });

    test('allows re-entry after a completed exit', () async {
      final store = InMemoryAttendeeStore();
      final localRepo = InMemoryStudentRepository();
      await localRepo.upsertAll([_studentFor('23ALR109')]);
      final service = _buildService(
        store,
        localRepo,
        FakeRemoteStudentRepository(const {}),
      );

      await service.recordAttendance(
        eventName: 'Tech Fest',
        scannedValue: '23ALR109',
        action: AttendanceAction.entry,
        departments: {'ALR': 'AIML'},
        timestamp: DateTime(2026, 3, 14, 9, 0, 0),
      );
      await service.recordAttendance(
        eventName: 'Tech Fest',
        scannedValue: '23ALR109',
        action: AttendanceAction.exit,
        departments: {'ALR': 'AIML'},
        timestamp: DateTime(2026, 3, 14, 10, 0, 0),
      );

      final reEntry = await service.recordAttendance(
        eventName: 'Tech Fest',
        scannedValue: '23ALR109',
        action: AttendanceAction.entry,
        departments: {'ALR': 'AIML'},
        timestamp: DateTime(2026, 3, 14, 11, 0, 0),
      );

      expect(reEntry, isA<Ok<Attendee, ScanError>>());
      expect(store.all().length, 2);
      final latest = store.all().last;
      expect(latest.inTime, DateTime(2026, 3, 14, 11, 0, 0));
      expect(latest.outTime, isNull);
    });

    test('treats active records independently across events', () async {
      final store = InMemoryAttendeeStore();
      final localRepo = InMemoryStudentRepository();
      await localRepo.upsertAll([_studentFor('23ALR109')]);
      final service = _buildService(
        store,
        localRepo,
        FakeRemoteStudentRepository(const {}),
      );

      await service.recordAttendance(
        eventName: 'Tech Fest',
        scannedValue: '23ALR109',
        action: AttendanceAction.entry,
        departments: {'ALR': 'AIML'},
      );

      final otherEventEntry = await service.recordAttendance(
        eventName: 'Workshop',
        scannedValue: '23ALR109',
        action: AttendanceAction.entry,
        departments: {'ALR': 'AIML'},
      );

      expect(otherEventEntry, isA<Ok<Attendee, ScanError>>());
      expect(store.all().length, 2);
    });

    test('rejects exit when no active entry exists', () async {
      final store = InMemoryAttendeeStore();
      final localRepo = InMemoryStudentRepository();
      await localRepo.upsertAll([_studentFor('23ALR109')]);
      final service = _buildService(
        store,
        localRepo,
        FakeRemoteStudentRepository(const {}),
      );

      final result = await service.recordAttendance(
        eventName: 'Tech Fest',
        scannedValue: '23ALR109',
        action: AttendanceAction.exit,
        departments: {'ALR': 'AIML'},
      );

      expect(result, isA<Err<Attendee, ScanError>>());
      expect((result as Err<Attendee, ScanError>).error, isA<DuplicateExit>());
    });

    test('rejects invalid barcode value', () async {
      final store = InMemoryAttendeeStore();
      final localRepo = InMemoryStudentRepository();
      final service = _buildService(
        store,
        localRepo,
        FakeRemoteStudentRepository(const {}),
      );

      final result = await service.recordAttendance(
        eventName: 'Tech Fest',
        scannedValue: 'bad-code',
        action: AttendanceAction.entry,
        departments: {'ALR': 'AIML'},
      );

      expect(result, isA<Err<Attendee, ScanError>>());
      expect((result as Err<Attendee, ScanError>).error, isA<MalformedInput>());
    });
  });
}
