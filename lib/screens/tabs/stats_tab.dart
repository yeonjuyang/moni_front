import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/transaction.dart';
import '../../services/user_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/month_selector.dart';

// ── Filter config ─────────────────────────────────────────────────────────────

class _FilterConfig {
  final DateTimeRange? customRange;
  final Set<int> selectedUserIds; // empty = all
  final Set<String> excludedCategories;

  const _FilterConfig({
    this.customRange,
    this.selectedUserIds = const {},
    this.excludedCategories = const {},
  });

  bool get hasActiveFilter =>
      customRange != null ||
      selectedUserIds.isNotEmpty ||
      excludedCategories.isNotEmpty;

  static const _FilterConfig empty = _FilterConfig();
}

// ── StatsTab ──────────────────────────────────────────────────────────────────

class StatsTab extends StatefulWidget {
  final DateTime currentMonth;
  final List<Transaction> transactions;
  final ValueChanged<DateTime> onMonthChanged;

  const StatsTab({
    super.key,
    required this.currentMonth,
    required this.transactions,
    required this.onMonthChanged,
  });

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  TransactionType _selectedType = TransactionType.expense;
  _FilterConfig _filter = _FilterConfig.empty;
  List<UserModel> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await UserService.fetchUsers();
      if (mounted) setState(() => _users = users);
    } catch (_) {}
  }

  List<Transaction> get _baseTransactions {
    var list = widget.transactions;

    final range = _filter.customRange;
    if (range != null) {
      list = list
          .where((t) =>
              !t.date.isBefore(range.start) && !t.date.isAfter(range.end))
          .toList();
    } else {
      list = list
          .where((t) =>
              t.date.year == widget.currentMonth.year &&
              t.date.month == widget.currentMonth.month)
          .toList();
    }

    if (_filter.selectedUserIds.isNotEmpty) {
      list = list
          .where((t) =>
              t.paidByUserId != null &&
              _filter.selectedUserIds.contains(t.paidByUserId))
          .toList();
    }

    if (_filter.excludedCategories.isNotEmpty) {
      list = list
          .where((t) => !_filter.excludedCategories.contains(t.category))
          .toList();
    }

    return list;
  }

  int get _totalIncome => _baseTransactions
      .where((t) => t.type == TransactionType.income)
      .fold(0, (s, t) => s + t.amount);

  int get _totalExpense => _baseTransactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0, (s, t) => s + t.amount);

  Map<String, int> _categoryMap(TransactionType type) {
    final map = <String, int>{};
    for (final t in _baseTransactions.where((t) => t.type == type)) {
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    return Map.fromEntries(
        map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  Future<void> _openFilter() async {
    final result = await showModalBottomSheet<_FilterConfig>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        initial: _filter,
        users: _users,
        currentMonth: widget.currentMonth,
      ),
    );
    if (result != null && mounted) {
      setState(() => _filter = result);
    }
  }

  Widget _buildActiveFilterChips() {
    final chips = <Widget>[];

    if (_filter.customRange != null) {
      final r = _filter.customRange!;
      chips.add(Chip(
        label: Text(
          '${r.start.month}/${r.start.day} ~ ${r.end.month}/${r.end.day}',
          style: const TextStyle(fontSize: 12),
        ),
        deleteIcon: const Icon(Icons.close, size: 14),
        onDeleted: () => setState(() => _filter = _FilterConfig(
              selectedUserIds: _filter.selectedUserIds,
              excludedCategories: _filter.excludedCategories,
            )),
        visualDensity: VisualDensity.compact,
      ));
    }

    for (final userId in _filter.selectedUserIds) {
      final user = _users.where((u) => u.userId == userId).firstOrNull;
      if (user == null) continue;
      chips.add(Chip(
        label: Text(user.nickname, style: const TextStyle(fontSize: 12)),
        deleteIcon: const Icon(Icons.close, size: 14),
        onDeleted: () => setState(() => _filter = _FilterConfig(
              customRange: _filter.customRange,
              selectedUserIds:
                  Set.from(_filter.selectedUserIds)..remove(userId),
              excludedCategories: _filter.excludedCategories,
            )),
        visualDensity: VisualDensity.compact,
      ));
    }

    for (final cat in _filter.excludedCategories) {
      chips.add(Chip(
        label: Text('$cat 제외', style: const TextStyle(fontSize: 12)),
        deleteIcon: const Icon(Icons.close, size: 14),
        onDeleted: () => setState(() => _filter = _FilterConfig(
              customRange: _filter.customRange,
              selectedUserIds: _filter.selectedUserIds,
              excludedCategories:
                  Set.from(_filter.excludedCategories)..remove(cat),
            )),
        visualDensity: VisualDensity.compact,
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(spacing: 6, runSpacing: 4, children: chips),
    );
  }

  String _rangeLabel(DateTimeRange r) =>
      '${r.start.year}.${r.start.month.toString().padLeft(2, '0')}.${r.start.day.toString().padLeft(2, '0')}'
      ' ~ '
      '${r.end.year}.${r.end.month.toString().padLeft(2, '0')}.${r.end.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final catMap = _categoryMap(_selectedType);
    final total =
        _selectedType == TransactionType.expense ? _totalExpense : _totalIncome;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        title: _filter.customRange != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('직접 지정',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.black.withValues(alpha: 0.4))),
                  Text(
                    _rangeLabel(_filter.customRange!),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              )
            : MonthSelector(
                currentMonth: widget.currentMonth,
                onChanged: widget.onMonthChanged),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: '필터',
            icon: Badge(
              isLabelVisible: _filter.hasActiveFilter,
              smallSize: 8,
              child: const Icon(Icons.tune_rounded),
            ),
            onPressed: _openFilter,
          ),
        ],
      ),
      body: _baseTransactions.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bar_chart_outlined,
                      size: 56,
                      color: Colors.black.withValues(alpha: 0.15)),
                  const SizedBox(height: 12),
                  const Text('해당 기간의 내역이 없어요',
                      style: TextStyle(color: Colors.black38, fontSize: 15)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                _SummaryBanner(income: _totalIncome, expense: _totalExpense),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<TransactionType>(
                    segments: const [
                      ButtonSegment(
                          value: TransactionType.expense, label: Text('지출')),
                      ButtonSegment(
                          value: TransactionType.income, label: Text('수입')),
                    ],
                    selected: {_selectedType},
                    onSelectionChanged: (s) =>
                        setState(() => _selectedType = s.first),
                  ),
                ),
                const SizedBox(height: 12),
                _buildActiveFilterChips(),
                if (catMap.isNotEmpty) ...[
                  _DonutChart(catMap: catMap, total: total),
                  const SizedBox(height: 24),
                  _CategorySection(catMap: catMap, total: total),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Column(
                      children: [
                        Icon(Icons.pie_chart_outline,
                            size: 56,
                            color: Colors.black.withValues(alpha: 0.15)),
                        const SizedBox(height: 12),
                        Text(
                          _selectedType == TransactionType.expense
                              ? '지출 내역이 없어요'
                              : '수입 내역이 없어요',
                          style: const TextStyle(
                              color: Colors.black38, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

// ── Filter sheet ──────────────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final _FilterConfig initial;
  final List<UserModel> users;
  final DateTime currentMonth;

  const _FilterSheet({
    required this.initial,
    required this.users,
    required this.currentMonth,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late bool _useCustomRange;
  DateTimeRange? _customRange;
  late Set<int> _selectedUserIds;
  late Set<String> _excludedCategories;

  @override
  void initState() {
    super.initState();
    _useCustomRange = widget.initial.customRange != null;
    _customRange = widget.initial.customRange;
    _selectedUserIds = Set.from(widget.initial.selectedUserIds);
    _excludedCategories = Set.from(widget.initial.excludedCategories);
  }

  Future<void> _pickDateRange() async {
    final m = widget.currentMonth;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: DateTime(m.year, m.month, 1),
            end: DateTime(m.year, m.month + 1, 0),
          ),
    );
    if (picked != null) setState(() => _customRange = picked);
  }

  void _reset() => setState(() {
        _useCustomRange = false;
        _customRange = null;
        _selectedUserIds = {};
        _excludedCategories = {};
      });

  void _apply() => Navigator.pop(
        context,
        _FilterConfig(
          customRange: _useCustomRange ? _customRange : null,
          selectedUserIds: Set.from(_selectedUserIds),
          excludedCategories: Set.from(_excludedCategories),
        ),
      );

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      );

  Widget _subLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(fontSize: 12, color: Colors.black45)),
      );

  Widget _categoryChips(List<String> cats) => Wrap(
        spacing: 8,
        runSpacing: 6,
        children: cats.map((c) {
          final excluded = _excludedCategories.contains(c);
          final color = categoryColors[c] ?? Colors.grey;
          return FilterChip(
            avatar: Icon(
              categoryIcons[c] ?? Icons.circle,
              size: 14,
              color: excluded ? Colors.black38 : color,
            ),
            label: Text(c,
                style: TextStyle(
                  color: excluded ? Colors.black38 : null,
                  decoration:
                      excluded ? TextDecoration.lineThrough : null,
                )),
            selected: excluded,
            selectedColor: Colors.black.withValues(alpha: 0.07),
            checkmarkColor: Colors.black45,
            onSelected: (v) => setState(() {
              if (v) {
                _excludedCategories.add(c);
              } else {
                _excludedCategories.remove(c);
              }
            }),
          );
        }).toList(),
      );

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 핸들
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2)),
          ),
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
            child: Row(
              children: [
                const Text('필터',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton(
                    onPressed: _reset, child: const Text('초기화')),
              ],
            ),
          ),
          const Divider(height: 1),

          // 스크롤 컨텐츠
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 기간 ──────────────────────────────────────
                  _sectionLabel('기간'),
                  Row(
                    children: [
                      Expanded(
                        child: _PeriodOption(
                          label: '월별',
                          selected: !_useCustomRange,
                          onTap: () =>
                              setState(() => _useCustomRange = false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PeriodOption(
                          label: '직접 지정',
                          selected: _useCustomRange,
                          onTap: () async {
                            setState(() => _useCustomRange = true);
                            await _pickDateRange();
                          },
                        ),
                      ),
                    ],
                  ),
                  if (_useCustomRange) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _pickDateRange,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: primary),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.date_range_outlined,
                                size: 16, color: primary),
                            const SizedBox(width: 8),
                            Text(
                              _customRange != null
                                  ? '${_customRange!.start.year}.${_customRange!.start.month.toString().padLeft(2, '0')}.${_customRange!.start.day.toString().padLeft(2, '0')}'
                                    ' ~ '
                                    '${_customRange!.end.year}.${_customRange!.end.month.toString().padLeft(2, '0')}.${_customRange!.end.day.toString().padLeft(2, '0')}'
                                  : '날짜 범위 선택',
                              style:
                                  TextStyle(fontSize: 13, color: primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // ── 사용자 ────────────────────────────────────
                  if (widget.users.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionLabel('사용자'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        FilterChip(
                          label: const Text('전체'),
                          selected: _selectedUserIds.isEmpty,
                          onSelected: (_) =>
                              setState(() => _selectedUserIds.clear()),
                        ),
                        ...widget.users.map((u) => FilterChip(
                              avatar: const Icon(Icons.person_outline,
                                  size: 16),
                              label: Text(u.nickname),
                              selected:
                                  _selectedUserIds.contains(u.userId),
                              onSelected: (v) => setState(() {
                                if (v) {
                                  _selectedUserIds.add(u.userId);
                                } else {
                                  _selectedUserIds.remove(u.userId);
                                  // 모두 해제되면 전체 선택 상태
                                }
                              }),
                            )),
                      ],
                    ),
                  ],

                  // ── 카테고리 제외 ─────────────────────────────
                  const SizedBox(height: 20),
                  _sectionLabel('카테고리 제외'),
                  _subLabel('지출'),
                  _categoryChips(expenseCategories),
                  const SizedBox(height: 12),
                  _subLabel('수입'),
                  _categoryChips(incomeCategories),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // 적용 버튼
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _apply,
                child:
                    const Text('적용', style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? primary.withValues(alpha: 0.08)
              : Colors.transparent,
          border: Border.all(color: selected ? primary : Colors.black12),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? primary : Colors.black54,
          ),
        ),
      ),
    );
  }
}

