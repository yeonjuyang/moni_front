import 'dart:math';
import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../utils/formatters.dart';
import '../widgets/month_selector.dart';

class CategoryDetailScreen extends StatefulWidget {
  final String category;
  final TransactionType type;
  final List<Transaction> transactions;
  final DateTime initialMonth;
  final Color categoryColor;
  final IconData categoryIcon;

  const CategoryDetailScreen({
    super.key,
    required this.category,
    required this.type,
    required this.transactions,
    required this.initialMonth,
    required this.categoryColor,
    required this.categoryIcon,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = widget.initialMonth;
  }

  List<Transaction> get _monthTransactions {
    return widget.transactions
        .where((t) =>
            t.date.year == _currentMonth.year &&
            t.date.month == _currentMonth.month)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  // 현재 연도 1-12월 합계
  List<int> get _yearlyTotals {
    return List.generate(12, (i) {
      final month = i + 1;
      return widget.transactions
          .where((t) =>
              t.date.year == _currentMonth.year && t.date.month == month)
          .fold(0, (s, t) => s + t.amount);
    });
  }

  int get _monthTotal => _monthTransactions.fold(0, (s, t) => s + t.amount);

  @override
  Widget build(BuildContext context) {
    final sorted = _monthTransactions;
    final yearlyTotals = _yearlyTotals;
    final hasYearData = yearlyTotals.any((v) => v > 0);
    final isExpense = widget.type == TransactionType.expense;
    final typeColor =
        isExpense ? const Color(0xFFE63946) : const Color(0xFF2A9D8F);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: widget.categoryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(widget.categoryIcon,
                  color: widget.categoryColor, size: 16),
            ),
            const SizedBox(width: 8),
            Text(widget.category,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          MonthSelector(
            currentMonth: _currentMonth,
            onChanged: (m) => setState(() => _currentMonth = m),
          ),
          const SizedBox(height: 12),
          if (hasYearData) ...[
            _LineChartCard(
              yearlyTotals: yearlyTotals,
              highlightedMonth: _currentMonth.month,
              color: widget.categoryColor,
            ),
            const SizedBox(height: 12),
          ],
          _SummaryCard(
            currentMonth: _currentMonth,
            isExpense: isExpense,
            typeColor: typeColor,
            total: _monthTotal,
            count: sorted.length,
          ),
          const SizedBox(height: 12),
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 48,
                      color: Colors.black.withValues(alpha: 0.15)),
                  const SizedBox(height: 10),
                  const Text('이 달의 내역이 없어요',
                      style:
                          TextStyle(color: Colors.black38, fontSize: 14)),
                ],
              ),
            )
          else
            ...sorted.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TransactionCard(
                    transaction: t, typeColor: typeColor),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Line chart ────────────────────────────────────────────────────────────────

class _LineChartCard extends StatelessWidget {
  final List<int> yearlyTotals;
  final int highlightedMonth;
  final Color color;

  const _LineChartCard({
    required this.yearlyTotals,
    required this.highlightedMonth,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: CustomPaint(
        painter: _LineChartPainter(
          values: yearlyTotals,
          highlightedMonth: highlightedMonth,
          color: color,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<int> values;
  final int highlightedMonth;
  final Color color;

  _LineChartPainter({
    required this.values,
    required this.highlightedMonth,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxVal = values.reduce(max);
    if (maxVal == 0) return;

    const labelH = 20.0;
    const topPad = 28.0;
    final chartH = size.height - labelH - topPad;
    final stepX = size.width / 11;

    final pts = List.generate(12, (i) {
      final x = i * stepX;
      final y = topPad + chartH * (1.0 - values[i] / maxVal);
      return Offset(x, y);
    });

    // 채우기 영역
    final fillPath = Path()..moveTo(pts[0].dx, topPad + chartH);
    for (final p in pts) fillPath.lineTo(p.dx, p.dy);
    fillPath.lineTo(pts[11].dx, topPad + chartH);
    fillPath.close();
    canvas.drawPath(fillPath,
        Paint()
          ..color = color.withValues(alpha: 0.08)
          ..style = PaintingStyle.fill);

    // 꺾은선
    final linePath = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < 12; i++) linePath.lineTo(pts[i].dx, pts[i].dy);
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // 점
    for (int i = 0; i < 12; i++) {
      final isHl = i == highlightedMonth - 1;
      if (isHl) {
        canvas.drawCircle(
            pts[i], 8, Paint()..color = color.withValues(alpha: 0.15));
        canvas.drawCircle(pts[i], 4.5, Paint()..color = color);
      } else if (values[i] > 0) {
        canvas.drawCircle(pts[i], 3,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.fill);
        canvas.drawCircle(pts[i], 3,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5);
      }
    }

    // 강조 월 금액 레이블
    final hlPt = pts[highlightedMonth - 1];
    final hlAmount = values[highlightedMonth - 1];
    if (hlAmount > 0) {
      final tp = TextPainter(
        text: TextSpan(
          text: _compact(hlAmount),
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          (hlPt.dx - tp.width / 2).clamp(0.0, size.width - tp.width),
          hlPt.dy - tp.height - 6,
        ),
      );
    }

    // 월 레이블 (1~12)
    for (int i = 0; i < 12; i++) {
      final isHl = i == highlightedMonth - 1;
      final tp = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            fontSize: 10,
            color: isHl ? color : Colors.grey.withValues(alpha: 0.6),
            fontWeight: isHl ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(pts[i].dx - tp.width / 2, size.height - labelH + 2),
      );
    }
  }

  String _compact(int amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(1)}천만';
    } else if (amount >= 10000) {
      return '${(amount / 10000).toStringAsFixed(1)}만';
    }
    return formatCurrency(amount);
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.values != values ||
      old.highlightedMonth != highlightedMonth ||
      old.color != color;
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final DateTime currentMonth;
  final bool isExpense;
  final Color typeColor;
  final int total;
  final int count;

  const _SummaryCard({
    required this.currentMonth,
    required this.isExpense,
    required this.typeColor,
    required this.total,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${currentMonth.month}월 ${isExpense ? '지출' : '수입'}',
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${formatCurrency(total)}원',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: typeColor,
                ),
              ),
              const SizedBox(width: 8),
              Text('총 $count건',
                  style: const TextStyle(
                      fontSize: 13, color: Colors.black38)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Transaction card ──────────────────────────────────────────────────────────

class _TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final Color typeColor;

  const _TransactionCard(
      {required this.transaction, required this.typeColor});

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '${t.date.day}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  '${t.date.month}월',
                  style: const TextStyle(
                      fontSize: 10, color: Colors.black38),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.title.isNotEmpty ? t.title : '(메모 없음)',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                if (t.paidByUserNickname != null)
                  Text(t.paidByUserNickname!,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black38)),
              ],
            ),
          ),
          Text(
            '${formatCurrency(t.amount)}원',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: typeColor),
          ),
        ],
      ),
    );
  }
}
