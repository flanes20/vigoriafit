import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/store.dart';

/// Identidad visual de VigoriaFit: energética y saludable, con tema claro/oscuro.
///
/// Los colores dependientes del tema son *getters* que leen [AppColors.dark].
class AppColors {
  AppColors._();

  /// Se calcula en cada lectura a partir de [AppStore.themeMode] (y del
  /// brillo del sistema si está en "Sistema") — nunca queda una bandera
  /// vieja pegada de antes de un cambio de tema o de una pantalla anterior,
  /// que era la causa de que algunas pantallas mostraran colores mezclados.
  static bool get dark {
    final mode = AppStore.instance.themeMode;
    if (mode == ThemeMode.dark) return true;
    if (mode == ThemeMode.light) return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }

  // Marca y semánticos (constantes).
  static const Color brand = Color(0xFFF15A36); // coral energético
  static const Color brandDark = Color(0xFFC63C22);
  static const Color mint = Color(0xFF14B8A6); // salud / hidratación
  static const Color water = Color(0xFF3B82F6);
  static const Color protein = Color(0xFF8B5CF6);
  static const Color success = Color(0xFF22C55E);
  static const Color warn = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFE5544B);

  static const List<Color> palette = [
    Color(0xFFF15A36),
    Color(0xFF14B8A6),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF64748B),
  ];

  // Dependientes del tema.
  static Color get bg =>
      dark ? const Color(0xFF14110F) : const Color(0xFFFAF7F5);
  static Color get surface =>
      dark ? const Color(0xFF1F1B18) : const Color(0xFFFFFFFF);
  static Color get surfaceAlt =>
      dark ? const Color(0xFF272220) : const Color(0xFFF3EEEA);
  static Color get ink =>
      dark ? const Color(0xFFF5F0EC) : const Color(0xFF1C1917);
  static Color get muted =>
      dark ? const Color(0xFFA8A29E) : const Color(0xFF78716C);
  static Color get faint =>
      dark ? const Color(0xFF7C756F) : const Color(0xFF9C948E);
  static Color get line =>
      dark ? const Color(0xFF33302C) : const Color(0xFFECE7E3);
  static Color get brandSoft =>
      dark ? const Color(0xFF3A2018) : const Color(0xFFFDE8E2);
  static Color get mintSoft =>
      dark ? const Color(0xFF10312D) : const Color(0xFFDBF5F1);
}

class AppTheme {
  AppTheme._();

  static ThemeData _base(Brightness b, Color bg, Color surface, Color line) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brand,
        brightness: b,
        primary: AppColors.brand,
        surface: surface,
      ),
      scaffoldBackgroundColor: bg,
      fontFamily: 'Roboto',
    );
    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: b == Brightness.dark
            ? const Color(0xFFF5F0EC)
            : const Color(0xFF1C1917),
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: line),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          textStyle:
              const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.6),
        ),
      ),
    );
  }

  static ThemeData get light => _base(Brightness.light, const Color(0xFFFAF7F5),
      const Color(0xFFFFFFFF), const Color(0xFFECE7E3));

  static ThemeData get dark => _base(Brightness.dark, const Color(0xFF14110F),
      const Color(0xFF1F1B18), const Color(0xFF33302C));
}

/// Utilidades de formato en español (Chile).
class Fmt {
  Fmt._();
  static String date(DateTime d) => DateFormat("EEEE d 'de' MMMM", 'es').format(d);
  static String shortDate(DateTime d) => DateFormat('d MMM', 'es').format(d);
  static String weekday(DateTime d) => DateFormat('EEE', 'es').format(d);
}
