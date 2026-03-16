import 'package:hive/hive.dart';

import '../domain/entities/attendee.dart';
import '../domain/services/attendance_flow_service.dart';

class HiveAttendeeStore implements AttendeeStore {
  HiveAttendeeStore(this.box);

  final Box<Attendee> box;

  @override
  Iterable<Attendee> all() => box.values;

  @override
  Future<void> add(Attendee attendee) async {
    await box.add(attendee);
  }

  @override
  Future<void> save(Attendee attendee) async {
    await attendee.save();
  }
}
