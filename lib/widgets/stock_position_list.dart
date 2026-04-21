import 'package:flutter/material.dart';
import '../models/stock_position.dart';
import 'package:intl/intl.dart';

class StockPositionList extends StatelessWidget {
  final List<StockPosition> positions;
  final Map<String, double> currentPrices;
  final Function(StockPosition)? onTap;

  const StockPositionList({
    super.key,
    required this.positions,
    required this.currentPrices,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (positions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            children: [
              Icon(Icons.show_chart, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text('目前無持股', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: positions.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final position = positions[index];
        final currentPrice = currentPrices[position.symbol] ?? position.averageCost;
        final gainLoss = (currentPrice - position.averageCost) * position.quantity;
        final gainLossPercent = ((currentPrice - position.averageCost) / position.averageCost) * 100;
        final isGain = gainLoss >= 0;

        return ListTile(
          onTap: onTap != null ? () => onTap!(position) : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    position.symbol,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    position.name,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    NumberFormat.simpleCurrency(decimalDigits: 2).format(currentPrice),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isGain ? Colors.green : Colors.red).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${isGain ? '+' : ''}${gainLossPercent.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: isGain ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('數量: ${position.quantity} 股', style: const TextStyle(fontSize: 13)),
                Text(
                  '市值: ${NumberFormat.simpleCurrency(decimalDigits: 0).format(position.quantity * currentPrice)}',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
