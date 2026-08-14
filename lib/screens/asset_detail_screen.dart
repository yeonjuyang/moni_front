import 'package:flutter/material.dart';
import '../models/asset.dart';
import '../models/transaction.dart';
import '../utils/formatters.dart';
import '../widgets/month_selector.dart';

enum _Direction { in_, out }

class AssetDetailScreen extends StatefulWidget {
  final AssetModel asset;
  final List<Transaction> transactions;
  final List<AssetModel> allAssets;

  const AssetDetailScreen({
    super.key,
    required this.asset,
    required this.transactions,
    required this.allAssets,
  });

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
  }

  List<Transaction> get _related {
    final list = widget.transactions
        .where((t) =>
            t.fromAssetId == widget.asset.assetId ||
            t.toAssetId == widget.asset.assetId)
        .toList();
    return list..sort((a, b) => b.date.compareTo(a.date));
  }

  List<Transaction> get _monthRelated => _related
      .where((t) =>
          t.date.year == _currentMonth.year &&
          t.date.month == _currentMonth.month)
      .toList();

  _Direction _directionOf(Transaction t) =>
      t.toAssetId == widget.asset.assetId ? _Direction.in_ : _Direction.out;

  String? _counterpartName(Transaction t) {
    if (t.type != TransactionType.transfer) return null;
    final otherId = t.fromAssetId == widget.asset.assetId
        ? t.toAssetId
        : t.fromAssetId;
    if (otherId == null) return null;
    return widget.allAssets
        .where((a) => a.assetId == otherId)
        .firstOrNull
        ?.assetName;
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    final related = _monthRelated;
    final totalIn = related
        .where((t) => _directionOf(t) == _Direction.in_)
        .fold(0, (s, t) => s + t.amount);
    final totalOut = related
        .where((t) => _directionOf(t) == _Direction.out)
        .fold(0, (s, t) => s + t.amount);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF4361EE).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(asset.icon, color: const Color(0xFF4361EE), size: 16),
            ),
            const SizedBox(width: 8),
            Text(asset.assetName,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _BalanceCard(balance: asset.balance, totalIn: totalIn, totalOut: totalOut),
          const SizedBox(height: 12),
          MonthSelector(
            currentMonth: _currentMonth,
            onChanged: (m) => setState(() => _currentMonth = m),
          ),
          const SizedBox(height: 4),
          if (related.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 48, color: Colors.black.withValues(alpha: 0.15)),
                  const SizedBox(height: 10),
                  const Text('이 달의 입출금 내역이 없어요',
                      style: TextStyle(color: Colors.black38, fontSize: 14)),
                ],
              ),
            )
          else
            ...related.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _AssetTransactionCard(
                    transaction: t,
                    direction: _directionOf(t),
                    counterpartName: _counterpartName(t),
                  ),
                )),
        ],
      ),
    );
  }
}

// ── 잔액 요약 카드 ────────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  final int balance;
  final int totalIn;
  final int totalOut;

  const _BalanceCard({
    required this.balance,
    required this.totalIn,
    required this.totalOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4361EE), Color(0xFF7209B7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4361EE).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('현재 잔액',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  '${formatCurrency(balance)}원',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 32,
            color: Colors.white.withValues(alpha: 0.2),
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SubItem(label: '들어옴', amount: totalIn, color: const Color(0xFFA8D8EA)),
                const SizedBox(height: 6),
                _SubItem(label: '나감', amount: totalOut, color: const Color(0xFFFFB3BA)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubItem extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;

  const _SubItem({required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500)),
        const SizedBox(width: 6),
        Expanded(
          child: Text('${formatCurrency(amount)}원',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

// ── 거래 카드 ─────────────────────────────────────────────────────────────────

class _AssetTransactionCard extends StatelessWidget {
  final Transaction transaction;
  final _Direction direction;
  final String? counterpartName;

  const _AssetTransactionCard({
    required this.transaction,
    required this.direction,
    required this.counterpartName,
  });

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final isIn = direction == _Direction.in_;
    final amountColor = isIn ? const Color(0xFF4361EE) : const Color(0xFFE17055);
    final color = categoryColors[t.category] ?? Colors.grey;
    final icon = categoryIcons[t.category] ?? Icons.circle;

    final String subtitle;
    if (t.type == TransactionType.transfer) {
      final other = counterpartName ?? '알 수 없는 자산';
      subtitle = isIn ? '$other 에서 이체' : '$other 로 이체';
    } else if (t.paidByUserNickname != null) {
      subtitle = '${t.category} · ${t.paidByUserNickname}';
    } else {
      subtitle = t.category;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  t.title.isNotEmpty ? t.title : '(메모 없음)',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatDateHeader(t.date)} · $subtitle',
                  style: const TextStyle(fontSize: 12, color: Colors.black38),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${isIn ? '+' : '-'}${formatCurrency(t.amount)}원',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: amountColor),
          ),
        ],
      ),
    );
  }
}
