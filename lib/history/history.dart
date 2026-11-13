import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class HistoryEntry {
  const HistoryEntry({
    required this.expression,
    required this.result,
    required this.at,
  });

  final String expression;
  final String result;
  final DateTime at;

  Map<String, Object> toJson() => {
    'expression': expression,
    'result': result,
    'at': at.toUtc().toIso8601String(),
  };

  /// Returns null for anything that is not a well-formed entry.
  static HistoryEntry? fromJson(Object? json) {
    if (json case {
      'expression': String expression,
      'result': String result,
      'at': String at,
    }) {
      final value = double.tryParse(result);
      final time = DateTime.tryParse(at);
      if (value != null && value.isFinite && time != null) {
        return HistoryEntry(
          expression: expression,
          result: result,
          at: time.toLocal(),
        );
      }
    }
    return null;
  }
}

class HistoryStore {
  HistoryStore(this._prefs);

  static Future<HistoryStore> open() async =>
      HistoryStore(await SharedPreferences.getInstance());

  static const maxEntries = 100;
  static const _key = 'calculator.history';

  final SharedPreferences _prefs;

  /// Newest first.
  List<HistoryEntry> load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return [];
    }
    if (decoded is! List) return [];
    return [for (final item in decoded) ?HistoryEntry.fromJson(item)];
  }

  Future<void> add(HistoryEntry entry) => _prefs.setString(
    _key,
    jsonEncode([
      for (final e in [entry, ...load()].take(maxEntries)) e.toJson(),
    ]),
  );

  Future<void> clear() => _prefs.remove(_key);
}
