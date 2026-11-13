import 'dart:math' as math;

enum Op {
  add('+', 1, _add),
  subtract('−', 1, _subtract),
  multiply('×', 2, _multiply),
  divide('÷', 2, _divide);

  const Op(this.symbol, this.precedence, this.apply);

  final String symbol;
  final int precedence;

  /// Returns null when the operation is undefined for these operands.
  final double? Function(double a, double b) apply;
}

double? _add(double a, double b) => a + b;
double? _subtract(double a, double b) => a - b;
double? _multiply(double a, double b) => a * b;
double? _divide(double a, double b) => b == 0 ? null : a / b;

sealed class CalcKey {
  const CalcKey();
}

final class DigitKey extends CalcKey {
  const DigitKey(this.digit) : assert(digit >= 0 && digit <= 9);
  final int digit;
}

final class DecimalKey extends CalcKey {
  const DecimalKey();
}

final class OperatorKey extends CalcKey {
  const OperatorKey(this.op);
  final Op op;
}

final class EqualsKey extends CalcKey {
  const EqualsKey();
}

final class ClearKey extends CalcKey {
  const ClearKey();
}

final class BackspaceKey extends CalcKey {
  const BackspaceKey();
}

final class PercentKey extends CalcKey {
  const PercentKey();
}

final class NegateKey extends CalcKey {
  const NegateKey();
}

typedef Calculation = ({String expression, String result});

typedef CalcStep = ({CalcState state, Calculation? completed});

typedef Term = ({double operand, Op op});

/// The number in the entry slot of [Editing].
sealed class Entry {
  const Entry();
  double get value;
  String get display;
}

/// Digits the user is typing, kept as text so `0.` and `1.50` display as typed.
final class TypedEntry extends Entry {
  const TypedEntry(this.text);
  final String text;

  @override
  double get value => double.parse(text);

  @override
  String get display => text;
}

/// A value produced by `%` or `±` on a result. Like a result, the next digit
/// replaces it instead of appending.
final class ComputedEntry extends Entry {
  const ComputedEntry(this.value);

  @override
  final double value;

  @override
  String get display => formatNumber(value);
}

sealed class CalcState {
  const CalcState();

  static const initial = Editing(terms: [], entry: null);

  String get expressionLine;
  String get mainLine;
}

final class Editing extends CalcState {
  const Editing({required this.terms, required this.entry});

  /// Committed operands, each followed by the operator typed after it.
  final List<Term> terms;

  /// Null until the user starts a number after the last operator.
  final Entry? entry;

  @override
  String get expressionLine => [
    for (final t in terms) ...[formatNumber(t.operand), t.op.symbol],
  ].join(' ');

  @override
  String get mainLine =>
      entry?.display ??
      (terms.isEmpty ? '0' : formatNumber(terms.last.operand));
}

final class ShowingResult extends CalcState {
  const ShowingResult({required this.expression, required this.result});

  ShowingResult.restore(Calculation c)
    : this(expression: c.expression, result: double.parse(c.result));

  final String expression;
  final double result;

  @override
  String get expressionLine => '$expression =';

  @override
  String get mainLine => formatNumber(result);
}

final class Failed extends CalcState {
  const Failed({required this.expression, required this.message});

  final String expression;
  final String message;

  @override
  String get expressionLine => '$expression =';

  @override
  String get mainLine => message;
}

CalcStep reduce(CalcState state, CalcKey key) => switch (state) {
  Editing() => _reduceEditing(state, key),
  ShowingResult() => _step(_reduceResult(state, key)),
  Failed() => _step(_reduceFailed(key)),
};

CalcStep _reduceEditing(Editing s, CalcKey key) {
  CalcStep withEntry(Entry? entry) =>
      _step(Editing(terms: s.terms, entry: entry));
  return switch (key) {
    DigitKey(:final digit) => withEntry(_appendDigit(s.entry, digit)),
    DecimalKey() => withEntry(_appendDecimal(s.entry)),
    OperatorKey(:final op) => _step(_pushOperator(s, op)),
    EqualsKey() => _equals(s),
    ClearKey() => _step(CalcState.initial),
    BackspaceKey() => withEntry(_backspace(s.entry)),
    PercentKey() => withEntry(_percent(s.entry)),
    NegateKey() => withEntry(_negate(s.entry)),
  };
}

CalcStep _step(CalcState state) => (state: state, completed: null);

CalcState _reduceResult(ShowingResult s, CalcKey key) => switch (key) {
  DigitKey(:final digit) => Editing(
    terms: const [],
    entry: _appendDigit(null, digit),
  ),
  DecimalKey() => Editing(terms: const [], entry: _appendDecimal(null)),
  OperatorKey(:final op) => Editing(
    terms: [(operand: s.result, op: op)],
    entry: null,
  ),
  EqualsKey() => s,
  ClearKey() || BackspaceKey() => CalcState.initial,
  PercentKey() => Editing(
    terms: const [],
    entry: ComputedEntry(s.result / 100),
  ),
  NegateKey() => Editing(terms: const [], entry: ComputedEntry(-s.result)),
};

