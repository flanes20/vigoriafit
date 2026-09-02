import 'dart:convert';

/// Un día dentro del plan semanal generado por la IA.
class DayPlan {
  final String day; // "Lunes", "Martes", ...
  final String focus; // ej: "Tren superior" o "Descanso activo"
  final String workoutTip; // consejo breve de entrenamiento
  final String mealTip; // consejo breve de alimentación

  DayPlan(this.day, this.focus, this.workoutTip, this.mealTip);

  Map<String, dynamic> toMap() =>
      {'d': day, 'f': focus, 'w': workoutTip, 'm': mealTip};

  factory DayPlan.fromMap(Map<String, dynamic> m) => DayPlan(
        m['d'] ?? '',
        m['f'] ?? '',
        m['w'] ?? '',
        m['m'] ?? '',
      );
}

/// Un plan semanal completo generado por la IA para el perfil del usuario.
class WeekPlan {
  final DateTime generatedAt;
  final List<DayPlan> days;

  WeekPlan(this.generatedAt, this.days);

  /// True si el plan tiene más de 7 días de antigüedad (conviene regenerarlo).
  bool get isStale =>
      DateTime.now().difference(generatedAt).inDays >= 7;

  Map<String, dynamic> toMap() => {
        'g': generatedAt.toIso8601String(),
        'days': days.map((d) => d.toMap()).toList(),
      };

  factory WeekPlan.fromMap(Map<String, dynamic> m) => WeekPlan(
        DateTime.parse(m['g']),
        (m['days'] as List)
            .map((e) => DayPlan.fromMap(e as Map<String, dynamic>))
            .toList(),
      );

  String toJson() => jsonEncode(toMap());
  factory WeekPlan.fromJson(String s) =>
      WeekPlan.fromMap(jsonDecode(s) as Map<String, dynamic>);
}
