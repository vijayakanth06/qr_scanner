import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../domain/entities/student.dart';

class FirebaseStudentRepository {
  FirebaseStudentRepository({FirebaseDatabase? database}) : _database = database;

  final FirebaseDatabase? _database;

  FirebaseDatabase? _resolveDatabase() {
    if (_database != null) return _database;
    try {
      return FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL:
            'https://qr-scanner-app-ca1fb-default-rtdb.asia-southeast1.firebasedatabase.app',
      );
    } catch (_) {
      return null;
    }
  }

  Future<Student?> getByRollNumber(String rollNumber) async {
    final normalized = rollNumber.trim().toUpperCase();
    if (normalized.isEmpty) return null;

    final database = _resolveDatabase();
    if (database == null) return null;

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
      );
    } catch (_) {
      return null;
    }
  }
}
