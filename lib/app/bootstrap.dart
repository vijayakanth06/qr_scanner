import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:qr_scanner/firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_environment.dart';
import '../core/config/college_config.dart';
import '../core/logging/app_logger.dart';
import '../features/attendance/domain/entities/attendee.dart';
import '../features/events/domain/entities/event.dart';
import '../features/students/domain/entities/student.dart';
import 'app.dart';
import 'di.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Print environment configuration
  AppEnvironment.printConfig();

  // Firebase is best-effort for realtime sync; app keeps working fully offline if unavailable.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    AppLogger.configure(
      errorReporter: (error, stackTrace, message, tag) {
        if (!kIsWeb) {
          return FirebaseCrashlytics.instance.recordError(
            error,
            stackTrace,
            reason: '${tag ?? 'App'}: $message',
            fatal: false,
          );
        }
        return Future.value();
      },
    );

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (!kIsWeb) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      }
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      if (!kIsWeb) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }
      return true;
    };

    // Crashlytics is only available on mobile/desktop platforms, not web
    if (!kIsWeb) {
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(!kDebugMode || AppEnvironment.diagnosticsEnabled);
    }

    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    AppLogger.success('Firebase initialized', tag: 'Bootstrap');
  } catch (error, stackTrace) {
    AppLogger.error(
      'Firebase bootstrap unavailable. Running offline.',
      tag: 'Bootstrap',
      error: error,
      stackTrace: stackTrace,
    );
  }

  await Hive.initFlutter();
  Hive.registerAdapter(AttendeeAdapter());
  Hive.registerAdapter(ScanModeAdapter());
  Hive.registerAdapter(EventAdapter());
  Hive.registerAdapter(StudentAdapter());

  // Shared preferences are used for sync metadata (version, timestamps, etc.).
  final sharedPreferences = await SharedPreferences.getInstance();

  // Register core infrastructure singletons before feature services.
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);

  final selectedCollegeId = sharedPreferences.getString('selectedCollegeId')?.trim();
  final scopedCollegeId = (selectedCollegeId != null && selectedCollegeId.isNotEmpty)
      ? selectedCollegeId
      : 'default';

  await Hive.openBox<Event>('events_$scopedCollegeId');
  await Hive.openBox<Attendee>('attendees_$scopedCollegeId');
  await Hive.openBox<Student>('students');
  AppLogger.success('Hive initialized', tag: 'Bootstrap');

  needsCollegePicker = true;
  if (selectedCollegeId != null && selectedCollegeId.trim().isNotEmpty) {
    try {
      final colleges = await CollegeConfig.loadAll();
      final collegeConfig = colleges.firstWhere(
        (config) => config.collegeId == selectedCollegeId,
      );

      getIt.registerSingleton<CollegeConfig>(collegeConfig);
      needsCollegePicker = false;
      AppLogger.success('Loaded selected college "$selectedCollegeId"', tag: 'Bootstrap');
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to restore selected college "$selectedCollegeId". Falling back to picker.',
        tag: 'Bootstrap',
        error: error,
        stackTrace: stackTrace,
      );
      await sharedPreferences.remove('selectedCollegeId');
    }
  }

  // Initialize DI container
  await setupDependencies();
  AppLogger.success('DI container initialized', tag: 'Bootstrap');

  runApp(const QrScannerApp());
}
