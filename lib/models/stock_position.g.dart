// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stock_position.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StockPositionAdapter extends TypeAdapter<StockPosition> {
  @override
  final int typeId = 1;

  @override
  StockPosition read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StockPosition(
      symbol: fields[0] as String,
      name: fields[1] as String,
      quantity: fields[2] as int,
      averageCost: fields[3] as double,
      isSynced: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, StockPosition obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.symbol)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.quantity)
      ..writeByte(3)
      ..write(obj.averageCost)
      ..writeByte(4)
      ..write(obj.isSynced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StockPositionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
