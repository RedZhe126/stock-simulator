import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:gsheets/gsheets.dart';

// ==========================================
// 1. DATA MODELS
// ==========================================

enum TransactionType { buy, sell }

@HiveType(typeId: 0)
class UserAsset extends HiveObject {
  @HiveField(0)
  double balance;

  @HiveField(1)
  double initialCapital;

  UserAsset({required this.balance, required this.initialCapital});
}

@HiveType(typeId: 1)
class StockPosition extends HiveObject {
  @HiveField(0)
  String symbol;

  @HiveField(1)
  String name;

  @HiveField(2)
  int quantity;

  @HiveField(3)
  double averageCost;

  StockPosition({
    required this.symbol,
    required this.name,
    required this.quantity,
    required this.averageCost,
  });
}

@HiveType(typeId: 2)
class TransactionRecord extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String symbol;

  @HiveField(2)
  TransactionType type;

  @HiveField(3)
  double price;

  @HiveField(4)
  int quantity;

  @HiveField(5)
  double commission;

  @HiveField(6)
  double tax;

  @HiveField(7)
  DateTime timestamp;

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
    double base = price * quantity;
    return type == TransactionType.buy ? base + commission : base - commission - tax;
  }
}

// Hive Adapters (Simulated for single file - normally generated)
class UserAssetAdapter extends TypeAdapter<UserAsset> {
  @override final int typeId = 0;
  @override UserAsset read(BinaryReader reader) => UserAsset(balance: reader.readDouble(), initialCapital: reader.readDouble());
  @override void write(BinaryWriter writer, UserAsset obj) { writer.writeDouble(obj.balance); writer.writeDouble(obj.initialCapital); }
}

class StockPositionAdapter extends TypeAdapter<StockPosition> {
  @override final int typeId = 1;
  @override StockPosition read(BinaryReader reader) => StockPosition(symbol: reader.readString(), name: reader.readString(), quantity: reader.readInt(), averageCost: reader.readDouble());
  @override void write(BinaryWriter writer, StockPosition obj) { writer.writeString(obj.symbol); writer.writeString(obj.name); writer.writeInt(obj.quantity); writer.writeDouble(obj.averageCost); }
}

class TransactionRecordAdapter extends TypeAdapter<TransactionRecord> {
  @override final int typeId = 2;
  @override TransactionRecord read(BinaryReader reader) => TransactionRecord(id: reader.readString(), symbol: reader.readString(), type: TransactionType.values[reader.readInt()], price: reader.readDouble(), quantity: reader.readInt(), commission: reader.readDouble(), tax: reader.readDouble(), timestamp: DateTime.fromMillisecondsSinceEpoch(reader.readInt()), isSynced: reader.readBool());
  @override void write(BinaryWriter writer, TransactionRecord obj) { writer.writeString(obj.id); writer.writeString(obj.symbol); writer.writeInt(obj.type.index); writer.writeDouble(obj.price); writer.writeInt(obj.quantity); writer.writeDouble(obj.commission); writer.writeDouble(obj.tax); writer.writeInt(obj.timestamp.millisecondsSinceEpoch); writer.writeBool(obj.isSynced); }
}

// ==========================================
// 2. SERVICES & LOGIC
// ==========================================

class TradeService {
  final double commissionRate = 0.001425;
  final double taxRate = 0.003;

  double calculateCommission(double price, int quantity) {
    double comm = price * quantity * commissionRate;
    return max(20.0, comm.roundToDouble());
  }

  double calculateTax(double price, int quantity) {
    return (price * quantity * taxRate).roundToDouble();
  }

  Map<String, dynamic> buyStock({
    required UserAsset asset,
    required String symbol,
    required String name,
    required double price,
    required int quantity,
    StockPosition? existingPosition,
  }) {
    double commission = calculateCommission(price, quantity);
    double totalCost = (price * quantity) + commission;

    if (asset.balance < totalCost) throw Exception('餘額不足');

    asset.balance -= totalCost;

    StockPosition position;
    if (existingPosition != null) {
      double totalOldCost = existingPosition.quantity * existingPosition.averageCost;
      int newQty = existingPosition.quantity + quantity;
      existingPosition.averageCost = (totalOldCost + totalCost) / newQty;
      existingPosition.quantity = newQty;
      position = existingPosition;
    } else {
      position = StockPosition(
        symbol: symbol,
        name: name,
        quantity: quantity,
        averageCost: totalCost / quantity,
      );
    }

    final tx = TransactionRecord(
      id: const Uuid().v4(),
      symbol: symbol,
      type: TransactionType.buy,
      price: price,
      quantity: quantity,
      commission: commission,
      tax: 0,
      timestamp: DateTime.now(),
    );

    return {'position': position, 'transaction': tx};
  }

