import 'package:flutter/material.dart';
import '../models/asset.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../services/asset_service.dart';
import '../services/category_service.dart';
import '../services/transaction_service.dart';
import '../services/user_service.dart';
import '../utils/api_error.dart';
import '../utils/formatters.dart';
import '../widgets/calculator_widget.dart';
import '../widgets/quick_date_picker.dart';
import '../widgets/selectable_icon_tile.dart';
import '../widgets/pill_toggle.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

class AddTransactionSheet extends StatefulWidget {
  final int ledgerId;
  final DateTime initialDate;
  final ValueChanged<Transaction> onSave;
  final Transaction? editing;
  final VoidCallback? onDelete;
  final List<Transaction> transactions;

  const AddTransactionSheet({
    super.key,
    required this.ledgerId,
    required this.initialDate,
    required this.onSave,
    this.editing,
    this.onDelete,
    this.transactions = const [],
  });

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  late TransactionType _type;
  final _titleController = TextEditingController();
  late int _amount;
  bool _showCalculator = false;
  bool _isSaving = false;
  String _selectedCategory = '';
  late DateTime _selectedDate;

  List<AssetModel> _assets = [];
  int? _selectedAssetId;
  int? _selectedToAssetId;
  bool _isLoadingAssets = true;

  List<UserModel> _users = [];
  int? _selectedUserId;
  bool _isLoadingUsers = true;
  final _noteController = TextEditingController();

