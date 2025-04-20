import 'package:hive/hive.dart';

part 'attendee.g.dart';

@HiveType(typeId: 0)
class Attendee extends HiveObject {
  @HiveField(0)
  String id; // Unique identifier from the QR Code

  @HiveField(1)
  String name;

  @HiveField(2)
  String batch; // ✅ Added missing batch field

  @HiveField(3)
  String department;

  @HiveField(4)
  DateTime inTime; // Entry time

  @HiveField(5)
  DateTime? outTime; // Exit time (nullable, updated when scanned again)

  @HiveField(6)
  String eventName; // Event where the attendee was added

  Attendee({
    required this.id,
    required this.name,
    required this.batch, // ✅ Now required
    required this.department,
    required this.inTime,
    this.outTime,
    required this.eventName,
  });

  // ✅ Static method to return an empty Attendee object (Fix for `null` issue)
  static Attendee empty() {
    return Attendee(
      id: '',
      name: '',
      batch: '', // ✅ Included batch here
      department: '',
      inTime: DateTime(2000, 1, 1), // Dummy default time
      outTime: null,
      eventName: '',
    );
  }
}
