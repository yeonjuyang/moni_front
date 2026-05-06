import 'package:flutter/material.dart';
import '../models/asset.dart';
import '../services/asset_service.dart';
import '../utils/formatters.dart';
import '../widgets/calculator_widget.dart';

class AssetSettingsScreen extends StatefulWidget {
  final int ledgerId;
  const AssetSettingsScreen({super.key, required this.ledgerId});

  @override
  State<AssetSettingsScreen> createState() => _AssetSettingsScreenState();
}

class _AssetSettingsScreenState extends State<AssetSettingsScreen> {
  List<AssetModel> _assets = [];
  bool _isLoading = true;

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

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final updated = List<AssetModel>.from(_assets);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    setState(() => _assets = updated);
    try {
      await AssetService.reorderAssets(
        ledgerId: widget.ledgerId,
        orderedIds: updated.map((a) => a.assetId).toList(),
      );
    } catch (_) {
      setState(() => _assets = List<AssetModel>.from(_assets)
        ..insert(oldIndex, updated.removeAt(newIndex)));
    }
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
            .showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
      }
    }
  }

  int get _totalBalance => _assets.fold(0, (sum, a) => sum + a.balance);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
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
                      borderRadius: BorderRadius.circular(16),
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
                          '${formatCurrency(_totalBalance)}원',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                // 자산 목록
                Expanded(
                  child: _assets.isEmpty
                      ? const Center(
                          child: Text('자산이 없어요',
                              style: TextStyle(color: Colors.black38)),
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _assets.length,
                          onReorder: _onReorder,
                          itemBuilder: (context, index) {
                            final asset = _assets[index];
                            return ListTile(
                              key: ValueKey(asset.assetId),
                              leading: CircleAvatar(
                                backgroundColor: cs.secondaryContainer,
                                child: Icon(asset.icon,
                                    color: cs.onSecondaryContainer,
                                    size: 20),
                              ),
                              title: Text(asset.assetName),
                              subtitle: Text(asset.typeLabel,
                                  style: const TextStyle(fontSize: 12)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${formatCurrency(asset.balance)}원',
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
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSheet(),
        child: const Icon(Icons.add),
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
            .showSnackBar(SnackBar(content: Text('저장 실패: $e')));
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
                    color: Colors.black12,
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
                style: TextStyle(fontSize: 13, color: Colors.black54)),
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
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 14),
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
                        _balanceSet
                            ? '${formatCurrency(_balance)}원'
                            : '잔액',
                        style: TextStyle(
                          fontSize: 15,
                          color: _balanceSet ? null : Colors.black38,
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
