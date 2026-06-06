import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/college_config.dart';
import '../../core/logging/app_logger.dart';
import '../../core/versioning/db_version_service.dart';
import 'presentation/blocked_screen.dart';
import '../students/domain/entities/student.dart';

sealed class SyncProgress {
  const SyncProgress();
}

class SyncChecking extends SyncProgress {
  const SyncChecking();
}

class SyncComparing extends SyncProgress {
  const SyncComparing();
}

class SyncDownloading extends SyncProgress {
  const SyncDownloading({required this.full});

  final bool full;
}

class SyncApplying extends SyncProgress {
  const SyncApplying();
}

class SyncDone extends SyncProgress {
  const SyncDone({required this.recordsUpdated, required this.version});

  final int recordsUpdated;
  final String version;
}

class SyncFailed extends SyncProgress {
  const SyncFailed({required this.message});

  final String message;
}

class SyncResult {
  const SyncResult.ok({required this.recordsUpdated, required this.version})
      : success = true,
        message = null;

  const SyncResult.error(this.message)
      : success = false,
        recordsUpdated = 0,
        version = null;

  final bool success;
  final int recordsUpdated;
  final String? version;
  final String? message;
}

class SyncService {
  SyncService({
    required DbVersionService dbVersionService,
    required SharedPreferences sharedPreferences,
    required CollegeConfig collegeConfig,
    required GlobalKey<NavigatorState> navigatorKey,
    Connectivity? connectivity,
  })  : _dbVersionService = dbVersionService,
        _prefs = sharedPreferences,
        _collegeConfig = collegeConfig,
        _navigatorKey = navigatorKey,
        _connectivity = connectivity ?? Connectivity();

  static const _localVersionKey = 'localVersion';
  static const _lastSyncTsKey = 'lastSyncTimestamp';
  static const _incrementalFailCountKey = 'incrementalFailCount';

  final DbVersionService _dbVersionService;
  final SharedPreferences _prefs;
  final CollegeConfig _collegeConfig;
  final GlobalKey<NavigatorState> _navigatorKey;
  final Connectivity _connectivity;

  final _progressController = StreamController<SyncProgress>.broadcast();

  Stream<SyncProgress> get progressStream => _progressController.stream;

  String? get _localVersion => _prefs.getString(_localVersionKey);

  String _normalizeRollKey(Object? rollNo) => rollNo.toString().trim().toUpperCase();

  Future<bool> hasUpdate() async {
    final serverVersion = await _dbVersionService.getCurrentVersion();
    if (serverVersion == null) return false;
    return serverVersion != _localVersion;
  }

  Future<SyncResult> triggerSync() async {
    _progressController.add(const SyncChecking());

    final connectivityResults = await _connectivity.checkConnectivity();
    final isOffline = connectivityResults.every((r) => r == ConnectivityResult.none);
    if (isOffline) {
      _progressController.add(const SyncFailed(message: 'offline'));
      AppLogger.info('Sync aborted – offline.', tag: 'SyncService');
      return const SyncResult.error('offline');
    }

    final serverVersion = await _dbVersionService.getCurrentVersion();
    final localVersion = _localVersion;

    if (serverVersion == null) {
      _progressController.add(const SyncFailed(message: 'No server version available'));
      return const SyncResult.error('no_server_version');
    }

    if (localVersion == serverVersion) {
      _progressController.add(SyncDone(recordsUpdated: 0, version: serverVersion));
      return SyncResult.ok(recordsUpdated: 0, version: serverVersion);
    }

    final mode = _decideMode(serverVersion: serverVersion, localVersion: localVersion);
    final failCount = _prefs.getInt(_incrementalFailCountKey) ?? 0;

    if (mode == _SyncMode.incremental && failCount >= 2) {
      AppLogger.warning(
        'Falling back to FULL sync after $failCount incremental failures.',
        tag: 'SyncService',
      );
      return _runFullSync(serverVersion: serverVersion);
    }

    if (mode == _SyncMode.full) {
      return _runFullSync(serverVersion: serverVersion);
    }

    return _runIncrementalSync(serverVersion: serverVersion);
  }

  _SyncMode _decideMode({required String serverVersion, required String? localVersion}) {
    if (localVersion == null || localVersion.isEmpty) {
      return _SyncMode.full;
    }

    final distance = _patchDistance(serverVersion, localVersion);
    if (distance <= _collegeConfig.syncPolicy.maxIncrementalGap) {
      return _SyncMode.incremental;
    }
    return _SyncMode.full;
  }

  int _patchDistance(String server, String local) {
    (int major, int patch) _parse(String v) {
      final parts = v.split('.');
      if (parts.length != 2) return (0, 0);
      final major = int.tryParse(parts[0]) ?? 0;
      final patch = int.tryParse(parts[1]) ?? 0;
      return (major, patch);
    }

    final s = _parse(server);
    final l = _parse(local);
    if (s.$1 != l.$1) return 9999; // force full sync on major bump.
    return (s.$2 - l.$2).abs();
  }

