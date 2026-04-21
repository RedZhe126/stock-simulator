import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/gsheet_sync_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Box _settingsBox = Hive.box('settings');
  final TextEditingController _jsonController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  bool _isValidating = false;

  @override
  void initState() {
    super.initState();
    _jsonController.text = _settingsBox.get('gsheet_json') ?? '';
    _idController.text = _settingsBox.get('spreadsheet_id') ?? '';
  }

  bool _isValidJson(String source) {
    try {
      final data = jsonDecode(source);
      return data is Map && data.containsKey('private_key') && data.containsKey('client_email');
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('系統設定', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader('Google Sheets 雲端同步'),
            const Text(
              '為了確保部署至 GitHub Pages 的安全性，請在此貼入憑證，這份資料僅會儲存在您的瀏覽器中。',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _jsonController,
              maxLines: 8,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: 'Service Account JSON',
                alignLabelWithHint: true,
                hintText: '貼入完整的 JSON 內容...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _idController,
              decoration: InputDecoration(
                labelText: 'Spreadsheet ID',
                hintText: '從網址中複製的 ID...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isValidating ? null : _saveAndTest,
                icon: _isValidating 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
                label: Text(_isValidating ? '正在驗證...' : '儲存並測試連線'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _clearSettings,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('清除所有設定', style: TextStyle(color: Colors.red)),
              ),
            ),
            const SizedBox(height: 60),
            const Divider(),
            const Center(
              child: Column(
                children: [
                  Text('FVSS - Flutter Virtual Stock Simulator', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text('Version 1.1.0 (Web Secure Edition)', style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _saveAndTest() async {
    final jsonStr = _jsonController.text.trim();
    final ssId = _idController.text.trim();

    if (jsonStr.isEmpty || ssId.isEmpty) {
      _showError('兩項欄位皆為必填');
      return;
    }

    if (!_isValidJson(jsonStr)) {
      _showError('JSON 格式錯誤或缺少必要的憑證欄位');
      return;
    }

    setState(() => _isValidating = true);

    await _settingsBox.put('gsheet_json', jsonStr);
    await _settingsBox.put('spreadsheet_id', ssId);

    final syncService = GSheetSyncService();
    final success = await syncService.initialize();

    setState(() => _isValidating = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '連線測試成功！資產已同步。' : '儲存成功但連線測試失敗，請檢查權限設定。'),
          backgroundColor: success ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  void _clearSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確定清除？'),
        content: const Text('這將刪除本地儲存的所有雲端憑證與 ID。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              await _settingsBox.clear();
              _jsonController.clear();
              _idController.clear();
              if (mounted) {
                Navigator.pop(context);
                _showError('設定已清除');
              }
            },
            child: const Text('清除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
