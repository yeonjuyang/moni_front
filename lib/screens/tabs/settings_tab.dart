import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/ledger.dart';
import '../../services/auth_service.dart';
import '../../services/ledger_service.dart';
import '../asset_settings_screen.dart';
import '../category_settings_screen.dart';
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
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          if (providerLabel != null) ...[
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text('$providerLabel로 로그인됨'),
            ),
            const Divider(),
          ],
          ListTile(
            leading: const Icon(Icons.book_outlined),
            title: const Text('가계부 설정'),
            subtitle: _ledger != null ? Text(_ledger!.ledgerName) : null,
            trailing: const Icon(Icons.chevron_right),
            onTap: _openLedgerSettings,
          ),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('카테고리 설정'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CategorySettingsScreen(ledgerId: widget.ledgerId),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('자산 설정'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AssetSettingsScreen(ledgerId: widget.ledgerId),
              ),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('로그아웃', style: TextStyle(color: Colors.red)),
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }
}
