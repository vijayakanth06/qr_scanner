import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../domain/entities/student.dart';

class StudentImportService {
  List<Student> parseCsv(String rawCsv) {
    final lines = const LineSplitter()
        .convert(rawCsv)
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (lines.length < 2) return [];

    final headers = _normalizeHeaders(_splitCsvLine(lines.first));
    final students = <Student>[];

    for (var i = 1; i < lines.length; i++) {
      final columns = _splitCsvLine(lines[i]);
      final row = _rowMap(headers, columns);
      final student = _studentFromMap(row);
      if (student != null) {
        students.add(student);
      }
    }

    return students;
  }

  List<Student> parseExcel(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return [];

    final firstSheet = excel.tables.values.first;
    if (firstSheet.rows.length < 2) return [];

    final headers = _normalizeHeaders(
      firstSheet.rows.first.map((e) => e?.value?.toString() ?? '').toList(),
    );

    final students = <Student>[];
    for (var i = 1; i < firstSheet.rows.length; i++) {
      final rowValues = firstSheet.rows[i].map((e) => e?.value?.toString() ?? '').toList();
      final row = _rowMap(headers, rowValues);
      final student = _studentFromMap(row);
      if (student != null) {
        students.add(student);
      }
    }

    return students;
  }

  List<String> _splitCsvLine(String line) {
    final values = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
        continue;
      }
      if (char == ',' && !inQuotes) {
        values.add(buffer.toString().trim());
        buffer.clear();
        continue;
      }
      buffer.write(char);
    }
    values.add(buffer.toString().trim());
    return values;
  }

  List<String> _normalizeHeaders(List<String> headers) {
    return headers
        .map((h) => h.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_'))
        .toList();
  }

  Map<String, String> _rowMap(List<String> headers, List<String> rowValues) {
    final row = <String, String>{};
    for (var i = 0; i < headers.length; i++) {
      row[headers[i]] = i < rowValues.length ? rowValues[i].trim() : '';
    }
    return row;
  }

  Student? _studentFromMap(Map<String, String> row) {
    final rollNumber = _pick(row, [
      'rollno',
      'roll_number',
      'roll',
      'register_no',
      'register_number',
    ]);
    if (rollNumber.isEmpty) return null;

    return Student(
      rollNumber: rollNumber.toUpperCase(),
      name: _pick(row, ['name', 'student_name']),
      mobileNumber: _pick(row, ['mobileno', 'mobile_number', 'phone', 'mobile']),
      branch: _pick(row, ['branch', 'department', 'dept']),
      section: _pick(row, ['section', 'sec']),
      residence: _pick(row, ['hosteller_or_dayscholar', 'residence', 'hosteller_dayscholar']),
    );
  }

  String _pick(Map<String, String> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }
}
