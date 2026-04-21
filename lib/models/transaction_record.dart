import 'package:hive/hive.dart';

part 'transaction_record.g.dart';

@HiveType(typeId: 2)
enum TransactionType {
  @HiveField(0)
  buy,
  @HiveField(1)
  sell,
}

@HiveType(typeId: 3)
class TransactionRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String symbol;

  @HiveField(2)
  final TransactionType type;

  @HiveField(3)
  final double price;

  @HiveField(4)
  final int quantity;

  @HiveField(5)
  final double commission;

  @HiveField(6)
  final double tax;

  @HiveField(7)
  final DateTime timestamp;

  @HiveField(8)
  bool isSynced;

  TransactionRecord({
    required this.id,
    required this.symbol,
    required this.type,
    required this.price,
    required this.quantity,
    required this.commission,
    required this.tax,
    required this.timestamp,
    this.isSynced = false,
  });

  double get totalAmount {
    if (type == TransactionType.buy) {
      return (price * quantity) + commission;
    } else {
      return (price * quantity) - commission - tax;
    }
  }
}
