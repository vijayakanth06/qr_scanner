import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:qr_scanner/features/attendance/data/hive_attendee_store.dart';
import 'package:qr_scanner/features/attendance/domain/entities/attendee.dart';
import 'package:qr_scanner/features/attendance/domain/services/attendance_flow_service.dart';
import 'package:qr_scanner/features/events/data/hive_event_repository.dart';
import 'package:qr_scanner/features/events/domain/entities/event.dart';
import 'package:qr_scanner/features/events/domain/repositories/event_repository.dart';
import 'package:qr_scanner/features/students/data/firebase_student_repository.dart';

/// Dependency Injection container setup.
/// Call this once during app bootstrap to register all services and repositories.
final getIt = GetIt.instance;

/// Initialize the DI container with all dependencies.
Future<void> setupDependencies() async {
  // External services (Firebase, local storage)
  getIt.registerSingleton<FirebaseAuth>(FirebaseAuth.instance);
  getIt.registerSingleton<FirebaseDatabase>(FirebaseDatabase.instance);

  // Repositories (data layer)
  final firebaseStudentRepo = FirebaseStudentRepository();
  getIt.registerSingleton<FirebaseStudentRepository>(firebaseStudentRepo);

  // Event repository
  final eventBox = Hive.box<Event>('events');
  getIt.registerSingleton<EventRepository>(
    HiveEventRepository(eventBox),
  );

  // Attendee store (domain service dependency, not a repository)
  final attendeeBox = Hive.box<Attendee>('attendees');
  getIt.registerSingleton<AttendeeStore>(
    HiveAttendeeStore(attendeeBox),
  );

  // Domain services (business logic)
  getIt.registerSingleton<AttendanceFlowService>(
    AttendanceFlowService(
      store: getIt<AttendeeStore>(),
    ),
  );
}

/// Get a service or repository from the DI container.
/// Example: `final repo = sl<EventRepository>();`
T sl<T extends Object>() => getIt<T>();
