import 'package:qr_scanner/features/attendance/data/excel_export.dart';
import 'package:qr_scanner/features/attendance/domain/entities/attendee.dart';
import 'package:qr_scanner/features/events/domain/entities/event.dart';

class ExportAttendeesUseCase {
  Future<String> call({
    required List<Attendee> attendees,
    required Event event,
    required String fileLocation,
    required List<String> selectedColumns,
  }) async {
    final path = await exportAttendeesToExcel(
      attendees: attendees,
      event: event,
      fileLocation: fileLocation,
      selectedColumns: selectedColumns,
    );
    return path;
  }
}
