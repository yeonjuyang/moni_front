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

  // Format expression for display: numbers get comma separators, operators become symbols
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

  // Evaluate with proper operator precedence (* / before + -)
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

    // First pass: * and /
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

    // Second pass: + and -
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
          // Strip trailing operator or dangling decimal before appending
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

        default: // digits: 0, 00, 000, 1-9
          // Map 00/000 → '0' when starting a new number to avoid leading zeros
          final isNewNum = _isResult || _expr.isEmpty || _endsWithOp;
          final digits = isNewNum && (label == '00' || label == '000') ? '0' : label;
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
        // Display
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 14),
          color: cs.surfaceContainerLow,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  displayText,
                  style: const TextStyle(
                      fontSize: 34, fontWeight: FontWeight.w600),
                ),
              ),
              if (!_isResult && hasOp) ...[
                const SizedBox(height: 2),
                Text(
                  '= ${formatCurrency(_currentValue)}원',
                  style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.4)),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        // Button grid
        Expanded(
          child: Column(
            children: [
              Expanded(child: _row(['+', '-', '×', '÷'], cs)),
              Expanded(child: _row(['7', '8', '9', '='], cs)),
              Expanded(child: _row(['4', '5', '6', '.'], cs)),
              Expanded(child: _row(['1', '2', '3', '지움'], cs)),
              Expanded(child: _row(['00', '0', '000', '확인'], cs)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(List<String> labels, ColorScheme cs) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: labels
            .map((l) => Expanded(
                  child: _CalcButton(
                    label: l,
                    onTap: l == '확인'
                        ? () => widget.onConfirm(_currentValue)
                        : () => _tap(l),
                    onLongPress: l == '지움' ? _clearAll : null,
                    bg: _bg(l, cs),
                    fg: _fg(l, cs),
                    fontSize: _fontSize(l),
                    bold: l == '확인' || l == '=',
                  ),
                ))
            .toList(),
      );

  Color _bg(String l, ColorScheme cs) {
    if ('+-×÷'.contains(l)) return cs.secondaryContainer;
    if (l == '=' || l == '확인') return cs.primary;
    if (l == '지움') return cs.errorContainer.withValues(alpha: 0.55);
    if (l == '.') return cs.surfaceContainerHighest;
    return cs.surface;
  }

  Color _fg(String l, ColorScheme cs) {
    if ('+-×÷'.contains(l)) return cs.onSecondaryContainer;
    if (l == '=' || l == '확인') return cs.onPrimary;
    if (l == '지움') return cs.error;
    return cs.onSurface;
  }

  double _fontSize(String l) {
    if (l == '확인') return 16;
    if (l == '지움') return 14;
    if (l == '000' || l == '00') return 18;
    return 22;
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
    this.fontSize = 22,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
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
