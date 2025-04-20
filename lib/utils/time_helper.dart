class TimeHelper {
  static String getCurrentTime() {
    DateTime now = DateTime.now();
    return "${now.hour}:${now.minute}:${now.second}";
  }
}
