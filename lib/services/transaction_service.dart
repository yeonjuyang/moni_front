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
      data: {
        'transactionType':
            transaction.type == TransactionType.income ? 'INCOME' : 'EXPENSE',
        'amount': transaction.amount,
        'memo': transaction.title,
        'transactionDate':
            '${transaction.date.year}-'
            '${transaction.date.month.toString().padLeft(2, '0')}-'
            '${transaction.date.day.toString().padLeft(2, '0')}',
        'categoryName': transaction.category,
        'fromAssetId': fromAssetId,
        'toAssetId': toAssetId,
      },
    );
    return Transaction.fromJson(response.data as Map<String, dynamic>);
  }
}
