import 'package:flutter/material.dart';

enum TransactionType { income, expense }

class Transaction {
  final String id;
  final String title;
  final int amount;
  final TransactionType type;
  final DateTime date;
  final String category;

  const Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.date,
    required this.category,
  });
}

const List<String> expenseCategories = ['식비', '카페', '교통', '쇼핑', '구독', '의료', '주거', '기타'];
const List<String> incomeCategories = ['급여', '부업', '용돈', '기타'];

const Map<String, IconData> categoryIcons = {
  '식비': Icons.restaurant_outlined,
  '카페': Icons.coffee_outlined,
  '교통': Icons.directions_bus_outlined,
  '쇼핑': Icons.shopping_bag_outlined,
  '구독': Icons.subscriptions_outlined,
  '의료': Icons.local_hospital_outlined,
  '주거': Icons.home_outlined,
  '기타': Icons.more_horiz,
  '급여': Icons.account_balance_outlined,
  '부업': Icons.work_outline,
  '용돈': Icons.people_outline,
};

const Map<String, Color> categoryColors = {
  '식비': Color(0xFFFF6B6B),
  '카페': Color(0xFFFFB347),
  '교통': Color(0xFF6BCB77),
  '쇼핑': Color(0xFF4D96FF),
  '구독': Color(0xFFAD5CFF),
  '의료': Color(0xFFFF6BAA),
  '주거': Color(0xFF4DC9D6),
  '기타': Color(0xFF9E9E9E),
  '급여': Color(0xFF26A69A),
  '부업': Color(0xFF42A5F5),
  '용돈': Color(0xFFEF5350),
};

final List<Transaction> mockTransactions = [
  Transaction(id: '1', title: '월급', amount: 3000000, type: TransactionType.income, date: DateTime(2026, 4, 1), category: '급여'),
  Transaction(id: '2', title: '스타벅스', amount: 6500, type: TransactionType.expense, date: DateTime(2026, 4, 3), category: '카페'),
  Transaction(id: '3', title: '마트 장보기', amount: 52000, type: TransactionType.expense, date: DateTime(2026, 4, 5), category: '식비'),
  Transaction(id: '4', title: '점심 식사', amount: 12000, type: TransactionType.expense, date: DateTime(2026, 4, 8), category: '식비'),
  Transaction(id: '5', title: '넷플릭스', amount: 17000, type: TransactionType.expense, date: DateTime(2026, 4, 10), category: '구독'),
  Transaction(id: '6', title: '교통카드 충전', amount: 50000, type: TransactionType.expense, date: DateTime(2026, 4, 12), category: '교통'),
  Transaction(id: '7', title: '부업 수입', amount: 300000, type: TransactionType.income, date: DateTime(2026, 4, 15), category: '부업'),
  Transaction(id: '8', title: '저녁 외식', amount: 35000, type: TransactionType.expense, date: DateTime(2026, 4, 18), category: '식비'),
  Transaction(id: '9', title: '온라인 쇼핑', amount: 89000, type: TransactionType.expense, date: DateTime(2026, 4, 20), category: '쇼핑'),
  Transaction(id: '10', title: '카페 라떼', amount: 5500, type: TransactionType.expense, date: DateTime(2026, 4, 22), category: '카페'),
  Transaction(id: '11', title: '약국', amount: 8900, type: TransactionType.expense, date: DateTime(2026, 4, 22), category: '의료'),
];
