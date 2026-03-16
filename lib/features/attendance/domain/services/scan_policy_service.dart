import '../../../events/domain/entities/event.dart';
import 'attendance_flow_service.dart';

bool isActionAllowed(ScanMode mode, AttendanceAction action) {
  if (mode == ScanMode.both) return true;
  if (mode == ScanMode.entryOnly) return action == AttendanceAction.entry;
  if (mode == ScanMode.exitOnly) return action == AttendanceAction.exit;
  return true;
}

bool isCooldownActive({
  required DateTime? lastScanAt,
  required DateTime now,
  required int cooldownSeconds,
}) {
  if (lastScanAt == null || cooldownSeconds <= 0) return false;
  return now.difference(lastScanAt).inSeconds < cooldownSeconds;
}
