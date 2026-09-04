import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/ledger_service.dart';
import '../utils/api_error.dart';
import 'home_screen.dart';
import 'ledger_onboarding_screen.dart';
import 'ledger_list_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

// 카카오/네이버 개발자 앱 키가 발급되면 이 상수를 false로 바꾸거나 제거한다.
const bool kDevLoginEnabled = kDebugMode;

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> _navigateAfterLogin(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final ledgers = await LedgerService.fetchMyLedgers();
      if (!context.mounted) return;

      if (ledgers.isEmpty) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const LedgerOnboardingScreen()));
        return;
      }

      final lastId = prefs.getInt('last_ledger_id');
      if (lastId != null && ledgers.any((l) => l.ledgerId == lastId)) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => HomeScreen(ledgerId: lastId)));
      } else if (ledgers.length == 1) {
        await LedgerService.saveLastLedgerId(ledgers.first.ledgerId);
        if (!context.mounted) return;
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => HomeScreen(ledgerId: ledgers.first.ledgerId)));
      } else {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => LedgerListScreen(ledgers: ledgers)));
      }
    } catch (_) {
      if (!context.mounted) return;
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const LedgerOnboardingScreen()));
    }
  }

  Future<void> _loginWithKakao(BuildContext context) async {
    try {
      await AuthService.loginWithKakao();
      if (!context.mounted) return;
      await _navigateAfterLogin(context);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카카오 로그인 실패: ${friendlyError(e)}')),
      );
    }
  }

  Future<void> _loginWithNaver(BuildContext context) async {
    try {
      await AuthService.loginWithNaver();
      if (!context.mounted) return;
      await _navigateAfterLogin(context);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('네이버 로그인 실패: ${friendlyError(e)}')),
      );
    }
  }

  Future<void> _loginPlaceholder(BuildContext context, String provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await prefs.setString('login_provider', provider);
    if (!context.mounted) return;
    await _navigateAfterLogin(context);
  }

  // 카카오/네이버 개발자 앱 키 발급 전 임시 테스트용 로그인.
  Future<void> _loginDev(BuildContext context, String email, String nickname) async {
    try {
      await AuthService.loginDev(email: email, nickname: nickname);
      if (!context.mounted) return;
      await _navigateAfterLogin(context);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('테스트 로그인 실패: ${friendlyError(e)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
        children: [
          // 상단 컬러 영역
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet,
                          size: 44,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Moni',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '개인과 공유 가계부를 간편하게',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 하단 흰색 카드 영역
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: EdgeInsets.fromLTRB(28, 28, 28, bottomPadding + 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                const Text(
                  '소셜 계정으로 간편하게 시작하기',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),

                _SocialButton(
                  label: '카카오로 계속하기',
                  badgeLabel: 'K',
                  buttonColor: const Color(0xFFFEE500),
                  textColor: const Color(0xFF191919),
                  badgeColor: const Color(0xFF191919),
                  badgeTextColor: const Color(0xFFFEE500),
                  onPressed: () => _loginWithKakao(context),
                ),
                const SizedBox(height: 10),

                _SocialButton(
                  label: '네이버로 계속하기',
                  badgeLabel: 'N',
                  buttonColor: const Color(0xFF03C75A),
                  textColor: Colors.white,
                  badgeColor: const Color(0xFF02A94E),
                  badgeTextColor: Colors.white,
                  onPressed: () => _loginWithNaver(context),
                ),
                const SizedBox(height: 10),

                _SocialButton(
                  label: 'Apple로 계속하기',
                  badgeLabel: '',
                  buttonColor: const Color(0xFF1C1C1E),
                  textColor: Colors.white,
                  badgeColor: const Color(0xFF333333),
                  badgeTextColor: Colors.white,
                  badgeIcon: Icons.apple,
                  onPressed: () => _loginPlaceholder(context, 'apple'),
                ),
                const SizedBox(height: 20),

                Text(
                  '로그인 시 이용약관 및 개인정보처리방침에 동의하게 됩니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black.withValues(alpha: 0.35),
                    height: 1.5,
                  ),
                ),

                if (kDevLoginEnabled) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    '개발 테스트 로그인 (카카오/네이버 키 발급 전 임시)',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _loginDev(context, 'test@test.com', '양씨'),
                          child: const Text('테스트 계정 1'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _loginDev(context, 'partner@test.com', '박민준'),
                          child: const Text('테스트 계정 2'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final String badgeLabel;
  final Color buttonColor;
  final Color textColor;
  final Color badgeColor;
  final Color badgeTextColor;
  final IconData? badgeIcon;
  final VoidCallback onPressed;

  const _SocialButton({
    required this.label,
    required this.badgeLabel,
    required this.buttonColor,
    required this.textColor,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.onPressed,
    this.badgeIcon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Center(
                  child: badgeIcon != null
                      ? Icon(badgeIcon, color: badgeTextColor, size: 18)
                      : Text(
                          badgeLabel,
                          style: TextStyle(
                            color: badgeTextColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
