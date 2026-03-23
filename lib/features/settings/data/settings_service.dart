import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/repositories/settings_repository.dart';

class SettingsService implements SettingsRepository {
  @override
  Future<Map<String, String>> loadDepartments() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('departments');
    if (data != null) {
      return Map<String, String>.from(jsonDecode(data));
    }
    return {
      'CV': 'Civil Engineering',
      'ME': 'Mechanical Engineering',
      'EC': 'Electronics and Communication Engineering',
      'CS': 'Computer Science and Engineering',
      'EE': 'Electrical and Electronics Engineering',
      'EI': 'Electronics and Instrumentation Engineering',
      'MT': 'Mechatronics Engineering',
      'AT': 'Automobile Engineering',
      'CH': 'Chemical Engineering',
      'IT': 'Information Technology',
      'FT': 'Food Technology',
      'AD': 'Artificial Intelligence and Data Science',
      'AL': 'Artificial Intelligence and Machine Learning',
      'ALR': 'Artificial Intelligence and Machine Learning',
      'ALL': 'Artificial Intelligence and Machine Learning',
      'AID': 'Artificial Intelligence and Data Science',
      'DS': 'Data Science',
      'ML': 'Machine Learning',
    };
  }

  @override
  Future<void> saveDepartments(Map<String, String> departments) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('departments', jsonEncode(departments));
  }

  Future<String> loadFileLocation() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('exportFileLocation') ?? '/storage/emulated/0/Download';
  }

  Future<void> saveFileLocation(String location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('exportFileLocation', location);
  }
}
