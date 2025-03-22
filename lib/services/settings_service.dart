import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SettingsService {
  static Future<Map<String, String>> loadDepartments() async {
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
    };
  }

  static Future<void> saveDepartments(Map<String, String> departments) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('departments', jsonEncode(departments));
  }
}
