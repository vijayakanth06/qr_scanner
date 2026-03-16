import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../../analytics/data/scan_analytics_service.dart';
import '../../../events/domain/entities/event.dart';
import '../../../students/data/hive_student_repository.dart';
import '../../../students/domain/entities/student.dart';
import '../../data/excel_export.dart';
import '../../data/hive_attendee_store.dart';
import '../../domain/entities/attendee.dart';
import '../../domain/services/attendance_flow_service.dart';
import '../../domain/services/scan_policy_service.dart';
import '../../domain/utils/roll_number_parser.dart';
import '../../../settings/data/settings_service.dart';
import 'barcode_scanner_screen.dart';

class EventScreen extends StatefulWidget {
  const EventScreen({super.key, required this.event});

  final Event event;

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  Box<Attendee>? attendeeBox;
  Box<Student>? studentBox;
  AttendanceFlowService? attendanceFlowService;
  HiveStudentRepository? studentRepository;
  final settingsRepository = SettingsService();
  final analyticsService = ScanAnalyticsService();

  Map<String, String> departments = {};
  List<Attendee> attendees = [];
  bool isLoading = true;
  bool isProcessingScan = false;
  DateTime? lastScanAt;

  final Map<String, DateTime> _lastExitByRoll = {};

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    attendeeBox = await Hive.openBox<Attendee>('attendees');
    studentBox = await Hive.openBox<Student>('students');
    attendanceFlowService = AttendanceFlowService(
      store: HiveAttendeeStore(attendeeBox!),
    );
    studentRepository = HiveStudentRepository(studentBox!);
    departments = await settingsRepository.loadDepartments();
    _refreshAttendees();
    if (!mounted) return;
    setState(() {
      isLoading = false;
    });
  }

  void _refreshAttendees() {
    final box = attendeeBox;
    if (box == null) return;

    final eventAttendees = box.values
        .where((a) => a.eventName == widget.event.name)
        .toList()
      ..sort((a, b) => b.inTime.compareTo(a.inTime));

    setState(() {
      attendees = eventAttendees;
    });
  }

  Future<void> _openScanner() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BarcodeScannerScreen(onScanned: _handleScannedCode),
      ),
    );
  }

  Future<void> _handleScannedCode(String qrData) async {
    if (isProcessingScan || attendanceFlowService == null) return;

    final now = DateTime.now();
    final cooldownSeconds = widget.event.cooldownSeconds;
    if (isCooldownActive(lastScanAt: lastScanAt, now: now, cooldownSeconds: cooldownSeconds)) {
      _showMessage('Cooldown active: wait $cooldownSeconds seconds before next scan.');
      return;
    }

    isProcessingScan = true;
    lastScanAt = now;

    final normalized = qrData.trim().toUpperCase();
    final student = studentRepository?.getByRollNumber(normalized);
    final action = await _showActionDialog(normalized, student);
    if (!mounted || action == null) {
      isProcessingScan = false;
      return;
    }

    if (!isActionAllowed(widget.event.scanMode, action)) {
      _showMessage('Selected action is not allowed for this event scan mode.');
      isProcessingScan = false;
      return;
    }

    if (action == AttendanceAction.exit && widget.event.restrictDuplicateExit) {
      final previousExit = _lastExitByRoll[normalized];
      final hasOpenEntry = attendees.any((a) => a.id == normalized && a.outTime == null);
      if (previousExit != null && !hasOpenEntry) {
        await analyticsService.incrementDuplicateExitAttempt();
        _showMessage('Duplicate Exit blocked for $normalized. Record Entry before next Exit.');
        isProcessingScan = false;
        return;
      }
    }

    final result = await attendanceFlowService!.recordAttendance(
      eventName: widget.event.name,
      scannedValue: normalized,
      action: action,
      departments: departments,
      studentName: student?.name,
      timestamp: now,
    );

    if (result.success) {
      await analyticsService.incrementSuccessfulScan();
      if (result.code == AttendanceResultCode.successExit) {
        _lastExitByRoll[normalized] = now;
      }

      final info = parseRollNumber(normalized, departments);
      final actionLabel = action == AttendanceAction.entry ? 'Entry' : 'Exit';
      final yearText = info.currentYear == null ? 'Year ?' : 'Year ${info.currentYear}';
      final nameText = student?.name.isNotEmpty == true ? ' | ${student!.name}' : '';
      _showMessage(
        '$actionLabel recorded for ${info.normalizedRollNumber}$nameText ($yearText) at ${formatDateTimeHuman(now)}',
      );
    } else {
      if (result.code == AttendanceResultCode.invalidBarcode) {
        await analyticsService.incrementInvalidScan();
      }
      if (result.code == AttendanceResultCode.duplicateEntry) {
        await analyticsService.incrementDuplicateEntryAttempt();
      }
      if (result.code == AttendanceResultCode.noActiveEntry) {
        await analyticsService.incrementDuplicateExitAttempt();
      }
      _showMessage('${result.message} Use format like 23ALR109.');
    }

    _refreshAttendees();
    isProcessingScan = false;
  }

  Future<AttendanceAction?> _showActionDialog(String rollNumber, Student? student) {
    final allowEntry = widget.event.scanMode != ScanMode.exitOnly;
    final allowExit = widget.event.scanMode != ScanMode.entryOnly;

    return showDialog<AttendanceAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attendance Action'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Scanned: $rollNumber'),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student == null ? 'Student profile not found (offline DB).' : 'Student profile',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text('Name: ${student?.name.isNotEmpty == true ? student!.name : 'Unknown'}'),
                    Text('Branch: ${student?.branch.isNotEmpty == true ? student!.branch : extractDepartment(rollNumber, departments)}'),
                    Text('Section: ${student?.section.isNotEmpty == true ? student!.section : 'Unknown'}'),
                    Text('Phone: ${student?.mobileNumber.isNotEmpty == true ? student!.mobileNumber : 'Unknown'}'),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('Cancel'),
                onPressed: () => Navigator.pop(context),
              ),
              ActionChip(
                label: const Text('Entry'),
                onPressed: allowEntry ? () => Navigator.pop(context, AttendanceAction.entry) : null,
              ),
              ActionChip(
                label: const Text('Exit'),
                onPressed: allowExit ? () => Navigator.pop(context, AttendanceAction.exit) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _exportToExcel() async {
    if (attendees.isEmpty) {
      _showMessage('No attendees to export');
      return;
    }

    try {
      final exportPath = await exportAttendeesToExcel(attendees, widget.event.name);
      await analyticsService.incrementExportSuccess();
      _showMessage('Attendance exported successfully: $exportPath');
    } catch (_) {
      await analyticsService.incrementExportFailure();
      _showMessage('Export failed. Please check storage permission and try again.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event.name),
        actions: [
          IconButton(
            onPressed: _exportToExcel,
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export Excel',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : attendees.isEmpty
              ? const Center(child: Text('No attendance yet. Tap camera to scan.'))
              : ListView.separated(
                  itemCount: attendees.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final attendee = attendees[index];
                    final year = calculateStudentYearFromBatch(attendee.batch);
                    final rollSuffix = extractRollSuffix(attendee.id);

                    return ListTile(
                      leading: const Icon(Icons.badge_outlined),
                      title: Text(attendee.id),
                      subtitle: Text(
                        '${attendee.name.isNotEmpty ? attendee.name : 'Unknown'} | ${attendee.department} | Batch ${attendee.batch} | ${year == null ? 'Year ?' : 'Year $year'} | Roll $rollSuffix\n'
                        'In: ${formatDateTimeHuman(attendee.inTime)}\n'
                        'Out: ${attendee.outTime == null ? 'Pending' : formatDateTimeHuman(attendee.outTime!)}',
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openScanner,
        icon: const Icon(Icons.camera_alt_outlined),
        label: const Text('Scan'),
      ),
    );
  }
}
