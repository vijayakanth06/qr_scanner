// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attendee.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AttendeeAdapter extends TypeAdapter<Attendee> {
  @override
  final int typeId = 0;

  @override
  Attendee read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Attendee(
      rollNumber: fields[0] as String,
      batch: fields[1] as String,
      department: fields[2] as String,
      time: fields[3] as String,
      eventName: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Attendee obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.rollNumber)
      ..writeByte(1)
      ..write(obj.batch)
      ..writeByte(2)
      ..write(obj.department)
      ..writeByte(3)
      ..write(obj.time)
      ..writeByte(4)
      ..write(obj.eventName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendeeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
