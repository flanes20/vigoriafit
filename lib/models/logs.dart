import 'dart:convert';

/// Registro de peso en una fecha (para el gráfico de progreso).
class WeightEntry {
  final DateTime date;
  final double kg;

  WeightEntry(this.date, this.kg);

  Map<String, dynamic> toMap() =>
      {'d': date.toIso8601String(), 'kg': kg};

  factory WeightEntry.fromMap(Map<String, dynamic> m) =>
      WeightEntry(DateTime.parse(m['d']), (m['kg']).toDouble());

  String toJson() => jsonEncode(toMap());
  factory WeightEntry.fromJson(String s) =>
      WeightEntry.fromMap(jsonDecode(s));
}

/// Una comida registrada en el día (nombre + calorías y proteína estimadas).
class FoodEntry {
  final String name;
  final int kcal;
  final int protein;

  FoodEntry(this.name, this.kcal, this.protein);

  Map<String, dynamic> toMap() => {'n': name, 'k': kcal, 'p': protein};
  factory FoodEntry.fromMap(Map<String, dynamic> m) =>
      FoodEntry(m['n'] ?? '', m['k'] ?? 0, m['p'] ?? 0);
}

/// Registro diario de hábitos: agua, entrenamientos y comidas registradas.
class DayLog {
  final String dateKey; // yyyy-MM-dd
  int water; // vasos de agua
  List<String> workouts; // ids de rutinas completadas ese día
  List<FoodEntry> foods; // comidas registradas (escáner IA o manual)

  DayLog(this.dateKey,
      {this.water = 0, List<String>? workouts, List<FoodEntry>? foods})
      : workouts = workouts ?? [],
        foods = foods ?? [];

  int get kcal => foods.fold(0, (s, e) => s + e.kcal);
  int get protein => foods.fold(0, (s, e) => s + e.protein);

  Map<String, dynamic> toMap() => {
        'k': dateKey,
        'w': water,
        'wo': workouts,
        'f': foods.map((e) => e.toMap()).toList(),
      };

  factory DayLog.fromMap(Map<String, dynamic> m) => DayLog(
        m['k'],
        water: m['w'] ?? 0,
        workouts: (m['wo'] as List?)?.map((e) => e.toString()).toList() ?? [],
        foods: (m['f'] as List?)
                ?.map((e) => FoodEntry.fromMap(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  String toJson() => jsonEncode(toMap());
  factory DayLog.fromJson(String s) => DayLog.fromMap(jsonDecode(s));
}

/// Clave de fecha estable (yyyy-MM-dd) para indexar los registros diarios.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