  List<CategoryModel> _expenseCategories = [];
  List<CategoryModel> _incomeCategories = [];
  bool _isLoadingCategories = true;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _type = e.type;
      _amount = e.amount;
      _selectedDate = e.date;
      _titleController.text = e.title;
      _selectedCategory = e.category;
      _selectedUserId = e.paidByUserId;
      _noteController.text = e.note ?? '';
    } else {
      _type = TransactionType.expense;
      _amount = 0;
      _selectedDate = widget.initialDate;
    }
    _loadAssets();
    _loadUsers();
    _loadCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadAssets() async {
    try {
      final assets = await AssetService.fetchAssets(ledgerId: widget.ledgerId);
      if (mounted) {
        setState(() {
          _assets = assets;
          if (_isEditing) {
            final e = widget.editing!;
            if (e.type == TransactionType.transfer) {
              _selectedAssetId = e.fromAssetId ?? (assets.isNotEmpty ? assets.first.assetId : null);
              _selectedToAssetId = e.toAssetId ??
                  (assets.length > 1 ? assets[1].assetId : null);
            } else {
              final originalId = e.type == TransactionType.expense
                  ? e.fromAssetId
                  : e.toAssetId;
              _selectedAssetId = originalId ?? (assets.isNotEmpty ? assets.first.assetId : null);
            }
          } else {
            if (assets.isNotEmpty) _selectedAssetId = assets.first.assetId;
            if (assets.length > 1) _selectedToAssetId = assets[1].assetId;
          }
          _isLoadingAssets = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingAssets = false);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await CategoryService.fetchCategories(ledgerId: widget.ledgerId);
      if (mounted) {
        setState(() {
          _expenseCategories = cats.where((c) => c.categoryType == 'EXPENSE').toList();
          _incomeCategories = cats.where((c) => c.categoryType == 'INCOME').toList();
          _isLoadingCategories = false;
          if (!_isEditing && _selectedCategory.isEmpty) {
            final defaults = _type == TransactionType.expense ? _expenseCategories : _incomeCategories;
            if (defaults.isNotEmpty) _selectedCategory = defaults.first.categoryName;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _loadUsers() async {
    try {
      final users = await UserService.fetchLedgerMembers(widget.ledgerId);
      if (mounted) {
        setState(() {
          _users = users;
          // 수정 모드: 이미 _selectedUserId 세팅됨
          // 등록 모드: 첫 번째 사용자 자동 선택
          if (!_isEditing && users.isNotEmpty) {
            _selectedUserId = users.first.userId;
          }
          _isLoadingUsers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  List<CategoryModel> get _categories {
    if (_type == TransactionType.transfer) return [];
    return _type == TransactionType.expense ? _expenseCategories : _incomeCategories;
  }

  List<String> get _titleSuggestions {
    final q = _titleController.text.trim().toLowerCase();
    if (q.isEmpty) return [];

    final freq = <String, int>{};
    for (final t in widget.transactions) {
      if (t.type != _type || t.title.isEmpty) continue;
      freq[t.title] = (freq[t.title] ?? 0) + 1;
    }

    final matches = freq.entries
        .where((e) => e.key.toLowerCase().startsWith(q) && e.key.toLowerCase() != q)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return matches.take(5).map((e) => e.key).toList();
  }

  void _applyTitleSuggestion(String suggestion) {
    _titleController.text = suggestion;
    _titleController.selection =
        TextSelection.collapsed(offset: suggestion.length);
    setState(() {});
  }

  int? get _computedFromAssetId => switch (_type) {
        TransactionType.expense || TransactionType.transfer => _selectedAssetId,
        TransactionType.income => null,
      };

  int? get _computedToAssetId => switch (_type) {
        TransactionType.income => _selectedAssetId,
        TransactionType.transfer => _selectedToAssetId,
        TransactionType.expense => null,
      };

  void _onTypeChanged(TransactionType type) {
    setState(() {
      _type = type;
      if (type == TransactionType.transfer) {
        _selectedCategory = '';
        if (_selectedToAssetId == null || _selectedToAssetId == _selectedAssetId) {
          _selectedToAssetId = _assets
              .where((a) => a.assetId != _selectedAssetId)
              .map((a) => a.assetId)
              .firstOrNull;
        }
      } else {
        final cats = type == TransactionType.expense ? _expenseCategories : _incomeCategories;
        _selectedCategory = cats.isNotEmpty ? cats.first.categoryName : '';
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showQuickDatePicker(
      context,
      initialDate: _selectedDate,
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _resetForm() {
    _titleController.clear();
    _noteController.clear();
    setState(() {
      _amount = 0;
      _showCalculator = false;
    });
  }

  Future<void> _saveAndContinue() async {
    if (!_validateBasicFields()) return;
    if (!_validateAssets()) return;
    final title = _titleController.text.trim();

    setState(() => _isSaving = true);

    try {
      final selectedUser = _users.where((u) => u.userId == _selectedUserId).firstOrNull;
      final draft = Transaction(
        id: '',
        title: title,
        amount: _amount,
        type: _type,
        date: _selectedDate,
        category: _type == TransactionType.transfer ? '이체' : _selectedCategory,
        paidByUserId: _selectedUserId,
        paidByUserNickname: selectedUser?.nickname,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );

      final saved = await TransactionService.createTransaction(
        ledgerId: widget.ledgerId,
        transaction: draft,
        fromAssetId: _computedFromAssetId,
        toAssetId: _computedToAssetId,
      );

      widget.onSave(saved);
      if (mounted) {
        setState(() => _isSaving = false);
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('저장 실패: ${friendlyError(e)}')));
        setState(() => _isSaving = false);
      }
    }
  }

  bool _validateBasicFields() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내용을 입력해주세요')),
      );
      return false;
    }
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('금액을 입력해주세요')),
      );
      return false;
    }
    return true;
  }

  bool _validateAssets() {
    if (_type == TransactionType.transfer) {
      if (_selectedAssetId == null || _selectedToAssetId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('출금 자산과 입금 자산을 선택해주세요')),
        );
        return false;
      }
      if (_selectedAssetId == _selectedToAssetId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('출금 자산과 입금 자산은 달라야 해요')),
        );
        return false;
      }
      return true;
    }

    if (_assets.isNotEmpty && _selectedAssetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('자산을 선택해주세요')),
      );
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (!_validateBasicFields()) return;
    if (!_validateAssets()) return;
    final title = _titleController.text.trim();

    setState(() => _isSaving = true);

    try {
      final selectedUser = _users.where((u) => u.userId == _selectedUserId).firstOrNull;
      final draft = Transaction(
        id: widget.editing?.id ?? '',
        title: title,
        amount: _amount,
        type: _type,
        date: _selectedDate,
        category: _type == TransactionType.transfer ? '이체' : _selectedCategory,
        paidByUserId: _selectedUserId,
        paidByUserNickname: selectedUser?.nickname,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      final Transaction saved;
      if (_isEditing) {
        saved = await TransactionService.updateTransaction(
          ledgerId: widget.ledgerId,
          transactionId: widget.editing!.id,
          transaction: draft,
          fromAssetId: _computedFromAssetId,
          toAssetId: _computedToAssetId,
        );
      } else {
        saved = await TransactionService.createTransaction(
          ledgerId: widget.ledgerId,
          transaction: draft,
          fromAssetId: _computedFromAssetId,
          toAssetId: _computedToAssetId,
        );
      }

      widget.onSave(saved);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('저장 실패: ${friendlyError(e)}')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('거래 삭제'),
        content: const Text('이 거래 내역을 삭제하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await TransactionService.deleteTransaction(
        ledgerId: widget.ledgerId,
        transactionId: widget.editing!.id,
      );
      widget.onDelete?.call();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('삭제 실패: ${friendlyError(e)}')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showCalculator) {
      return _buildCalculatorView(context);
    }
    return _buildFormView(context);
  }

  Widget _buildCalculatorView(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () => setState(() => _showCalculator = false),
                ),
                const Text('금액 입력',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: CalculatorWidget(
              initialValue: _amount,
              onConfirm: (value) {
                if (mounted) {
                  setState(() {
                    _amount = value;
                    _showCalculator = false;
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormView(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),

            if (_isEditing)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('거래 수정',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: _isSaving ? null : _delete,
                  ),
                ],
              ),

            // 수입/지출 토글
            PillToggle(
              selectedIndex: switch (_type) {
                TransactionType.expense => 0,
                TransactionType.income => 1,
                TransactionType.transfer => 2,
              },
              onSelected: (i) => _onTypeChanged(switch (i) {
                0 => TransactionType.expense,
                1 => TransactionType.income,
                _ => TransactionType.transfer,
              }),
              items: const [
                PillToggleItem(label: '지출', color: AppColors.expense),
                PillToggleItem(label: '수입', color: AppColors.income),
                PillToggleItem(label: '이체', color: AppColors.primaryDark),
              ],
            ),
            const SizedBox(height: 16),

            // 날짜
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 18, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    Text(formatDateHeader(_selectedDate),
                        style: const TextStyle(fontSize: 15)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 금액
            InkWell(
              onTap: () => setState(() => _showCalculator = true),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calculate_outlined,
                        size: 18, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _amount > 0 ? '${formatCurrency(_amount)}원' : '금액',
                        style: TextStyle(
                            fontSize: 15,
                            color: _amount > 0 ? null : AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 내용
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '내용',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
            ),
            if (_titleSuggestions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _titleSuggestions.map((s) {
                    return ActionChip(
                      avatar: const Icon(Icons.history, size: 14),
                      label: Text(s, style: const TextStyle(fontSize: 13)),
                      onPressed: () => _applyTitleSuggestion(s),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 12),

            // 비고 (선택)
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '비고 (선택)',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),

            // 자산
            _buildAssetSection(),
            const SizedBox(height: 16),

            // 카테고리 (이체는 카테고리 없음)
            if (_type != TransactionType.transfer) ...[
              const Text('카테고리',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
              const SizedBox(height: 8),
              if (_isLoadingCategories)
                const SizedBox(
                  height: 36,
                  child: Row(children: [
                    SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('카테고리 불러오는 중...', style: TextStyle(color: AppColors.textMuted)),
                  ]),
                )
              else if (_categories.isEmpty)
                const Text('카테고리가 없어요. 설정에서 먼저 추가해주세요.',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((c) {
                    final isSelected = _selectedCategory == c.categoryName;
                    return SelectableIconTile(
                      icon: c.icon,
                      color: c.color,
                      label: c.categoryName,
                      selected: isSelected,
                      onTap: () =>
                          setState(() => _selectedCategory = c.categoryName),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),
            ],

            // 사람
            _buildPersonSection(),
            const SizedBox(height: 20),

            // 저장 / 계속
            if (_isEditing)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('수정', style: TextStyle(fontSize: 16)),
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _isSaving ? null : _save,
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('저장',
                                style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 52,
                      child: FilledButton.tonal(
                        onPressed: _isSaving ? null : _saveAndContinue,
                        child: const Text('계속',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetSection() {
    if (_isLoadingAssets) {
      return const SizedBox(
        height: 36,
        child: Row(children: [
          SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 8),
          Text('자산 불러오는 중...', style: TextStyle(color: AppColors.textMuted)),
        ]),
      );
    }

    if (_assets.isEmpty) {
      final label = _type == TransactionType.income ? '입금 자산' : '출금 자산';
      return Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text('$label: 자산을 먼저 등록해주세요',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ],
      );
    }

    if (_type == TransactionType.transfer) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _assetPicker(
            label: '출금 자산',
            selectedId: _selectedAssetId,
            onSelected: (id) => setState(() => _selectedAssetId = id),
          ),
          const SizedBox(height: 14),
          _assetPicker(
            label: '입금 자산',
            selectedId: _selectedToAssetId,
            onSelected: (id) => setState(() => _selectedToAssetId = id),
          ),
        ],
      );
    }

    final label = _type == TransactionType.expense ? '출금 자산' : '입금 자산';
    return _assetPicker(
      label: label,
      selectedId: _selectedAssetId,
      onSelected: (id) => setState(() => _selectedAssetId = id),
    );
  }

  Widget _assetPicker({
    required String label,
    required int? selectedId,
    required ValueChanged<int?> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _assets.map((asset) {
            return SelectableIconTile(
              icon: asset.icon,
              color: AppColors.primaryDark,
              label: asset.assetName,
              selected: selectedId == asset.assetId,
              onTap: () => onSelected(asset.assetId),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPersonSection() {
    if (_isLoadingUsers) {
      return const SizedBox(
        height: 36,
        child: Row(children: [
          SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 8),
          Text('사용자 불러오는 중...', style: TextStyle(color: AppColors.textMuted)),
        ]),
      );
    }

    if (_users.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('사람',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _users.map((user) {
            return ChoiceChip(
              avatar: const Icon(Icons.person_outline, size: 16),
              label: Text(user.nickname),
              selected: _selectedUserId == user.userId,
              onSelected: (_) =>
                  setState(() => _selectedUserId = user.userId),
            );
          }).toList(),
        ),
      ],
    );
  }
}
