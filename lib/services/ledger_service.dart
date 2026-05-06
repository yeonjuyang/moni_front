import 'package:shared_preferences/shared_preferences.dart';
import '../models/ledger.dart';
import 'api_client.dart';

class LedgerService {
  static Future<LedgerModel> getLedger(int ledgerId) async {
    final response = await ApiClient.dio.get('/api/ledgers/$ledgerId');
    return LedgerModel.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<LedgerModel> updateLedger({required int ledgerId, required String ledgerName}) async {
    final response = await ApiClient.dio.put('/api/ledgers/$ledgerId', data: {
      'ledgerName': ledgerName,
      'ledgerType': 'PERSONAL',
    });
    return LedgerModel.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<LedgerModel> createLedger({required String ledgerName}) async {
    final response = await ApiClient.dio.post('/api/ledgers', data: {
      'ledgerName': ledgerName,
      'ledgerType': 'PERSONAL',
    });
    return LedgerModel.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<void> saveLastLedgerId(int ledgerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_ledger_id', ledgerId);
  }

  static Future<int?> getLastLedgerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('last_ledger_id');
  }
}
