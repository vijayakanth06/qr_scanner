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
      id: fields[0] as String,
      name: fields[1] as String,
      batch: fields[2] as String,
      department: fields[3] as String,
      inTime: fields[4] as DateTime,
      outTime: fields[5] as DateTime?,
      eventName: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Attendee obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.batch)
      ..writeByte(3)
      ..write(obj.department)
      ..writeByte(4)
      ..write(obj.inTime)
      ..writeByte(5)
      ..write(obj.outTime)
      ..writeByte(6)
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
