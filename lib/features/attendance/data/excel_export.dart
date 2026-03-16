import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/entities/attendee.dart';

Future<String> exportAttendeesToExcel(List<Attendee> attendees, String eventName) async {
  final excel = Excel.createExcel();
  final sheet = excel['Attendees'];

  sheet.appendRow(['ID', 'Name', 'Department', 'In Time', 'Out Time']);

  for (final attendee in attendees) {
    sheet.appendRow([
      attendee.id,
      attendee.name,
      attendee.department,
      attendee.inTime.toString(),
      attendee.outTime?.toString() ?? 'Not Scanned',
    ]);
  }

  final encoded = excel.encode();
  if (encoded == null) {
    throw Exception('Failed to generate Excel bytes');
  }

  final Directory appDirectory = await getApplicationDocumentsDirectory();
  Directory targetDirectory = appDirectory;
  if (Platform.isAndroid) {
    final downloads = Directory('/storage/emulated/0/Download');
    if (downloads.existsSync()) {
      targetDirectory = downloads;
    }
  }

  final safeEventName = eventName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  final path = '${targetDirectory.path}/$safeEventName.xlsx';
  final file = File(path);
  await file.create(recursive: true);
  await file.writeAsBytes(encoded, flush: true);

  return path;
}
