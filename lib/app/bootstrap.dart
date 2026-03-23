import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/config/app_environment.dart';
import '../core/logging/app_logger.dart';
import '../features/attendance/domain/entities/attendee.dart';
import '../features/events/domain/entities/event.dart';
import 'app.dart';
import 'di.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Print environment configuration
  AppEnvironment.printConfig();

  // Firebase is best-effort for realtime sync; app keeps working fully offline if unavailable.
  try {
    await Firebase.initializeApp();

    AppLogger.configure(
      errorReporter: (error, stackTrace, message, tag) {
        return FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          reason: '${tag ?? 'App'}: $message',
          fatal: false,
        );
      },
    );

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode || AppEnvironment.diagnosticsEnabled);

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
  await Hive.openBox<Event>('events');
  await Hive.openBox<Attendee>('attendees');
  AppLogger.success('Hive initialized', tag: 'Bootstrap');

  // Initialize DI container
  await setupDependencies();
  AppLogger.success('DI container initialized', tag: 'Bootstrap');

  runApp(const QrScannerApp());
}
