import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/ledger.dart';
import '../../services/auth_service.dart';
import '../../services/ledger_service.dart';
import '../category_settings_screen.dart';
import '../ledger_onboarding_screen.dart';
import '../ledger_list_screen.dart';
import '../ledger_settings_screen.dart';
import '../login_screen.dart';

class SettingsTab extends StatefulWidget {
  final int ledgerId;
  const SettingsTab({super.key, required this.ledgerId});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  LedgerModel? _ledger;
  String? _loginProvider;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final ledger = await LedgerService.getLedger(widget.ledgerId);
    if (!mounted) return;
    setState(() {
      _loginProvider = prefs.getString('login_provider');
      _ledger = ledger;
    });
  }

  Future<void> _openLedgerSettings() async {
    if (_ledger == null) return;
    final updated = await Navigator.push<LedgerModel>(
      context,
      MaterialPageRoute(
        builder: (_) => LedgerSettingsScreen(ledger: _ledger!),
      ),
    );
    if (updated != null) setState(() => _ledger = updated);
  }

  Future<void> _switchLedger(BuildContext context) async {
    try {
      final ledgers = await LedgerService.fetchMyLedgers();
      if (!context.mounted) return;
      if (ledgers.isEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LedgerOnboardingScreen()),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LedgerListScreen(ledgers: ledgers)),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('가계부 목록을 불러오지 못했습니다: $e')),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    await AuthService.logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _logout(context);
            },
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final providerLabel = {
      'kakao': '카카오',
      'naver': '네이버',
      'apple': 'Apple',
    }[_loginProvider];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        centerTitle: true,
        title: const Text('설정',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── 가계부 섹션 ──────────────────────────────
          _SectionLabel('가계부'),
          _SettingsCard(
            items: [
              _SettingsItem(
                icon: Icons.book_outlined,
                label: '가계부 설정',
                subtitle: _ledger?.ledgerName,
                onTap: _openLedgerSettings,
              ),
              _SettingsItem(
                icon: Icons.category_outlined,
                label: '카테고리 설정',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CategorySettingsScreen(ledgerId: widget.ledgerId),
                  ),
                ),
              ),
              _SettingsItem(
                icon: Icons.swap_horiz_outlined,
                label: '가계부 전환',
                onTap: () => _switchLedger(context),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── 계정 섹션 ────────────────────────────────
          _SectionLabel('계정'),
          _SettingsCard(
            items: [
              if (providerLabel != null)
                _SettingsItem(
                  icon: Icons.person_outline,
                  label: '$providerLabel 로그인',
                  tappable: false,
                ),
              _SettingsItem(
                icon: Icons.logout,
                label: '로그아웃',
                destructive: true,
                onTap: () => _confirmLogout(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Settings card ─────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final List<_SettingsItem> items;
  const _SettingsCard({required this.items});

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
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _SettingsRow(item: items[i]),
            if (i < items.length - 1)
              const Divider(height: 1, indent: 52, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

// ── Settings row ──────────────────────────────────────────────────────────────

class _SettingsItem {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool destructive;
  final bool tappable;
  final VoidCallback? onTap;

  const _SettingsItem({
    required this.icon,
    required this.label,
    this.subtitle,
    this.destructive = false,
    this.tappable = true,
    this.onTap,
  });
}

class _SettingsRow extends StatelessWidget {
  final _SettingsItem item;
  const _SettingsRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.destructive ? Colors.red : Colors.black87;
    final iconBg = item.destructive
        ? Colors.red.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);
    final iconColor = item.destructive
        ? Colors.red
        : Theme.of(context).colorScheme.primary;

    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: color)),
                if (item.subtitle != null)
                  Text(item.subtitle!,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black38)),
              ],
            ),
          ),
          if (item.tappable)
            const Icon(Icons.chevron_right, size: 18, color: Colors.black26),
        ],
      ),
    );

    if (!item.tappable || item.onTap == null) return content;

    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(20),
      child: content,
    );
  }
}
