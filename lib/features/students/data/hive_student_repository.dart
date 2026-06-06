import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../domain/entities/student.dart';
import '../domain/repositories/student_repository.dart';

class HiveStudentRepository implements StudentRepository {
  HiveStudentRepository(this.box);

  final Box<Student> box;
  bool _didLogLookupDiagnostics = false;

  String _normalizeRollKey(String rollNumber) => rollNumber.trim().toUpperCase();

  @override
  int count() => box.length;

  @override
  Student? getByRollNumber(String rollNumber) {
    final key = _normalizeRollKey(rollNumber);
    if (!_didLogLookupDiagnostics) {
      debugPrint('[StudentRepo] Looking up: "$key"');
      debugPrint('[StudentRepo] Box keys sample: ${box.keys.take(3).toList()}');
      _didLogLookupDiagnostics = true;
    }
    return box.get(key);
  }

  @override
  Future<void> upsertAll(List<Student> students) async {
    final payload = <String, Student>{};
    for (final student in students) {
      final key = _normalizeRollKey(student.rollNumber);
      payload[key] = student;
    }
    await box.putAll(payload);
  }
}
