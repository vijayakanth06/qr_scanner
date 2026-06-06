import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../../data/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final settingsRepository = SettingsService();
  static const MethodChannel _exportChannel = MethodChannel('qr_scanner/export');

  Map<String, String> departments = {};
  String exportFileLocation = '/storage/emulated/0/Download';

  String _locationLabel(String value) {
    if (value.startsWith('content://')) {
      final decoded = Uri.decodeComponent(value);
      final marker = 'primary:';
      final markerIndex = decoded.lastIndexOf(marker);
      if (markerIndex >= 0) {
        final folder = decoded.substring(markerIndex + marker.length);
        if (folder.trim().isNotEmpty) return folder;
      }
      return 'Selected folder';
    }

    final normalized = value.trim();
    if (normalized.isEmpty) return 'Downloads';
    return normalized.split('/').last.isNotEmpty ? normalized.split('/').last : 'Downloads';
  }

  @override
  void initState() {
    super.initState();
    loadDepartments();
    _loadFileLocation();
  }

  Future<void> loadDepartments() async {
    departments = await settingsRepository.loadDepartments();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadFileLocation() async {
    final location = await settingsRepository.loadFileLocation();
    if (!mounted) return;
    setState(() {
      exportFileLocation = location;
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

  Future<void> _changeFileLocation() async {
    String? result;

    if (Platform.isAndroid) {
      try {
        result = await _exportChannel.invokeMethod<String>('pickExportFolder');
      } on PlatformException catch (error) {
        _showMessage('Folder selection failed: ${error.message ?? error.code}');
        return;
      }
    } else {
      result = await FilePicker.platform.getDirectoryPath();
    }

    if (result == null || result.trim().isEmpty) return;

    setState(() => exportFileLocation = result!);
    await settingsRepository.saveFileLocation(result);
    _showMessage('Export location updated.');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    final lower = message.toLowerCase();
    final isError = lower.contains('failed') || lower.contains('error') || lower.contains('denied');
    final isSuccess = lower.contains('success') ||
        lower.contains('synced') ||
        lower.contains('saved') ||
        lower.contains('updated') ||
        lower.contains('completed');

    final backgroundColor = isError
        ? const Color(0xFFD32F2F)
        : isSuccess
            ? const Color(0xFF2E7D32)
            : const Color(0xFF1565C0);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Column(
        children: [
          // Export File Location Section
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Export Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Save location: ${_locationLabel(exportFileLocation)}',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _changeFileLocation,
                    icon: const Icon(Icons.folder),
                    label: const Text('Change Save Location'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Departments Section
          const Padding(
            padding: EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Departments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
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
