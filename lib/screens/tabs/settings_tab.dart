import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../asset_settings_screen.dart';
import '../category_settings_screen.dart';
import '../login_screen.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  Future<String?> _getLoginProvider() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('login_provider');
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
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: FutureBuilder<String?>(
        future: _getLoginProvider(),
        builder: (context, snapshot) {
          final provider = snapshot.data ?? '';
          final providerLabel = {
            'kakao': '카카오',
            'naver': '네이버',
            'apple': 'Apple',
          }[provider];

          return ListView(
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
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.category_outlined),
                title: const Text('카테고리 설정'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CategorySettingsScreen(),
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
                    builder: (_) => const AssetSettingsScreen(),
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
          );
        },
      ),
    );
  }
}
