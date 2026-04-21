import 'package:uuid/uuid.dart';
import '../models/user_asset.dart';
import '../models/stock_position.dart';
import '../models/transaction_record.dart';

class TradeService {
  static const double commissionRate = 0.001425;
  static const double taxRate = 0.003;

  /// Calculate commission for a given trade volume (0.1425%, min 20 TWD)
  double calculateCommission(double price, int quantity) {
    double commission = price * quantity * commissionRate;
    // Round to nearest integer (TWD standard)
    int roundedCommission = commission.round();
    // Enforce minimum 20 TWD
    return roundedCommission < 20 ? 20.0 : roundedCommission.toDouble();
  }

  /// Calculate tax for a given trade volume (sell only, 0.3%)
  double calculateTax(double price, int quantity) {
    double tax = price * quantity * taxRate;
    // Round to nearest integer
    return tax.roundToDouble();
  }

  /// Execute a Buy Order
  /// Returns a map with the updated UserAsset and the new TransactionRecord
  Map<String, dynamic> buyStock({
    required UserAsset asset,
    required String symbol,
    required String name,
    required double price,
    required int quantity,
    StockPosition? existingPosition,
  }) {
    final commission = calculateCommission(price, quantity);
    final totalCost = (price * quantity) + commission;

    if (asset.balance < totalCost) {
      throw Exception('Insufficient balance');
    }

    // Update Asset
    asset.balance -= totalCost;
    asset.totalInvested += totalCost;

    // Update/Create Position
    StockPosition updatedPosition;
    if (existingPosition != null) {
      final totalQuantity = existingPosition.quantity + quantity;
      final totalCostBasis = existingPosition.bookValue + totalCost;
      existingPosition.quantity = totalQuantity;
      existingPosition.averageCost = totalCostBasis / totalQuantity;
      existingPosition.isSynced = false;
      updatedPosition = existingPosition;
    } else {
      updatedPosition = StockPosition(
        symbol: symbol,
        name: name,
        quantity: quantity,
        averageCost: totalCost / quantity,
        isSynced: false,
      );
    }

    // Create Transaction Record
    final transaction = TransactionRecord(
      id: const Uuid().v4(),
      symbol: symbol,
      type: TransactionType.buy,
      price: price,
      quantity: quantity,
      commission: commission,
      tax: 0.0,
      timestamp: DateTime.now(),
      isSynced: false,
    );

    return {
      'asset': asset,
      'position': updatedPosition,
      'transaction': transaction,
    };
  }

  /// Execute a Sell Order
  Map<String, dynamic> sellStock({
    required UserAsset asset,
    required StockPosition position,
    required double price,
    required int quantity,
  }) {
    if (position.quantity < quantity) {
      throw Exception('Insufficient shares');
    }

    final commission = calculateCommission(price, quantity);
    final tax = calculateTax(price, quantity);
    final grossProceeds = price * quantity;
    final netProceeds = grossProceeds - commission - tax;

    // Book value of the portion sold
    final bookValueSold = quantity * position.averageCost;

    // Update Asset
    asset.balance += netProceeds;
    asset.totalInvested -= bookValueSold;

    // Update Position
    position.quantity -= quantity;
    position.isSynced = false;

    // Create Transaction Record
    final transaction = TransactionRecord(
      id: const Uuid().v4(),
      symbol: position.symbol,
      type: TransactionType.sell,
      price: price,
      quantity: quantity,
      commission: commission,
      tax: tax,
      timestamp: DateTime.now(),
      isSynced: false,
    );

    return {
      'asset': asset,
      'position': position,
      'transaction': transaction,
    };
  }
}
