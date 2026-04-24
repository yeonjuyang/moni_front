import 'package:flutter/material.dart';
import '../utils/formatters.dart';

class MonthSelector extends StatelessWidget {
  final DateTime currentMonth;
  final ValueChanged<DateTime> onChanged;

  const MonthSelector({
    super.key,
    required this.currentMonth,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(DateTime(currentMonth.year, currentMonth.month - 1)),
        ),
        Text(
          formatMonthLabel(currentMonth),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onChanged(DateTime(currentMonth.year, currentMonth.month + 1)),
        ),
      ],
    );
  }
}