  Map<String, dynamic> sellStock({
    required UserAsset asset,
    required StockPosition position,
    required double price,
    required int quantity,
  }) {
    if (position.quantity < quantity) throw Exception('庫存不足');

    double commission = calculateCommission(price, quantity);
    double tax = calculateTax(price, quantity);
    double receiveAmount = (price * quantity) - commission - tax;

    asset.balance += receiveAmount;
    position.quantity -= quantity;

    final tx = TransactionRecord(
      id: const Uuid().v4(),
      symbol: symbol, // This symbol is from the function scope or position
      type: TransactionType.sell,
      price: price,
      quantity: quantity,
      commission: commission,
      tax: tax,
      timestamp: DateTime.now(),
    );
    // Fix: use position.symbol instead of undefined symbol
    tx.symbol = position.symbol;

    return {'position': position, 'transaction': tx};
  }
}

class KLineData {
  final DateTime time;
  final double open, high, low, close;
  KLineData(this.time, this.open, this.high, this.low, this.close);
}

class StockPrice {
  final String symbol, name;
  final double currentPrice, change, changePercentage;
  final List<KLineData> kLines;
  StockPrice({required this.symbol, required this.name, required this.currentPrice, required this.change, required this.changePercentage, required this.kLines});
}

class MockDataProvider {
  StockPrice getStaticPrice(String symbol) {
    final random = Random(symbol.hashCode);
    double base = 100 + random.nextDouble() * 500;
    double change = (random.nextDouble() - 0.4) * 10;
    
    List<KLineData> kLines = List.generate(50, (i) {
      double dayBase = base - (50 - i) * 2;
      return KLineData(DateTime.now().subtract(Duration(days: 50 - i)), dayBase - 2, dayBase + 5, dayBase - 4, dayBase + 1);
    });

    return StockPrice(
      symbol: symbol,
      name: symbol == '2330' ? '台積電' : (symbol == '2603' ? '長榮' : '熱門標的'),
      currentPrice: base,
      change: change,
      changePercentage: (change / base) * 100,
      kLines: kLines,
    );
  }
}

class GSheetSyncService {
  final Box _settingsBox = Hive.box('settings');
  
  bool get isConfigured => _settingsBox.containsKey('gsheet_json') && _settingsBox.get('gsheet_json').toString().isNotEmpty;

  Future<void> sync(PortfolioProvider provider) async {
    if (!isConfigured) return;
    try {
      final gsheets = GSheets(_settingsBox.get('gsheet_json'));
      final ss = await gsheets.spreadsheet(_settingsBox.get('spreadsheet_id'));
      
      // Sync Transactions
      var txSheet = ss.worksheetByTitle('Transactions') ?? await ss.addWorksheet('Transactions');
      final txBox = Hive.box<TransactionRecord>('transactions');
      final unsynced = txBox.values.where((tx) => !tx.isSynced).toList();
      
      for (var tx in unsynced) {
        await txSheet.values.appendRow([tx.timestamp.toIso8601String(), tx.symbol, tx.type.name, tx.price, tx.quantity, tx.commission, tx.tax, tx.totalAmount]);
        tx.isSynced = true;
        await tx.save();
      }

      // Sync Portfolio (overwrite)
      var pSheet = ss.worksheetByTitle('Portfolio') ?? await ss.addWorksheet('Portfolio');
      await pSheet.values.clear();
      await pSheet.values.insertRow(1, ['Symbol', 'Name', 'Qty', 'AvgCost', 'MarketValue']);
      for (var pos in provider.positions) {
        double current = provider.currentPrices[pos.symbol] ?? pos.averageCost;
        await pSheet.values.appendRow([pos.symbol, pos.name, pos.quantity, pos.averageCost, pos.quantity * current]);
      }
    } catch (e) {
      print('Sync Error: $e');
    }
  }
}

