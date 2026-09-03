import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';
import '../utils/api_error.dart';
import 'tabs/ledger_tab.dart';
import 'tabs/asset_tab.dart';
import 'tabs/stats_tab.dart';
import 'tabs/settings_tab.dart';
import '../widgets/floating_nav_bar.dart';
import '../theme/app_colors.dart';

class HomeScreen extends StatefulWidget {
  final int ledgerId;
  const HomeScreen({super.key, required this.ledgerId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  List<Transaction> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    try {
      final transactions = await TransactionService.fetchTransactions(ledgerId: widget.ledgerId);
      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('데이터를 불러오지 못했습니다: ${friendlyError(e)}')),
        );
      }
    }
  }

  void _addTransaction(Transaction transaction) {
    setState(() => _transactions.add(transaction));
  }

  void _updateTransaction(Transaction updated) {
    setState(() {
      final idx = _transactions.indexWhere((t) => t.id == updated.id);
      if (idx != -1) _transactions[idx] = updated;
    });
  }

  void _deleteTransaction(String id) {
    setState(() => _transactions.removeWhere((t) => t.id == id));
  }

  void _changeMonth(DateTime month) {
    setState(() => _currentMonth = month);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final tabs = [
      LedgerTab(
        ledgerId: widget.ledgerId,
        currentMonth: _currentMonth,
        transactions: _transactions,
        onMonthChanged: _changeMonth,
        onAddTransaction: _addTransaction,
        onUpdateTransaction: _updateTransaction,
        onDeleteTransaction: _deleteTransaction,
        onRefresh: _loadTransactions,
      ),
      StatsTab(
        ledgerId: widget.ledgerId,
        currentMonth: _currentMonth,
        transactions: _transactions,
        onMonthChanged: _changeMonth,
      ),
      AssetTab(ledgerId: widget.ledgerId, transactions: _transactions),
      SettingsTab(ledgerId: widget.ledgerId),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: tabs[_selectedIndex],
      bottomNavigationBar: FloatingNavBar(
        selectedIndex: _selectedIndex,
        onSelect: (i) => setState(() => _selectedIndex = i),
        items: const [
          FloatingNavItem(
            icon: Icons.book_outlined,
            selectedIcon: Icons.book,
            label: '가계부',
          ),
          FloatingNavItem(
            icon: Icons.bar_chart_outlined,
            selectedIcon: Icons.bar_chart,
            label: '통계',
          ),
          FloatingNavItem(
            icon: Icons.account_balance_wallet_outlined,
            selectedIcon: Icons.account_balance_wallet,
            label: '자산',
          ),
          FloatingNavItem(
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
            label: '설정',
          ),
        ],
      ),
    );
  }
}

