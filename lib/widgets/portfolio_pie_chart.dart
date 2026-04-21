import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/stock_position.dart';

class PortfolioPieChart extends StatelessWidget {
  final double cash;
  final List<StockPosition> positions;
  final Map<String, double> currentPrices;

  const PortfolioPieChart({
    super.key,
    required this.cash,
    required this.positions,
    required this.currentPrices,
  });

  @override
  Widget build(BuildContext context) {
    double totalValue = cash;
    for (var p in positions) {
      totalValue += p.quantity * (currentPrices[p.symbol] ?? p.averageCost);
    }

    if (totalValue == 0) return const SizedBox.shrink();

    final List<PieChartSectionData> sections = [];
    
    // Cash section
    sections.add(PieChartSectionData(
      color: Colors.blueGrey,
      value: cash,
      title: '現金',
      radius: 50,
      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
    ));

    // Stock sections
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red];
    for (int i = 0; i < positions.length; i++) {
      final p = positions[i];
      final val = p.quantity * (currentPrices[p.symbol] ?? p.averageCost);
      sections.add(PieChartSectionData(
        color: colors[i % colors.length],
        value: val,
        title: p.symbol,
        radius: 50,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }

    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sections: sections,
          sectionsSpace: 2,
          centerSpaceRadius: 40,
        ),
      ),
    );
  }
}
