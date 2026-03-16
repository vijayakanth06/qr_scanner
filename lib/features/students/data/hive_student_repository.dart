import 'package:hive/hive.dart';

import '../domain/entities/student.dart';
import '../domain/repositories/student_repository.dart';

class HiveStudentRepository implements StudentRepository {
  HiveStudentRepository(this.box);

  final Box<Student> box;

  @override
  int count() => box.length;

  @override
  Student? getByRollNumber(String rollNumber) {
    return box.get(rollNumber.trim().toUpperCase());
  }

  @override
  Future<void> upsertAll(List<Student> students) async {
    final payload = <String, Student>{};
    for (final student in students) {
      payload[student.rollNumber.trim().toUpperCase()] = student;
    }
    await box.putAll(payload);
  }
}
