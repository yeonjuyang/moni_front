import 'package:flutter/material.dart';
import '../models/asset.dart';
import '../models/transaction.dart';
import '../services/asset_service.dart';
import '../utils/formatters.dart';
import '../widgets/calculator_widget.dart';
import '../widgets/quick_date_picker.dart';
import 'add_transaction_sheet.dart';

// ── 필터 모델 ─────────────────────────────────────────────────────────────────

class _Filter {
  final DateTimeRange? dateRange;
  final Set<int> assetIds;
  final Set<String> categories;
  final int? minAmount;
  final int? maxAmount;

  const _Filter({
    this.dateRange,
    this.assetIds = const {},
    this.categories = const {},
    this.minAmount,
    this.maxAmount,
  });

  bool get isActive =>
      dateRange != null ||
      assetIds.isNotEmpty ||
      categories.isNotEmpty ||
      minAmount != null ||
      maxAmount != null;
}

// ── 검색 화면 ─────────────────────────────────────────────────────────────────

class TransactionSearchScreen extends StatefulWidget {
  final int ledgerId;
  final List<Transaction> transactions;
  final ValueChanged<Transaction> onUpdate;
  final ValueChanged<String> onDelete;

  const TransactionSearchScreen({
    super.key,
    required this.ledgerId,
    required this.transactions,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<TransactionSearchScreen> createState() =>
      _TransactionSearchScreenState();
}

class _TransactionSearchScreenState extends State<TransactionSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  _Filter _filter = const _Filter();
  List<AssetModel> _assets = [];

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadAssets() async {
    try {
      final assets =
          await AssetService.fetchAssets(ledgerId: widget.ledgerId);
      if (mounted) setState(() => _assets = assets);
    } catch (_) {}
  }

  List<Transaction> get _results {
    var list = widget.transactions.toList();

    // 필터 적용
    final f = _filter;
    if (f.dateRange != null) {
      list = list
          .where((t) =>
              !t.date.isBefore(f.dateRange!.start) &&
              !t.date.isAfter(f.dateRange!.end))
          .toList();
    }
    if (f.assetIds.isNotEmpty) {
      list = list.where((t) {
        if (t.type == TransactionType.transfer) {
          return (t.fromAssetId != null && f.assetIds.contains(t.fromAssetId)) ||
              (t.toAssetId != null && f.assetIds.contains(t.toAssetId));
        }
        final id = t.type == TransactionType.expense
            ? t.fromAssetId
            : t.toAssetId;
        return id != null && f.assetIds.contains(id);
      }).toList();
    }
    if (f.categories.isNotEmpty) {
      list = list.where((t) => f.categories.contains(t.category)).toList();
    }
    if (f.minAmount != null) {
      list = list.where((t) => t.amount >= f.minAmount!).toList();
    }
    if (f.maxAmount != null) {
      list = list.where((t) => t.amount <= f.maxAmount!).toList();
    }

    // 텍스트 검색 적용
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((t) =>
              t.title.toLowerCase().contains(q) ||
              t.category.toLowerCase().contains(q) ||
              (t.note?.toLowerCase().contains(q) ?? false))
          .toList();
    }

    // 필터도 검색어도 없으면 빈 리스트
    if (!_filter.isActive && q.isEmpty) return [];

    return list..sort((a, b) => b.date.compareTo(a.date));
  }

