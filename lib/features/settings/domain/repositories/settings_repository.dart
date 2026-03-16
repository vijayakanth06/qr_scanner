abstract class SettingsRepository {
  Future<Map<String, String>> loadDepartments();
  Future<void> saveDepartments(Map<String, String> departments);
}
