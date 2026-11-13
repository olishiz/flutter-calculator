# Flutter Calculator

A calculator app with standard operator precedence and a saved history of past calculations. Runs on Android, iOS, Windows and the web.

## Run it

```sh
flutter pub get
flutter run            # pick a device
flutter run -d chrome  # web
flutter run -d windows # Windows desktop
```

## Test it

```sh
flutter analyze
flutter test
flutter test integration_test -d windows
```

## Layout

- `lib/calculator/calculator.dart` is the pure Dart engine. `reduce(CalcState, CalcKey)` returns the next state, plus a `Calculation` when `=` finishes one. `CalcState` is one of `Editing`, `ShowingResult` or `Failed`. Operators live in the `Op` enum with their symbol, precedence and function.
- `lib/history/history.dart` stores up to 100 entries, newest first, in `shared_preferences`. Malformed stored data is skipped rather than thrown.
- `lib/ui/` holds the calculator and history screens. Widgets only call `reduce` and `HistoryStore`.
- `test/` covers the engine, the store and the screens. `integration_test/` runs the real app.

## Web build

`flutter build web --no-web-resources-cdn` bundles the rendering engine. Roboto is bundled in `assets/fonts/`, so the web build loads no fonts from Google.
