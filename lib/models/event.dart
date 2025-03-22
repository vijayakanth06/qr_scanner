import 'package:hive/hive.dart';

part 'event.g.dart';

@HiveType(typeId: 1) // Unique type ID for Hive
class Event extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String venue;

  @HiveField(2)
  DateTime date;

  Event({required this.name, required this.venue, required this.date});
}
