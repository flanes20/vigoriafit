/// Sistema de unidades y funciones de conversión y formato para VigoriaFit.
enum UnitSystem {
  metric,
  imperial;

  String get label => this == metric ? 'Métrico' : 'Imperial';
  String get description => this == metric ? 'kg, cm' : 'lb, ft/in';
  String get weightUnit => this == metric ? 'kg' : 'lb';
  String get heightUnit => this == metric ? 'cm' : 'ft/in';
}

/// Helper para conversiones matemáticas y formateo consistente de unidades.
class UnitHelper {
  const UnitHelper._();

  static const double kgToLbsFactor = 2.20462262;
  static const double cmToInchesFactor = 0.393700787;

  /// Convierte kilogramos a libras.
  static double kgToLbs(double kg) => kg * kgToLbsFactor;

  /// Convierte libras a kilogramos.
  static double lbsToKg(double lbs) => lbs / kgToLbsFactor;

  /// Convierte centímetros a pulgadas.
  static double cmToInches(double cm) => cm * cmToInchesFactor;

  /// Convierte pulgadas a centímetros.
  static double inchesToCm(double inches) => inches / cmToInchesFactor;

  /// Formatea un peso expresado canónicamente en kilogramos según el [system] elegido.
  static String formatWeight(
    double kg, {
    UnitSystem system = UnitSystem.metric,
    int decimals = 1,
  }) {
    if (system == UnitSystem.metric) {
      return kg == kg.roundToDouble()
          ? '${kg.round()} kg'
          : '${kg.toStringAsFixed(decimals)} kg';
    } else {
      final lbs = kgToLbs(kg);
      return lbs == lbs.roundToDouble()
          ? '${lbs.round()} lb'
          : '${lbs.toStringAsFixed(decimals)} lb';
    }
  }

  /// Formatea una diferencia de peso (ej. +1.5 kg / -3.3 lb).
  static String formatWeightDiff(
    double kgDiff, {
    UnitSystem system = UnitSystem.metric,
    int decimals = 1,
  }) {
    final absDiff = kgDiff.abs();
    final sign = kgDiff > 0 ? '+' : (kgDiff < 0 ? '-' : '');
    if (system == UnitSystem.metric) {
      return '$sign${absDiff.toStringAsFixed(decimals)} kg';
    } else {
      final lbsDiff = kgToLbs(absDiff);
      return '$sign${lbsDiff.toStringAsFixed(decimals)} lb';
    }
  }

  /// Formatea una estatura expresada canónicamente en centímetros según el [system].
  static String formatHeight(
    double cm, {
    UnitSystem system = UnitSystem.metric,
  }) {
    if (system == UnitSystem.metric) {
      return '${cm.round()} cm';
    } else {
      final totalInches = (cm / 2.54).round();
      final feet = totalInches ~/ 12;
      final inches = totalInches % 12;
      return "$feet'$inches\"";
    }
  }
}
