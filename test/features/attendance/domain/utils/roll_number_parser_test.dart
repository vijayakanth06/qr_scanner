import 'package:flutter_test/flutter_test.dart';
import 'package:qr_scanner/features/attendance/domain/utils/roll_number_parser.dart';

void main() {
  group('roll number parser', () {
    test('validates barcode format', () {
      expect(isValidRollNumber('23ALR109'), isTrue);
      expect(isValidRollNumber('23ALL001'), isTrue);
      expect(isValidRollNumber('23AL1099'), isFalse);
      expect(isValidRollNumber('INVALID'), isFalse);
    });

    test('extracts batch, department and suffix', () {
      final departments = {
        'ALR': 'Artificial Intelligence and Machine Learning',
      };

      final info = parseRollNumber('23alr109', departments);

      expect(info.normalizedRollNumber, '23ALR109');
      expect(info.batchYear, '2023');
      expect(info.department, 'Artificial Intelligence and Machine Learning');
      expect(info.rollSuffix, '109');
    });

    test('calculates student year from batch', () {
      final year = calculateStudentYearFromBatch(
        '2023',
        now: DateTime(2026, 3, 14),
      );
      expect(year, 4);

      final outOfRange = calculateStudentYearFromBatch(
        '2019',
        now: DateTime(2026, 3, 14),
      );
      expect(outOfRange, isNull);
    });
  });
}
