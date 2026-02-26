// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OrderModelAdapter extends TypeAdapter<OrderModel> {
  @override
  final int typeId = 0;

  @override
  OrderModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OrderModel(
      itemNames: (fields[0] as List).cast<String>(),
      itemQuantities: (fields[1] as List).cast<int>(),
      itemPrices: (fields[2] as List).cast<double>(),
      totalAmount: fields[3] as double,
      status: fields[4] as String,
      timestamp: fields[5] as DateTime,
      deliveryLat: fields[6] as double,
      deliveryLng: fields[7] as double,
      xenditInvoiceId: fields[8] as String,
      riderStep: fields[9] as int,
      orderStartTime: fields[10] as DateTime?,
      itemAddons: (fields[11] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, OrderModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.itemNames)
      ..writeByte(1)
      ..write(obj.itemQuantities)
      ..writeByte(2)
      ..write(obj.itemPrices)
      ..writeByte(3)
      ..write(obj.totalAmount)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.timestamp)
      ..writeByte(6)
      ..write(obj.deliveryLat)
      ..writeByte(7)
      ..write(obj.deliveryLng)
      ..writeByte(8)
      ..write(obj.xenditInvoiceId)
      ..writeByte(9)
      ..write(obj.riderStep)
      ..writeByte(10)
      ..write(obj.orderStartTime)
      ..writeByte(11)
      ..write(obj.itemAddons);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
