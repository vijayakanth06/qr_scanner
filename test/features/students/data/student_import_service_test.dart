import 'package:flutter_test/flutter_test.dart';
import 'package:qr_scanner/features/students/data/student_import_service.dart';

void main() {
  group('student import service', () {
    test('parses csv student rows', () {
      final service = StudentImportService();
      const csv = 'rollno,name,mobileno,branch,section,hosteller_or_dayscholar\n'
          '23ALR109,John,9999999999,AIML,A,Hosteller\n';

      final students = service.parseCsv(csv);

      expect(students.length, 1);
      expect(students.first.rollNumber, '23ALR109');
      expect(students.first.name, 'John');
      expect(students.first.branch, 'AIML');
    });
  });
}
