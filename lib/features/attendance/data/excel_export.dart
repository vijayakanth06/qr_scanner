import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../features/events/domain/entities/event.dart';
import '../domain/entities/attendee.dart';

const MethodChannel _exportChannel = MethodChannel('qr_scanner/export');

Future<String> exportAttendeesToExcel({
  required List<Attendee> attendees,
  required Event event,
  required String fileLocation,
  required List<String> selectedColumns,
}) async {
  final excel = Excel.createExcel();
  final sheet = excel['Attendees'];

  // Column headers based on selection
  final headers = selectedColumns;
  sheet.appendRow(headers);

  // Add attendee data
  for (final attendee in attendees) {
    final row = <dynamic>[];
    for (final colName in selectedColumns) {
      switch (colName) {
        case 'ID':
          row.add(attendee.id);
          break;
        case 'Name':
          row.add(attendee.name);
          break;
        case 'Department':
          row.add(attendee.department);
          break;
        case 'In Time':
          row.add(attendee.inTime.toString());
          break;
        case 'Out Time':
          row.add(attendee.outTime?.toString() ?? 'Not Scanned');
          break;
        case 'Roll Number':
          row.add(attendee.id); // Using ID as roll number
          break;
        case 'Section':
          row.add(attendee.batch);
          break;
        case 'Status':
          row.add(attendee.outTime != null ? 'Present' : 'Entered');
          break;
      }
    }
    sheet.appendRow(row);
  }

  final encoded = excel.encode();
  if (encoded == null) {
    throw Exception('Failed to generate Excel bytes');
  }

  // Format filename: eventname-venue-date-session.xlsx
  final fileName = _generateFileName(event);

  if (Platform.isAndroid && fileLocation.startsWith('content://')) {
    final uri = await _writeToAndroidTreeUri(
      treeUri: fileLocation,
      fileName: fileName,
      bytes: Uint8List.fromList(encoded),
    );
    return uri;
  }

  if (Platform.isAndroid && fileLocation.startsWith('/storage/')) {
    throw Exception(
      'Selected folder is a legacy Android path and cannot be written directly. '
      'Please reselect export folder in Settings.',
    );
  }
  
  // Request permission and get target directory
  Directory targetDirectory = await _getTargetDirectory(fileLocation);
  
  // Ensure directory exists
  if (!targetDirectory.existsSync()) {
    await targetDirectory.create(recursive: true);
  }

  final path = '${targetDirectory.path}/$fileName';
  final file = File(path);
  
  try {
    await file.writeAsBytes(encoded, flush: true);
  } catch (e) {
    final isCustomLocation = fileLocation.trim().isNotEmpty &&
        !fileLocation.contains('Download') &&
        !fileLocation.startsWith('/storage/emulated/0/Download');

    if (isCustomLocation) {
      rethrow;
    }

    // Fallback to documents directory only for default location failures
    final documentsDir = await getApplicationDocumentsDirectory();
    final fallbackPath = '${documentsDir.path}/$fileName';
    final fallbackFile = File(fallbackPath);
    await fallbackFile.writeAsBytes(encoded, flush: true);
    return fallbackPath;
  }

  return path;
}

Future<String> _writeToAndroidTreeUri({
  required String treeUri,
  required String fileName,
  required Uint8List bytes,
}) async {
  String? result;
  try {
    result = await _exportChannel.invokeMethod<String>(
      'writeBytesToTreeUri',
      {
        'treeUri': treeUri,
        'fileName': fileName,
        'bytes': bytes,
      },
    );
  } on PlatformException catch (error) {
    final reason = '${error.code}${error.message == null ? '' : ': ${error.message}'}';
    throw Exception('Android SAF export failed ($reason).');
  }

  if (result == null || result.isEmpty) {
    throw Exception('Failed to write file to selected folder');
  }

  return result;
}

Future<Directory> _getTargetDirectory(String fileLocation) async {
  // If location is default Downloads, try to access it properly
  if (fileLocation.contains('Download') || fileLocation.isEmpty) {
    if (Platform.isAndroid) {
      // Request storage permission first
      await Permission.storage.request();
      
      // Try standard Downloads directory
      final downloads = Directory('/storage/emulated/0/Download');
      if (downloads.existsSync()) {
        return downloads;
      }
      
      // Fallback to Documents
      return await getApplicationDocumentsDirectory();
    }
  }
  
  // For custom paths, verify they exist and are accessible
  final customDir = Directory(fileLocation);
  if (customDir.existsSync()) {
    return customDir;
  }
  
  // Final fallback to Documents directory
  return await getApplicationDocumentsDirectory();
}

String _generateFileName(Event event) {
  final eventName = event.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  final venue = event.venue.isEmpty ? 'unknown' : event.venue.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  
  // Format date as DDMMMYY (e.g., 23Mar26)
  final date = event.date;
  final day = date.day.toString().padLeft(2, '0');
  final month = _getMonthAbbr(date.month);
  final year = date.year.toString().substring(2);
  final dateStr = '$day$month$year';
  
  // Determine session based on time (morning: 6-12, afternoon: 12-18, evening: 18+)
  final hour = DateTime.now().hour;
  final session = hour < 12 ? 'Morning' : (hour < 18 ? 'Afternoon' : 'Evening');
  
  return '$eventName-$venue-$dateStr-$session.xlsx';
}

String _getMonthAbbr(int month) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return months[month - 1];
}
