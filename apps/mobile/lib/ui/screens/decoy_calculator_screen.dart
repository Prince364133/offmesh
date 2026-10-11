import 'package:flutter/material.dart';
import '../../core/haven_engine.dart';

class DecoyCalculatorScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const DecoyCalculatorScreen({super.key, required this.onUnlocked});

  @override
  State<DecoyCalculatorScreen> createState() => _DecoyCalculatorScreenState();
}

class _DecoyCalculatorScreenState extends State<DecoyCalculatorScreen> {
  String _display = '0';
  String _pinBuffer = '';
  double? _firstOperand;
  String? _operator;
  bool _shouldResetDisplay = false;

  void _onDigit(String digit) {
    setState(() {
      _pinBuffer += digit;
      if (_display == '0' || _shouldResetDisplay) {
        _display = digit;
        _shouldResetDisplay = false;
      } else {
        if (_display.length < 12) {
          _display += digit;
        }
      }
    });
  }

  void _onOperator(String op) {
    setState(() {
      _firstOperand = double.tryParse(_display);
      _operator = op;
      _shouldResetDisplay = true;
    });
  }

  void _onEquals() {
    // Check if entered pin in buffer matches the stealth decoy PIN!
    final engine = HavenEngine.instance;
    if (engine.verifyPin(_pinBuffer)) {
      widget.onUnlocked();
      return;
    }

    setState(() {
      if (_firstOperand != null && _operator != null) {
        final secondOperand = double.tryParse(_display) ?? 0;
        double result = 0;
        switch (_operator) {
          case '+':
            result = _firstOperand! + secondOperand;
            break;
          case '−':
            result = _firstOperand! - secondOperand;
            break;
          case '×':
            result = _firstOperand! * secondOperand;
            break;
          case '÷':
            result = secondOperand != 0 ? _firstOperand! / secondOperand : 0;
            break;
        }
        _display = result.toString().endsWith('.0')
            ? result.toInt().toString()
            : result.toStringAsFixed(2);
        _firstOperand = null;
        _operator = null;
        _shouldResetDisplay = true;
      }
      _pinBuffer = '';
    });
  }

  void _onClear() {
    setState(() {
      _display = '0';
      _pinBuffer = '';
      _firstOperand = null;
      _operator = null;
      _shouldResetDisplay = false;
    });
  }

  void _onToggleSign() {
    setState(() {
      if (_display.startsWith('-')) {
        _display = _display.substring(1);
      } else if (_display != '0') {
        _display = '-$_display';
      }
    });
  }

  void _onPercent() {
    setState(() {
      final val = double.tryParse(_display) ?? 0;
      _display = (val / 100).toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Display Area
            Expanded(
              flex: 3,
              child: Container(
                alignment: Alignment.bottomRight,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Text(
                  _display,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -1,
                  ),
                ),
              ),
            ),

            // Keypad
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildRow(['AC', '±', '%', '÷'], [Colors.grey[700]!, Colors.grey[700]!, Colors.grey[700]!, Colors.orange[800]!]),
                      _buildRow(['7', '8', '9', '×'], [Colors.grey[900]!, Colors.grey[900]!, Colors.grey[900]!, Colors.orange[800]!]),
                      _buildRow(['4', '5', '6', '−'], [Colors.grey[900]!, Colors.grey[900]!, Colors.grey[900]!, Colors.orange[800]!]),
                      _buildRow(['1', '2', '3', '+'], [Colors.grey[900]!, Colors.grey[900]!, Colors.grey[900]!, Colors.orange[800]!]),
                      _buildRow(['0', '.', '='], [Colors.grey[900]!, Colors.grey[900]!, Colors.orange[800]!], isBottomRow: true),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<String> labels, List<Color> colors, {bool isBottomRow = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(labels.length, (i) {
        final label = labels[i];
        final color = colors[i];
        final isZero = isBottomRow && label == '0';

        return Container(
          width: isZero ? 170 : 76,
          height: 76,
          margin: const EdgeInsets.all(4),
          child: ElevatedButton(
            onPressed: () {
              if (label == 'AC') {
                _onClear();
              } else if (label == '±') {
                _onToggleSign();
              } else if (label == '%') {
                _onPercent();
              } else if (['÷', '×', '−', '+'].contains(label)) {
                _onOperator(label);
              } else if (label == '=') {
                _onEquals();
              } else {
                _onDigit(label);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isZero ? 40 : 50),
              ),
              padding: EdgeInsets.zero,
              elevation: 0,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: label == 'AC' ? 22 : 28,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        );
      }),
    );
  }
}
