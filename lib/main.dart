import 'package:flutter/material.dart';

import 'history/history.dart';
import 'ui/calculator_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(CalculatorApp(store: await HistoryStore.open()));
}

class CalculatorApp extends StatelessWidget {
  const CalculatorApp({super.key, required this.store});

  final HistoryStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calculator',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: CalculatorScreen(store: store),
    );
  }
}

ThemeData _theme(Brightness brightness) => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.indigo,
    brightness: brightness,
  ),
);
