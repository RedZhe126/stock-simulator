import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/portfolio_provider.dart';
import '../services/mock_data_provider.dart';
import 'stock_detail_screen.dart';

class WatchlistPage extends StatelessWidget {
  const WatchlistPage({super.key});

  @override
  Widget build(BuildContext context) {
    final portfolio = context.watch<PortfolioProvider>();
    final mockProvider = MockDataProvider();

    return Scaffold(
      appBar: AppBar(
        title: const Text('自選股看板', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: portfolio.watchlist.isEmpty
          ? const Center(child: Text('目前無自選股，請從搜尋加入。', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              itemCount: portfolio.watchlist.length,
              itemBuilder: (context, index) {
                final symbol = portfolio.watchlist[index];
                return FutureBuilder<StockPrice>(
                  future: mockProvider.getPrice(symbol),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const ListTile(title: CircularProgressIndicator());
                    
                    final stock = snapshot.data!;
                    final isGain = stock.change >= 0;

                    return ListTile(
                      title: Text(stock.symbol, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(stock.name),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            stock.currentPrice.toStringAsFixed(2),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isGain ? Colors.red : Colors.green,
                            ),
                          ),
                          Text(
                            '${isGain ? '+' : ''}${stock.changePercentage.toStringAsFixed(2)}%',
                            style: TextStyle(
                              color: isGain ? Colors.red : Colors.green,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StockDetailScreen(
                              symbol: stock.symbol,
                              name: stock.name,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
