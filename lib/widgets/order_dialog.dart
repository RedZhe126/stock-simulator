import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/portfolio_provider.dart';
import '../services/trade_service.dart';

class OrderDialog extends StatefulWidget {
  final String symbol;
  final String name;
  final double currentPrice;

  const OrderDialog({
    super.key,
    required this.symbol,
    required this.name,
    required this.currentPrice,
  });

  @override
  State<OrderDialog> createState() => _OrderDialogState();
}

class _OrderDialogState extends State<OrderDialog> {
  bool isBuy = true;
  final TextEditingController _quantityController = TextEditingController(text: '1000');
  final TradeService _tradeService = TradeService();

  @override
  Widget build(BuildContext context) {
    int quantity = int.tryParse(_quantityController.text) ?? 0;
    double commission = _tradeService.calculateCommission(widget.currentPrice, quantity);
    double tax = isBuy ? 0 : _tradeService.calculateTax(widget.currentPrice, quantity);
    double total = (widget.currentPrice * quantity) + (isBuy ? commission : -(commission + tax));

    return AlertDialog(
      title: Text('${isBuy ? '買入' : '賣出'} ${widget.symbol} - ${widget.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('買入'), icon: Icon(Icons.add_shopping_cart)),
                ButtonSegment(value: false, label: Text('賣出'), icon: Icon(Icons.sell)),
              ],
              selected: {isBuy},
              onSelectionChanged: (val) => setState(() => isBuy = val.first),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: '委託數量 (股)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('預估單價', NumberFormat.simpleCurrency().format(widget.currentPrice)),
            _buildInfoRow('預估手續費', NumberFormat.simpleCurrency().format(commission)),
            if (!isBuy) _buildInfoRow('預估證交稅', NumberFormat.simpleCurrency().format(tax)),
            const Divider(),
            _buildInfoRow(
              isBuy ? '預計支付' : '預計應收',
              NumberFormat.simpleCurrency().format(total),
              isBold: true,
              color: isBuy ? Colors.blue : Colors.green,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        ElevatedButton(
          onPressed: quantity > 0 ? () async {
            final provider = context.read<PortfolioProvider>();
            try {
              if (isBuy) {
                await provider.executeBuy(widget.symbol, widget.name, widget.currentPrice, quantity);
              } else {
                await provider.executeSell(widget.symbol, widget.currentPrice, quantity);
              }
              if (mounted) Navigator.pop(context);
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            }
          } : null,
          child: const Text('確認委託'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 18 : 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
