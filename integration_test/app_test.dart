import 'package:calculator/history/history.dart';
import 'package:calculator/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> launchApp(WidgetTester tester) async {
  SharedPreferences.resetStatic();
  final store = await HistoryStore.open();
  await tester.pumpWidget(CalculatorApp(key: UniqueKey(), store: store));
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a calculation survives an app restart', (tester) async {
    await (await HistoryStore.open()).clear();
    await launchApp(tester);

    for (final label in ['1', '2', '×', '3', '=']) {
      await tester.tap(find.byKey(ValueKey('key-$label')));
      await tester.pump();
    }
    expect(find.text('36'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('open-history')));
    await tester.pumpAndSettle();
    expect(find.text('12 × 3'), findsOneWidget);

    await launchApp(tester);
    expect(
      find.text('12 × 3'),
      findsNothing,
      reason: 'restart lands on the calculator',
    );

    await tester.tap(find.byKey(const ValueKey('open-history')));
    await tester.pumpAndSettle();
    expect(find.text('12 × 3'), findsOneWidget);
    expect(find.text('= 36'), findsOneWidget);
  });
}
