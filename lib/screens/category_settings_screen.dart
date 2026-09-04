import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/category_service.dart';
import '../utils/api_error.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

class CategorySettingsScreen extends StatefulWidget {
  final int ledgerId;
  const CategorySettingsScreen({super.key, required this.ledgerId});

  @override
  State<CategorySettingsScreen> createState() => _CategorySettingsScreenState();
}

class _CategorySettingsScreenState extends State<CategorySettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<CategoryModel> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final cats = await CategoryService.fetchCategories(ledgerId: widget.ledgerId);
      if (mounted) setState(() { _categories = cats; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<CategoryModel> get _expense =>
      _categories.where((c) => c.categoryType == 'EXPENSE').toList();
  List<CategoryModel> get _income =>
      _categories.where((c) => c.categoryType == 'INCOME').toList();

  void _showSheet({CategoryModel? editing}) {
    final type = _tabController.index == 0 ? 'EXPENSE' : 'INCOME';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CategorySheet(
        categoryType: editing?.categoryType ?? type,
        editing: editing,
        onSave: (name, iconName, iconColor) async {
          if (editing == null) {
            final created = await CategoryService.createCategory(
              ledgerId: widget.ledgerId,
              categoryName: name,
              categoryType: type,
              iconName: iconName,
              iconColor: iconColor,
            );
            setState(() => _categories.add(created));
          } else {
            final updated = await CategoryService.updateCategory(
              ledgerId: widget.ledgerId,
              categoryId: editing.categoryId,
              categoryName: name,
              categoryType: editing.categoryType,
              iconName: iconName,
              iconColor: iconColor,
            );
            setState(() {
              final idx = _categories
                  .indexWhere((c) => c.categoryId == editing.categoryId);
              if (idx != -1) _categories[idx] = updated;
            });
          }
        },
      ),
    );
  }

  Future<void> _delete(CategoryModel cat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('카테고리 삭제'),
        content: Text('"${cat.categoryName}"을 삭제하시겠어요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await CategoryService.deleteCategory(
          ledgerId: widget.ledgerId, categoryId: cat.categoryId);
      setState(
          () => _categories.removeWhere((c) => c.categoryId == cat.categoryId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('삭제 실패: ${friendlyError(e)}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('카테고리 설정'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: '지출'), Tab(text: '수입')],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _CategoryList(
                    categories: _expense,
                    onEdit: _showSheet,
                    onDelete: _delete),
                _CategoryList(
                    categories: _income,
                    onEdit: _showSheet,
                    onDelete: _delete),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSheet(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  final List<CategoryModel> categories;
  final void Function({CategoryModel? editing}) onEdit;
  final void Function(CategoryModel) onDelete;

  const _CategoryList({
    required this.categories,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const Center(
        child: Text('카테고리가 없어요', style: TextStyle(color: AppColors.textMuted)),
      );
    }
    return ListView.separated(
      itemCount: categories.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 72, endIndent: 16),
      itemBuilder: (context, index) {
        final cat = categories[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: cat.color.withValues(alpha: 0.15),
            child: Icon(cat.icon, color: cat.color, size: 20),
          ),
          title: Text(cat.categoryName),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => onEdit(editing: cat),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: Colors.red),
                onPressed: () => onDelete(cat),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CategorySheet extends StatefulWidget {
  final String categoryType;
  final CategoryModel? editing;
  final Future<void> Function(String name, String iconName, String iconColor)
      onSave;

  const _CategorySheet({
    required this.categoryType,
    this.editing,
    required this.onSave,
  });

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  late final TextEditingController _nameController;
  late String _selectedIcon;
  late String _selectedColor;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _nameController = TextEditingController(text: e?.categoryName ?? '');
    _selectedIcon = e?.iconName ?? categoryIconMap.keys.first;
    _selectedColor = e?.iconColor ?? categoryColorOptions.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await widget.onSave(name, _selectedIcon, _selectedColor);
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

  @override
  Widget build(BuildContext context) {
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
            Text(
              widget.editing != null ? '카테고리 수정' : '카테고리 추가',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '카테고리 이름',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 20),
            const Text('아이콘',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            _buildIconGrid(),
            const SizedBox(height: 20),
            const Text('색상',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            _buildColorGrid(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _isSaving ? null : () => _save(),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('저장', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconGrid() {
    final selectedColor = parseHexColor(_selectedColor);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categoryIconMap.entries.map((entry) {
        final isSelected = _selectedIcon == entry.key;
        return GestureDetector(
          onTap: () => setState(() => _selectedIcon = entry.key),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected
                  ? selectedColor.withValues(alpha: 0.15)
                  : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: isSelected
                  ? Border.all(color: selectedColor, width: 2)
                  : null,
            ),
            child: Icon(
              entry.value,
              size: 22,
              color: isSelected ? selectedColor : AppColors.textMuted,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColorGrid() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: categoryColorOptions.map((hex) {
        final color = parseHexColor(hex);
        final isSelected = _selectedColor == hex;
        return GestureDetector(
          onTap: () => setState(() => _selectedColor = hex),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppColors.textMuted : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : null,
          ),
        );
      }).toList(),
    );
  }
}