class PortfolioProvider extends ChangeNotifier {
  final Box<UserAsset> _assetBox = Hive.box<UserAsset>('user_assets');
  final Box<StockPosition> _positionBox = Hive.box<StockPosition>('positions');
  final Box<TransactionRecord> _transactionBox = Hive.box<TransactionRecord>('transactions');
  final Box<String> _watchlistBox = Hive.box<String>('watchlist');
  
  final TradeService _tradeService = TradeService();
  final MockDataProvider _mock = MockDataProvider();

  UserAsset? userAsset;
  List<StockPosition> positions = [];
  Map<String, double> currentPrices = {};
  List<String> watchlist = [];

  Future<void> initialize() async {
    if (_assetBox.isEmpty) await _assetBox.add(UserAsset(balance: 1000000, initialCapital: 1000000));
    userAsset = _assetBox.getAt(0);
    positions = _positionBox.values.toList();
    watchlist = _watchlistBox.values.toList();
    for (var p in positions) currentPrices[p.symbol] = _mock.getStaticPrice(p.symbol).currentPrice;
    notifyListeners();
  }

  double get totalPortfolioValue {
    double stocks = 0;
    for (var p in positions) stocks += p.quantity * (currentPrices[p.symbol] ?? p.averageCost);
    return (userAsset?.balance ?? 0) + stocks;
  }

  void toggleFavorite(String symbol) {
    if (watchlist.contains(symbol)) {
      watchlist.remove(symbol);
      final key = _watchlistBox.keys.firstWhere((k) => _watchlistBox.get(k) == symbol);
      _watchlistBox.delete(key);
    } else {
      watchlist.add(symbol);
      _watchlistBox.add(symbol);
    }
    notifyListeners();
  }

  Future<void> executeBuy(String symbol, String name, double price, int quantity) async {
    final res = _tradeService.buyStock(asset: userAsset!, symbol: symbol, name: name, price: price, quantity: quantity, existingPosition: positions.any((p) => p.symbol == symbol) ? positions.firstWhere((p) => p.symbol == symbol) : null);
    await userAsset!.save();
    if (res['position'].isInBox) await res['position'].save(); else await _positionBox.add(res['position']);
    await _transactionBox.add(res['transaction']);
    positions = _positionBox.values.toList();
    currentPrices[symbol] = price;
    notifyListeners();
  }
}

// ==========================================
// 3. UI COMPONENTS
// ==========================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(UserAssetAdapter());
  Hive.registerAdapter(StockPositionAdapter());
  Hive.registerAdapter(TransactionRecordAdapter());
  await Hive.openBox<UserAsset>('user_assets');
  await Hive.openBox<StockPosition>('positions');
  await Hive.openBox<TransactionRecord>('transactions');
  await Hive.openBox<String>('watchlist');
  await Hive.openBox('settings');

  runApp(ChangeNotifierProvider(
    create: (_) => PortfolioProvider()..initialize(),
    child: const FVSSApp(),
  ));
}

class FVSSApp extends StatelessWidget {
  const FVSSApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF1E3A8A),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(primary: Color(0xFF3B82F6)),
      ),
      home: const MainScaffold(),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});
  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _idx = 0;
  final _pages = [const Dashboard(), const Watchlist(), const Settings()];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_idx],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '首頁'),
          BottomNavigationBarItem(icon: Icon(Icons.star), label: '自選'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '設定'),
        ],
      ),
    );
  }
}

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.watch<PortfolioProvider>();
    if (p.userAsset == null) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      appBar: AppBar(title: const Text('FVSS 儀表板'), actions: [IconButton(icon: const Icon(Icons.search), onPressed: () => showSearch(context: context, delegate: StockSearch()))]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _AssetCard(total: p.totalPortfolioValue, cash: p.userAsset!.balance),
            const SizedBox(height: 20),
            _PositionList(positions: p.positions, prices: p.currentPrices),
          ],
        ),
      ),
    );
  }
}

class _AssetCard extends StatelessWidget {
  final double total, cash;
  const _AssetCard({required this.total, required this.cash});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('總預估資產', style: TextStyle(color: Colors.grey)),
            Text(NumberFormat.simpleCurrency(name: 'TWD ').format(total), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const Divider(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('可用現金'), Text(NumberFormat.simpleCurrency(name: 'TWD ').format(cash))]),
          ],
        ),
      ),
    );
  }
}

