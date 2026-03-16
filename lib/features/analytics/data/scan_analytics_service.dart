import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ScanAnalytics {
  const ScanAnalytics({
    required this.successfulScans,
    required this.invalidScans,
    required this.duplicateEntryAttempts,
    required this.duplicateExitAttempts,
    required this.exportSuccess,
    required this.exportFailure,
  });

  final int successfulScans;
  final int invalidScans;
  final int duplicateEntryAttempts;
  final int duplicateExitAttempts;
  final int exportSuccess;
  final int exportFailure;

  Map<String, dynamic> toJson() {
    return {
      'successfulScans': successfulScans,
      'invalidScans': invalidScans,
      'duplicateEntryAttempts': duplicateEntryAttempts,
      'duplicateExitAttempts': duplicateExitAttempts,
      'exportSuccess': exportSuccess,
      'exportFailure': exportFailure,
    };
  }

  static ScanAnalytics fromJson(Map<String, dynamic> json) {
    return ScanAnalytics(
      successfulScans: json['successfulScans'] as int? ?? 0,
      invalidScans: json['invalidScans'] as int? ?? 0,
      duplicateEntryAttempts: json['duplicateEntryAttempts'] as int? ?? 0,
      duplicateExitAttempts: json['duplicateExitAttempts'] as int? ?? 0,
      exportSuccess: json['exportSuccess'] as int? ?? 0,
      exportFailure: json['exportFailure'] as int? ?? 0,
    );
  }
}

class ScanAnalyticsService {
  static const _storageKey = 'scan_analytics';

  Future<ScanAnalytics> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const ScanAnalytics(
        successfulScans: 0,
        invalidScans: 0,
        duplicateEntryAttempts: 0,
        duplicateExitAttempts: 0,
        exportSuccess: 0,
        exportFailure: 0,
      );
    }
    return ScanAnalytics.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(ScanAnalytics analytics) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(analytics.toJson()));
  }

  Future<void> incrementSuccessfulScan() async {
    final current = await load();
    await save(ScanAnalytics(
      successfulScans: current.successfulScans + 1,
      invalidScans: current.invalidScans,
      duplicateEntryAttempts: current.duplicateEntryAttempts,
      duplicateExitAttempts: current.duplicateExitAttempts,
      exportSuccess: current.exportSuccess,
      exportFailure: current.exportFailure,
    ));
  }

  Future<void> incrementInvalidScan() async {
    final current = await load();
    await save(ScanAnalytics(
      successfulScans: current.successfulScans,
      invalidScans: current.invalidScans + 1,
      duplicateEntryAttempts: current.duplicateEntryAttempts,
      duplicateExitAttempts: current.duplicateExitAttempts,
      exportSuccess: current.exportSuccess,
      exportFailure: current.exportFailure,
    ));
  }

  Future<void> incrementDuplicateEntryAttempt() async {
    final current = await load();
    await save(ScanAnalytics(
      successfulScans: current.successfulScans,
      invalidScans: current.invalidScans,
      duplicateEntryAttempts: current.duplicateEntryAttempts + 1,
      duplicateExitAttempts: current.duplicateExitAttempts,
      exportSuccess: current.exportSuccess,
      exportFailure: current.exportFailure,
    ));
  }

  Future<void> incrementDuplicateExitAttempt() async {
    final current = await load();
    await save(ScanAnalytics(
      successfulScans: current.successfulScans,
      invalidScans: current.invalidScans,
      duplicateEntryAttempts: current.duplicateEntryAttempts,
      duplicateExitAttempts: current.duplicateExitAttempts + 1,
      exportSuccess: current.exportSuccess,
      exportFailure: current.exportFailure,
    ));
  }

  Future<void> incrementExportSuccess() async {
    final current = await load();
    await save(ScanAnalytics(
      successfulScans: current.successfulScans,
      invalidScans: current.invalidScans,
      duplicateEntryAttempts: current.duplicateEntryAttempts,
      duplicateExitAttempts: current.duplicateExitAttempts,
      exportSuccess: current.exportSuccess + 1,
      exportFailure: current.exportFailure,
    ));
  }

  Future<void> incrementExportFailure() async {
    final current = await load();
    await save(ScanAnalytics(
      successfulScans: current.successfulScans,
      invalidScans: current.invalidScans,
      duplicateEntryAttempts: current.duplicateEntryAttempts,
      duplicateExitAttempts: current.duplicateExitAttempts,
      exportSuccess: current.exportSuccess,
      exportFailure: current.exportFailure + 1,
    ));
  }
}
