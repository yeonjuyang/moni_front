import 'package:flutter/material.dart';
import '../models/asset.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../services/asset_service.dart';
import '../services/category_service.dart';
import '../services/transaction_service.dart';
import '../services/user_service.dart';
import '../utils/formatters.dart';
import '../widgets/calculator_widget.dart';

class AddTransactionSheet extends StatefulWidget {
  final int ledgerId;
  final DateTime initialDate;
  final ValueChanged<Transaction> onSave;
  final Transaction? editing;
  final VoidCallback? onDelete;

  const AddTransactionSheet({
    super.key,
    required this.ledgerId,
    required this.initialDate,
    required this.onSave,
    this.editing,
    this.onDelete,
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
      _selectedDate = DateTime.now();
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
          if (assets.isNotEmpty) _selectedAssetId = assets.first.assetId;
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
      final users = await UserService.fetchUsers();
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

  List<CategoryModel> get _categories =>
      _type == TransactionType.expense ? _expenseCategories : _incomeCategories;

  void _onTypeChanged(TransactionType type) {
    setState(() {
      _type = type;
      final cats = type == TransactionType.expense ? _expenseCategories : _incomeCategories;
      _selectedCategory = cats.isNotEmpty ? cats.first.categoryName : '';
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _amount <= 0) return;

    if (_assets.isNotEmpty && _selectedAssetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('자산을 선택해주세요')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final selectedUser = _users.where((u) => u.userId == _selectedUserId).firstOrNull;
      final draft = Transaction(
        id: widget.editing?.id ?? '',
        title: title,
        amount: _amount,
        type: _type,
        date: _selectedDate,
        category: _selectedCategory,
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
          fromAssetId: _type == TransactionType.expense ? _selectedAssetId : null,
          toAssetId: _type == TransactionType.income ? _selectedAssetId : null,
        );
      } else {
        saved = await TransactionService.createTransaction(
          ledgerId: widget.ledgerId,
          transaction: draft,
          fromAssetId: _type == TransactionType.expense ? _selectedAssetId : null,
          toAssetId: _type == TransactionType.income ? _selectedAssetId : null,
        );
      }

      widget.onSave(saved);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('저장 실패: $e')));
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
            .showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
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
                    color: Colors.black12,
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
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                      value: TransactionType.expense, label: Text('지출')),
                  ButtonSegment(
                      value: TransactionType.income, label: Text('수입')),
                ],
                selected: {_type},
                onSelectionChanged: (s) => _onTypeChanged(s.first),
              ),
            ),
            const SizedBox(height: 16),

            // 내용
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '내용',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
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
            const SizedBox(height: 12),

            // 금액
            InkWell(
              onTap: () => setState(() => _showCalculator = true),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calculate_outlined,
                        size: 18, color: Colors.black54),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _amount > 0 ? '${formatCurrency(_amount)}원' : '금액',
                        style: TextStyle(
                            fontSize: 15,
                            color: _amount > 0 ? null : Colors.black38),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 자산
            _buildAssetSection(),
            const SizedBox(height: 16),

            // 사람
            _buildPersonSection(),
            const SizedBox(height: 16),

            // 카테고리
            const Text('카테고리',
                style: TextStyle(fontSize: 13, color: Colors.black54)),
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
                  Text('카테고리 불러오는 중...', style: TextStyle(color: Colors.black38)),
                ]),
              )
            else if (_categories.isEmpty)
              const Text('카테고리가 없어요. 설정에서 먼저 추가해주세요.',
                  style: TextStyle(fontSize: 13, color: Colors.black38))
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _categories.map((c) {
                  final isSelected = _selectedCategory == c.categoryName;
                  return ChoiceChip(
                    avatar: Icon(c.icon, size: 14,
                        color: isSelected ? null : c.color),
                    label: Text(c.categoryName),
                    selected: isSelected,
                    onSelected: (_) =>
                        setState(() => _selectedCategory = c.categoryName),
                  );
                }).toList(),
              ),
            const SizedBox(height: 16),

            // 날짜
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 18, color: Colors.black54),
                    const SizedBox(width: 8),
                    Text(formatDateHeader(_selectedDate),
                        style: const TextStyle(fontSize: 15)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 저장
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
                    : Text(_isEditing ? '수정' : '저장',
                        style: const TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetSection() {
    final label = _type == TransactionType.expense ? '출금 자산' : '입금 자산';

    if (_isLoadingAssets) {
      return const SizedBox(
        height: 36,
        child: Row(children: [
          SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 8),
          Text('자산 불러오는 중...', style: TextStyle(color: Colors.black38)),
        ]),
      );
    }

    if (_assets.isEmpty) {
      return Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.black38),
          const SizedBox(width: 6),
          Text('$label: 자산을 먼저 등록해주세요',
              style: const TextStyle(fontSize: 13, color: Colors.black38)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _assets.map((asset) {
            return ChoiceChip(
              avatar: Icon(asset.icon, size: 16),
              label: Text(asset.assetName),
              selected: _selectedAssetId == asset.assetId,
              onSelected: (_) =>
                  setState(() => _selectedAssetId = asset.assetId),
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
          Text('사용자 불러오는 중...', style: TextStyle(color: Colors.black38)),
        ]),
      );
    }

    if (_users.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('사람',
            style: TextStyle(fontSize: 13, color: Colors.black54)),
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