  void _openEdit(Transaction t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => AddTransactionSheet(
        ledgerId: widget.ledgerId,
        initialDate: t.date,
        editing: t,
        onSave: (updated) {
          widget.onUpdate(updated);
          setState(() {});
        },
        onDelete: () {
          widget.onDelete(t.id);
          setState(() {});
        },
      ),
    );
  }

  void _openFilter() {
    final expenseCats = widget.transactions
        .where((t) => t.type == TransactionType.expense)
        .map((t) => t.category)
        .toSet()
        .toList()
      ..sort();
    final incomeCats = widget.transactions
        .where((t) => t.type == TransactionType.income)
        .map((t) => t.category)
        .toSet()
        .toList()
      ..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        initial: _filter,
        assets: _assets,
        expenseCategories: expenseCats,
        incomeCategories: incomeCats,
        onApply: (f) => setState(() => _filter = f),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final hasInput = _filter.isActive || _query.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '내용, 카테고리, 비고 검색',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.black38, fontSize: 16),
          ),
          style: const TextStyle(fontSize: 16),
          onChanged: (v) => setState(() => _query = v),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, size: 20),
              onPressed: () {
                _controller.clear();
                setState(() => _query = '');
              },
            ),
          IconButton(
            icon: Icon(
              Icons.tune_outlined,
              color: _filter.isActive
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            onPressed: _openFilter,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // 활성 필터 요약 바
          if (_filter.isActive)
            _FilterSummaryBar(
              filter: _filter,
              assets: _assets,
              onClear: () => setState(() => _filter = const _Filter()),
            ),
          Expanded(
            child: !hasInput
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search, size: 48, color: Colors.black12),
                        SizedBox(height: 12),
                        Text('검색어나 필터를 설정해보세요',
                            style: TextStyle(
                                color: Colors.black38, fontSize: 14)),
                      ],
                    ),
                  )
                : results.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 48, color: Colors.black12),
                            SizedBox(height: 12),
                            Text('검색 결과가 없어요',
                                style: TextStyle(
                                    color: Colors.black38, fontSize: 14)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding:
                            const EdgeInsets.fromLTRB(16, 12, 16, 32),
                        itemCount: results.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) => _SearchTile(
                          transaction: results[i],
                          onTap: () => _openEdit(results[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ── 필터 요약 바 ──────────────────────────────────────────────────────────────

class _FilterSummaryBar extends StatelessWidget {
  final _Filter filter;
  final List<AssetModel> assets;
  final VoidCallback onClear;

  const _FilterSummaryBar({
    required this.filter,
    required this.assets,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chips = <String>[];

    if (filter.dateRange != null) {
      final s = filter.dateRange!.start;
      final e = filter.dateRange!.end;
      chips.add('${s.month}/${s.day} ~ ${e.month}/${e.day}');
    }
    if (filter.assetIds.isNotEmpty) {
      final names = assets
          .where((a) => filter.assetIds.contains(a.assetId))
          .map((a) => a.assetName)
          .join(', ');
      chips.add(names.isNotEmpty ? names : '자산 ${filter.assetIds.length}개');
    }
    if (filter.categories.isNotEmpty) {
      chips.add('카테고리 ${filter.categories.length}개');
    }
    if (filter.minAmount != null || filter.maxAmount != null) {
      final min = filter.minAmount != null
          ? '${formatCurrency(filter.minAmount!)}원~'
          : '';
      final max = filter.maxAmount != null
          ? '~${formatCurrency(filter.maxAmount!)}원'
          : '';
      chips.add('$min$max');
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: chips
                    .map((c) => Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(c,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onPrimaryContainer)),
                        ))
                    .toList(),
              ),
            ),
          ),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8)),
            child:
                const Text('초기화', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ── 검색 결과 타일 ────────────────────────────────────────────────────────────

class _SearchTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onTap;

  const _SearchTile({required this.transaction, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final isExpense = t.type == TransactionType.expense;
    final isTransfer = t.type == TransactionType.transfer;
    final color = categoryColors[t.category] ?? Colors.grey;
    final icon = categoryIcons[t.category] ?? Icons.circle;
    final amountColor = isTransfer
        ? Colors.black54
        : isExpense
            ? const Color(0xFFE17055)
            : const Color(0xFF4361EE);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
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
                  Text(t.title.isNotEmpty ? t.title : '(메모 없음)',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${formatDateHeader(t.date)}  ·  ${t.category}',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black38),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isTransfer
                  ? '${formatCurrency(t.amount)}원'
                  : '${isExpense ? '-' : '+'}${formatCurrency(t.amount)}원',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: amountColor),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 필터 시트 ─────────────────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final _Filter initial;
  final List<AssetModel> assets;
  final List<String> expenseCategories;
  final List<String> incomeCategories;
  final ValueChanged<_Filter> onApply;

  const _FilterSheet({
    required this.initial,
    required this.assets,
    required this.expenseCategories,
    required this.incomeCategories,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  DateTimeRange? _dateRange;
  late Set<int> _assetIds;
  late Set<String> _categories;
  int? _minAmount;
  int? _maxAmount;
  int _catTab = 0; // 0=지출, 1=수입

  @override
  void initState() {
    super.initState();
    _dateRange = widget.initial.dateRange;
    _assetIds = Set.from(widget.initial.assetIds);
    _categories = Set.from(widget.initial.categories);
    _minAmount = widget.initial.minAmount;
    _maxAmount = widget.initial.maxAmount;
  }

  void _reset() => setState(() {
        _dateRange = null;
        _assetIds = {};
        _categories = {};
        _minAmount = null;
        _maxAmount = null;
      });

  Future<int?> _pickAmount(int initial) {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AmountPickerSheet(initialValue: initial),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 12),
            child: Row(
              children: [
                const Text('필터',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton(
                    onPressed: _reset,
                    child: const Text('초기화',
                        style: TextStyle(fontSize: 13))),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              children: [
                _section('기간', _buildPeriod()),
                _section('자산', _buildAsset()),
                _section('카테고리', _buildCategory()),
                _section('금액', _buildAmount()),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () {
                        widget.onApply(_Filter(
                          dateRange: _dateRange,
                          assetIds: Set.from(_assetIds),
                          categories: Set.from(_categories),
                          minAmount: _minAmount,
                          maxAmount: _maxAmount,
                        ));
                        Navigator.pop(context);
                      },
                      style: FilledButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('확인',
                          style: TextStyle(fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, Widget content) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            content,
          ],
        ),
      );

  Widget _buildPeriod() => Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: '시작일',
                  date: _dateRange?.start,
                  onTap: () async {
                    final p = await showQuickDatePicker(context,
                        initialDate:
                            _dateRange?.start ?? DateTime.now());
                    if (p != null) {
                      setState(() {
                        final end = _dateRange?.end;
                        _dateRange = DateTimeRange(
                          start: p,
                          end: (end != null && !end.isBefore(p)) ? end : p,
                        );
                      });
                    }
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('~',
                    style:
                        TextStyle(fontSize: 16, color: Colors.black38)),
              ),
              Expanded(
                child: _DateField(
                  label: '종료일',
                  date: _dateRange?.end,
                  onTap: () async {
                    final p = await showQuickDatePicker(
                      context,
                      initialDate: _dateRange?.end ??
                          _dateRange?.start ??
                          DateTime.now(),
                      firstDate: _dateRange?.start,
                    );
                    if (p != null) {
                      setState(() {
                        final start = _dateRange?.start ?? p;
                        _dateRange = DateTimeRange(start: start, end: p);
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          if (_dateRange != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _dateRange = null),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4)),
                child: const Text('기간 초기화',
                    style:
                        TextStyle(fontSize: 12, color: Colors.black45)),
              ),
            ),
        ],
      );

  Widget _buildAsset() {
    if (widget.assets.isEmpty) {
      return const Text('자산이 없어요',
          style: TextStyle(fontSize: 13, color: Colors.black38));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: widget.assets.map((a) {
        final sel = _assetIds.contains(a.assetId);
        return FilterChip(
          avatar: Icon(a.icon, size: 14),
          label: Text(a.assetName),
          selected: sel,
          onSelected: (v) => setState(() =>
              v ? _assetIds.add(a.assetId) : _assetIds.remove(a.assetId)),
        );
      }).toList(),
    );
  }

  Widget _buildCategory() {
    final cats =
        _catTab == 0 ? widget.expenseCategories : widget.incomeCategories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(3),
          child: Row(
            children: [
              _CatTab(
                  label: '지출',
                  selected: _catTab == 0,
                  onTap: () => setState(() => _catTab = 0)),
              _CatTab(
                  label: '수입',
                  selected: _catTab == 1,
                  onTap: () => setState(() => _catTab = 1)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (cats.isEmpty)
          Text('거래 내역이 없어요',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.black.withValues(alpha: 0.35)))
        else
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: cats.map((cat) {
              final sel = _categories.contains(cat);
              return FilterChip(
                label: Text(cat),
                selected: sel,
                onSelected: (v) => setState(() =>
                    v ? _categories.add(cat) : _categories.remove(cat)),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildAmount() => Row(
        children: [
          Expanded(
            child: _AmountField(
              label: '최솟값',
              amount: _minAmount,
              onTap: () async {
                final v = await _pickAmount(_minAmount ?? 0);
                if (v != null)
                  setState(() => _minAmount = v > 0 ? v : null);
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text('~',
                style:
                    TextStyle(fontSize: 16, color: Colors.black38)),
          ),
          Expanded(
            child: _AmountField(
              label: '최댓값',
              amount: _maxAmount,
              onTap: () async {
                final v = await _pickAmount(_maxAmount ?? 0);
                if (v != null)
                  setState(() => _maxAmount = v > 0 ? v : null);
              },
            ),
          ),
        ],
      );
}

// ── 보조 위젯 ─────────────────────────────────────────────────────────────────

class _CatTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CatTab(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4)
                  ]
                : null,
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? Colors.black87 : Colors.black45,
                )),
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DateField(
      {required this.label, this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: Colors.black38)),
            const SizedBox(height: 3),
            Text(
              date != null
                  ? '${date!.year}.${date!.month.toString().padLeft(2, '0')}.${date!.day.toString().padLeft(2, '0')}'
                  : '선택',
              style: TextStyle(
                  fontSize: 13,
                  color:
                      date != null ? Colors.black87 : Colors.black38),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  final String label;
  final int? amount;
  final VoidCallback onTap;

  const _AmountField(
      {required this.label, this.amount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: Colors.black38)),
            const SizedBox(height: 3),
            Text(
              amount != null ? '${formatCurrency(amount!)}원' : '미설정',
              style: TextStyle(
                  fontSize: 13,
                  color: amount != null
                      ? Colors.black87
                      : Colors.black38),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountPickerSheet extends StatelessWidget {
  final int initialValue;

  const _AmountPickerSheet({required this.initialValue});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text('금액 입력',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: CalculatorWidget(
              initialValue: initialValue,
              onConfirm: (v) => Navigator.pop(context, v),
            ),
          ),
        ],
      ),
    );
  }
}
