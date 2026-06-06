import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:qr_scanner/app/di.dart';
import 'package:qr_scanner/app/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_scanner/core/errors/result.dart';
import 'package:qr_scanner/core/errors/scan_error.dart';
import 'package:qr_scanner/core/notifications/notification_service.dart';

import '../../application/export_attendees_usecase.dart';
import '../../../events/domain/entities/event.dart';
import '../../../students/domain/entities/student.dart';
import '../../../students/domain/repositories/student_repository.dart';
import '../../domain/entities/attendee.dart';
import '../../domain/services/attendance_flow_service.dart';
import '../../domain/services/scan_policy_service.dart';
import '../../domain/utils/roll_number_parser.dart';
import '../../../settings/data/settings_service.dart';
import 'barcode_scanner_screen.dart';

class _ScanTimelineEntry {
  const _ScanTimelineEntry({
    required this.type,
    required this.message,
    required this.timestamp,
    this.scanError,
    this.rollNumber,
  });

  final ScanOutcomeType type;
  final String message;
  final DateTime timestamp;
  final ScanError? scanError;
  final String? rollNumber;
}

class EventScreen extends StatefulWidget {
  const EventScreen({super.key, required this.event});

  final Event event;

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  Box<Attendee>? attendeeBox;
  AttendanceFlowService? attendanceFlowService;
  final Connectivity _connectivity = Connectivity();
  final settingsRepository = SettingsService();
  late final ExportAttendeesUseCase _exportAttendeesUseCase = ExportAttendeesUseCase();
  String _attendeesBoxName = 'attendees_default';

  Map<String, String> departments = {};
  List<Attendee> attendees = [];
  bool isLoading = true;
  bool isProcessingScan = false;
  String fileLocation = '';
  final List<String> allAvailableColumns = ['ID', 'Name', 'Department', 'In Time', 'Out Time', 'Roll Number', 'Status'];
  List<String> selectedColumns = ['ID', 'Name', 'Department', 'In Time', 'Out Time'];

  final Map<String, DateTime> _lastScanByRoll = {};
  final Map<String, Student> _studentMemoryCache = {};
  final List<_ScanTimelineEntry> _scanTimeline = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final prefs = sl<SharedPreferences>();
    final selectedCollegeId = prefs.getString('selectedCollegeId')?.trim() ?? '';
    final scopedCollegeId = selectedCollegeId.isEmpty ? 'default' : selectedCollegeId;
    _attendeesBoxName = 'attendees_$scopedCollegeId';

    if (Hive.isBoxOpen(_attendeesBoxName)) {
      attendeeBox = Hive.box<Attendee>(_attendeesBoxName);
    } else {
      attendeeBox = await Hive.openBox<Attendee>(_attendeesBoxName);
    }
    attendanceFlowService = sl<AttendanceFlowService>();
    departments = await settingsRepository.loadDepartments();
    fileLocation = await settingsRepository.loadFileLocation();
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

