import 'package:firebase_database/firebase_database.dart';

import '../config/college_config.dart';
import '../logging/app_logger.dart';

/// Abstraction over the multi-tenant Firebase schema for versioned student data.
class DbVersionService {
  DbVersionService({
    required FirebaseDatabase database,
    required CollegeConfig collegeConfig,
  })  : _database = database,
        _collegeId = collegeConfig.collegeId;

  final FirebaseDatabase _database;
  final String _collegeId;

  DatabaseReference get _root => _database.ref('colleges/$_collegeId');

  DatabaseReference get metaRef => _root.child('meta');

  DatabaseReference get liveStudentsRef => _root.child('studentsByRoll');

  DatabaseReference versionMetadataRef(String version) =>
      _root.child('versions/$version/metadata');

  DatabaseReference versionStudentsRef(String version) =>
      _root.child('versions/$version/studentsByRoll');

  DatabaseReference get auditRef => _root.child('audit/studentMutations');

  Future<String?> getCurrentVersion() async {
    try {
      final snap = await metaRef.child('currentVersion').get();
      if (!snap.exists) return null;
      final value = snap.value;
      if (value is String) return value;
      return value?.toString();
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to read current schema version.',
        tag: 'DbVersionService',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<DataSnapshot> loadLiveStudents() {
    return liveStudentsRef.get();
  }

  Future<DataSnapshot> loadAuditSince(int sinceMillis) {
    // Order by timestamp and read all mutations strictly after [sinceMillis].
    final query = auditRef.orderByChild('timestamp').startAfter(sinceMillis);
    return query.get();
  }
}