class _PositionList extends StatelessWidget {
  final List<StockPosition> positions;
  final Map<String, double> prices;
  const _PositionList({required this.positions, required this.prices});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('庫存持股', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ...positions.map((pos) {
          double cur = prices[pos.symbol] ?? pos.averageCost;
          double gain = (cur - pos.averageCost) * pos.quantity;
          return ListTile(
            title: Text('${pos.symbol} ${pos.name}'),
            subtitle: Text('成本: ${pos.averageCost.toStringAsFixed(2)}'),
            trailing: Text(gain.toStringAsFixed(0), style: TextStyle(color: gain >= 0 ? Colors.red : Colors.green)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Detail(symbol: pos.symbol, name: pos.name))),
          );
        }),
      ],
    );
  }
}

class StockSearch extends SearchDelegate {
  final stocks = [{'s': '2330', 'n': '台積電'}, {'s': '2603', 'n': '長榮'}, {'s': '2454', 'n': '聯發科'}];
  @override List<Widget>? buildActions(BuildContext context) => [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  @override Widget? buildLeading(BuildContext context) => IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));
  @override Widget buildResults(BuildContext context) => Container();
  @override Widget buildSuggestions(BuildContext context) {
    final list = stocks.where((s) => s['s']!.contains(query) || s['n']!.contains(query)).toList();
    return ListView.builder(itemCount: list.length, itemBuilder: (_, i) => ListTile(title: Text(list[i]['s']!), subtitle: Text(list[i]['n']!), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Detail(symbol: list[i]['s']!, name: list[i]['n']!)))));
  }
}

class Detail extends StatelessWidget {
  final String symbol, name;
  const Detail({super.key, required this.symbol, required this.name});
  @override
  Widget build(BuildContext context) {
    final stock = MockDataProvider().getStaticPrice(symbol);
    return Scaffold(
      appBar: AppBar(title: Text('$symbol $name'), actions: [IconButton(icon: Icon(context.watch<PortfolioProvider>().watchlist.contains(symbol) ? Icons.star : Icons.star_border), onPressed: () => context.read<PortfolioProvider>().toggleFavorite(symbol))]),
      body: Column(
        children: [
          Padding(padding: const EdgeInsets.all(20), child: Text(stock.currentPrice.toStringAsFixed(2), style: TextStyle(fontSize: 40, color: stock.change >= 0 ? Colors.red : Colors.green))),
          SizedBox(height: 250, child: SfCartesianChart(series: <CandleSeries>[CandleSeries<KLineData, DateTime>(dataSource: stock.kLines, xValueMapper: (d, _) => d.time, lowValueMapper: (d, _) => d.low, highValueMapper: (d, _) => d.high, openValueMapper: (d, _) => d.open, closeValueMapper: (d, _) => d.close, bullColor: Colors.red, bearColor: Colors.green)])),
          ElevatedButton(onPressed: () => _buy(context), child: const Text('立即買入')),
        ],
      ),
    );
  }
  void _buy(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text('確認買入'), content: const Text('確認以市價買入 1,000 股？'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')), TextButton(onPressed: () { context.read<PortfolioProvider>().executeBuy(symbol, name, MockDataProvider().getStaticPrice(symbol).currentPrice, 1000); Navigator.pop(context); }, child: const Text('確認'))]));
  }
}

class Watchlist extends StatelessWidget {
  const Watchlist({super.key});
  @override
  Widget build(BuildContext context) {
    final list = context.watch<PortfolioProvider>().watchlist;
    return Scaffold(
      appBar: AppBar(title: const Text('我的自選')),
      body: ListView(children: list.map((s) => ListTile(title: Text(s), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Detail(symbol: s, name: '自選標的'))))).toList()),
    );
  }
}

class Settings extends StatefulWidget {
  const Settings({super.key});
  @override State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final _c = TextEditingController(text: Hive.box('settings').get('gsheet_json'));
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('同步設定')),
      padding: const EdgeInsets.all(20),
      body: Column(children: [
        TextField(controller: _c, maxLines: 5, decoration: const InputDecoration(labelText: 'GSheet JSON', border: OutlineInputBorder())),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: () { Hive.box('settings').put('gsheet_json', _c.text); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已儲存'))); }, child: const Text('儲存設定')),
        const SizedBox(height: 10),
        ElevatedButton(onPressed: () => GSheetSyncService().sync(context.read<PortfolioProvider>()), child: const Text('手動同步至雲端')),
      ]),
    );
  }
}
