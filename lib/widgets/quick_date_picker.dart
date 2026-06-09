import 'package:flutter/material.dart';

Future<DateTime?> showQuickDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _QuickDatePicker(
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? DateTime(2030),
    ),
  );
}

class _QuickDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const _QuickDatePicker({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_QuickDatePicker> createState() => _QuickDatePickerState();
}

class _QuickDatePickerState extends State<_QuickDatePicker> {
  late DateTime _viewing; // month being displayed
  late DateTime _selected;

  static const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
    _viewing = DateTime(widget.initialDate.year, widget.initialDate.month);
  }

  bool get _canGoPrev =>
      DateTime(_viewing.year, _viewing.month - 1).isAfter(
        DateTime(widget.firstDate.year, widget.firstDate.month - 1),
      );

  bool get _canGoNext =>
      DateTime(_viewing.year, _viewing.month + 1).isBefore(
        DateTime(widget.lastDate.year, widget.lastDate.month + 1),
      );

  @override
  Widget build(BuildContext context) {
    final daysInMonth =
        DateUtils.getDaysInMonth(_viewing.year, _viewing.month);
    final firstWeekday =
        DateTime(_viewing.year, _viewing.month, 1).weekday % 7; // 0=Sun

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Month nav ────────────────────────────────
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _canGoPrev
                    ? () => setState(() => _viewing =
                        DateTime(_viewing.year, _viewing.month - 1))
                    : null,
              ),
              Expanded(
                child: Text(
                  '${_viewing.year}년 ${_viewing.month}월',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _canGoNext
                    ? () => setState(() => _viewing =
                        DateTime(_viewing.year, _viewing.month + 1))
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Weekday headers ──────────────────────────
          Row(
            children: _weekdays.map((d) {
              final isSun = d == '일';
              final isSat = d == '토';
              return Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSun
                          ? Colors.red.shade300
                          : isSat
                              ? Colors.blue.shade300
                              : Colors.black45,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),

          // ── Day grid ─────────────────────────────────
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 0,
              childAspectRatio: 1,
            ),
            itemCount: firstWeekday + daysInMonth,
            itemBuilder: (_, index) {
              if (index < firstWeekday) return const SizedBox();
              final day = index - firstWeekday + 1;
              final date = DateTime(_viewing.year, _viewing.month, day);
              final isSelected = DateUtils.isSameDay(date, _selected);
              final isToday = DateUtils.isSameDay(date, DateTime.now());
              final outOfRange = date.isBefore(widget.firstDate) ||
                  date.isAfter(widget.lastDate);
              final weekday = date.weekday % 7; // 0=Sun,6=Sat
              final isSun = weekday == 0;
              final isSat = weekday == 6;

              Color textColor;
              if (outOfRange) {
                textColor = Colors.black12;
              } else if (isSelected) {
                textColor = Colors.white;
              } else if (isSun) {
                textColor = Colors.red.shade400;
              } else if (isSat) {
                textColor = Colors.blue.shade400;
              } else {
                textColor = Colors.black87;
              }

              return GestureDetector(
                onTap: outOfRange
                    ? null
                    : () => Navigator.pop(context, date),
                child: Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: isToday && !isSelected
                          ? Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.4),
                              width: 1.5,
                            )
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected || isToday
                              ? FontWeight.w700
                              : FontWeight.normal,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
