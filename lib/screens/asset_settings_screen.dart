import 'package:flutter/material.dart';
import '../models/asset.dart';
import '../services/asset_service.dart';
import '../utils/api_error.dart';
import '../utils/formatters.dart';
import '../widgets/calculator_widget.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

class AssetSettingsScreen extends StatefulWidget {
  final int ledgerId;
  const AssetSettingsScreen({super.key, required this.ledgerId});

  @override
  State<AssetSettingsScreen> createState() => _AssetSettingsScreenState();
}

class _AssetSettingsScreenState extends State<AssetSettingsScreen> {
  List<AssetModel> _assets = [];
  bool _isLoading = true;
  Future<void>? _pendingReorder;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final assets = await AssetService.fetchAssets(ledgerId: widget.ledgerId);
      if (mounted) setState(() { _assets = assets; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSheet({AssetModel? editing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AssetSheet(
        editing: editing,
        onSave: (name, type, balance) async {
          if (editing == null) {
            final created = await AssetService.createAsset(
              ledgerId: widget.ledgerId,
              assetName: name,
              assetType: type,
              balance: balance,
            );
            setState(() => _assets.add(created));
          } else {
            final updated = await AssetService.updateAsset(
              ledgerId: widget.ledgerId,
              assetId: editing.assetId,
              assetName: name,
              assetType: type,
              balance: balance,
            );
            setState(() {
              final idx =
                  _assets.indexWhere((a) => a.assetId == editing.assetId);
              if (idx != -1) _assets[idx] = updated;
            });
          }
        },
      ),
    );
  }

  Map<String, List<AssetModel>> get _groupedAssets {
    final grouped = <String, List<AssetModel>>{};
    for (final a in _assets) {
      grouped.putIfAbsent(a.assetType, () => []).add(a);
    }
    return grouped;
  }

  // 같은 종류(현금/은행/카드) 안에서만 이웃과 순서를 맞바꾼다.
  // 드래그 기반 재정렬(SliverReorderableList)은 그룹별로 분리된 리스트를
  // 하나의 CustomScrollView에 두면 드래그가 인식되지 않거나 항목이
  // 사라지는 등 불안정해서, 훨씬 안정적인 위/아래 버튼 방식으로 대체했다.
  Future<void> _moveWithinType(String type, int index, int delta) async {
    final grouped = _groupedAssets;
    final group = List<AssetModel>.from(grouped[type]!);
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= group.length) return;

    final original = List<AssetModel>.from(_assets);
    final item = group.removeAt(index);
    group.insert(newIndex, item);
    grouped[type] = group;

    final reordered = <AssetModel>[
      for (final t in assetTypes.where(grouped.containsKey)) ...grouped[t]!,
    ];
    // sortOrder 필드도 새 위치에 맞게 다시 매겨야 한다. 배열 순서만 바꾸고
    // 필드는 그대로 두면, 다른 화면(자산 탭)에서 sortOrder 기준으로 다시
    // 정렬할 때 원래 순서로 되돌아가 버린다.
    final updated = <AssetModel>[
      for (var i = 0; i < reordered.length; i++)
        AssetModel(
          assetId: reordered[i].assetId,
          assetName: reordered[i].assetName,
          assetType: reordered[i].assetType,
          balance: reordered[i].balance,
          sortOrder: i + 1,
        ),
    ];
    setState(() => _assets = updated);
    _pendingReorder = AssetService.reorderAssets(
      ledgerId: widget.ledgerId,
      orderedIds: updated.map((a) => a.assetId).toList(),
    ).catchError((_) {
      if (mounted) setState(() => _assets = original);
    });
    await _pendingReorder;
  }

  Future<void> _delete(AssetModel asset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('자산 삭제'),
        content: Text('"${asset.assetName}"을 삭제하시겠어요?'),
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
      await AssetService.deleteAsset(ledgerId: widget.ledgerId, assetId: asset.assetId);
      setState(() => _assets.removeWhere((a) => a.assetId == asset.assetId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('삭제 실패: ${friendlyError(e)}')));
      }
    }
  }

  int get _totalBalance => _assets.fold(0, (sum, a) => sum + a.balance);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _pendingReorder;
        if (context.mounted) Navigator.pop(context, _assets);
      },
      child: Scaffold(
      appBar: AppBar(title: const Text('자산 설정')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 총 자산 요약
                if (_assets.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    padding: const EdgeInsets.symmetric(
                        vertical: 18, horizontal: 20),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('총 자산',
                            style: TextStyle(
                                fontSize: 13,
                                color: cs.onPrimaryContainer
                                    .withValues(alpha: 0.7))),
                        const SizedBox(height: 4),
                        Text(
                          '${_totalBalance < 0 ? '-' : ''}${formatCurrency(_totalBalance)}원',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                // 자산 목록 (종류별 그룹, 순서 변경은 같은 종류 안에서만)
                Expanded(
                  child: _assets.isEmpty
                      ? const Center(
                          child: Text('자산이 없어요',
                              style: TextStyle(color: AppColors.textMuted)),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          children: [
                            for (final type in assetTypes
                                .where(_groupedAssets.containsKey)) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                                child: Text(
                                  assetTypeLabels[type]!,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textMuted),
                                ),
                              ),
                              for (int index = 0;
                                  index < _groupedAssets[type]!.length;
                                  index++)
                                Builder(builder: (context) {
                                  final group = _groupedAssets[type]!;
                                  final asset = group[index];
                                  return ListTile(
                                    key: ValueKey(asset.assetId),
                                    leading: CircleAvatar(
                                      backgroundColor: cs.secondaryContainer,
                                      child: Icon(asset.icon,
                                          color: cs.onSecondaryContainer,
                                          size: 20),
                                    ),
                                    title: Text(asset.assetName),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${asset.balance < 0 ? '-' : ''}${formatCurrency(asset.balance)}원',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined,
                                              size: 20),
                                          onPressed: () =>
                                              _showSheet(editing: asset),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline,
                                              size: 20, color: Colors.red),
                                          onPressed: () => _delete(asset),
                                        ),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              width: 24,
                                              height: 22,
                                              child: IconButton(
                                                padding: EdgeInsets.zero,
                                                iconSize: 16,
                                                icon: const Icon(
                                                    Icons.keyboard_arrow_up),
                                                onPressed: index == 0
                                                    ? null
                                                    : () => _moveWithinType(
                                                        type, index, -1),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 24,
                                              height: 22,
                                              child: IconButton(
                                                padding: EdgeInsets.zero,
                                                iconSize: 16,
                                                icon: const Icon(
                                                    Icons.keyboard_arrow_down),
                                                onPressed:
                                                    index == group.length - 1
                                                        ? null
                                                        : () => _moveWithinType(
                                                            type, index, 1),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                            ],
                          ],
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSheet(),
        child: const Icon(Icons.add),
      ),
      ),
    );
  }
}

