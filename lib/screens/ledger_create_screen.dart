import 'package:flutter/material.dart';
import '../services/ledger_service.dart';
import '../utils/api_error.dart';
import 'home_screen.dart';
import '../theme/app_colors.dart';

class LedgerCreateScreen extends StatefulWidget {
  const LedgerCreateScreen({super.key});

  @override
  State<LedgerCreateScreen> createState() => _LedgerCreateScreenState();
}

class _LedgerCreateScreenState extends State<LedgerCreateScreen> {
  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('가계부 이름을 입력해주세요')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final ledger = await LedgerService.createLedger(ledgerName: name);
      final nickname = _nicknameController.text.trim();
      if (nickname.isNotEmpty) {
        await LedgerService.updateMyNickname(
            ledgerId: ledger.ledgerId, nickname: nickname);
      }
      await LedgerService.saveLastLedgerId(ledger.ledgerId);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(ledgerId: ledger.ledgerId)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('생성 실패: ${friendlyError(e)}')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const Icon(Icons.account_balance_wallet, size: 64, color: Colors.white),
            const SizedBox(height: 16),
            const Text(
              '가계부 만들기',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '가계부 이름을 정해주세요',
              style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7)),
            ),
            const Spacer(),
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: EdgeInsets.fromLTRB(
                  28, 32, 28, MediaQuery.of(context).viewInsets.bottom + 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: '가계부 이름',
                      hintText: '예) 우리집 가계부',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nicknameController,
                    decoration: const InputDecoration(
                      labelText: '이 가계부에서 내 이름',
                      hintText: '예) 홍길동',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _create(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _isSaving ? null : _create,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('시작하기', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
