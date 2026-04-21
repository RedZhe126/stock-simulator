// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_asset.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserAssetAdapter extends TypeAdapter<UserAsset> {
  @override
  final int typeId = 0;

  @override
  UserAsset read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserAsset(
      balance: fields[0] as double,
      initialCapital: fields[1] as double,
      totalInvested: fields[2] as double,
    );
  }

  @override
  void write(BinaryWriter writer, UserAsset obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.balance)
      ..writeByte(1)
      ..write(obj.initialCapital)
      ..writeByte(2)
      ..write(obj.totalInvested);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAssetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
