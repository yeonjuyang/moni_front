import 'package:flutter/material.dart';
import '../models/ledger.dart';
import '../services/ledger_service.dart';
import 'home_screen.dart';
import 'ledger_create_screen.dart';
import 'ledger_onboarding_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

class LedgerListScreen extends StatelessWidget {
  final List<LedgerModel> ledgers;

  const LedgerListScreen({super.key, required this.ledgers});

  Future<void> _selectLedger(BuildContext context, LedgerModel ledger) async {
    await LedgerService.saveLastLedgerId(ledger.ledgerId);
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(ledgerId: ledger.ledgerId)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('가계부 선택'),
        leading: Navigator.canPop(context)
            ? const BackButton()
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          ...ledgers.map((ledger) => _LedgerCard(
                ledger: ledger,
                onTap: () => _selectLedger(context, ledger),
              )),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LedgerCreateScreen()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('새 가계부 만들기'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LedgerOnboardingScreen()),
            ),
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('초대 코드로 참여'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerCard extends StatelessWidget {
  final LedgerModel ledger;
  final VoidCallback onTap;

  const _LedgerCard({required this.ledger, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isShared = ledger.ledgerType == 'SHARED';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  isShared ? Icons.people_outlined : Icons.person_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ledger.ledgerName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(isShared ? '공유 가계부' : '개인 가계부',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.divider),
            ],
          ),
        ),
      ),
    );
  }
}
