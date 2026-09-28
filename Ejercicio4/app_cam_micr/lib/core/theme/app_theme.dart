import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

enum AppPalette {
  guinda('Guinda IPN', Color(0xFF6C1D45)),
  azul('Azul ESCOM', Color(0xFF003B71));

  const AppPalette(this.label, this.seed);
  final String label;
  final Color seed;
}

/// Material Design 3 con la misma configuración en iOS y Android para que
/// la interfaz sea consistente en ambas plataformas.
class AppTheme {
  AppTheme._();

  static ThemeData light(AppPalette palette) => _build(palette, Brightness.light);
  static ThemeData dark(AppPalette palette) => _build(palette, Brightness.dark);

  static ThemeData _build(AppPalette palette, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.seed,
      brightness: brightness,
      // "fidelity" respeta el tono real del guinda/azul institucional.
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
