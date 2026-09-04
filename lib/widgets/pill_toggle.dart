import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';

class PillToggleItem {
  final String label;
  final String? amountText;
  final Color color;

  const PillToggleItem({
    required this.label,
    this.amountText,
    required this.color,
  });
}

/// 지출/수입(/이체) 같은 타입 선택에 쓰는 공용 pill 토글.
/// amountText를 주면 "지출 11,500원"처럼 라벨 옆에 금액을 같이 보여준다.
class PillToggle extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<PillToggleItem> items;

  const PillToggle({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: _PillToggleSegment(
                item: items[i],
                selected: i == selectedIndex,
                onTap: () => onSelected(i),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PillToggleSegment extends StatelessWidget {
  final PillToggleItem item;
  final bool selected;
  final VoidCallback onTap;

  const _PillToggleSegment({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: selected ? AppShadows.card : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(item.label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? item.color : AppColors.textMuted)),
              if (item.amountText != null) ...[
                const SizedBox(width: 6),
                Text(item.amountText!,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: selected ? item.color : AppColors.textMuted)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
