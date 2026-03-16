import 'package:hive/hive.dart';

part 'event.g.dart';

enum ScanMode {
  both,
  entryOnly,
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
