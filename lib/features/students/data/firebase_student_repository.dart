import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../../core/logging/app_logger.dart';

import '../domain/entities/student.dart';

const _defaultDatabaseUrl =
    'https://qr-scanner-app-ca1fb-default-rtdb.asia-southeast1.firebasedatabase.app';
const _databaseUrl = String.fromEnvironment(
  'FIREBASE_DATABASE_URL',
  defaultValue: _defaultDatabaseUrl,
);

class FirebaseStudentRepository {
  FirebaseStudentRepository({FirebaseDatabase? database}) : _database = database;

  final FirebaseDatabase? _database;
  static const int _maxAttempts = 3;
  static const List<int> _retryDelaysMs = [150, 400, 900];

  FirebaseDatabase? _resolveDatabase() {
    if (_database != null) return _database;
    try {
      return FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: _databaseUrl,
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to resolve FirebaseDatabase instance.',
        tag: 'FirebaseStudentRepository',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<Student?> getByRollNumber(String rollNumber) async {
    final normalized = rollNumber.trim().toUpperCase();
    if (normalized.isEmpty) return null;

    final database = _resolveDatabase();
    if (database == null) return null;

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final snapshot = await database.ref('studentsByRoll/$normalized').get();
        if (!snapshot.exists || snapshot.value is! Map) return null;

        final data = Map<String, dynamic>.from(snapshot.value as Map);
        return Student(
          rollNumber: (data['rollNo'] ?? normalized).toString().trim().toUpperCase(),
          name: (data['name'] ?? '').toString().trim(),
          mobileNumber: (data['studentMobileNo'] ?? '').toString().trim(),
          branch: (data['branch'] ?? '').toString().trim(),
          section: (data['section'] ?? '').toString().trim(),
          residence: (data['hostellerDayScholar'] ?? '').toString().trim(),
          yearOfStudy: (data['yearOfStudy'] as String?)?.trim(),
        );
      } catch (error, stackTrace) {
        final isLastAttempt = attempt == _maxAttempts;
        AppLogger.warning(
          'RTDB lookup attempt $attempt failed for $normalized: $error',
          tag: 'FirebaseStudentRepository',
        );

        if (isLastAttempt) {
          AppLogger.error(
            'RTDB lookup exhausted retries for $normalized.',
            tag: 'FirebaseStudentRepository',
            error: error,
            stackTrace: stackTrace,
          );
          return null;
        }

        await Future<void>.delayed(Duration(milliseconds: _retryDelaysMs[attempt - 1]));
      }
    }

    return null;
  }
}