CalcState _reduceFailed(CalcKey key) => switch (key) {
  DigitKey(:final digit) => Editing(
    terms: const [],
    entry: _appendDigit(null, digit),
  ),
  DecimalKey() => Editing(terms: const [], entry: _appendDecimal(null)),
  _ => CalcState.initial,
};

Entry _appendDigit(Entry? entry, int digit) => switch (entry) {
  TypedEntry(text: '0') || null || ComputedEntry() => TypedEntry('$digit'),
  TypedEntry(:final text) => TypedEntry('$text$digit'),
};

Entry _appendDecimal(Entry? entry) => switch (entry) {
  TypedEntry(:final text) when text.contains('.') => entry,
  TypedEntry(:final text) => TypedEntry('$text.'),
  null || ComputedEntry() => const TypedEntry('0.'),
};

Entry? _backspace(Entry? entry) {
  if (entry is! TypedEntry) return null;
  final text = entry.text.substring(0, entry.text.length - 1);
  if (text.isEmpty || text == '-') return null;
  return TypedEntry(
    double.parse(text) == 0 ? text.replaceFirst('-', '') : text,
  );
}

Entry? _percent(Entry? entry) =>
    entry == null ? null : ComputedEntry(entry.value / 100);

Entry? _negate(Entry? entry) => switch (entry) {
  TypedEntry(:final text, :final value) when value != 0 => TypedEntry(
    text.startsWith('-') ? text.substring(1) : '-$text',
  ),
  ComputedEntry(:final value) => ComputedEntry(-value),
  _ => entry,
};

Editing _pushOperator(Editing s, Op op) => switch (s.entry) {
  final entry? => Editing(
    terms: [...s.terms, (operand: entry.value, op: op)],
    entry: null,
  ),
  null when s.terms.isEmpty => Editing(
    terms: [(operand: 0, op: op)],
    entry: null,
  ),
  null => Editing(
    terms: [
      ...s.terms.take(s.terms.length - 1),
      (operand: s.terms.last.operand, op: op),
    ],
    entry: null,
  ),
};

CalcStep _equals(Editing s) {
  final operands = [for (final t in s.terms) t.operand, ?s.entry?.value];
  if (operands.length < 2) return _step(s);
  final ops = [
    for (final t in s.terms) t.op,
  ].take(operands.length - 1).toList();

  final expression = [
    formatNumber(operands.first),
    for (var i = 0; i < ops.length; i++) ...[
      ops[i].symbol,
      formatNumber(operands[i + 1]),
    ],
  ].join(' ');

  final value = _evaluate(operands, ops);
  if (value == null) {
    return _step(
      Failed(expression: expression, message: "Can't divide by zero"),
    );
  }
  if (!value.isFinite) {
    return _step(
      Failed(expression: expression, message: 'Result is too large'),
    );
  }
  return (
    state: ShowingResult(expression: expression, result: value),
    completed: (expression: expression, result: formatNumber(value)),
  );
}

/// Operator-precedence evaluation. Returns null if any step is undefined.
double? _evaluate(List<double> operands, List<Op> ops) {
  final values = [operands.first];
  final pending = <Op>[];

  bool applyTop() {
    final b = values.removeLast();
    final a = values.removeLast();
    final r = pending.removeLast().apply(a, b);
    if (r == null) return false;
    values.add(r);
    return true;
  }

  for (var i = 0; i < ops.length; i++) {
    while (pending.isNotEmpty && pending.last.precedence >= ops[i].precedence) {
      if (!applyTop()) return null;
    }
    pending.add(ops[i]);
    values.add(operands[i + 1]);
  }
  while (pending.isNotEmpty) {
    if (!applyTop()) return null;
  }
  return values.single;
}

const _significantDigits = 12;

String formatNumber(double value) {
  if (value == 0) return '0';
  final rounded = double.parse(value.toStringAsPrecision(_significantDigits));
  if (rounded == 0) return '0';
  final magnitude = rounded.abs();
  if (magnitude >= 1e12 || magnitude < 1e-9) {
    final [mantissa, exponent] = rounded
        .toStringAsExponential(_significantDigits - 1)
        .split('e');
    return '${_trimFraction(mantissa)}e$exponent';
  }
  final integerDigits = (math.log(magnitude) / math.ln10).floor() + 1;
  final decimals = (_significantDigits - integerDigits).clamp(0, 20);
  return _trimFraction(rounded.toStringAsFixed(decimals));
}

String _trimFraction(String s) =>
    s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
