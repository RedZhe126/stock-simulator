import 'dart:convert';
import 'package:gsheets/gsheets.dart';
import 'package:hive/hive.dart';
import '../models/transaction_record.dart';
import '../models/stock_position.dart';

class GSheetSyncService {
  static final GSheetSyncService _instance = GSheetSyncService._internal();
  factory GSheetSyncService() => _instance;
  GSheetSyncService._internal();

  GSheets? _gsheets;
  Spreadsheet? _spreadsheet;
  
  final Box _settingsBox = Hive.box('settings');

  bool get isConfigured => 
      _settingsBox.containsKey('gsheet_json') && 
      _settingsBox.get('gsheet_json').toString().isNotEmpty &&
      _settingsBox.containsKey('spreadsheet_id');

  Future<bool> initialize() async {
    if (!isConfigured) return false;

    try {
      final credentials = _settingsBox.get('gsheet_json');
      final spreadsheetId = _settingsBox.get('spreadsheet_id');
      
      _gsheets = GSheets(credentials);
      _spreadsheet = await _gsheets!.spreadsheet(spreadsheetId);
      return true;
    } catch (e) {
      print('GSheet Init Error: $e');
      return false;
    }
  }

  Future<void> syncTransactions(List<TransactionRecord> transactions) async {
    if (!await initialize()) return;

    var sheet = _spreadsheet!.worksheetByTitle('Transactions') ?? 
                await _spreadsheet!.addWorksheet('Transactions');

    // Add headers if new
    final values = await sheet.values.allRows();
    if (values.isEmpty) {
      await sheet.values.insertRow(1, [
        'Date', 'Symbol', 'Type', 'Price', 'Qty', 'Commission', 'Tax', 'Total'
      ]);
    }

    for (var tx in transactions) {
      if (tx.isSynced) continue;

      try {
        await sheet.values.appendRow([
          tx.timestamp.toIso8601String(),
          tx.symbol,
          tx.type == TransactionType.buy ? 'BUY' : 'SELL',
          tx.price,
          tx.quantity,
          tx.commission,
          tx.tax,
          tx.totalAmount,
        ]);
        tx.isSynced = true;
        await tx.save();
      } catch (e) {
        print('Sync TX Error: $e');
      }
    }
  }

  Future<void> syncPortfolio(List<StockPosition> positions, Map<String, double> currentPrices, double balance) async {
    if (!await initialize()) return;

    var sheet = _spreadsheet!.worksheetByTitle('Portfolio') ?? 
                await _spreadsheet!.addWorksheet('Portfolio');

    await sheet.values.clear();
    await sheet.values.insertRow(1, [
      'Symbol', 'Name', 'Qty', 'AvgCost', 'MarketValue'
    ]);
    
    for (var pos in positions) {
      final currentPrice = currentPrices[pos.symbol] ?? pos.averageCost;
      final marketValue = pos.quantity * currentPrice; 
      
      await sheet.values.appendRow([
        pos.symbol,
        pos.name,
        pos.quantity,
        pos.averageCost,
        marketValue,
      ]);
    }
    
    await sheet.values.appendRow(['Total Cash', '', '', '', balance]);
  }
}
