import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../features/attendance/domain/entities/attendee.dart';
import '../features/events/domain/entities/event.dart';
import '../features/students/domain/entities/student.dart';
import 'app.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase is best-effort for realtime sync; app keeps working fully offline if unavailable.
  try {
    await Firebase.initializeApp();
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  } catch (_) {}

  await Hive.initFlutter();
  Hive.registerAdapter(AttendeeAdapter());
  Hive.registerAdapter(EventAdapter());
  Hive.registerAdapter(StudentAdapter());
  await Hive.openBox<Event>('events');
  await Hive.openBox<Attendee>('attendees');
  await Hive.openBox<Student>('students');

  runApp(const QrScannerApp());
}