  Future<ScanHandleResult> _handleScannedCode(String qrData) async {
    if (attendanceFlowService == null) {
      return const ScanHandleResult(
        shouldCloseScanner: false,
        type: ScanOutcomeType.blocked,
        message: 'Attendance service is still loading. Please wait a moment.',
      );
    }

    if (isProcessingScan) {
      return const ScanHandleResult(
        shouldCloseScanner: false,
        type: ScanOutcomeType.info,
        message: 'Previous scan is still processing.',
      );
    }

    final now = DateTime.now();
    final normalized = qrData.trim().toUpperCase();
    if (normalized.isEmpty) {
      final result = const ScanHandleResult(
        shouldCloseScanner: false,
        type: ScanOutcomeType.invalid,
        message: 'Empty QR content. Please scan a valid roll number barcode.',
      );
      _recordTimeline(
        type: result.type,
        message: result.message,
        timestamp: now,
      );
      return result;
    }

    final cooldownSeconds = widget.event.cooldownSeconds;
    final lastScanForRoll = _lastScanByRoll[normalized];
    if (isCooldownActive(lastScanAt: lastScanForRoll, now: now, cooldownSeconds: cooldownSeconds)) {
      final elapsed = now.difference(lastScanForRoll!).inSeconds;
      final remaining = (cooldownSeconds - elapsed).clamp(1, cooldownSeconds);
      final cooldownError = CooldownActive(rollNo: normalized, remainingSeconds: remaining);
      final result = ScanHandleResult(
        shouldCloseScanner: false,
        type: ScanOutcomeType.blocked,
        message: 'Wait ${remaining}s',
        scannedCode: normalized,
      );
      _recordScanErrorTimeline(error: cooldownError, timestamp: now, rollNumber: normalized);
      return result;
    }

    isProcessingScan = true;
    _lastScanByRoll[normalized] = now;

    try {
      final student = await _resolveStudentProfile(normalized);
      final action = await _resolveAction(normalized, student);
      if (!mounted) {
        return const ScanHandleResult(
          shouldCloseScanner: true,
          type: ScanOutcomeType.info,
          message: 'Scan flow closed.',
        );
      }

      if (action == null) {
        final result = ScanHandleResult(
          shouldCloseScanner: false,
          type: ScanOutcomeType.info,
          message: 'Action cancelled for $normalized.',
          scannedCode: normalized,
        );
        _recordTimeline(
          type: result.type,
          message: result.message,
          timestamp: now,
          rollNumber: normalized,
        );
        return result;
      }

      if (!isActionAllowed(widget.event.scanMode, action)) {
        final result = const ScanHandleResult(
          shouldCloseScanner: false,
          type: ScanOutcomeType.blocked,
          message: 'Selected action is not allowed for this event scan mode.',
        );
        _recordTimeline(
          type: result.type,
          message: result.message,
          timestamp: now,
          rollNumber: null,
        );
        return result;
      }

      final connectivity = await _connectivity.checkConnectivity();
      final isOnline = connectivity.any((r) => r != ConnectivityResult.none);

      final result = await attendanceFlowService!.recordAttendance(
        eventName: widget.event.name,
        scannedValue: normalized,
        action: action,
        departments: departments,
        studentName: student?.name,
        studentYearOfStudy: student?.yearOfStudy,
        timestamp: now,
        isOnline: isOnline,
      );

      if (result is Ok<Attendee, ScanError>) {
        final info = parseRollNumber(normalized, departments);
        final actionLabel = action == AttendanceAction.entry ? 'ENTRY' : 'EXIT';
        final nameText = student?.name.isNotEmpty == true ? student!.name : 'Unknown';
        final uiMessage = '$actionLabel • ${info.normalizedRollNumber} • $nameText';

        final outcomeType = action == AttendanceAction.exit
            ? ScanOutcomeType.successExit
            : ScanOutcomeType.successEntry;

        _recordTimeline(
          type: outcomeType,
          message: uiMessage,
          timestamp: now,
          rollNumber: normalized,
        );
        _refreshAttendees();

        return ScanHandleResult(
          shouldCloseScanner: false,
          type: outcomeType,
          message: uiMessage,
          scannedCode: normalized,
        );
      }
      if (result is Err<Attendee, ScanError>) {
        final error = result.error;
        final notificationService = sl<NotificationService>();

        if (error is ScannerHardwareError) {
          notificationService.showError(
            'Scanner error — tap to retry',
            onRetry: _openScanner,
          );
          return const ScanHandleResult(
            shouldCloseScanner: false,
            type: ScanOutcomeType.blocked,
            message: 'Scanner error. Please retry.',
          );
        }

        _recordScanErrorTimeline(error: error, timestamp: now, rollNumber: normalized);

        final message = switch (error) {
          MalformedInput() => 'Invalid code',
          UnknownRoll() => 'Unknown student',
          CooldownActive(:final remainingSeconds) => 'Wait ${remainingSeconds}s',
          DuplicateExit() => 'Already exited',
          OfflineLookupMiss() => 'Not in cache',
          ScannerHardwareError() => 'Scanner error',
        };

        final type = error is MalformedInput ? ScanOutcomeType.invalid : ScanOutcomeType.blocked;
        return ScanHandleResult(
          shouldCloseScanner: false,
          type: type,
          message: message,
          scannedCode: normalized,
        );
      }

      return const ScanHandleResult(
        shouldCloseScanner: false,
        type: ScanOutcomeType.blocked,
        message: 'Scan failed. Please try again.',
      );
    } finally {
      isProcessingScan = false;
    }
  }

