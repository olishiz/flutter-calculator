import 'dart:convert';

import 'package:calculator/history/history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

HistoryEntry entry(int n) => HistoryEntry(
  expression: '$n + 0',
  result: '$n',
  at: DateTime.utc(2026, 1, 1).add(Duration(minutes: n)),
);

Future<HistoryStore> freshStore() async {
  SharedPreferences.resetStatic();
  return HistoryStore.open();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('is empty when nothing was stored', () async {
    expect((await freshStore()).load(), isEmpty);
  });

  test('entries survive a fresh store, newest first', () async {
    final store = await freshStore();
    await store.add(entry(1));
    await store.add(entry(2));

    final loaded = (await freshStore()).load();
    expect(loaded.map((e) => e.expression), ['2 + 0', '1 + 0']);
    expect(loaded.map((e) => e.result), ['2', '1']);
    expect(loaded.first.at.isAtSameMomentAs(entry(2).at), isTrue);
  });

  test('keeps only the newest 100 entries', () async {
    final store = await freshStore();
    for (var n = 1; n <= 105; n++) {
      await store.add(entry(n));
    }

    final loaded = (await freshStore()).load();
    expect(loaded, hasLength(100));
    expect(loaded.first.result, '105');
    expect(loaded.last.result, '6');
  });

  test('clear removes every entry', () async {
    final store = await freshStore();
    await store.add(entry(1));
    await store.clear();

    expect((await freshStore()).load(), isEmpty);
  });

  group('malformed storage', () {
    Future<List<HistoryEntry>> loadStored(String raw) async {
      SharedPreferences.setMockInitialValues({'calculator.history': raw});
      return (await freshStore()).load();
    }

    test('invalid JSON yields an empty list', () async {
      expect(await loadStored('{not json'), isEmpty);
    });

    test('a non-list payload yields an empty list', () async {
      expect(await loadStored('{"expression": "1 + 1"}'), isEmpty);
    });

    test('malformed entries are skipped', () async {
      final good = entry(7).toJson();
      final loaded = await loadStored(
        jsonEncode([
          good,
          {'expression': '1 + 1', 'result': '2'},
          {'expression': '1 + 1', 'result': 'two', 'at': good['at']},
          {'expression': 1, 'result': '2', 'at': good['at']},
          {'expression': '1 + 1', 'result': '2', 'at': 'yesterday'},
          'garbage',
          null,
        ]),
      );
      expect(loaded.map((e) => e.result), ['7']);
    });
  });
}
