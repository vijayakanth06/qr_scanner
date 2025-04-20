class DepartmentHelper {
  static Map<String, String> departmentCodes = {
    "CSE": "Computer Science",
    "ECE": "Electronics and Communication",
    "EEE": "Electrical and Electronics",
    "MECH": "Mechanical Engineering",
    "CIVIL": "Civil Engineering"
  };

  static String getDepartmentName(String code) {
    return departmentCodes[code] ?? "Unknown Department";
  }
}
