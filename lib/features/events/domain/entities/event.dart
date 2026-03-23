import 'package:hive/hive.dart';

part 'event.g.dart';

@HiveType(typeId: 3)
enum ScanMode {
  @HiveField(0)
  both,
  @HiveField(1)
  entryOnly,
  @HiveField(2)
  exitOnly,
}

@HiveType(typeId: 1)
class Event extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String venue;

  @HiveField(2)
  DateTime date;

  @HiveField(3)
  ScanMode scanMode;

  @HiveField(4)
  int cooldownSeconds;

  @HiveField(5)
  bool restrictDuplicateExit;

  Event({
    required this.name,
    required this.venue,
    required this.date,
    this.scanMode = ScanMode.both,
    this.cooldownSeconds = 3,
    this.restrictDuplicateExit = true,
  });
}
