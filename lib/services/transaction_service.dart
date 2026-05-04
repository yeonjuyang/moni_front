import '../models/transaction.dart';
import 'api_client.dart';

class TransactionService {
  static Future<List<Transaction>> fetchTransactions({required int ledgerId}) async {
    final response = await ApiClient.dio.get('/api/ledgers/$ledgerId/transactions');
    return (response.data as List)
        .map((json) => Transaction.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  static Future<Transaction> createTransaction({
    required int ledgerId,
    required Transaction transaction,
    int? fromAssetId,
    int? toAssetId,
  }) async {
    final response = await ApiClient.dio.post(
      '/api/ledgers/$ledgerId/transactions',
      data: _buildBody(transaction, fromAssetId, toAssetId),
    );
    return Transaction.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<Transaction> updateTransaction({
    required int ledgerId,
    required String transactionId,
    required Transaction transaction,
    int? fromAssetId,
    int? toAssetId,
  }) async {
    final response = await ApiClient.dio.put(
      '/api/ledgers/$ledgerId/transactions/$transactionId',
      data: _buildBody(transaction, fromAssetId, toAssetId),
    );
    return Transaction.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<void> deleteTransaction({
    required int ledgerId,
    required String transactionId,
  }) async {
    await ApiClient.dio.delete(
      '/api/ledgers/$ledgerId/transactions/$transactionId',
    );
  }

  static Map<String, dynamic> _buildBody(
      Transaction t, int? fromAssetId, int? toAssetId) {
    return {
      'transactionType': t.type == TransactionType.income ? 'INCOME' : 'EXPENSE',
      'amount': t.amount,
      'memo': t.title,
      'transactionDate':
          '${t.date.year}-'
          '${t.date.month.toString().padLeft(2, '0')}-'
          '${t.date.day.toString().padLeft(2, '0')}',
      'categoryName': t.category,
      'fromAssetId': fromAssetId,
      'toAssetId': toAssetId,
      'paidByUserId': t.paidByUserId,
      'note': t.note,
    };
  }
}
