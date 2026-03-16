import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../features/attendance/domain/entities/attendee.dart';
import '../features/events/domain/entities/event.dart';
import '../features/students/domain/entities/student.dart';
import 'app.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(AttendeeAdapter());
  Hive.registerAdapter(EventAdapter());
  Hive.registerAdapter(StudentAdapter());
  await Hive.openBox<Event>('events');
  await Hive.openBox<Attendee>('attendees');
  await Hive.openBox<Student>('students');

  runApp(const QrScannerApp());
}
