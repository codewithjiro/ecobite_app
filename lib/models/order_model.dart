import 'package:hive/hive.dart';

part 'order_model.g.dart';

@HiveType(typeId: 0)
class OrderModel extends HiveObject {
  @HiveField(0)
  final List<String> itemNames;

  @HiveField(1)
  final List<int> itemQuantities;

  @HiveField(2)
  final List<double> itemPrices;

  @HiveField(3)
  final double totalAmount;

  @HiveField(4)
  String status;

  @HiveField(5)
  final DateTime timestamp;

  @HiveField(6)
  final double deliveryLat;

  @HiveField(7)
  final double deliveryLng;

  @HiveField(8)
  final String xenditInvoiceId;

  @HiveField(9)
  int riderStep;          // how far the rider has travelled

  @HiveField(10)
  DateTime? orderStartTime; // when the order was placed (for timer resume)

  OrderModel({
    required this.itemNames,
    required this.itemQuantities,
    required this.itemPrices,
    required this.totalAmount,
    required this.status,
    required this.timestamp,
    required this.deliveryLat,
    required this.deliveryLng,
    required this.xenditInvoiceId,
    this.riderStep = 0,
    DateTime? orderStartTime,
  }) : orderStartTime = orderStartTime ?? DateTime.now();
}
