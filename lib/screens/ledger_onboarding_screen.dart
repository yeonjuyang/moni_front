import 'package:flutter/material.dart';
import '../services/ledger_service.dart';
import 'home_screen.dart';
import 'ledger_create_screen.dart';

class LedgerOnboardingScreen extends StatefulWidget {
  const LedgerOnboardingScreen({super.key});

  @override
  State<LedgerOnboardingScreen> createState() => _LedgerOnboardingScreenState();
}

class _LedgerOnboardingScreenState extends State<LedgerOnboardingScreen> {
  bool _showJoinInput = false;
  final _codeController = TextEditingController();
  bool _isJoining = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('초대 코드는 6자리입니다')),
      );
      return;
    }
    setState(() => _isJoining = true);
    try {
      final ledger = await LedgerService.joinLedger(code);
      await LedgerService.saveLastLedgerId(ledger.ledgerId);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(ledgerId: ledger.ledgerId)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('참여 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4361EE),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const Icon(Icons.account_balance_wallet, size: 64, color: Colors.white),
            const SizedBox(height: 16),
            const Text(
              '가계부 시작하기',
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              '새로 만들거나 초대 코드로 참여하세요',
              style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7)),
            ),
            const Spacer(),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: EdgeInsets.fromLTRB(
                  28, 32, 28, MediaQuery.of(context).viewInsets.bottom + 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LedgerCreateScreen()),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('새 가계부 만들기', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _showJoinInput = !_showJoinInput),
                      icon: const Icon(Icons.group_add_outlined),
                      label: const Text('초대 코드로 참여', style: TextStyle(fontSize: 16)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF4361EE)),
                        foregroundColor: const Color(0xFF4361EE),
                      ),
                    ),
                  ),
                  if (_showJoinInput) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _codeController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: '초대 코드 6자리',
                        hintText: 'ABC123',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      onSubmitted: (_) => _join(),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: _isJoining ? null : _join,
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF4361EE)),
                        child: _isJoining
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('참여하기'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
