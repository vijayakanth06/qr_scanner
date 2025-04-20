import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import '../models/attendee.dart';

Future<void> exportAttendeesToExcel(List<Attendee> attendees, String eventName) async {
  var excel = Excel.createExcel();
  var sheet = excel['Attendees'];

  // Add headers
  sheet.appendRow(['ID', 'Name', 'Department', 'In Time', 'Out Time']);

  // Add data
  for (var attendee in attendees) {
    sheet.appendRow([
      attendee.id,
      attendee.name,
      attendee.department,
      attendee.inTime.toString(),
      attendee.outTime?.toString() ?? "Not Scanned",
    ]);
  }

  // Save file
  Directory? directory = await getExternalStorageDirectory();
  String path = '${directory?.path}/$eventName.xlsx';
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(excel.encode()!);

  
}
class ExcelExport {
  static Future<String> generateExcel(List<Map<String, String>> data, String eventName) async {
    var excel = Excel.createExcel();
    var sheet = excel['Sheet1'];

    sheet.appendRow(['Roll Number', 'Batch', 'Department', 'In Time', 'Out Time']);
    for (var row in data) {
      sheet.appendRow([
        row['rollNumber'] ?? '',
        row['batch'] ?? '',
        row['department'] ?? '',
        row['inTime'] ?? '',
        row['outTime'] ?? ''
      ]);
    }

    String filePath = '/storage/emulated/0/Download/${eventName}_attendance.xlsx';
    File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(excel.encode()!);

    return filePath;
  }
}
