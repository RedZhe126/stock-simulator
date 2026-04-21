import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_asset.dart';
import '../models/stock_position.dart';
import '../models/transaction_record.dart';
import 'mock_data_provider.dart';
import 'trade_service.dart';

class PortfolioProvider extends ChangeNotifier {
  final Box<UserAsset> _assetBox = Hive.box<UserAsset>('user_assets');
  final Box<StockPosition> _positionBox = Hive.box<StockPosition>('positions');
  final Box<TransactionRecord> _transactionBox = Hive.box<TransactionRecord>('transactions');
  final Box<String> _watchlistBox = Hive.box<String>('watchlist');
  
  final StockDataProvider _dataProvider = MockDataProvider();
  final TradeService _tradeService = TradeService();

  UserAsset? _userAsset;
  List<StockPosition> _positions = [];
  Map<String, double> _currentPrices = {};
  List<String> _watchlist = [];

  UserAsset? get userAsset => _userAsset;
  List<StockPosition> get positions => _positions;
  Map<String, double> get currentPrices => _currentPrices;
  List<String> get watchlist => _watchlist;

  bool isFavorite(String symbol) => _watchlist.contains(symbol);

  Future<void> toggleFavorite(String symbol) async {
    if (_watchlist.contains(symbol)) {
      _watchlist.remove(symbol);
      final key = _watchlistBox.keys.firstWhere((k) => _watchlistBox.get(k) == symbol);
      await _watchlistBox.delete(key);
    } else {
      _watchlist.add(symbol);
      await _watchlistBox.add(symbol);
    }
    notifyListeners();
  }

  double get totalPortfolioValue {
    double stockValue = 0;
    for (var position in _positions) {
      final currentPrice = _currentPrices[position.symbol] ?? position.averageCost;
      stockValue += position.quantity * currentPrice;
    }
    return (_userAsset?.balance ?? 0) + stockValue;
  }

  double get totalUnrealizedGain {
    double gain = 0;
    for (var position in _positions) {
      final currentPrice = _currentPrices[position.symbol] ?? position.averageCost;
      gain += position.quantity * (currentPrice - position.averageCost);
    }
    return gain;
  }

  Future<void> initialize() async {
    // Seed initial asset if empty
    if (_assetBox.isEmpty) {
      await _assetBox.add(UserAsset(
        balance: 1000000,
        initialCapital: 1000000,
      ));
    }
    _userAsset = _assetBox.getAt(0);
    _positions = _positionBox.values.toList();
    
    await refreshPrices();
  }

  Future<void> refreshPrices() async {
    for (var position in _positions) {
      final priceData = await _dataProvider.getPrice(position.symbol);
      _currentPrices[position.symbol] = priceData.currentPrice;
    }
    notifyListeners();
  }

  Future<void> executeBuy(String symbol, String name, double price, int quantity) async {
    if (_userAsset == null) return;

    final result = _tradeService.buyStock(
      asset: _userAsset!,
      symbol: symbol,
      name: name,
      price: price,
      quantity: quantity,
      existingPosition: _positions.any((p) => p.symbol == symbol) 
          ? _positions.firstWhere((p) => p.symbol == symbol) 
          : null,
    );

    await _userAsset!.save();
    final StockPosition position = result['position'];
    
    if (position.isInBox) {
      await position.save();
    } else {
      await _positionBox.add(position);
    }
    
    await _transactionBox.add(result['transaction']);
    
    _positions = _positionBox.values.toList();
    _currentPrices[symbol] = price;
    notifyListeners();
  }

  Future<void> executeSell(String symbol, double price, int quantity) async {
    if (_userAsset == null) return;
    if (!_positions.any((p) => p.symbol == symbol)) return;

    final position = _positions.firstWhere((p) => p.symbol == symbol);
    
    final result = _tradeService.sellStock(
      asset: _userAsset!,
      position: position,
      price: price,
      quantity: quantity,
    );

    await _userAsset!.save();
    
    if (position.quantity == 0) {
      await position.delete();
    } else {
      await position.save();
    }

    await _transactionBox.add(result['transaction']);
    
    _positions = _positionBox.values.toList();
    _currentPrices[symbol] = price;
    notifyListeners();
  }

  Future<StockPrice> getFullStockPrice(String symbol) async {
    return await _dataProvider.getPrice(symbol);
  }
}
