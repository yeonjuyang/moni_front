import 'package:flutter/material.dart';
import '../models/transaction.dart';
import 'tabs/ledger_tab.dart';
import 'tabs/stats_tab.dart';
import 'tabs/settings_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final List<Transaction> _transactions = List.from(mockTransactions);

  void _addTransaction(Transaction transaction) {
    setState(() => _transactions.add(transaction));
  }

  void _changeMonth(DateTime month) {
    setState(() => _currentMonth = month);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      LedgerTab(
        currentMonth: _currentMonth,
        transactions: _transactions,
        onMonthChanged: _changeMonth,
        onAddTransaction: _addTransaction,
      ),
      StatsTab(
        currentMonth: _currentMonth,
        transactions: _transactions,
        onMonthChanged: _changeMonth,
      ),
      const SettingsTab(),
    ];

    return Scaffold(
      body: tabs[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: '가계부',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '통계',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '설정',
          ),
        ],
      ),
    );
  }
}