  Future<SyncResult> _runFullSync({required String serverVersion}) async {
    _progressController.add(const SyncDownloading(full: true));

    try {
      final snapshot = await _dbVersionService.loadLiveStudents();
      final box = Hive.box<Student>('students');

      final students = <String, Student>{};

      if (snapshot.exists && snapshot.value != null) {
        final raw = snapshot.value as Map<Object?, Object?>;
        raw.forEach((key, value) {
          if (value is! Map) return;
          final data = Map<String, dynamic>.from(value);
          final roll = _normalizeRollKey(data['rollNo'] ?? key);
          if (roll.isEmpty) return;

          students[roll] = Student(
            rollNumber: roll,
            name: (data['name'] ?? '').toString().trim(),
            mobileNumber: (data['studentMobileNo'] ?? '').toString().trim(),
            branch: (data['branch'] ?? '').toString().trim(),
            section: (data['section'] ?? '').toString().trim(),
            residence: (data['hostellerDayScholar'] ?? '').toString().trim(),
            yearOfStudy: (data['yearOfStudy'] as String?)?.trim(),
          );
        });
      }

      _progressController.add(const SyncApplying());

      await box.clear();
      if (students.isNotEmpty) {
        await box.putAll(students.map((key, value) => MapEntry(key, value)));
      }

      await _prefs.setString(_localVersionKey, serverVersion);
      await _prefs.setInt(_lastSyncTsKey, DateTime.now().millisecondsSinceEpoch);
      await _prefs.setInt(_incrementalFailCountKey, 0);

      if (students.isEmpty) {
        _showBlockedScreen();
      }

      _progressController.add(SyncDone(recordsUpdated: students.length, version: serverVersion));
      return SyncResult.ok(recordsUpdated: students.length, version: serverVersion);
    } catch (error, stackTrace) {
      debugPrint('[Sync] Error: $error');
      debugPrint('[Sync] Stack: $stackTrace');
      AppLogger.error(
        'Full sync failed.',
        tag: 'SyncService',
        error: error,
        stackTrace: stackTrace,
      );
      _progressController.add(SyncFailed(message: error.toString()));
      return SyncResult.error(error.toString());
    }
  }

  Future<SyncResult> _runIncrementalSync({required String serverVersion}) async {
    _progressController.add(const SyncComparing());

    final lastTs = _prefs.getInt(_lastSyncTsKey) ?? 0;
    try {
      final snapshot = await _dbVersionService.loadAuditSince(lastTs);
      if (!snapshot.exists || snapshot.value == null) {
        await _prefs.setString(_localVersionKey, serverVersion);
        await _prefs.setInt(_incrementalFailCountKey, 0);
        _progressController.add(SyncDone(recordsUpdated: 0, version: serverVersion));
        return SyncResult.ok(recordsUpdated: 0, version: serverVersion);
      }

      final box = Hive.box<Student>('students');
      final raw = snapshot.value as Map<Object?, Object?>;
      var updated = 0;

      for (final entry in raw.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final data = Map<String, dynamic>.from(value);
        final action = (data['action'] ?? '').toString();
        final roll = _normalizeRollKey(data['rollNo'] ?? entry.key);
        if (roll.isEmpty) continue;

        if (action == 'delete') {
          await box.delete(roll);
          updated++;
          continue;
        }

        final after = data['after'];
        if (after is! Map) continue;
        final studentData = Map<String, dynamic>.from(after);
        final student = Student(
          rollNumber: roll,
          name: (studentData['name'] ?? '').toString().trim(),
          mobileNumber: (studentData['studentMobileNo'] ?? '').toString().trim(),
          branch: (studentData['branch'] ?? '').toString().trim(),
          section: (studentData['section'] ?? '').toString().trim(),
          residence: (studentData['hostellerDayScholar'] ?? '').toString().trim(),
          yearOfStudy: (studentData['yearOfStudy'] as String?)?.trim(),
        );
        await box.put(roll, student);
        updated++;
      }

      await _prefs.setString(_localVersionKey, serverVersion);
      await _prefs.setInt(_lastSyncTsKey, DateTime.now().millisecondsSinceEpoch);
      await _prefs.setInt(_incrementalFailCountKey, 0);
      _progressController.add(SyncDone(recordsUpdated: updated, version: serverVersion));
      return SyncResult.ok(recordsUpdated: updated, version: serverVersion);
    } catch (error, stackTrace) {
      debugPrint('[Sync] Error: $error');
      debugPrint('[Sync] Stack: $stackTrace');
      final currentFail = _prefs.getInt(_incrementalFailCountKey) ?? 0;
      await _prefs.setInt(_incrementalFailCountKey, currentFail + 1);

      AppLogger.error(
        'Incremental sync failed.',
        tag: 'SyncService',
        error: error,
        stackTrace: stackTrace,
      );
      _progressController.add(SyncFailed(message: error.toString()));
      return SyncResult.error(error.toString());
    }
  }

  void _showBlockedScreen() {
    final nav = _navigatorKey.currentState;
    if (nav == null) return;
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => BlockedScreen(collegeName: _collegeConfig.collegeName),
      ),
    );
  }
}

enum _SyncMode { full, incremental }
