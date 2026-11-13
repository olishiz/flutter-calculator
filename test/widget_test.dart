import 'package:calculator/history/history.dart';
import 'package:calculator/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<HistoryStore> pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  SharedPreferences.resetStatic();
  final store = await HistoryStore.open();
  await tester.pumpWidget(CalculatorApp(store: store));
  return store;
}

Future<void> tapKeys(WidgetTester tester, String keys) async {
  for (final label in keys.split('')) {
    await tester.tap(find.byKey(ValueKey('key-$label')));
    await tester.pump();
  }
}

String line(WidgetTester tester, String key) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(Text),
      ),
    )
    .data!;

Future<void> openHistory(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('open-history')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tapping keys computes with precedence', (tester) async {
    await pumpApp(tester);
    expect(line(tester, 'main-line'), '0');

    await tapKeys(tester, '2+3×4=');

    expect(line(tester, 'main-line'), '14');
    expect(line(tester, 'expression-line'), '2 + 3 × 4 =');
  });

  testWidgets('history lists calculations newest first', (tester) async {
    await pumpApp(tester);
    await tapKeys(tester, '12×3=');
    await tapKeys(tester, '7−2=');

    await openHistory(tester);

    expect(find.text('12 × 3'), findsOneWidget);
    expect(find.text('= 36'), findsOneWidget);
    expect(find.text('just now'), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.text('7 − 2')).dy,
      lessThan(tester.getTopLeft(find.text('12 × 3')).dy),
    );
  });

  testWidgets('tapping a history row loads its result', (tester) async {
    await pumpApp(tester);
    await tapKeys(tester, '12×3=');
    await tapKeys(tester, 'C');
    await openHistory(tester);

    await tester.tap(find.text('12 × 3'));
    await tester.pumpAndSettle();

    expect(line(tester, 'main-line'), '36');
    expect(line(tester, 'expression-line'), '12 × 3 =');
    await tapKeys(tester, '+4=');
    expect(line(tester, 'main-line'), '40');
  });

  testWidgets('clearing history asks first', (tester) async {
    final store = await pumpApp(tester);
    await tapKeys(tester, '12×3=');
    await openHistory(tester);

    await tester.tap(find.byKey(const ValueKey('clear-history')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('12 × 3'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('clear-history')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-clear')));
    await tester.pumpAndSettle();

    expect(find.text('12 × 3'), findsNothing);
    expect(find.text('No calculations yet'), findsOneWidget);
    expect(store.load(), isEmpty);
  });

  testWidgets('shows an empty state with no history', (tester) async {
    await pumpApp(tester);
    await openHistory(tester);

    expect(find.text('No calculations yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('clear-history')), findsNothing);
  });

  testWidgets('hardware keyboard drives the calculator', (tester) async {
    await pumpApp(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.digit7);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadMultiply);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit6);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(line(tester, 'main-line'), '42');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit9);
    await tester.sendKeyEvent(
      LogicalKeyboardKey.asterisk,
      physicalKey: PhysicalKeyboardKey.digit8,
      character: '*',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit8);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal, character: '=');
    await tester.pump();
    expect(line(tester, 'main-line'), '45');
    expect(line(tester, 'expression-line'), '9 × 5 =');
  });

  testWidgets('long numbers fit on a phone-sized screen', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(tester);

    await tapKeys(tester, '123456789012345678');

    final text = find.descendant(
      of: find.byKey(const ValueKey('main-line')),
      matching: find.byType(Text),
    );
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: text, matching: find.byType(RichText)),
    );
    expect(paragraph.didExceedMaxLines, isFalse);
    final rect = tester.getRect(text);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(360));
  });
}
