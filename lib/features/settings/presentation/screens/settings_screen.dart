import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';

import '../../../analytics/data/scan_analytics_service.dart';
import '../../../students/data/hive_student_repository.dart';
import '../../../students/data/student_import_service.dart';
import '../../../students/domain/entities/student.dart';
import '../../data/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final settingsRepository = SettingsService();
  final studentImportService = StudentImportService();
  final analyticsService = ScanAnalyticsService();

  Map<String, String> departments = {};
  int studentCount = 0;
  ScanAnalytics analytics = const ScanAnalytics(
    successfulScans: 0,
    invalidScans: 0,
    duplicateEntryAttempts: 0,
    duplicateExitAttempts: 0,
    exportSuccess: 0,
    exportFailure: 0,
  );

  @override
  void initState() {
    super.initState();
    loadDepartments();
    _loadStudentCount();
    _loadAnalytics();
  }

  Future<void> loadDepartments() async {
    departments = await settingsRepository.loadDepartments();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadStudentCount() async {
    final box = await Hive.openBox<Student>('students');
    final repo = HiveStudentRepository(box);
    if (!mounted) return;
    setState(() {
      studentCount = repo.count();
    });
  }

  Future<void> _loadAnalytics() async {
    final data = await analyticsService.load();
    if (!mounted) return;
    setState(() {
      analytics = data;
    });
  }

  void addDepartment(String code, String name) {
    setState(() => departments[code.toUpperCase()] = name.trim());
    settingsRepository.saveDepartments(departments);
  }

  void deleteDepartment(String code) {
    setState(() => departments.remove(code));
    settingsRepository.saveDepartments(departments);
  }

  Future<void> importStudents() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final ext = (file.extension ?? '').toLowerCase();

    final box = await Hive.openBox<Student>('students');
    final repo = HiveStudentRepository(box);

    try {
      var parsed = <Student>[];
      if (ext == 'csv') {
        final content = String.fromCharCodes(file.bytes ?? <int>[]);
        parsed = studentImportService.parseCsv(content);
      } else if (ext == 'xlsx') {
        if (file.bytes == null) {
          _showMessage('Invalid Excel file content.');
          return;
        }
        parsed = studentImportService.parseExcel(file.bytes!);
      }

      if (parsed.isEmpty) {
        _showMessage('No valid students found. Ensure roll number column exists.');
        return;
      }

      await repo.upsertAll(parsed);
      await _loadStudentCount();
      _showMessage('Imported ${parsed.length} students successfully.');
    } catch (_) {
      _showMessage('Student import failed. Please verify file headers and format.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Department Settings')),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Students in offline DB: $studentCount'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: importStudents,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Import Students CSV/Excel'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Scan Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Successful scans: ${analytics.successfulScans}'),
                  Text('Invalid scans: ${analytics.invalidScans}'),
                  Text('Duplicate entry attempts: ${analytics.duplicateEntryAttempts}'),
                  Text('Duplicate exit attempts: ${analytics.duplicateExitAttempts}'),
                  Text('Export success: ${analytics.exportSuccess}'),
                  Text('Export failure: ${analytics.exportFailure}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: departments.length,
              itemBuilder: (context, index) {
                final code = departments.keys.elementAt(index);
                return ListTile(
                  title: Text('$code - ${departments[code]}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => deleteDepartment(code),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDepartmentDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDepartmentDialog(BuildContext context) {
    final codeController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Department'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: codeController, decoration: const InputDecoration(labelText: 'Code')),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (codeController.text.isNotEmpty && nameController.text.isNotEmpty) {
                addDepartment(codeController.text, nameController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
