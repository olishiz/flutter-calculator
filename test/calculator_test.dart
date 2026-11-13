import 'package:calculator/calculator/calculator.dart';
import 'package:flutter_test/flutter_test.dart';

const _keysByLabel = <String, CalcKey>{
  '0': DigitKey(0),
  '1': DigitKey(1),
  '2': DigitKey(2),
  '3': DigitKey(3),
  '4': DigitKey(4),
  '5': DigitKey(5),
  '6': DigitKey(6),
  '7': DigitKey(7),
  '8': DigitKey(8),
  '9': DigitKey(9),
  '.': DecimalKey(),
  '+': OperatorKey(Op.add),
  '−': OperatorKey(Op.subtract),
  '×': OperatorKey(Op.multiply),
  '÷': OperatorKey(Op.divide),
  '=': EqualsKey(),
  'C': ClearKey(),
  '⌫': BackspaceKey(),
  '%': PercentKey(),
  '±': NegateKey(),
};

class Session {
  Session([this.state = CalcState.initial]);

  CalcState state;
  final completed = <Calculation>[];

  Session press(String keys) {
    for (final label in keys.split('')) {
      final step = reduce(state, _keysByLabel[label]!);
      state = step.state;
      if (step.completed case final c?) completed.add(c);
    }
    return this;
  }

  String get main => state.mainLine;
  String get expression => state.expressionLine;
}

Session press(String keys) => Session().press(keys);

