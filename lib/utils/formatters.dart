String formatCurrency(int amount) {
  final str = amount.abs().toString();
  final result = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) result.write(',');
    result.write(str[i]);
  }
  return result.toString();
}

/// 달력 셀처럼 좁은 공간에서 쓰는 축약 금액 표시. 1만원 미만은 그대로,
/// 이상이면 "1.2만" 형태로 줄여서 표시한다.
String formatCompactCurrency(int amount) {
  final abs = amount.abs();
  if (abs < 10000) return formatCurrency(amount);
  final man = abs / 10000;
  final display =
      man == man.roundToDouble() ? man.toStringAsFixed(0) : man.toStringAsFixed(1);
  return '$display만';
}

String formatMonthLabel(DateTime date) => '${date.year}년 ${date.month}월';

String formatDateHeader(DateTime date) {
  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  return '${date.month}월 ${date.day}일 ${weekdays[date.weekday - 1]}요일';
}
