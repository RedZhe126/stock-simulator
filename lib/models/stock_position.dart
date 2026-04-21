import 'package:hive/hive.dart';

part 'stock_position.g.dart';

@HiveType(typeId: 1)
class StockPosition extends HiveObject {
  @HiveField(0)
  final String symbol;

  @HiveField(1)
  final String name;

  @HiveField(2)
  int quantity;

  @HiveField(3)
  double averageCost;

  @HiveField(4)
  bool isSynced;

  StockPosition({
    required this.symbol,
    required this.name,
    required this.quantity,
    required this.averageCost,
    this.isSynced = false,
  });

  // Calculate book value (cost basis)
  double get bookValue => quantity * averageCost;
}
