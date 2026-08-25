import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/ledger.dart';
import '../services/ledger_service.dart';
import '../utils/api_error.dart';
import 'ledger_onboarding_screen.dart';
import 'ledger_list_screen.dart';

class LedgerSettingsScreen extends StatefulWidget {
  final LedgerModel ledger;
  const LedgerSettingsScreen({super.key, required this.ledger});

  @override
  State<LedgerSettingsScreen> createState() => _LedgerSettingsScreenState();
}

class _LedgerSettingsScreenState extends State<LedgerSettingsScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _nicknameController;
  late LedgerModel _ledger;
  bool _isSaving = false;
  bool _isGenerating = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _ledger = widget.ledger;
    _nameController = TextEditingController(text: _ledger.ledgerName);
    _nicknameController = TextEditingController(text: _ledger.myNickname ?? '');
    _load();
  }

  Future<void> _load() async {
    try {
      final fresh = await LedgerService.getLedger(_ledger.ledgerId);
      if (!mounted) return;
      setState(() {
        _ledger = fresh;
        _nameController.text = fresh.ledgerName;
        _nicknameController.text = fresh.myNickname ?? '';
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await Future.wait([
        LedgerService.updateLedger(
          ledgerId: _ledger.ledgerId,
          ledgerName: name,
        ),
        LedgerService.updateMyNickname(
          ledgerId: _ledger.ledgerId,
          nickname: _nicknameController.text.trim(),
        ),
      ]);
      if (!mounted) return;
      final fresh = await LedgerService.getLedger(_ledger.ledgerId);
      if (!mounted) return;
      setState(() => _ledger = fresh);
      Navigator.pop(context, fresh);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('저장 실패: ${friendlyError(e)}')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteLedger() async {
    setState(() => _isDeleting = true);
    try {
      await LedgerService.deleteLedger(_ledger.ledgerId);
      if (!mounted) return;
      final ledgers = await LedgerService.fetchMyLedgers();
      if (!mounted) return;
      if (ledgers.isEmpty) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LedgerOnboardingScreen()),
          (_) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => LedgerListScreen(ledgers: ledgers)),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('삭제 실패: ${friendlyError(e)}')));
        setState(() => _isDeleting = false);
      }
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('가계부 삭제'),
        content: Text('"${_ledger.ledgerName}" 가계부를 삭제하시겠어요?\n모든 거래 내역이 사라집니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteLedger();
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateInviteCode() async {
    setState(() => _isGenerating = true);
    try {
      final updated = await LedgerService.generateInviteCode(_ledger.ledgerId);
      if (mounted) setState(() => _ledger = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('코드 생성 실패: ${friendlyError(e)}')));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('초대 코드가 복사됐어요'), duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final code = _ledger.inviteCode;

    return Scaffold(
      appBar: AppBar(
          title: const Text('가계부 설정'),
          actions: [
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('저장'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '가계부 이름',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: '이 가계부에서 내 이름',
                hintText: '비워두면 기본 닉네임 사용',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 24),
            const Text('초대 코드',
                style: TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (code != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        code,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 6,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_outlined),
                      onPressed: () => _copyCode(code),
                      tooltip: '복사',
                    ),
                  ],
                ),
              )
            else
              Text(
                '아직 초대 코드가 없어요',
                style: TextStyle(color: Colors.black38, fontSize: 14),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isGenerating ? null : _generateInviteCode,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              label: Text(code != null ? '코드 재생성' : '초대 코드 생성'),
            ),
            if (code != null) ...[
              const SizedBox(height: 6),
              Text(
                '코드를 재생성하면 기존 코드는 사용할 수 없어요.',
                style: TextStyle(fontSize: 12, color: Colors.black38),
              ),
            ],
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isDeleting ? null : _confirmDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isDeleting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.red))
                    : const Text('가계부 삭제'),
              ),
            ),
          ],
      ),
    );
  }
}
