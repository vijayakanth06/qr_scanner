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
      scanMode: fields[3] as ScanMode,
      cooldownSeconds: fields[4] as int,
      restrictDuplicateExit: fields[5] as bool,
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
      ..write(obj.scanMode)
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

class ScanModeAdapter extends TypeAdapter<ScanMode> {
  @override
  final int typeId = 3;

  @override
  ScanMode read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ScanMode.both;
      case 1:
        return ScanMode.entryOnly;
      case 2:
        return ScanMode.exitOnly;
      default:
        return ScanMode.both;
    }
  }

  @override
  void write(BinaryWriter writer, ScanMode obj) {
    switch (obj) {
      case ScanMode.both:
        writer.writeByte(0);
        break;
      case ScanMode.entryOnly:
        writer.writeByte(1);
        break;
      case ScanMode.exitOnly:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