class _AssetSheet extends StatefulWidget {
  final AssetModel? editing;
  final Future<void> Function(String name, String type, int balance) onSave;

  const _AssetSheet({this.editing, required this.onSave});

  @override
  State<_AssetSheet> createState() => _AssetSheetState();
}

class _AssetSheetState extends State<_AssetSheet> {
  late final TextEditingController _nameController;
  late String _selectedType;
  late int _balance;
  bool _balanceSet = false;
  bool _showCalculator = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _nameController = TextEditingController(text: e?.assetName ?? '');
    _selectedType = e?.assetType ?? 'BANK';
    _balance = e?.balance ?? 0;
    _balanceSet = e != null;
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
      await widget.onSave(name, _selectedType, _balance);
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
    if (_showCalculator) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20),
                    onPressed: () =>
                        setState(() => _showCalculator = false),
                  ),
                  const Text('잔액 입력',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: CalculatorWidget(
                initialValue: _balance,
                onConfirm: (value) {
                  if (mounted) {
                    setState(() {
                      _balance = value;
                      _balanceSet = true;
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
              widget.editing != null ? '자산 수정' : '자산 추가',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            // 이름
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '자산 이름',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            // 종류
            const Text('종류',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: assetTypes.map((type) {
                return ChoiceChip(
                  avatar: Icon(assetTypeIcons[type], size: 16),
                  label: Text(assetTypeLabels[type]!),
                  selected: _selectedType == type,
                  onSelected: (_) =>
                      setState(() => _selectedType = type),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // 잔액 (계산기)
            InkWell(
              onTap: () => setState(() => _showCalculator = true),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 14),
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
                        _balanceSet
                            ? '${formatCurrency(_balance)}원'
                            : '잔액',
                        style: TextStyle(
                          fontSize: 15,
                          color: _balanceSet ? null : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
}
