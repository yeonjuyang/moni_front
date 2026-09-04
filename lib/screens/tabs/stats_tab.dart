import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/category.dart';
import '../../models/detail_period.dart';
import '../../models/transaction.dart';
import '../../services/category_service.dart';
import '../../services/user_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/month_selector.dart';
import '../../widgets/quick_date_picker.dart';
import '../category_detail_screen.dart';
import '../user_detail_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_radius.dart';
import '../../widgets/pill_toggle.dart';

// ── Filter config ─────────────────────────────────────────────────────────────

enum _PeriodMode { monthly, yearly, custom }

class _FilterConfig {
  final _PeriodMode periodMode;
  final DateTimeRange? customRange; // used only when periodMode == custom
  final Set<int> selectedUserIds;   // empty = all
  final Set<String> excludedCategories;

  const _FilterConfig({
    this.periodMode = _PeriodMode.monthly,
    this.customRange,
    this.selectedUserIds = const {},
    this.excludedCategories = const {},
  });

  bool get hasActiveFilter =>
      periodMode != _PeriodMode.monthly ||
      selectedUserIds.isNotEmpty ||
      excludedCategories.isNotEmpty;

  static const _FilterConfig empty = _FilterConfig();
}

// ── StatsTab ──────────────────────────────────────────────────────────────────

class StatsTab extends StatefulWidget {
  final int ledgerId;
  final DateTime currentMonth;
  final List<Transaction> transactions;
  final ValueChanged<DateTime> onMonthChanged;

  const StatsTab({
    super.key,
    required this.ledgerId,
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
  Map<String, CategoryModel> _categories = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final usersFut = UserService.fetchLedgerMembers(widget.ledgerId);
      final catsFut = CategoryService.fetchCategories(ledgerId: widget.ledgerId);
      final users = await usersFut;
      final cats = await catsFut;
      if (!mounted) return;
      setState(() {
        _users = users;
        _categories = {for (final c in cats) c.categoryName: c};
      });
    } catch (_) {}
  }

  Color _catColor(String cat) =>
      _categories[cat]?.color ?? categoryColors[cat] ?? Colors.grey;

  IconData _catIcon(String cat) =>
      _categories[cat]?.icon ?? categoryIcons[cat] ?? Icons.more_horiz;

