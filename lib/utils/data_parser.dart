import 'package:intl/intl.dart';

String extractBatch(String rollNumber) {
  if (rollNumber.length >= 2) {
    return '20${rollNumber.substring(0, 2)}';
  }
  return 'Unknown';
}

String extractDepartment(String rollNumber, Map<String, String> departments) {
  if (rollNumber.length >= 4) {
    String deptCode = rollNumber.substring(2, 4);
    return departments[deptCode] ?? 'Unknown Department';
  }
  return 'Unknown';
}

String getCurrentTime() {
  return DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
}

