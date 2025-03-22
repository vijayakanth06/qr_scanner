import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, String> departments = {};

  @override
  void initState() {
    super.initState();
    loadDepartments();
  }

  Future<void> loadDepartments() async {
    departments = await SettingsService.loadDepartments();
    setState(() {});
  }

  void addDepartment(String code, String name) {
    setState(() => departments[code] = name);
    SettingsService.saveDepartments(departments);
  }

  void deleteDepartment(String code) {
    setState(() => departments.remove(code));
    SettingsService.saveDepartments(departments);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Department Settings')),
      body: ListView.builder(
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
          children: [
            TextField(controller: codeController, decoration: const InputDecoration(labelText: 'Code')),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
          ],
        ),
        actions: [
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
