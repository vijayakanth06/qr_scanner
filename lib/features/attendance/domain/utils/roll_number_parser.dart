import 'package:intl/intl.dart';

class RollNumberInfo {
  const RollNumberInfo({
    required this.normalizedRollNumber,
    required this.batchYear,
    required this.department,
    required this.rollSuffix,
    this.currentYear,
  });

  final String normalizedRollNumber;
  final String batchYear;
  final String department;
  final String rollSuffix;
  final int? currentYear;
}

bool isValidRollNumber(String value) {
  return RegExp(r'^\d{2}[A-Z]{2,4}\d{3}$').hasMatch(value.trim().toUpperCase());
}

String extractBatch(String rollNumber) {
  final normalized = rollNumber.trim().toUpperCase();
  final match = RegExp(r'^(\d{2})[A-Z]{2,4}\d{3}$').firstMatch(normalized);
  if (match != null) {
    return '20${match.group(1)!}';
  }
  return 'Unknown';
}

String extractDepartment(String rollNumber, Map<String, String> departments) {
  final normalized = rollNumber.trim().toUpperCase();
  final match = RegExp(r'^\d{2}([A-Z]{2,4})\d{3}$').firstMatch(normalized);
  if (match != null) {
    final deptCode = match.group(1)!;
    return departments[deptCode] ?? 'Unknown Department';
  }
  return 'Unknown Department';
}

String extractRollSuffix(String rollNumber) {
  final normalized = rollNumber.trim().toUpperCase();
  final match = RegExp(r'^\d{2}[A-Z]{2,4}(\d{3})$').firstMatch(normalized);
  if (match != null) {
    return match.group(1)!;
  }
  return 'Unknown';
}

int? calculateStudentYearFromBatch(String batchYear, {DateTime? now}) {
  final year = int.tryParse(batchYear);
  if (year == null) return null;

  final referenceTime = now ?? DateTime.now();
  final diff = referenceTime.year - year;
  if (diff < 0) return null;

  final currentYear = diff + 1;
  if (currentYear < 1 || currentYear > 4) {
    return null;
  }
  return currentYear;
}

String formatDateTimeHuman(DateTime dateTime) {
  return DateFormat('dd MMM yyyy, hh:mm:ss a').format(dateTime);
}

RollNumberInfo parseRollNumber(String input, Map<String, String> departments) {
  final normalized = input.trim().toUpperCase();
  final batchYear = extractBatch(normalized);
  final department = extractDepartment(normalized, departments);
  final rollSuffix = extractRollSuffix(normalized);
  final currentYear = calculateStudentYearFromBatch(batchYear);

  return RollNumberInfo(
    normalizedRollNumber: normalized,
    batchYear: batchYear,
    department: department,
    rollSuffix: rollSuffix,
    currentYear: currentYear,
  );
}
