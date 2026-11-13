import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../calculator/calculator.dart';
import '../history/history.dart';
import 'history_screen.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key, required this.store});

  final HistoryStore store;

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  CalcState _state = CalcState.initial;

  void _press(CalcKey key) {
    final step = reduce(_state, key);
    setState(() => _state = step.state);
    if (step.completed case final c?) {
      unawaited(
        widget.store.add(
          HistoryEntry(
            expression: c.expression,
            result: c.result,
            at: DateTime.now(),
          ),
        ),
      );
    }
  }

  Future<void> _openHistory() async {
    final picked = await Navigator.of(context).push<HistoryEntry>(
      MaterialPageRoute(builder: (_) => HistoryScreen(store: widget.store)),
    );
    if (picked == null) return;
    setState(() {
      _state = ShowingResult.restore((
        expression: picked.expression,
        result: picked.result,
      ));
    });
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key =
        _keysByLogicalKey[event.logicalKey] ??
        _keysByCharacter[event.character];
    if (key == null) return KeyEventResult.ignored;
    _press(key);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Calculator'),
          actions: [
            IconButton(
              key: const ValueKey('open-history'),
              tooltip: 'History',
              icon: const Icon(Icons.history),
              onPressed: _openHistory,
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  Expanded(flex: 2, child: _Display(state: _state)),
                  Expanded(flex: 5, child: _Keypad(onPressed: _press)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final _keysByLogicalKey = <LogicalKeyboardKey, CalcKey>{
  LogicalKeyboardKey.enter: const EqualsKey(),
  LogicalKeyboardKey.numpadEnter: const EqualsKey(),
  LogicalKeyboardKey.backspace: const BackspaceKey(),
  LogicalKeyboardKey.escape: const ClearKey(),
  LogicalKeyboardKey.numpadAdd: const OperatorKey(Op.add),
  LogicalKeyboardKey.numpadSubtract: const OperatorKey(Op.subtract),
  LogicalKeyboardKey.numpadMultiply: const OperatorKey(Op.multiply),
  LogicalKeyboardKey.numpadDivide: const OperatorKey(Op.divide),
  LogicalKeyboardKey.numpadDecimal: const DecimalKey(),
  LogicalKeyboardKey.numpadEqual: const EqualsKey(),
};

const _keysByCharacter = <String, CalcKey>{
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
  '-': OperatorKey(Op.subtract),
  '*': OperatorKey(Op.multiply),
  '/': OperatorKey(Op.divide),
  '=': EqualsKey(),
  '%': PercentKey(),
};

class _Display extends StatelessWidget {
  const _Display({required this.state});

  final CalcState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FitLine(
            state.expressionLine,
            key: const ValueKey('expression-line'),
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Flexible(
            child: _FitLine(
              state.mainLine,
              key: const ValueKey('main-line'),
              style: theme.textTheme.displayLarge?.copyWith(
                fontSize: 72,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single right-aligned line that shrinks to fit instead of overflowing.
class _FitLine extends StatelessWidget {
  const _FitLine(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Text(text, maxLines: 1, style: style),
    );
  }
}

const _layout = <List<CalcKey>>[
  [ClearKey(), BackspaceKey(), PercentKey(), OperatorKey(Op.divide)],
  [DigitKey(7), DigitKey(8), DigitKey(9), OperatorKey(Op.multiply)],
  [DigitKey(4), DigitKey(5), DigitKey(6), OperatorKey(Op.subtract)],
  [DigitKey(1), DigitKey(2), DigitKey(3), OperatorKey(Op.add)],
  [NegateKey(), DigitKey(0), DecimalKey(), EqualsKey()],
];

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onPressed});

  final ValueChanged<CalcKey> onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          for (final row in _layout)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final key in row)
                    Expanded(
                      child: _KeyButton(
                        calcKey: key,
                        onPressed: () => onPressed(key),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({required this.calcKey, required this.onPressed});

  final CalcKey calcKey;
  final VoidCallback onPressed;

  String get _label => switch (calcKey) {
    DigitKey(:final digit) => '$digit',
    DecimalKey() => '.',
    OperatorKey(:final op) => op.symbol,
    EqualsKey() => '=',
    ClearKey() => 'C',
    BackspaceKey() => '⌫',
    PercentKey() => '%',
    NegateKey() => '±',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (calcKey) {
      EqualsKey() => (scheme.primary, scheme.onPrimary),
      OperatorKey() => (scheme.primaryContainer, scheme.onPrimaryContainer),
      ClearKey() ||
      BackspaceKey() ||
      PercentKey() ||
      NegateKey() => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      DigitKey() ||
      DecimalKey() => (scheme.surfaceContainerHighest, scheme.onSurface),
    };
    final textStyle = Theme.of(
      context,
    ).textTheme.headlineMedium?.copyWith(color: foreground);

    return Padding(
      padding: const EdgeInsets.all(5),
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('key-$_label'),
          // Keeps keyboard focus on the screen so typing still reaches it
          // after a key is clicked.
          canRequestFocus: false,
          onTap: onPressed,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: calcKey is BackspaceKey
                    ? Icon(
                        Icons.backspace_outlined,
                        color: foreground,
                        size: textStyle?.fontSize,
                        semanticLabel: 'Backspace',
                      )
                    : Text(_label, style: textStyle),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
