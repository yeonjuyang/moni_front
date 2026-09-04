import 'package:flutter/material.dart';
import '../../models/asset.dart';
import '../../models/transaction.dart';
import '../../services/asset_service.dart';
import '../../utils/api_error.dart';
import '../../utils/formatters.dart';
import '../asset_detail_screen.dart';
import '../asset_settings_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_radius.dart';

class AssetTab extends StatefulWidget {
  final int ledgerId;
  final List<Transaction> transactions;

  const AssetTab({super.key, required this.ledgerId, required this.transactions});

  @override
  State<AssetTab> createState() => _AssetTabState();
}

class _AssetTabState extends State<AssetTab> {
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
      if (!mounted) return;
      setState(() {
        _assets = assets;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('자산을 불러오지 못했습니다: ${friendlyError(e)}')));
    }
  }

  int get _totalBalance => _assets.fold(0, (s, a) => s + a.balance);

  void _openAssetDetail(AssetModel asset) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssetDetailScreen(
          asset: asset,
          transactions: widget.transactions,
          allAssets: _assets,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: const SizedBox.shrink(),
        leadingWidth: 48,
        centerTitle: true,
        title: const Text('자산', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_outlined),
            tooltip: '자산 관리',
            onPressed: () async {
              final result = await Navigator.push<List<AssetModel>>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AssetSettingsScreen(ledgerId: widget.ledgerId),
                ),
              );
              if (!mounted) return;
              if (result != null) {
                setState(() => _assets = result);
              } else {
                _load();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _assets.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.account_balance_wallet_outlined,
                                  size: 56,
                                  color: Colors.black.withValues(alpha: 0.15)),
                              const SizedBox(height: 12),
                              const Text('자산이 없어요',
                                  style: TextStyle(
                                      color: AppColors.textMuted, fontSize: 15)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                      children: [
                        _TotalBalanceCard(totalBalance: _totalBalance),
                        const SizedBox(height: 20),
                        ..._buildGroupedAssets(context),
                      ],
                    ),
            ),
    );
  }

  List<Widget> _buildGroupedAssets(BuildContext context) {
    final grouped = <String, List<AssetModel>>{};
    for (final a in _assets) {
      grouped.putIfAbsent(a.assetType, () => []).add(a);
    }

    // 그룹 순서는 자산 종류 기준으로 고정 (현금 → 은행 → 카드 → 기타)
    final sortedTypes = assetTypes.where(grouped.containsKey).toList();

    final widgets = <Widget>[];
    for (final type in sortedTypes) {
      final list = grouped[type]!..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            assetTypeLabels[type] ?? type,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      );
      for (final a in list) {
        widgets.add(_AssetRow(asset: a, onTap: () => _openAssetDetail(a)));
      }
      widgets.add(const SizedBox(height: 10));
    }
    return widgets;
  }
}

class _TotalBalanceCard extends StatelessWidget {
  final int totalBalance;

  const _TotalBalanceCard({required this.totalBalance});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.hero(AppColors.primary),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '총 자산',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.65),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${totalBalance < 0 ? '-' : ''}${formatCurrency(totalBalance)}원',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetRow extends StatelessWidget {
  final AssetModel asset;
  final VoidCallback onTap;

  const _AssetRow({required this.asset, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const color = AppColors.primaryDark;
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
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(asset.icon, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    asset.assetName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  '${asset.balance < 0 ? '-' : ''}${formatCurrency(asset.balance)}원',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
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