  Future<Student?> _resolveStudentProfile(String rollNumber) async {
    final normalized = rollNumber.trim().toUpperCase();
    if (normalized.isEmpty) return null;

    final memoryHit = _studentMemoryCache[normalized];
    if (memoryHit != null) {
      return memoryHit;
    }

    final repo = sl<StudentRepository>();
    final student = repo.getByRollNumber(normalized);
    if (student != null) {
      _studentMemoryCache[normalized] = student;
    }
    return student;
  }

  Future<AttendanceAction?> _resolveAction(String rollNumber, Student? student) async {
    if (widget.event.scanMode == ScanMode.entryOnly) return AttendanceAction.entry;
    if (widget.event.scanMode == ScanMode.exitOnly) return AttendanceAction.exit;
    return _showActionDialog(rollNumber, student);
  }

  Future<AttendanceAction?> _showActionDialog(String rollNumber, Student? student) {
    final allowEntry = widget.event.scanMode != ScanMode.exitOnly;
    final allowExit = widget.event.scanMode != ScanMode.entryOnly;
    final hasActiveEntry = attendees.any((a) => a.id == rollNumber && a.outTime == null);
    final suggestedAction = hasActiveEntry ? AttendanceAction.exit : AttendanceAction.entry;

    return showModalBottomSheet<AttendanceAction>(
      context: context,
      backgroundColor: kBackgroundColor,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance Action',
              style: const TextStyle(
                color: kTextPrimaryColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Scanned: $rollNumber',
              style: const TextStyle(
                color: kTextSecondaryColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: kPrimaryLightColor,
                borderRadius: BorderRadius.circular(12),
                border: const Border.fromBorderSide(BorderSide(color: kBorderColor)),
              ),
              child: Row(
                children: [
                  Icon(
                    suggestedAction == AttendanceAction.entry ? Icons.login : Icons.logout,
                    color: kPrimaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      suggestedAction == AttendanceAction.entry
                          ? 'Suggested: Entry (no active entry record)'
                          : 'Suggested: Exit (active entry found)',
                      style: const TextStyle(color: kTextPrimaryColor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Card(
              color: kBackgroundColor,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: student == null
                    ? Text(
                        'Student not found — roll: $rollNumber',
                        style: const TextStyle(
                          color: kErrorColor,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Student profile',
                            style: TextStyle(
                              color: kTextPrimaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('Name: ${student.name}', style: const TextStyle(color: kTextPrimaryColor)),
                          Text('Branch: ${student.branch.isNotEmpty ? student.branch : extractDepartment(rollNumber, departments)}', style: const TextStyle(color: kTextPrimaryColor)),
                          Text('Section: ${student.section}', style: const TextStyle(color: kTextPrimaryColor)),
                          Text('Phone: ${student.mobileNumber}', style: const TextStyle(color: kTextPrimaryColor)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.login),
                      label: const Text('Entry'),
                      style: FilledButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      onPressed: allowEntry
                          ? () {
                              HapticFeedback.mediumImpact();
                              Navigator.pop(context, AttendanceAction.entry);
                            }
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.logout),
                      label: const Text('Exit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kPrimaryColor,
                        side: const BorderSide(color: kPrimaryColor),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      onPressed: allowExit
                          ? () {
                              HapticFeedback.heavyImpact();
                              Navigator.pop(context, AttendanceAction.exit);
                            }
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.close),
                label: const Text('Cancel'),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportToExcel() async {
    if (attendees.isEmpty) {
      _recordTimeline(
        type: ScanOutcomeType.info,
        message: 'No attendees to export.',
        timestamp: DateTime.now(),
      );
      return;
    }

    // Show column selection dialog
    await _showColumnSelectionDialog();

    try {
      final exportPath = await _exportAttendeesUseCase(
        attendees: attendees,
        event: widget.event,
        fileLocation: fileLocation,
        selectedColumns: selectedColumns,
      );
      _recordTimeline(
        type: ScanOutcomeType.info,
        message: 'Attendance exported successfully: $exportPath',
        timestamp: DateTime.now(),
      );
    } catch (error, stackTrace) {
      debugPrint('Attendance export failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      final detail = error is PlatformException
          ? '${error.code}${error.message == null ? '' : ': ${error.message}'}'
          : error.toString();
      _recordTimeline(
        type: ScanOutcomeType.blocked,
        message: 'Export failed: $detail',
        timestamp: DateTime.now(),
      );
    }
  }

  Future<void> _showColumnSelectionDialog() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Columns to Export'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  children: allAvailableColumns.map((column) {
                    return CheckboxListTile(
                      title: Text(column),
                      value: selectedColumns.contains(column),
                      onChanged: (bool? checked) {
                        setState(() {
                          if (checked == true) {
                            if (!selectedColumns.contains(column)) {
                              selectedColumns.add(column);
                            }
                          } else {
                            selectedColumns.remove(column);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selectedColumns.isEmpty
                      ? null
                      : () => Navigator.pop(context),
                  child: const Text('Export'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _recordTimeline({
    required ScanOutcomeType type,
    required String message,
    required DateTime timestamp,
    ScanError? scanError,
    String? rollNumber,
  }) {
    if (!mounted) return;
    setState(() {
      _scanTimeline.insert(
        0,
        _ScanTimelineEntry(
          type: type,
          message: message,
          timestamp: timestamp,
          scanError: scanError,
          rollNumber: rollNumber,
        ),
      );
      if (_scanTimeline.length > 8) {
        _scanTimeline.removeRange(8, _scanTimeline.length);
      }
    });
  }

  void _recordScanErrorTimeline({
    required ScanError error,
    required DateTime timestamp,
    String? rollNumber,
  }) {
    if (error is ScannerHardwareError) {
      return;
    }

    final label = switch (error) {
      MalformedInput() => 'Invalid code',
      UnknownRoll() => 'Unknown student',
      CooldownActive(:final remainingSeconds) => 'Wait ${remainingSeconds}s',
      DuplicateExit() => 'Already exited',
      OfflineLookupMiss() => 'Not in cache',
      ScannerHardwareError() => 'Scanner error',
    };

    _recordTimeline(
      type: ScanOutcomeType.blocked,
      message: label,
      timestamp: timestamp,
      scanError: error,
      rollNumber: rollNumber,
    );
  }

  ({Color rowColor, Color borderColor, Color iconColor, IconData icon, String label}) _scanErrorUi(
    ScanError error,
  ) {
    final rowColor = switch (error) {
      MalformedInput() => const Color(0xFFFFF3E0),
      UnknownRoll() => const Color(0xFFFFF3E0),
      CooldownActive() => const Color(0xFFFFF3E0),
      DuplicateExit() => const Color(0xFFFFF3E0),
      OfflineLookupMiss() => const Color(0xFFF5F7FA),
      ScannerHardwareError() => throw UnimplementedError(),
    };

    final borderColor = switch (error) {
      MalformedInput() => kErrorColor,
      UnknownRoll() => kErrorColor,
      CooldownActive() => kErrorColor,
      DuplicateExit() => kErrorColor,
      OfflineLookupMiss() => kBorderColor,
      ScannerHardwareError() => throw UnimplementedError(),
    };

    final icon = switch (error) {
      MalformedInput() => Icons.cancel_outlined,
      UnknownRoll() => Icons.help_outline,
      CooldownActive() => Icons.timer_outlined,
      DuplicateExit() => Icons.warning_amber_outlined,
      OfflineLookupMiss() => Icons.cloud_off_outlined,
      ScannerHardwareError() => throw UnimplementedError(),
    };

    final iconColor = switch (error) {
      MalformedInput() => kErrorColor,
      UnknownRoll() => kErrorColor,
      CooldownActive() => kErrorColor,
      DuplicateExit() => kErrorColor,
      OfflineLookupMiss() => kPrimaryColor,
      ScannerHardwareError() => throw UnimplementedError(),
    };

    final label = switch (error) {
      MalformedInput() => 'Invalid code',
      UnknownRoll() => 'Unknown student',
      CooldownActive(:final remainingSeconds) => 'Wait ${remainingSeconds}s',
      DuplicateExit() => 'Already exited',
      OfflineLookupMiss() => 'Not in cache',
      ScannerHardwareError() => throw UnimplementedError(),
    };

    return (
      rowColor: rowColor,
      borderColor: borderColor,
      iconColor: iconColor,
      icon: icon,
      label: label,
    );
  }

  Widget _buildScanTimelineRow({
    required ScanError error,
    required DateTime timestamp,
  }) {
    final ui = _scanErrorUi(error);
    final timestampText =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: ui.rowColor,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: ui.borderColor, width: 4)),
      ),
      child: Row(
        children: [
          Icon(ui.icon, size: 20, color: ui.iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ui.label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimaryColor),
            ),
          ),
          Text(timestampText, style: const TextStyle(fontSize: 12, color: kTextSecondaryColor)),
        ],
      ),
    );
  }

  (Color background, Color foreground, IconData icon, String label) _timelineStyle(
    BuildContext context,
    ScanOutcomeType type,
  ) {
    if (type == ScanOutcomeType.successEntry) {
      return (const Color(0xFFF1F8E9), kSuccessColor, Icons.login, 'ENTRY');
    }
    if (type == ScanOutcomeType.successExit) {
      return (const Color(0xFFF1F8E9), kSuccessColor, Icons.logout, 'EXIT');
    }
    if (type == ScanOutcomeType.invalid) {
      return (const Color(0xFFFFF3E0), kErrorColor, Icons.error_outline, 'INVALID');
    }
    if (type == ScanOutcomeType.blocked) {
      return (const Color(0xFFFFF3E0), kErrorColor, Icons.block, 'BLOCKED');
    }
    return (kPrimaryLightColor, kPrimaryColor, Icons.info_outline, 'INFO');
  }

  Widget _buildTimeline() {
    if (_scanTimeline.isEmpty) return const SizedBox.shrink();

    final items = _scanTimeline.take(3).toList();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: const Border.fromBorderSide(BorderSide(color: kBorderColor)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent scan results',
            style: const TextStyle(
              color: kTextPrimaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < items.length; i++) ...[
            Builder(
              builder: (context) {
                final item = items[i];
                final scanError = item.scanError;
                if (scanError != null) {
                  return _buildScanTimelineRow(error: scanError, timestamp: item.timestamp);
                }
                final style = _timelineStyle(context, item.type);
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: style.$1,
                    borderRadius: BorderRadius.circular(8),
                    border: Border(left: BorderSide(color: style.$2, width: 4)),
                  ),
                  child: Row(
                    children: [
                      Icon(style.$3, color: style.$2, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: kTextPrimaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${item.timestamp.hour.toString().padLeft(2, '0')}:${item.timestamp.minute.toString().padLeft(2, '0')}:${item.timestamp.second.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: kTextSecondaryColor, fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (i < items.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text(widget.event.name),
        backgroundColor: kBackgroundColor,
        surfaceTintColor: Colors.transparent,
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
          : Column(
              children: [
                _buildTimeline(),
                Expanded(
                  child: attendees.isEmpty
                      ? const Center(
                          child: Text(
                            'No attendance yet. Tap camera to scan.',
                            style: TextStyle(color: kTextSecondaryColor),
                          ),
                        )
                      : ListView.separated(
                          itemCount: attendees.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final attendee = attendees[index];
                            final yearText = attendee.yearOfStudy?.isNotEmpty == true
                                ? 'Year ${attendee.yearOfStudy}'
                                : 'Year ?';

                            return ListTile(
                              leading: const Icon(Icons.badge_outlined),
                              title: Text(attendee.id),
                              subtitle: Text(
                                '${attendee.name.isNotEmpty ? attendee.name : 'Unknown'} | ${attendee.department} | Batch ${attendee.batch} | $yearText\n'
                                'In: ${formatDateTimeHuman(attendee.inTime)}\n'
                                'Out: ${attendee.outTime == null ? 'Pending' : formatDateTimeHuman(attendee.outTime!)}',
                              ),
                              isThreeLine: true,
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openScanner,
        icon: const Icon(Icons.camera_alt_outlined),
        label: const Text('Scan'),
      ),
    );
  }
}
