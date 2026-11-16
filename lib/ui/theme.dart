import 'package:flutter/material.dart';

const Color kBrandBlue = Color(0xFF3156D3);

/// Larguras de referência do Material 3 para layout responsivo.
class Breakpoints {
  static const double medium = 600;
  static const double expanded = 840;
  static const double large = 1200;
}

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: kBrandBlue, brightness: brightness);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      margin: EdgeInsets.zero,
    ),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
  );
}

/// Cores das prioridades 1 a 4, legíveis em tema claro e escuro.
({Color background, Color foreground}) priorityColors(BuildContext context, int priority) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final base = switch (priority) {
    4 => const Color(0xFFC62835),
    3 => const Color(0xFF3156D3),
    2 => const Color(0xFFB4650A),
    _ => const Color(0xFF0B7F6F),
  };
  return dark
      ? (background: base.withValues(alpha: 0.28), foreground: Color.lerp(base, Colors.white, 0.6)!)
      : (background: base.withValues(alpha: 0.12), foreground: base);
}

String priorityLabel(int priority) => switch (priority) {
      4 => 'P4 · Crítica',
      3 => 'P3 · Alta',
      2 => 'P2 · Média',
      _ => 'P1 · Baixa',
    };
