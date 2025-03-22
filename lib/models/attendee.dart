import 'package:hive/hive.dart';

part 'attendee.g.dart';

@HiveType(typeId: 0)
class Attendee extends HiveObject {
  @HiveField(0)
  String rollNumber;

  @HiveField(1)
  String batch;

  @HiveField(2)
  String department;

  @HiveField(3)
  String time;

  Attendee({required this.rollNumber, required this.batch, required this.department, required this.time});
}
