import 'package:flutter/material.dart';
import '../../models/transaction.dart';
import '../../utils/formatters.dart';
import '../../widgets/month_selector.dart';
import '../add_transaction_sheet.dart';

class LedgerTab extends StatefulWidget {
  final int ledgerId;
  final DateTime currentMonth;
  final List<Transaction> transactions;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<Transaction> onAddTransaction;
  final ValueChanged<Transaction> onUpdateTransaction;
  final ValueChanged<String> onDeleteTransaction;
  final Future<void> Function() onRefresh;

  const LedgerTab({
    super.key,
    required this.ledgerId,
    required this.currentMonth,
    required this.transactions,
    required this.onMonthChanged,
    required this.onAddTransaction,
    required this.onUpdateTransaction,
    required this.onDeleteTransaction,
    required this.onRefresh,
  });

  @override
  State<LedgerTab> createState() => _LedgerTabState();
}

class _LedgerTabState extends State<LedgerTab> {
  DateTime? _selectedDate;

  @override
  void didUpdateWidget(LedgerTab old) {
    super.didUpdateWidget(old);
    if (old.currentMonth != widget.currentMonth) {
      _selectedDate = null;
    }
  }

  List<Transaction> get _monthTransactions {
    return widget.transactions
        .where((t) =>
            t.date.year == widget.currentMonth.year &&
            t.date.month == widget.currentMonth.month)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<Transaction> get _displayedTransactions {
    final d = _selectedDate;
    if (d != null) {
      return _monthTransactions
          .where((t) =>
              t.date.year == d.year &&
              t.date.month == d.month &&
              t.date.day == d.day)
          .toList();
    }
    return [];
  }

  int get _totalIncome => _monthTransactions
      .where((t) => t.type == TransactionType.income)
      .fold(0, (sum, t) => sum + t.amount);

  int get _totalExpense => _monthTransactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0, (sum, t) => sum + t.amount);

  Map<DateTime, List<Transaction>> get _groupedDisplayed {
    final map = <DateTime, List<Transaction>>{};
    for (final t in _displayedTransactions) {
      final key = DateTime(t.date.year, t.date.month, t.date.day);
      map.putIfAbsent(key, () => []).add(t);
    }
    return map;
  }

  void _onMonthChanged(DateTime month) {
    setState(() => _selectedDate = null);
    widget.onMonthChanged(month);
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
        ledgerId: widget.ledgerId,
        initialDate: _selectedDate ??
            DateTime(widget.currentMonth.year, widget.currentMonth.month),
        onSave: widget.onAddTransaction,
      ),
    );
  }

  void _openEditSheet(BuildContext context, Transaction transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AddTransactionSheet(
        ledgerId: widget.ledgerId,
        initialDate: transaction.date,
        editing: transaction,
        onSave: widget.onUpdateTransaction,
        onDelete: () => widget.onDeleteTransaction(transaction.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedDisplayed;
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final displayed = _displayedTransactions;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        title: MonthSelector(
            currentMonth: widget.currentMonth, onChanged: _onMonthChanged),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          _SummaryCard(income: _totalIncome, expense: _totalExpense),
          Expanded(
            child: RefreshIndicator(
              onRefresh: widget.onRefresh,
              child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _CalendarSection(
                    currentMonth: widget.currentMonth,
                    transactions: _monthTransactions,
                    selectedDate: _selectedDate,
                    onDateSelected: (date) =>
                        setState(() => _selectedDate = date),
                  ),
                ),
                if (displayed.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 48,
                              color: Colors.black.withValues(alpha: 0.15)),
                          const SizedBox(height: 12),
                          Text(
                            _selectedDate != null
                                ? '이 날의 내역이 없어요'
                                : '날짜를 선택해주세요',
                            style: const TextStyle(
                                color: Colors.black38, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 96),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final date = sortedDates[i];
                          return _DateGroup(
                            date: date,
                            transactions: grouped[date]!,
                            onEdit: (t) => _openEditSheet(context, t),
                          );
                        },
                        childCount: sortedDates.length,
                      ),
                    ),
                  ),
              ],
            ),
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

// ─── 달력 ──────────────────────────────────────────────────────────────────

class _CalendarSection extends StatelessWidget {
  final DateTime currentMonth;
  final List<Transaction> transactions;
  final DateTime? selectedDate;
  final ValueChanged<DateTime?> onDateSelected;

  const _CalendarSection({
    required this.currentMonth,
    required this.transactions,
    required this.selectedDate,
    required this.onDateSelected,
  });

