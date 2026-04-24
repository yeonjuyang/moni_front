String formatCurrency(int amount) {
  final str = amount.abs().toString();
  final result = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) result.write(',');
    result.write(str[i]);
  }
  return result.toString();
}

String formatMonthLabel(DateTime date) => '${date.year}년 ${date.month}월';

String formatDateHeader(DateTime date) {
  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  return '${date.month}월 ${date.day}일 ${weekdays[date.weekday - 1]}요일';
}
