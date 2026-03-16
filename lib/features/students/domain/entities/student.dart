import 'package:hive/hive.dart';

part 'student.g.dart';

@HiveType(typeId: 2)
class Student extends HiveObject {
  @HiveField(0)
  String rollNumber;

  @HiveField(1)
  String name;

  @HiveField(2)
  String mobileNumber;

  @HiveField(3)
  String branch;

  @HiveField(4)
  String section;

  @HiveField(5)
  String residence;

  Student({
    required this.rollNumber,
    required this.name,
    required this.mobileNumber,
    required this.branch,
    required this.section,
    required this.residence,
  });
}