  /// day → (income, expense)
  Map<int, (int, int)> get _dailyTotals {
    final map = <int, (int, int)>{};
    for (final t in transactions) {
      final d = t.date.day;
      final cur = map[d] ?? (0, 0);
      map[d] = t.type == TransactionType.income
          ? (cur.$1 + t.amount, cur.$2)
          : (cur.$1, cur.$2 + t.amount);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final totals = _dailyTotals;
    final today = DateTime.now();
    final firstDay = DateTime(currentMonth.year, currentMonth.month, 1);
    final daysInMonth =
        DateTime(currentMonth.year, currentMonth.month + 1, 0).day;
    // Sunday=0 … Saturday=6 (Dart weekday: Mon=1…Sun=7)
    final startOffset = firstDay.weekday % 7;
    final rowCount = ((startOffset + daysInMonth) / 7).ceil();

    const headers = ['일', '월', '화', '수', '목', '금', '토'];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
          // 요일 헤더
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: headers.map((h) {
                return Expanded(
                  child: Center(
                    child: Text(
                      h,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: h == '일'
                            ? Colors.red.shade400
                            : h == '토'
                                ? Colors.blue.shade400
                                : Colors.black54,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          // 날짜 행
          ...List.generate(rowCount, (row) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(7, (col) {
                final day = row * 7 + col - startOffset + 1;
                if (day < 1 || day > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 60));
                }
                final date =
                    DateTime(currentMonth.year, currentMonth.month, day);
                final totalsForDay = totals[day];
                final income = totalsForDay?.$1 ?? 0;
                final expense = totalsForDay?.$2 ?? 0;
                final isSelected = selectedDate?.day == day &&
                    selectedDate?.month == currentMonth.month &&
                    selectedDate?.year == currentMonth.year;
                final isToday = today.year == currentMonth.year &&
                    today.month == currentMonth.month &&
                    today.day == day;

                return Expanded(
                  child: _DayCell(
                    day: day,
                    income: income,
                    expense: expense,
                    isSelected: isSelected,
                    isToday: isToday,
                    isSunday: col == 0,
                    isSaturday: col == 6,
                    onTap: () =>
                        onDateSelected(isSelected ? null : date),
                  ),
                );
              }),
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final int income;
  final int expense;
  final bool isSelected;
  final bool isToday;
  final bool isSunday;
  final bool isSaturday;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.income,
    required this.expense,
    required this.isSelected,
    required this.isToday,
    required this.isSunday,
    required this.isSaturday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final Color dayNumColor;
    if (isSelected) {
      dayNumColor = cs.onPrimary;
    } else if (isToday) {
      dayNumColor = cs.primary;
    } else if (isSunday) {
      dayNumColor = Colors.red.shade400;
    } else if (isSaturday) {
      dayNumColor = Colors.blue.shade400;
    } else {
      dayNumColor = Colors.black87;
    }

    final Color expenseColor =
        isSelected ? cs.onPrimary.withValues(alpha: 0.9) : const Color(0xFFE17055);
    final Color incomeColor =
        isSelected ? cs.onPrimary.withValues(alpha: 0.9) : const Color(0xFF4361EE);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: isSelected
            ? BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(8),
              )
            : isToday
                ? BoxDecoration(
                    border: Border.all(color: cs.primary, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 13,
                fontWeight: (isToday || isSelected)
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: dayNumColor,
              ),
            ),
            if (expense > 0) ...[
              const SizedBox(height: 2),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '-${formatCurrency(expense)}',
                    style: TextStyle(fontSize: 9, color: expenseColor),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
            if (income > 0) ...[
              const SizedBox(height: 1),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '+${formatCurrency(income)}',
                    style: TextStyle(fontSize: 9, color: incomeColor),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── 요약 카드 ──────────────────────────────────────────────────────────────

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
          Expanded(child: _SummaryItem(label: '수입', amount: income)),
          Container(width: 1, height: 44, color: Colors.white.withValues(alpha: 0.25)),
          Expanded(child: _SummaryItem(label: '지출', amount: expense)),
          Container(width: 1, height: 44, color: Colors.white.withValues(alpha: 0.25)),
          Expanded(child: _SummaryItem(label: '잔액', amount: balance, showSign: balance < 0)),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final int amount;
  final bool showSign;

  const _SummaryItem({
    required this.label,
    required this.amount,
    this.showSign = false,
  });

  @override
  Widget build(BuildContext context) {
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
            color: showSign ? const Color(0xFFFFB3BA) : Colors.white,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ─── 거래 목록 ──────────────────────────────────────────────────────────────

class _DateGroup extends StatelessWidget {
  final DateTime date;
  final List<Transaction> transactions;
  final ValueChanged<Transaction> onEdit;

  const _DateGroup({
    required this.date,
    required this.transactions,
    required this.onEdit,
  });

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
                Text('+${formatCurrency(dayIncome)}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF4361EE))),
              if (dayIncome > 0 && dayExpense > 0) const SizedBox(width: 6),
              if (dayExpense > 0)
                Text('-${formatCurrency(dayExpense)}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFE17055))),
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
                _TransactionTile(
                  transaction: transactions[i],
                  onTap: () => onEdit(transactions[i]),
                ),
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
  final VoidCallback onTap;

  const _TransactionTile({required this.transaction, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == TransactionType.expense;
    final color = categoryColors[transaction.category] ?? Colors.grey;
    final icon = categoryIcons[transaction.category] ?? Icons.circle;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
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
                  Text(transaction.title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(
                    transaction.paidByUserNickname != null
                        ? '${transaction.category} · ${transaction.paidByUserNickname}'
                        : transaction.category,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black38),
                  ),
                  if (transaction.note != null && transaction.note!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      transaction.note!,
                      style: const TextStyle(fontSize: 12, color: Colors.black45),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Text(
              '${isExpense ? '-' : '+'}${formatCurrency(transaction.amount)}원',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isExpense
                    ? const Color(0xFFE17055)
                    : const Color(0xFF4361EE),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
