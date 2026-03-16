import '../entities/student.dart';

abstract class StudentRepository {
  Future<void> upsertAll(List<Student> students);
  Student? getByRollNumber(String rollNumber);
  int count();
}
