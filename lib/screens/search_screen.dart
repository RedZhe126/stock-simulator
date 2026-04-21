import 'package:flutter/material.dart';
import '../services/mock_data_provider.dart';
import 'stock_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final MockDataProvider _dataProvider = MockDataProvider();
  String _query = '';
  List<Map<String, String>> _allStocks = [
    {'symbol': '2330', 'name': '台積電'},
    {'symbol': '2603', 'name': '長榮'},
    {'symbol': '2454', 'name': '聯發科'},
    {'symbol': '2317', 'name': '鴻海'},
    {'symbol': '2881', 'name': '富邦金'},
    {'symbol': '2882', 'name': '國泰金'},
    {'symbol': '2303', 'name': '聯電'},
  ];

  @override
  Widget build(BuildContext context) {
    final filteredStocks = _allStocks.where((s) {
      return s['symbol']!.contains(_query) || s['name']!.contains(_query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '輸入代碼或名稱...',
            border: InputBorder.none,
          ),
          onChanged: (val) => setState(() => _query = val),
        ),
      ),
      body: ListView.builder(
        itemCount: filteredStocks.length,
        itemBuilder: (context, index) {
          final stock = filteredStocks[index];
          return ListTile(
            leading: const Icon(Icons.show_chart),
            title: Text(stock['symbol']!),
            subtitle: Text(stock['name']!),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StockDetailScreen(
                    symbol: stock['symbol']!,
                    name: stock['name']!,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
