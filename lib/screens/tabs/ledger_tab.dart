import 'package:flutter/material.dart';
import '../../models/transaction.dart';
import '../../utils/formatters.dart';
import '../../widgets/month_selector.dart';
import '../add_transaction_sheet.dart';

class LedgerTab extends StatelessWidget {
  final DateTime currentMonth;
  final List<Transaction> transactions;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<Transaction> onAddTransaction;

  const LedgerTab({
    super.key,
    required this.currentMonth,
    required this.transactions,
    required this.onMonthChanged,
    required this.onAddTransaction,
  });

  List<Transaction> get _monthTransactions {
    return transactions
        .where((t) => t.date.year == currentMonth.year && t.date.month == currentMonth.month)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  int get _totalIncome => _monthTransactions
      .where((t) => t.type == TransactionType.income)
      .fold(0, (sum, t) => sum + t.amount);

  int get _totalExpense => _monthTransactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0, (sum, t) => sum + t.amount);

  Map<DateTime, List<Transaction>> get _groupedTransactions {
    final map = <DateTime, List<Transaction>>{};
    for (final t in _monthTransactions) {
      final key = DateTime(t.date.year, t.date.month, t.date.day);
      map.putIfAbsent(key, () => []).add(t);
    }
    return map;
  }

  void _openAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AddTransactionSheet(
        initialDate: DateTime(currentMonth.year, currentMonth.month),
        onSave: onAddTransaction,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedTransactions;
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        title: MonthSelector(currentMonth: currentMonth, onChanged: onMonthChanged),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          _SummaryCard(income: _totalIncome, expense: _totalExpense),
          Expanded(
            child: _monthTransactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 56, color: Colors.black.withValues(alpha: 0.15)),
                        const SizedBox(height: 12),
                        const Text(
                          '이번 달 내역이 없어요',
                          style: TextStyle(color: Colors.black38, fontSize: 15),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: sortedDates.length,
                    itemBuilder: (context, i) {
                      final date = sortedDates[i];
                      return _DateGroup(date: date, transactions: grouped[date]!);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('내역 추가'),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int income;
  final int expense;

  const _SummaryCard({required this.income, required this.expense});

  @override
  Widget build(BuildContext context) {
    final balance = income - expense;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4361EE), Color(0xFF7209B7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4361EE).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryItem(label: '수입', amount: income, isIncome: true),
          ),
          Container(width: 1, height: 44, color: Colors.white.withValues(alpha: 0.25)),
          Expanded(
            child: _SummaryItem(label: '지출', amount: expense, isIncome: false),
          ),
          Container(width: 1, height: 44, color: Colors.white.withValues(alpha: 0.25)),
          Expanded(
            child: _SummaryItem(label: '잔액', amount: balance, isBalance: true),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final int amount;
  final bool isIncome;
  final bool isBalance;

  const _SummaryItem({
    required this.label,
    required this.amount,
    this.isIncome = false,
    this.isBalance = false,
  });

  @override
  Widget build(BuildContext context) {
    Color valueColor = Colors.white;
    if (isBalance && amount < 0) {
      valueColor = const Color(0xFFFFB3BA);
    }

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.65),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${formatCurrency(amount.abs())}원',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _DateGroup extends StatelessWidget {
  final DateTime date;
  final List<Transaction> transactions;

  const _DateGroup({required this.date, required this.transactions});

  @override
  Widget build(BuildContext context) {
    final dayIncome = transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0, (s, t) => s + t.amount);
    final dayExpense = transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0, (s, t) => s + t.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          child: Row(
            children: [
              Text(
                formatDateHeader(date),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black45,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              if (dayIncome > 0)
                Text(
                  '+${formatCurrency(dayIncome)}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF4361EE)),
                ),
              if (dayIncome > 0 && dayExpense > 0) const SizedBox(width: 6),
              if (dayExpense > 0)
                Text(
                  '-${formatCurrency(dayExpense)}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFE17055)),
                ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              for (int i = 0; i < transactions.length; i++) ...[
                _TransactionTile(transaction: transactions[i]),
                if (i < transactions.length - 1)
                  const Divider(height: 1, indent: 64, endIndent: 16),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Transaction transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == TransactionType.expense;
    final color = categoryColors[transaction.category] ?? Colors.grey;
    final icon = categoryIcons[transaction.category] ?? Icons.circle;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  transaction.category,
                  style: const TextStyle(fontSize: 12, color: Colors.black38),
                ),
              ],
            ),
          ),
          Text(
            '${isExpense ? '-' : '+'}${formatCurrency(transaction.amount)}원',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isExpense ? const Color(0xFFE17055) : const Color(0xFF4361EE),
            ),
          ),
        ],
      ),
    );
  }
}
