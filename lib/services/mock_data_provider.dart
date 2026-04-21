import 'dart:math';

class KLineData {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  KLineData({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });
}

class StockPrice {
  final String symbol;
  final String name;
  final double currentPrice;
  final double change;
  final double changePercentage;
  final List<KLineData> kLines;

  StockPrice({
    required this.symbol,
    required this.name,
    required this.currentPrice,
    required this.change,
    required this.changePercentage,
    this.kLines = const [],
  });
}

abstract class StockDataProvider {
  Future<StockPrice> getPrice(String symbol);
  Future<List<StockPrice>> getWatchlist();
  Future<List<KLineData>> getKLineData(String symbol);
}

class MockDataProvider implements StockDataProvider {
  final Random _random = Random();

  final Map<String, String> _stockNames = {
    '2330': '台積電',
    '2603': '長榮',
    '2454': '聯發科',
    '2317': '鴻海',
  };

  final Map<String, double> _basePrices = {
    '2330': 780.0,
    '2603': 175.0,
    '2454': 1050.0,
    '2317': 155.0,
  };

  @override
  Future<StockPrice> getPrice(String symbol) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    final basePrice = _basePrices[symbol] ?? 100.0;
    final name = _stockNames[symbol] ?? '未知股票';
    
    // Random fluctuation +/- 2%
    final fluctuation = (basePrice * 0.02) * (_random.nextDouble() * 2 - 1);
    final currentPrice = basePrice + fluctuation;
    final change = fluctuation;
    final changePercentage = (change / basePrice) * 100;
    
    final kLines = await getKLineData(symbol);

    return StockPrice(
      symbol: symbol,
      name: name,
      currentPrice: currentPrice,
      change: change,
      changePercentage: changePercentage,
      kLines: kLines,
    );
  }

  @override
  Future<List<KLineData>> getKLineData(String symbol) async {
    final basePrice = _basePrices[symbol] ?? 100.0;
    final List<KLineData> data = [];
    double lastClose = basePrice;
    final now = DateTime.now();

    for (int i = 50; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) continue;

      final fluctuation = lastClose * 0.02 * (_random.nextDouble() - 0.5);
      final open = lastClose;
      final close = open + fluctuation;
      final high = max(open, close) + (lastClose * 0.01 * _random.nextDouble());
      final low = min(open, close) - (lastClose * 0.01 * _random.nextDouble());
      final volume = 1000.0 + _random.nextDouble() * 5000.0;

      data.add(KLineData(
        time: date,
        open: open,
        high: high,
        low: low,
        close: close,
        volume: volume,
      ));
      lastClose = close;
    }
    return data;
  }

  @override
  Future<List<StockPrice>> getWatchlist() async {
    final List<StockPrice> prices = [];
    for (var symbol in _stockNames.keys) {
      prices.add(await getPrice(symbol));
    }
    return prices;
  }
}
