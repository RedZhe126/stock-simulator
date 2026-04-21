import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/stock_position.dart';
import '../services/mock_data_provider.dart';
import '../services/portfolio_provider.dart';
import '../widgets/order_dialog.dart';

class StockDetailScreen extends StatelessWidget {
  final String symbol;
  final String name;

  const StockDetailScreen({
    super.key,
    required this.symbol,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final mockProvider = MockDataProvider();
    final portfolio = context.watch<PortfolioProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('$symbol $name'),
        actions: [
          IconButton(
            icon: Icon(
              portfolio.isFavorite(symbol) ? Icons.star : Icons.star_border,
              color: portfolio.isFavorite(symbol) ? Colors.yellow : null,
            ),
            onPressed: () => portfolio.toggleFavorite(symbol),
          ),
        ],
      ),
      body: FutureBuilder<StockPrice>(
        future: mockProvider.getPrice(symbol),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final stock = snapshot.data!;
          return SingleChildScrollView(
            child: Column(
              children: [
                _buildPriceHeader(stock),
                _buildChart(stock.kLines),
                _buildFiveLevelQuotes(stock.currentPrice),
                const SizedBox(height: 100), // Padding for FAB
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // In a real app we'd fetch the absolute latest price
          mockProvider.getPrice(symbol).then((stock) {
            showDialog(
              context: context,
              builder: (context) => OrderDialog(
                symbol: symbol,
                name: name,
                currentPrice: stock.currentPrice,
              ),
            );
          });
        },
        label: const Text('下單交易'),
        icon: const Icon(Icons.shopping_cart),
      ),
    );
  }

  Widget _buildPriceHeader(StockPrice stock) {
    final isGain = stock.change >= 0;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Text(
            stock.currentPrice.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: isGain ? Colors.red : Colors.green, // Taiwan: Red is up
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${isGain ? '+' : ''}${stock.change.toStringAsFixed(2)}',
                style: TextStyle(color: isGain ? Colors.red : Colors.green, fontSize: 18),
              ),
              Text(
                '${isGain ? '+' : ''}${stock.changePercentage.toStringAsFixed(2)}%',
                style: TextStyle(color: isGain ? Colors.red : Colors.green, fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChart(List<KLineData> data) {
    return SizedBox(
      height: 300,
      child: SfCartesianChart(
        trackballBehavior: TrackballBehavior(
          enable: true,
          activationMode: ActivationMode.singleTap,
          tooltipSettings: const InteractiveTooltip(enable: true),
        ),
        zoomPanBehavior: ZoomPanBehavior(
          enablePinching: true,
          enablePanning: true,
          zoomMode: ZoomMode.x,
        ),
        primaryXAxis: DateTimeAxis(
          dateFormat: DateFormat('MM/dd'),
          intervalType: DateTimeIntervalType.days,
        ),
        primaryYAxis: NumericAxis(
          opposedPosition: true,
          numberFormat: NumberFormat.simpleCurrency(decimalDigits: 0),
        ),
        series: <CandleSeries<KLineData, DateTime>>[
          CandleSeries<KLineData, DateTime>(
            dataSource: data,
            xValueMapper: (KLineData d, _) => d.time,
            lowValueMapper: (KLineData d, _) => d.low,
            highValueMapper: (KLineData d, _) => d.high,
            openValueMapper: (KLineData d, _) => d.open,
            closeValueMapper: (KLineData d, _) => d.close,
            enableSolidCandles: true,
            bearColor: Colors.green,
            bullColor: Colors.red, // Red is UP
          ),
        ],
      ),
    );
  }

  Widget _buildFiveLevelQuotes(double currentPrice) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('五檔報價', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildQuoteSide('買進', currentPrice, true)),
              const VerticalDivider(),
              Expanded(child: _buildQuoteSide('賣出', currentPrice, false)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteSide(String label, double basePrice, bool isBuy) {
    return Column(
      children: List.generate(5, (i) {
        final price = basePrice + (isBuy ? -(i * 0.5) : (i * 0.5));
        final qty = (50 + i * 10).toString();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(price.toStringAsFixed(2), style: TextStyle(color: isBuy ? Colors.red : Colors.green)),
              Text(qty, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        );
      }),
    );
  }
}