// ── Donut chart ───────────────────────────────────────────────────────────────

class _DonutChart extends StatelessWidget {
  final Map<String, int> catMap;
  final int total;

  const _DonutChart({required this.catMap, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          SizedBox(
            width: 220,
            height: 220,
            child: CustomPaint(
              painter: _DonutPainter(catMap: catMap, total: total),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('합계',
                        style: TextStyle(
                            fontSize: 12, color: Colors.black38)),
                    const SizedBox(height: 4),
                    Text(
                      '${formatCurrency(total)}원',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: catMap.entries.map((e) {
              final color = categoryColors[e.key] ?? Colors.grey;
              final pct = total > 0
                  ? (e.value / total * 100).toStringAsFixed(1)
                  : '0.0';
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text('${e.key} $pct%',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final Map<String, int> catMap;
  final int total;

  _DonutPainter({required this.catMap, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 44.0;
    const gapAngle = 0.03;

    final rect =
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    double startAngle = -pi / 2;
    for (final entry in catMap.entries) {
      final sweep = (entry.value / total) * 2 * pi - gapAngle;
      if (sweep <= 0) continue;
      paint.color = categoryColors[entry.key] ?? Colors.grey;
      canvas.drawArc(rect, startAngle + gapAngle / 2, sweep, false, paint);
      startAngle += sweep + gapAngle;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.catMap != catMap || old.total != total;
}

// ── Summary banner ────────────────────────────────────────────────────────────

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
            '잔액',
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
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.65))),
                Text(
                  '${formatCurrency(amount)}원',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
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

// ── Category list ─────────────────────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  final Map<String, int> catMap;
  final int total;

  const _CategorySection({required this.catMap, required this.total});

  @override
  Widget build(BuildContext context) {
    final maxAmount = catMap.values.first;
    return Container(
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
    final percent =
        total > 0 ? (amount / total * 100).toStringAsFixed(1) : '0.0';

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
              child: Icon(categoryIcons[category] ?? Icons.circle,
                  color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(category,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${formatCurrency(amount)}원',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                Text('$percent%',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.black38)),
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
