import 'package:hive/hive.dart';

part 'attendee.g.dart';

@HiveType(typeId: 0)
class Attendee extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String batch;

  @HiveField(3)
  String department;

  @HiveField(4)
  DateTime inTime;

  @HiveField(5)
  DateTime? outTime;

  @HiveField(6)
  String eventName;

  Attendee({
    required this.id,
    required this.name,
    required this.batch,
    required this.department,
    required this.inTime,
    this.outTime,
    required this.eventName,
  });
}