  List<Transaction> get _baseTransactions {
    var list = widget.transactions;

    switch (_filter.periodMode) {
      case _PeriodMode.monthly:
        list = list
            .where((t) =>
                t.date.year == widget.currentMonth.year &&
                t.date.month == widget.currentMonth.month)
            .toList();
      case _PeriodMode.yearly:
        list = list
            .where((t) => t.date.year == widget.currentMonth.year)
            .toList();
      case _PeriodMode.custom:
        final range = _filter.customRange;
        if (range != null) {
          list = list
              .where((t) =>
                  !t.date.isBefore(range.start) &&
                  !t.date.isAfter(range.end))
              .toList();
        } else {
          list = list
              .where((t) =>
                  t.date.year == widget.currentMonth.year &&
                  t.date.month == widget.currentMonth.month)
              .toList();
        }
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

  Map<String, int> _userMap(TransactionType type) {
    // 결제자가 없어도 가계부 멤버 전원을 0원으로 먼저 채워서, 지출이 없는 사람도 항상 보이게 한다.
    final map = <String, int>{for (final u in _users) u.nickname: 0};
    for (final t in _baseTransactions.where((t) => t.type == type)) {
      final name = t.paidByUserNickname ?? '알 수 없음';
      map[name] = (map[name] ?? 0) + t.amount;
    }
    return Map.fromEntries(
        map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  Map<String, int> _categoryMap(TransactionType type) {
    // 거래가 없는 카테고리도 0원으로 먼저 채워서, 지출/수입이 없어도 항상 보이게 한다.
    final typeStr = type == TransactionType.expense ? 'EXPENSE' : 'INCOME';
    final orderedCategories = _categories.values
        .where((c) => c.categoryType == typeStr)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final map = <String, int>{for (final c in orderedCategories) c.categoryName: 0};
    for (final t in _baseTransactions.where((t) => t.type == type)) {
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    return Map.fromEntries(
        map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  DetailPeriod get _detailPeriod {
    switch (_filter.periodMode) {
      case _PeriodMode.monthly:
        return DetailPeriod(mode: DetailPeriodMode.monthly, date: widget.currentMonth);
      case _PeriodMode.yearly:
        return DetailPeriod(mode: DetailPeriodMode.yearly, date: widget.currentMonth);
      case _PeriodMode.custom:
        if (_filter.customRange != null) {
          return DetailPeriod(
            mode: DetailPeriodMode.custom,
            date: widget.currentMonth,
            range: _filter.customRange,
          );
        }
        return DetailPeriod(mode: DetailPeriodMode.monthly, date: widget.currentMonth);
    }
  }

  List<Transaction> get _filteredForDetail {
    var list = widget.transactions.where((t) => t.type == _selectedType);
    if (_filter.selectedUserIds.isNotEmpty) {
      list = list.where((t) =>
          t.paidByUserId != null &&
          _filter.selectedUserIds.contains(t.paidByUserId));
    }
    if (_filter.excludedCategories.isNotEmpty) {
      list = list.where((t) => !_filter.excludedCategories.contains(t.category));
    }
    return list.toList();
  }

  void _openCategoryDetail(String category) {
    final transactions =
        _filteredForDetail.where((t) => t.category == category).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryDetailScreen(
          category: category,
          type: _selectedType,
          transactions: transactions,
          period: _detailPeriod,
          categoryColor: _catColor(category),
          categoryIcon: _catIcon(category),
        ),
      ),
    );
  }

  void _openUserDetail(String nickname, Color color) {
    final transactions = _filteredForDetail
        .where((t) => t.paidByUserNickname == nickname)
        .toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserDetailScreen(
          nickname: nickname,
          type: _selectedType,
          transactions: transactions,
          period: _detailPeriod,
          color: color,
        ),
      ),
    );
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
        expenseCategories: widget.transactions
            .where((t) => t.type == TransactionType.expense)
            .map((t) => t.category)
            .toSet()
            .toList()
          ..sort(),
        incomeCategories: widget.transactions
            .where((t) => t.type == TransactionType.income)
            .map((t) => t.category)
            .toSet()
            .toList()
          ..sort(),
      ),
    );
    if (result != null && mounted) {
      setState(() => _filter = result);
    }
  }

  Widget _buildActiveFilterChips() {
    final chips = <Widget>[];

    if (_filter.periodMode == _PeriodMode.yearly) {
      chips.add(Chip(
        label: const Text('연별', style: TextStyle(fontSize: 12)),
        deleteIcon: const Icon(Icons.close, size: 14),
        onDeleted: () => setState(() => _filter = _FilterConfig(
              selectedUserIds: _filter.selectedUserIds,
              excludedCategories: _filter.excludedCategories,
            )),
        visualDensity: VisualDensity.compact,
      ));
    }

    if (_filter.periodMode == _PeriodMode.custom &&
        _filter.customRange != null) {
      chips.add(Chip(
        label: const Text('기간별', style: TextStyle(fontSize: 12)),
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
              periodMode: _filter.periodMode,
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
              periodMode: _filter.periodMode,
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
    final userMap = _userMap(_selectedType);
    final total =
        _selectedType == TransactionType.expense ? _totalExpense : _totalIncome;
    final colorMap = {for (final cat in catMap.keys) cat: _catColor(cat)};
    final iconMap = {for (final cat in catMap.keys) cat: _catIcon(cat)};

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: switch (_filter.periodMode) {
          _PeriodMode.yearly => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => widget.onMonthChanged(
                      DateTime(widget.currentMonth.year - 1, widget.currentMonth.month)),
                ),
                Text('${widget.currentMonth.year}년',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => widget.onMonthChanged(
                      DateTime(widget.currentMonth.year + 1, widget.currentMonth.month)),
                ),
              ],
            ),
          _PeriodMode.custom when _filter.customRange != null => GestureDetector(
              onTap: _openFilter,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _rangeLabel(_filter.customRange!),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit_calendar_outlined,
                      size: 14, color: AppColors.textMuted),
                ],
              ),
            ),
          _ => MonthSelector(
              currentMonth: widget.currentMonth,
              onChanged: widget.onMonthChanged),
        },
        leading: const SizedBox.shrink(),
        leadingWidth: 48,
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
      body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                PillToggle(
                  selectedIndex:
                      _selectedType == TransactionType.expense ? 0 : 1,
                  onSelected: (i) => setState(() => _selectedType =
                      i == 0 ? TransactionType.expense : TransactionType.income),
                  items: [
                    PillToggleItem(
                        label: '지출',
                        amountText: '${formatCurrency(_totalExpense)}원',
                        color: AppColors.expense),
                    PillToggleItem(
                        label: '수입',
                        amountText: '${formatCurrency(_totalIncome)}원',
                        color: AppColors.income),
                  ],
                ),
                const SizedBox(height: 12),
                _buildActiveFilterChips(),
                if (catMap.isNotEmpty) ...[
                  _DonutChart(catMap: catMap, total: total, colorMap: colorMap),
                  const SizedBox(height: 24),
                  _CategorySection(
                    catMap: catMap,
                    total: total,
                    onTapCategory: _openCategoryDetail,
                    colorMap: colorMap,
                    iconMap: iconMap,
                  ),
                  if (userMap.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 10),
                      child: Text(
                        '사용자별 ${_selectedType == TransactionType.expense ? '지출' : '수입'}',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                    _UserSection(
                      userMap: userMap,
                      total: total,
                      onTapUser: (nickname, color) =>
                          _openUserDetail(nickname, color),
                    ),
                  ],
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
                              ? '지출 카테고리가 없어요. 설정에서 먼저 추가해주세요.'
                              : '수입 카테고리가 없어요. 설정에서 먼저 추가해주세요.',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 15),
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
  final List<String> expenseCategories;
  final List<String> incomeCategories;

  const _FilterSheet({
    required this.initial,
    required this.users,
    required this.currentMonth,
    required this.expenseCategories,
    required this.incomeCategories,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late _PeriodMode _periodMode;
  DateTimeRange? _customRange;
  late Set<int> _selectedUserIds;
  late Set<String> _excludedCategories;

  @override
  void initState() {
    super.initState();
    _periodMode = widget.initial.periodMode;
    _customRange = widget.initial.customRange;
    _selectedUserIds = Set.from(widget.initial.selectedUserIds);
    _excludedCategories = Set.from(widget.initial.excludedCategories);
  }

  void _reset() => setState(() {
        _periodMode = _PeriodMode.monthly;
        _customRange = null;
        _selectedUserIds = {};
        _excludedCategories = {};
      });

  void _apply() => Navigator.pop(
        context,
        _FilterConfig(
          periodMode: _periodMode,
          customRange: _periodMode == _PeriodMode.custom ? _customRange : null,
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
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
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
              color: excluded ? AppColors.textMuted : color,
            ),
            label: Text(c,
                style: TextStyle(
                  color: excluded ? AppColors.textMuted : null,
                  decoration:
                      excluded ? TextDecoration.lineThrough : null,
                )),
            selected: excluded,
            selectedColor: Colors.black.withValues(alpha: 0.07),
            checkmarkColor: AppColors.textMuted,
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
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2)),
          ),
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Row(
              children: [
                const Text('필터',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
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
                          selected: _periodMode == _PeriodMode.monthly,
                          onTap: () =>
                              setState(() => _periodMode = _PeriodMode.monthly),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PeriodOption(
                          label: '연별',
                          selected: _periodMode == _PeriodMode.yearly,
                          onTap: () =>
                              setState(() => _periodMode = _PeriodMode.yearly),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PeriodOption(
                          label: '기간 설정',
                          selected: _periodMode == _PeriodMode.custom,
                          onTap: () => setState(() => _periodMode = _PeriodMode.custom),
                        ),
                      ),
                    ],
                  ),
                  if (_periodMode == _PeriodMode.custom) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _DateField(
                            label: '시작일',
                            date: _customRange?.start,
                            onTap: () async {
                              final picked = await showQuickDatePicker(
                                context,
                                initialDate: _customRange?.start ?? DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() {
                                  final end = _customRange?.end;
                                  _customRange = DateTimeRange(
                                    start: picked,
                                    end: (end != null && !end.isBefore(picked))
                                        ? end
                                        : picked,
                                  );
                                });
                              }
                            },
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text('~',
                              style: TextStyle(
                                  fontSize: 16, color: AppColors.textMuted)),
                        ),
                        Expanded(
                          child: _DateField(
                            label: '종료일',
                            date: _customRange?.end,
                            onTap: () async {
                              final picked = await showQuickDatePicker(
                                context,
                                initialDate: _customRange?.end ??
                                    _customRange?.start ??
                                    DateTime.now(),
                                firstDate: _customRange?.start,
                              );
                              if (picked != null) {
                                setState(() {
                                  final start = _customRange?.start ?? picked;
                                  _customRange =
                                      DateTimeRange(start: start, end: picked);
                                });
                              }
                            },
                          ),
                        ),
                      ],
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
                  if (widget.expenseCategories.isNotEmpty || widget.incomeCategories.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionLabel('카테고리 제외'),
                    if (widget.expenseCategories.isNotEmpty) ...[
                      _subLabel('지출'),
                      _categoryChips(widget.expenseCategories),
                    ],
                    if (widget.incomeCategories.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _subLabel('수입'),
                      _categoryChips(widget.incomeCategories),
                    ],
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ),

          // 하단 버튼
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _reset,
                      child: const Text('초기화',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: _apply,
                      child: const Text('적용',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
              ],
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
          border: Border.all(color: selected ? primary : AppColors.divider),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? primary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

// ── Date field ────────────────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final hasDate = date != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: hasDate ? primary : AppColors.divider),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                  fontSize: 10,
                  color: hasDate ? primary : AppColors.textMuted),
            ),
            const SizedBox(height: 3),
            Text(
              hasDate
                  ? '${date!.year}.${date!.month.toString().padLeft(2, '0')}.${date!.day.toString().padLeft(2, '0')}'
                  : '날짜 선택',
              style: TextStyle(
                fontSize: 13,
                fontWeight: hasDate ? FontWeight.w600 : FontWeight.normal,
                color: hasDate ? primary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Donut chart ───────────────────────────────────────────────────────────────

class _DonutChart extends StatelessWidget {
  final Map<String, int> catMap;
  final int total;
  final Map<String, Color> colorMap;

  const _DonutChart({
    required this.catMap,
    required this.total,
    required this.colorMap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.card,
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          SizedBox(
            width: 220,
            height: 220,
            child: CustomPaint(
              painter: _DonutPainter(catMap: catMap, total: total, colorMap: colorMap),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('합계',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
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
              final color = colorMap[e.key] ?? Colors.grey;
              final pct = total > 0
                  ? (e.value / total * 100).round().toString()
                  : '0';
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
                          fontSize: 12, color: AppColors.textMuted)),
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
  final Map<String, Color> colorMap;

  _DonutPainter({required this.catMap, required this.total, required this.colorMap});

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
      paint.color = colorMap[entry.key] ?? Colors.grey;
      canvas.drawArc(rect, startAngle + gapAngle / 2, sweep, false, paint);
      startAngle += sweep + gapAngle;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.catMap != catMap || old.total != total;
}

// ── User stats ────────────────────────────────────────────────────────────────

const _kUserColors = [
  AppColors.primaryDark,
  Color(0xFF7B2CBF),
  Color(0xFF8A6508),
  Color(0xFFB5540E),
  Color(0xFFB0248F),
];

class _UserSection extends StatelessWidget {
  final Map<String, int> userMap;
  final int total;
  final void Function(String nickname, Color color) onTapUser;

  const _UserSection({
    required this.userMap,
    required this.total,
    required this.onTapUser,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < userMap.entries.length; i++)
          _StatRow(
            label: userMap.entries.elementAt(i).key,
            amount: userMap.entries.elementAt(i).value,
            percent: total > 0
                ? (userMap.entries.elementAt(i).value / total * 100)
                    .round()
                    .toString()
                : '0',
            color: _kUserColors[i % _kUserColors.length],
            icon: Icons.person_outline,
            onTap: () => onTapUser(
              userMap.entries.elementAt(i).key,
              _kUserColors[i % _kUserColors.length],
            ),
          ),
      ],
    );
  }
}

// ── Category list ─────────────────────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  final Map<String, int> catMap;
  final int total;
  final ValueChanged<String> onTapCategory;
  final Map<String, Color> colorMap;
  final Map<String, IconData> iconMap;

  const _CategorySection({
    required this.catMap,
    required this.total,
    required this.onTapCategory,
    required this.colorMap,
    required this.iconMap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final entry in catMap.entries)
          _StatRow(
            label: entry.key,
            amount: entry.value,
            percent: total > 0 ? (entry.value / total * 100).round().toString() : '0',
            color: colorMap[entry.key] ?? Colors.grey,
            icon: iconMap[entry.key],
            onTap: () => onTapCategory(entry.key),
          ),
      ],
    );
  }
}

/// 카테고리·사용자 리스트 공통 행: 색상 있는 퍼센트 + (아이콘) + 이름 + 금액.
class _StatRow extends StatelessWidget {
  final String label;
  final int amount;
  final String percent;
  final Color color;
  final IconData? icon;
  final VoidCallback onTap;

  const _StatRow({
    required this.label,
    required this.amount,
    required this.percent,
    required this.color,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('$percent%',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: color)),
                  ),
                ),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: icon != null
                      ? Container(
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Icon(icon, size: 14, color: color),
                        )
                      : Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle),
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                Text('${formatCurrency(amount)}원',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 18, color: AppColors.divider),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
