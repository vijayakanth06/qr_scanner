import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qr_scanner/core/config/college_config.dart';
import 'package:qr_scanner/core/notifications/notification_service.dart';
import 'package:qr_scanner/core/versioning/db_version_service.dart';
import 'package:qr_scanner/features/attendance/data/hive_attendee_store.dart';
import 'package:qr_scanner/features/attendance/domain/entities/attendee.dart';
import 'package:qr_scanner/features/attendance/domain/services/attendance_flow_service.dart';
import 'package:qr_scanner/features/events/data/hive_event_repository.dart';
import 'package:qr_scanner/features/events/domain/entities/event.dart';
import 'package:qr_scanner/features/events/domain/repositories/event_repository.dart';
import 'package:qr_scanner/features/students/data/firebase_student_repository.dart';
import 'package:qr_scanner/features/students/data/hive_student_repository.dart';
import 'package:qr_scanner/features/students/domain/entities/student.dart';
import 'package:qr_scanner/features/students/domain/repositories/student_repository.dart';
import 'package:qr_scanner/features/sync/sync_service.dart';

/// Dependency Injection container setup.
/// Call this once during app bootstrap to register all services and repositories.
final getIt = GetIt.instance;

String _resolveActiveCollegeId() {
  if (getIt.isRegistered<CollegeConfig>()) {
    return getIt<CollegeConfig>().collegeId;
  }
  if (getIt.isRegistered<SharedPreferences>()) {
    final selectedCollegeId = getIt<SharedPreferences>().getString('selectedCollegeId')?.trim() ?? '';
    if (selectedCollegeId.isNotEmpty) {
      return selectedCollegeId;
    }
  }
  return 'default';
}

String _eventsBoxNameFor(String collegeId) => 'events_$collegeId';
String _attendeesBoxNameFor(String collegeId) => 'attendees_$collegeId';

/// Initialize the DI container with all dependencies.
Future<void> setupDependencies() async {
  if (!getIt.isRegistered<GlobalKey<NavigatorState>>()) {
    getIt.registerSingleton<GlobalKey<NavigatorState>>(GlobalKey<NavigatorState>());
  }

  // External services (Firebase, local storage)
  getIt.registerSingleton<FirebaseAuth>(FirebaseAuth.instance);
  getIt.registerSingleton<FirebaseDatabase>(FirebaseDatabase.instance);

  // Global UI notifications
  getIt.registerSingleton<NotificationService>(NotificationService());

  // Repositories (data layer)
  final firebaseStudentRepo = FirebaseStudentRepository();
  getIt.registerSingleton<FirebaseStudentRepository>(firebaseStudentRepo);

  final studentsBox = Hive.box<Student>('students');
  getIt.registerSingleton<StudentRepository>(HiveStudentRepository(studentsBox));

  final activeCollegeId = _resolveActiveCollegeId();

  // Event repository
  final eventBoxName = _eventsBoxNameFor(activeCollegeId);
  final eventBox = Hive.isBoxOpen(eventBoxName)
      ? Hive.box<Event>(eventBoxName)
      : await Hive.openBox<Event>(eventBoxName);
  getIt.registerSingleton<EventRepository>(
    HiveEventRepository(eventBox),
  );

  // Attendee store (domain service dependency, not a repository)
  final attendeeBoxName = _attendeesBoxNameFor(activeCollegeId);
  final attendeeBox = Hive.isBoxOpen(attendeeBoxName)
      ? Hive.box<Attendee>(attendeeBoxName)
      : await Hive.openBox<Attendee>(attendeeBoxName);
  getIt.registerSingleton<AttendeeStore>(
    HiveAttendeeStore(attendeeBox),
  );

  await setupCollegeDependencies();
}

Future<void> setupCollegeDependencies() async {
  if (!getIt.isRegistered<CollegeConfig>() || !getIt.isRegistered<SharedPreferences>()) {
    return;
  }

  final collegeConfig = getIt<CollegeConfig>();
  final sharedPreferences = getIt<SharedPreferences>();

  if (getIt.isRegistered<AttendanceFlowService>()) {
    getIt.unregister<AttendanceFlowService>();
  }
  if (getIt.isRegistered<AttendeeStore>()) {
    getIt.unregister<AttendeeStore>();
  }
  if (getIt.isRegistered<EventRepository>()) {
    getIt.unregister<EventRepository>();
  }
  if (getIt.isRegistered<SyncService>()) {
    getIt.unregister<SyncService>();
  }
  if (getIt.isRegistered<DbVersionService>()) {
    getIt.unregister<DbVersionService>();
  }

  final eventBoxName = _eventsBoxNameFor(collegeConfig.collegeId);
  final eventBox = Hive.isBoxOpen(eventBoxName)
      ? Hive.box<Event>(eventBoxName)
      : await Hive.openBox<Event>(eventBoxName);
  getIt.registerSingleton<EventRepository>(
    HiveEventRepository(eventBox),
  );

  final attendeeBoxName = _attendeesBoxNameFor(collegeConfig.collegeId);
  final attendeeBox = Hive.isBoxOpen(attendeeBoxName)
      ? Hive.box<Attendee>(attendeeBoxName)
      : await Hive.openBox<Attendee>(attendeeBoxName);
  getIt.registerSingleton<AttendeeStore>(
    HiveAttendeeStore(attendeeBox),
  );

  getIt.registerSingleton<DbVersionService>(
    DbVersionService(
      database: getIt<FirebaseDatabase>(),
      collegeConfig: collegeConfig,
    ),
  );

  getIt.registerSingleton<SyncService>(
    SyncService(
      dbVersionService: getIt<DbVersionService>(),
      sharedPreferences: sharedPreferences,
      collegeConfig: collegeConfig,
      navigatorKey: getIt<GlobalKey<NavigatorState>>(),
    ),
  );

  getIt.registerSingleton<AttendanceFlowService>(
    AttendanceFlowService(
      store: getIt<AttendeeStore>(),
      studentRepository: getIt<StudentRepository>(),
      remoteStudentRepository: getIt<FirebaseStudentRepository>(),
      collegeConfig: collegeConfig,
    ),
  );
}

/// Get a service or repository from the DI container.
/// Example: `final repo = sl<EventRepository>();`
T sl<T extends Object>() => getIt<T>();
