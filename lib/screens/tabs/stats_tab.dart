import 'package:flutter/material.dart';
import '../../models/transaction.dart';
import '../../utils/formatters.dart';
import '../../widgets/month_selector.dart';

class StatsTab extends StatelessWidget {
  final DateTime currentMonth;
  final List<Transaction> transactions;
  final ValueChanged<DateTime> onMonthChanged;

  const StatsTab({
    super.key,
    required this.currentMonth,
    required this.transactions,
    required this.onMonthChanged,
  });

  List<Transaction> get _monthTransactions => transactions
      .where((t) => t.date.year == currentMonth.year && t.date.month == currentMonth.month)
      .toList();

  int get _totalIncome => _monthTransactions
      .where((t) => t.type == TransactionType.income)
      .fold(0, (s, t) => s + t.amount);

  int get _totalExpense => _monthTransactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0, (s, t) => s + t.amount);

  Map<String, int> get _expenseByCategory {
    final map = <String, int>{};
    for (final t in _monthTransactions.where((t) => t.type == TransactionType.expense)) {
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    return Map.fromEntries(map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  @override
  Widget build(BuildContext context) {
    final catMap = _expenseByCategory;
    final maxAmount = catMap.isEmpty ? 1 : catMap.values.first;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        title: MonthSelector(currentMonth: currentMonth, onChanged: onMonthChanged),
        centerTitle: true,
        elevation: 0,
      ),
      body: _monthTransactions.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bar_chart_outlined, size: 56, color: Colors.black.withValues(alpha: 0.15)),
                  const SizedBox(height: 12),
                  const Text('이번 달 내역이 없어요', style: TextStyle(color: Colors.black38, fontSize: 15)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                _SummaryBanner(income: _totalIncome, expense: _totalExpense),
                if (catMap.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _CategorySection(
                    catMap: catMap,
                    total: _totalExpense,
                    maxAmount: maxAmount,
                  ),
                ],
              ],
            ),
    );
  }
}

class _SummaryBanner extends StatelessWidget {
  final int income;
  final int expense;

  const _SummaryBanner({required this.income, required this.expense});

  @override
  Widget build(BuildContext context) {
    final balance = income - expense;
    final isPositive = balance >= 0;

    return Container(
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
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '이번 달 잔액',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.65),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${isPositive ? '+' : '-'}${formatCurrency(balance.abs())}원',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isPositive ? Colors.white : const Color(0xFFFFB3BA),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _BannerItem(
                  icon: Icons.arrow_downward_rounded,
                  label: '수입',
                  amount: income,
                  color: const Color(0xFFA8D8EA),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BannerItem(
                  icon: Icons.arrow_upward_rounded,
                  label: '지출',
                  amount: expense,
                  color: const Color(0xFFFFB3BA),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int amount;
  final Color color;

  const _BannerItem({
    required this.icon,
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
                Text(
                  '${formatCurrency(amount)}원',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final Map<String, int> catMap;
  final int total;
  final int maxAmount;

  const _CategorySection({
    required this.catMap,
    required this.total,
    required this.maxAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            '지출 카테고리',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              for (int i = 0; i < catMap.entries.length; i++) ...[
                _CategoryRow(
                  category: catMap.entries.elementAt(i).key,
                  amount: catMap.entries.elementAt(i).value,
                  total: total,
                  maxAmount: maxAmount,
                ),
                if (i < catMap.length - 1) const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final String category;
  final int amount;
  final int total;
  final int maxAmount;

  const _CategoryRow({
    required this.category,
    required this.amount,
    required this.total,
    required this.maxAmount,
  });

  @override
  Widget build(BuildContext context) {
    final color = categoryColors[category] ?? Colors.grey;
    final ratio = amount / maxAmount;
    final percent = total > 0 ? (amount / total * 100).toStringAsFixed(1) : '0.0';

    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(categoryIcons[category] ?? Icons.circle, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                category,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${formatCurrency(amount)}원',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                Text(
                  '$percent%',
                  style: const TextStyle(fontSize: 11, color: Colors.black38),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
