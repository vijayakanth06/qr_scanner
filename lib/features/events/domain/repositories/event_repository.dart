import '../entities/event.dart';

abstract class EventRepository {
  Future<List<Event>> getAll();
  Future<void> add(Event event);
  Future<void> deleteAt(int index);
  Event? getAt(int index);
}
