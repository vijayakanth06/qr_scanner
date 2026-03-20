import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import '../../../analytics/data/scan_analytics_service.dart';
import '../../../events/domain/entities/event.dart';
import '../../../students/data/firebase_student_repository.dart';
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

class _ScanTimelineEntry {
  const _ScanTimelineEntry({
    required this.type,
    required this.message,
    required this.timestamp,
    this.rollNumber,
  });

  final ScanOutcomeType type;
  final String message;
  final DateTime timestamp;
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
  Box<Student>? studentBox;
  AttendanceFlowService? attendanceFlowService;
  HiveStudentRepository? studentRepository;
  FirebaseStudentRepository? firebaseStudentRepository;
  final settingsRepository = SettingsService();
  final analyticsService = ScanAnalyticsService();

  Map<String, String> departments = {};
  List<Attendee> attendees = [];
  bool isLoading = true;
  bool isProcessingScan = false;
  final Map<String, DateTime> _lastScanByRoll = {};
  final Map<String, Student> _studentMemoryCache = {};
  final List<_ScanTimelineEntry> _scanTimeline = [];

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
    firebaseStudentRepository = FirebaseStudentRepository();
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
      final result = ScanHandleResult(
        shouldCloseScanner: false,
        type: ScanOutcomeType.blocked,
        message: 'Cooldown active for $normalized. Wait ${remaining}s before rescanning this roll.',
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

        final info = parseRollNumber(normalized, departments);
        final actionLabel = action == AttendanceAction.entry ? 'ENTRY' : 'EXIT';
        final nameText = student?.name.isNotEmpty == true ? student!.name : 'Unknown';
        final uiMessage = '$actionLabel • ${info.normalizedRollNumber} • $nameText';

        final outcomeType = result.code == AttendanceResultCode.successExit
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

      if (result.code == AttendanceResultCode.invalidBarcode) {
        await analyticsService.incrementInvalidScan();
      }
      if (result.code == AttendanceResultCode.duplicateEntry) {
        await analyticsService.incrementDuplicateEntryAttempt();
      }
      if (result.code == AttendanceResultCode.noActiveEntry) {
        await analyticsService.incrementDuplicateExitAttempt();
      }

      final type = result.code == AttendanceResultCode.invalidBarcode
          ? ScanOutcomeType.invalid
          : ScanOutcomeType.blocked;
      final uiMessage = '${result.message} Use format like 23ALR109.';

      _recordTimeline(
        type: type,
        message: uiMessage,
        timestamp: now,
        rollNumber: normalized,
      );
      return ScanHandleResult(
        shouldCloseScanner: false,
        type: type,
        message: uiMessage,
        scannedCode: normalized,
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

    final localHit = studentRepository?.getByRollNumber(normalized);
    if (localHit != null) {
      _studentMemoryCache[normalized] = localHit;
      return localHit;
    }

    final remoteHit = await firebaseStudentRepository?.getByRollNumber(normalized);
    if (remoteHit != null) {
      _studentMemoryCache[normalized] = remoteHit;
      await studentRepository?.upsertAll([remoteHit]);
      return remoteHit;
    }

    return null;
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Scanned: $rollNumber',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    suggestedAction == AttendanceAction.entry ? Icons.login : Icons.logout,
                    color: suggestedAction == AttendanceAction.entry
                        ? Colors.green.shade700
                        : Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      suggestedAction == AttendanceAction.entry
                          ? 'Suggested: Entry (no active entry record)'
                          : 'Suggested: Exit (active entry found)',
                    ),
                  ),
                ],
              ),
            ),
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
                        backgroundColor: Colors.green.shade600,
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
                    child: FilledButton.icon(
                      icon: const Icon(Icons.logout),
                      label: const Text('Exit'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
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

    try {
      final exportPath = await exportAttendeesToExcel(attendees, widget.event.name);
      await analyticsService.incrementExportSuccess();
      _recordTimeline(
        type: ScanOutcomeType.info,
        message: 'Attendance exported successfully: $exportPath',
        timestamp: DateTime.now(),
      );
    } catch (_) {
      await analyticsService.incrementExportFailure();
      _recordTimeline(
        type: ScanOutcomeType.blocked,
        message: 'Export failed. Please check storage permission and try again.',
        timestamp: DateTime.now(),
      );
    }
  }

  void _recordTimeline({
    required ScanOutcomeType type,
    required String message,
    required DateTime timestamp,
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
          rollNumber: rollNumber,
        ),
      );
      if (_scanTimeline.length > 8) {
        _scanTimeline.removeRange(8, _scanTimeline.length);
      }
    });
  }

  (Color background, Color foreground, IconData icon, String label) _timelineStyle(
    BuildContext context,
    ScanOutcomeType type,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final successScheme = ColorScheme.fromSeed(seedColor: Colors.green);
    if (type == ScanOutcomeType.successEntry) {
      return (successScheme.primaryContainer, successScheme.onPrimaryContainer, Icons.login, 'ENTRY');
    }
    if (type == ScanOutcomeType.successExit) {
      return (scheme.errorContainer, scheme.onErrorContainer, Icons.logout, 'EXIT');
    }
    if (type == ScanOutcomeType.invalid) {
      return (scheme.errorContainer, scheme.onErrorContainer, Icons.error_outline, 'INVALID');
    }
    if (type == ScanOutcomeType.blocked) {
      return (scheme.secondaryContainer, scheme.onSecondaryContainer, Icons.block, 'BLOCKED');
    }
    return (scheme.surfaceContainerHighest, scheme.onSurfaceVariant, Icons.info_outline, 'INFO');
  }

  Widget _buildTimeline() {
    if (_scanTimeline.isEmpty) return const SizedBox.shrink();

    final items = _scanTimeline.take(3).toList();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent scan results',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < items.length; i++) ...[
            Builder(
              builder: (context) {
                final item = items[i];
                final style = _timelineStyle(context, item.type);
                return Row(
                  children: [
                    Icon(style.$3, color: style.$2, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${item.timestamp.hour.toString().padLeft(2, '0')}:${item.timestamp.minute.toString().padLeft(2, '0')}:${item.timestamp.second.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
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
          : Column(
              children: [
                _buildTimeline(),
                Expanded(
                  child: attendees.isEmpty
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