void main() {
  test('starts at 0 with an empty expression line', () {
    final s = Session();
    expect(s.main, '0');
    expect(s.expression, '');
  });

  group('precedence', () {
    test('× binds tighter than +', () {
      final s = press('2+3×4=');
      expect(s.main, '14');
      expect(s.expression, '2 + 3 × 4 =');
      expect(s.completed, [(expression: '2 + 3 × 4', result: '14')]);
    });

    test('÷ binds tighter than −', () {
      expect(press('10−6÷2=').main, '7');
    });

    test('same precedence evaluates left to right', () {
      expect(press('8−3−2=').main, '3');
      expect(press('8÷4×2=').main, '4');
    });
  });

  group('entering numbers', () {
    test('shows committed terms on the expression line while typing', () {
      final s = press('12+3');
      expect(s.expression, '12 +');
      expect(s.main, '3');
    });

    test('keeps the last operand on the main line after an operator', () {
      expect(press('12×').main, '12');
    });

    test('leading zeros collapse', () {
      expect(press('007').main, '7');
      expect(press('000').main, '0');
    });

    test('a number takes at most one decimal point', () {
      expect(press('1.2.3').main, '1.23');
    });

    test('decimal on an empty entry gives 0.', () {
      expect(press('.').main, '0.');
      expect(press('5+.').main, '0.');
      expect(press('.5+.5=').main, '1');
    });
  });

  group('operators', () {
    test('an operator right after another replaces it', () {
      final s = press('5+×3=');
      expect(s.main, '15');
      expect(s.expression, '5 × 3 =');
    });

    test('an operator on the initial 0 uses 0 as the first operand', () {
      expect(press('−5=').main, '-5');
    });

    test('an operator after a result continues from it', () {
      final s = press('2+3=×4=');
      expect(s.main, '20');
      expect(s.expression, '5 × 4 =');
    });
  });

  group('after a result', () {
    test('a digit starts a fresh entry', () {
      final s = press('2+3=7');
      expect(s.main, '7');
      expect(s.expression, '');
      expect(s.press('+1=').main, '8');
    });

    test('a decimal starts a fresh entry', () {
      expect(press('2+3=.').main, '0.');
    });

    test('a restored result can be continued', () {
      final s = Session(
        ShowingResult.restore((expression: '12 × 3', result: '36')),
      );
      expect(s.expression, '12 × 3 =');
      expect(s.main, '36');
      expect(s.press('+4=').main, '40');
      expect(s.completed, [(expression: '36 + 4', result: '40')]);
    });
  });

  group('backspace', () {
    test('removes the last typed character', () {
      expect(press('123⌫').main, '12');
      expect(press('1⌫').main, '0');
      expect(press('1.⌫').main, '1');
    });

    test('never touches committed terms', () {
      final s = press('12+3⌫⌫');
      expect(s.expression, '12 +');
      expect(s.press('4=').main, '16');
    });

    test('drops a lone minus sign', () {
      expect(press('5±⌫').main, '0');
    });

    test('clears a result', () {
      final s = press('2+3=⌫');
      expect(s.main, '0');
      expect(s.expression, '');
    });

    test('clears a failure', () {
      final s = press('5÷0=⌫');
      expect(s.main, '0');
      expect(s.expression, '');
    });
  });

  test('C resets to the initial state', () {
    final s = press('12+3C');
    expect(s.main, '0');
    expect(s.expression, '');
    expect(s.press('=').completed, isEmpty);
  });

  group('percent', () {
    test('divides the entry by 100', () {
      expect(press('50%').main, '0.5');
      expect(press('50%+1=').main, '1.5');
    });

    test('divides a result by 100', () {
      final s = press('2+3=%');
      expect(s.main, '0.05');
      expect(s.expression, '');
    });

    test('a digit after percent starts a new number', () {
      expect(press('50%7').main, '7');
    });
  });

  group('negate', () {
    test('toggles the sign of the entry', () {
      expect(press('12±').main, '-12');
      expect(press('12±±').main, '12');
      expect(press('1.5±0').main, '-1.50');
    });

    test('leaves zero unsigned', () {
      expect(press('±').main, '0');
      expect(press('0±').main, '0');
    });

    test('negates a result', () {
      expect(press('2+3=±').main, '-5');
    });

    test('negative operands appear in the expression', () {
      final s = press('5±×2=');
      expect(s.main, '-10');
      expect(s.expression, '-5 × 2 =');
    });
  });

  group('division by zero', () {
    test('fails with a message and records nothing', () {
      final s = press('5÷0=');
      expect(s.main, "Can't divide by zero");
      expect(s.expression, '5 ÷ 0 =');
      expect(s.completed, isEmpty);
    });

    test('a digit afterwards becomes the new entry', () {
      final s = press('5÷0=7');
      expect(s.main, '7');
      expect(s.expression, '');
    });

    test('an operator afterwards is ignored', () {
      final s = press('5÷0=+');
      expect(s.main, '0');
      expect(s.expression, '');
      expect(s.press('2=').completed, isEmpty);
    });

    test('C afterwards clears', () {
      expect(press('5÷0=C').main, '0');
    });
  });

  group('equals', () {
    test('drops a trailing operator', () {
      final s = press('2+3×=');
      expect(s.main, '5');
      expect(s.expression, '2 + 3 =');
      expect(s.completed, [(expression: '2 + 3', result: '5')]);
    });

    test('does nothing on the initial state', () {
      final s = press('=');
      expect(s.main, '0');
      expect(s.completed, isEmpty);
    });

    test('does nothing with a single number', () {
      final s = press('7=');
      expect(s.main, '7');
      expect(s.expression, '');
      expect(s.completed, isEmpty);
      expect(press('7+=').completed, isEmpty);
    });

    test('pressed repeatedly after a result adds nothing', () {
      final s = press('2+3===');
      expect(s.main, '5');
      expect(s.completed, hasLength(1));
    });
  });

  group('formatting', () {
    test('rounds away binary noise', () {
      expect(press('0.1+0.2=').main, '0.3');
    });

    test('shows at most 12 significant digits', () {
      expect(press('1÷3=').main, '0.333333333333');
      expect(press('2÷3=').main, '0.666666666667');
    });

    test('trims trailing zeros and a dangling point', () {
      expect(press('2.5×2=').main, '5');
      final s = press('1.50+0=');
      expect(s.main, '1.5');
      expect(s.expression, '1.5 + 0 =');
    });

    test('never shows -0', () {
      expect(press('5±×0=').main, '0');
    });

    test('uses exponent form from 1e12 up', () {
      expect(press('999999999999×1=').main, '999999999999');
      expect(press('1000000×1000000=').main, '1e+12');
      expect(press('1230000000×1000000=').main, '1.23e+15');
    });

    test('uses exponent form below 1e-9', () {
      expect(press('1÷1000000000=').main, '0.000000001');
      expect(press('1÷10000000000=').main, '1e-10');
    });
  });

  test('a result beyond double range fails instead of showing Infinity', () {
    final almostE300 = press('999999999999${'×999999999999=' * 24}');
    expect(almostE300.main, '9.99999999975e+299');
    expect(almostE300.press('×999999999999=').main, 'Result is too large');
  });
}
