import 'package:hive/hive.dart';

import '../domain/entities/event.dart';
import '../domain/repositories/event_repository.dart';

class HiveEventRepository implements EventRepository {
  HiveEventRepository(this.box);

  final Box<Event> box;

  @override
  Future<void> add(Event event) async {
    await box.add(event);
  }

  @override
  Future<void> deleteAt(int index) async {
    await box.deleteAt(index);
  }

  @override
  Future<List<Event>> getAll() async {
    return box.values.toList();
  }

  @override
  Event? getAt(int index) {
    return box.getAt(index);
  }
}
