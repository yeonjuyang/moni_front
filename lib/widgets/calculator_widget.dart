import 'package:flutter/material.dart';
import '../utils/formatters.dart';

class CalculatorWidget extends StatefulWidget {
  final int initialValue;
  final ValueChanged<int> onConfirm;

  const CalculatorWidget({
    super.key,
    this.initialValue = 0,
    required this.onConfirm,
  });

  @override
  State<CalculatorWidget> createState() => _CalculatorWidgetState();
}

class _CalculatorWidgetState extends State<CalculatorWidget> {
  String _expr = '';
  bool _isResult = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue > 0) {
      _expr = widget.initialValue.toString();
      _isResult = true;
    }
  }

  bool get _endsWithOp =>
      _expr.isNotEmpty && '+-*/'.contains(_expr[_expr.length - 1]);

  int get _currentValue {
    String e = _expr;
    if (_endsWithOp || e.endsWith('.')) e = e.substring(0, e.length - 1);
    return e.isEmpty ? 0 : _eval(e);
  }

  String _format(String expr) {
    final sb = StringBuffer();
    final buf = StringBuffer();
    for (final ch in expr.split('')) {
      if (RegExp(r'[\d.]').hasMatch(ch)) {
        buf.write(ch);
      } else {
        if (buf.isNotEmpty) {
          _writeFmtNum(sb, buf.toString());
          buf.clear();
        }
        sb.write(switch (ch) {
          '+' => ' + ',
          '-' => ' - ',
          '*' => ' × ',
          '/' => ' ÷ ',
          _ => ch,
        });
      }
    }
    if (buf.isNotEmpty) _writeFmtNum(sb, buf.toString());
    return sb.toString();
  }

  void _writeFmtNum(StringBuffer sb, String raw) {
    final parts = raw.split('.');
    sb.write(formatCurrency(int.tryParse(parts[0]) ?? 0));
    if (parts.length > 1) sb.write('.${parts[1]}');
  }

  int _eval(String expr) {
    if (expr.isEmpty) return 0;
    final tokens = <dynamic>[];
    final buf = StringBuffer();
    for (final ch in expr.split('')) {
      if (RegExp(r'[\d.]').hasMatch(ch)) {
        buf.write(ch);
      } else if ('+-*/'.contains(ch)) {
        if (buf.isNotEmpty) {
          tokens.add(double.tryParse(buf.toString()) ?? 0.0);
          buf.clear();
        }
        tokens.add(ch);
      }
    }
    if (buf.isNotEmpty) tokens.add(double.tryParse(buf.toString()) ?? 0.0);
    if (tokens.isEmpty || tokens.first is String) return 0;
    if (tokens.length == 1) return (tokens[0] as double).round();

    int i = 1;
    while (i < tokens.length) {
      if (tokens[i] == '*' || tokens[i] == '/') {
        final l = tokens[i - 1] as double;
        final r = tokens[i + 1] as double;
        tokens.replaceRange(
            i - 1, i + 2, [tokens[i] == '*' ? l * r : (r == 0 ? 0.0 : l / r)]);
      } else {
        i += 2;
      }
    }

    double result = tokens[0] as double;
    for (int j = 1; j + 1 < tokens.length; j += 2) {
      result += (tokens[j] == '+' ? 1 : -1) * (tokens[j + 1] as double);
    }
    return result < 0 ? 0 : result.round();
  }

  void _tap(String label) {
    setState(() {
      switch (label) {
        case '지움':
          if (_isResult) {
            _expr = '';
            _isResult = false;
          } else if (_expr.isNotEmpty) {
            _expr = _expr.substring(0, _expr.length - 1);
          }

        case '=':
          if (_expr.isNotEmpty && !_endsWithOp && !_expr.endsWith('.')) {
            _expr = _eval(_expr).toString();
            _isResult = true;
          }

        case '+' || '-' || '×' || '÷':
          if (_expr.isEmpty) return;
          final op = switch (label) {
            '×' => '*',
            '÷' => '/',
            _ => label,
          };
          if (_isResult) _isResult = false;
          final base = (_endsWithOp || _expr.endsWith('.'))
              ? _expr.substring(0, _expr.length - 1)
              : _expr;
          _expr = '$base$op';

        case '.':
          if (_isResult) {
            _expr = '0.';
            _isResult = false;
          } else if (_expr.isEmpty || _endsWithOp) {
            _expr += '0.';
          } else {
            final lastOpIdx = _expr.lastIndexOf(RegExp(r'[+\-*/]'));
            final currentNum =
                lastOpIdx < 0 ? _expr : _expr.substring(lastOpIdx + 1);
            if (!currentNum.contains('.')) _expr += '.';
          }

        default:
          final isNewNum = _isResult || _expr.isEmpty || _endsWithOp;
          final digits =
              isNewNum && (label == '00' || label == '000') ? '0' : label;
          if (_isResult) {
            _expr = digits;
            _isResult = false;
          } else {
            _expr += digits;
          }
      }
    });
  }

  void _clearAll() => setState(() {
        _expr = '';
        _isResult = false;
      });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasOp = _expr.contains(RegExp(r'[+\-*/]'));
    final displayText = _expr.isEmpty ? '0' : _format(_expr);

    return Column(
      children: [
        // ── 디스플레이 ──────────────────────────────────
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  displayText,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (!_isResult && hasOp) ...[
                const SizedBox(height: 3),
                Text(
                  '= ${formatCurrency(_currentValue)}원',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.primary.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFEEEEEE)),
        // ── 버튼 그리드 ─────────────────────────────────
        Expanded(
          child: ColoredBox(
            color: const Color(0xFFF5F6FA),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Expanded(child: _row(['+', '-', '×', '÷'], cs)),
                  const SizedBox(height: 7),
                  Expanded(child: _row(['7', '8', '9', '='], cs)),
                  const SizedBox(height: 7),
                  Expanded(child: _row(['4', '5', '6', '.'], cs)),
                  const SizedBox(height: 7),
                  Expanded(child: _row(['1', '2', '3', '지움'], cs)),
                  const SizedBox(height: 7),
                  Expanded(child: _row(['00', '0', '000', '확인'], cs)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(List<String> labels, ColorScheme cs) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 7),
          Expanded(
            child: _CalcButton(
              label: labels[i],
              onTap: labels[i] == '확인'
                  ? () => widget.onConfirm(_currentValue)
                  : () => _tap(labels[i]),
              onLongPress: labels[i] == '지움' ? _clearAll : null,
              bg: _bg(labels[i], cs),
              fg: _fg(labels[i], cs),
              fontSize: _fontSize(labels[i]),
              bold: labels[i] == '확인' || labels[i] == '=',
            ),
          ),
        ],
      ],
    );
  }

  Color _bg(String l, ColorScheme cs) {
    if ('+-×÷'.contains(l)) return const Color(0xFFEEF0FF);
    if (l == '=') return const Color(0xFFEEF0FF);
    if (l == '확인') return cs.primary;
    if (l == '지움') return const Color(0xFFFEF0F0);
    if (l == '.') return const Color(0xFFEEEFF4);
    return Colors.white;
  }

  Color _fg(String l, ColorScheme cs) {
    if ('+-×÷='.contains(l)) return cs.primary;
    if (l == '확인') return Colors.white;
    if (l == '지움') return Colors.red.shade400;
    return Colors.black87;
  }

  double _fontSize(String l) {
    if (l == '확인') return 15;
    if (l == '지움') return 13;
    if (l == '000' || l == '00') return 17;
    return 21;
  }
}

class _CalcButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color bg;
  final Color fg;
  final double fontSize;
  final bool bold;

  const _CalcButton({
    required this.label,
    required this.onTap,
    this.onLongPress,
    required this.bg,
    required this.fg,
    this.fontSize = 21,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}
