// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EventAdapter extends TypeAdapter<Event> {
  @override
  final int typeId = 1;

  @override
  Event read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Event(
      name: fields[0] as String,
      venue: fields[1] as String,
      date: fields[2] as DateTime,
      scanMode: fields[3] == null
          ? ScanMode.both
          : ScanMode.values[fields[3] as int],
      cooldownSeconds: fields[4] as int? ?? 3,
      restrictDuplicateExit: fields[5] as bool? ?? true,
    );
  }

  @override
  void write(BinaryWriter writer, Event obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.venue)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.scanMode.index)
      ..writeByte(4)
      ..write(obj.cooldownSeconds)
      ..writeByte(5)
      ..write(obj.restrictDuplicateExit);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
