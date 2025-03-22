import 'package:excel/excel.dart';
import 'dart:io';

class ExcelService {
  static Future<String> generateExcel(List<Map<String, String>> attendees, String eventName) async {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];

    // Define headers
    sheet.appendRow(['Roll Number', 'Batch', 'Department', 'Time']);

    // Add data
    for (var attendee in attendees) {
      sheet.appendRow([
        attendee['rollNumber']!,
        attendee['batch']!,
        attendee['department']!,
        attendee['time']!,
      ]);
    }

    // Ensure bytes are written
    List<int>? encodedBytes = excel.encode(); // Encode Excel data to bytes
    if (encodedBytes == null) {
      throw Exception("Failed to encode Excel file.");
    }

    // Get the correct storage location (Downloads folder)
    final directory = Directory('/storage/emulated/0/Download'); // Use Downloads folder on Android
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    final path = '${directory.path}/$eventName-Attendance.xlsx';
    final file = File(path);

    file.writeAsBytesSync(encodedBytes); // Ensure bytes are written correctly

    return path;
  }
}
