import '../services/store.dart';

/// Un logro desbloqueable. [check] mira el estado actual del store y decide
/// si ya se cumplió, así no hay que guardar flags aparte: se derivan solas.
class Achievement {
  final String id;
  final String emoji;
  final String title;
  final String desc;
  final bool Function(AppStore s) check;

  const Achievement(this.id, this.emoji, this.title, this.desc, this.check);
}

/// Catálogo de logros de VigoriaFit.
class Achievements {
  Achievements._();

  static final List<Achievement> all = [
    Achievement('first_workout', '🥇', 'Primer paso', 'Completa tu primer entrenamiento.',
        (s) => s.totalWorkoutsDone >= 1),
    Achievement('workouts_10', '💪', 'En marcha', 'Completa 10 entrenamientos.',
        (s) => s.totalWorkoutsDone >= 10),
    Achievement('workouts_50', '🏋️', 'Imparable', 'Completa 50 entrenamientos.',
        (s) => s.totalWorkoutsDone >= 50),
    Achievement('streak_3', '🔥', 'Prendiendo la mecha', 'Racha de 3 días seguidos.',
        (s) => s.streak >= 3),
    Achievement('streak_7', '🔥', 'Una semana completa', 'Racha de 7 días seguidos.',
        (s) => s.streak >= 7),
    Achievement('streak_30', '🌟', 'Hábito de verdad', 'Racha de 30 días seguidos.',
        (s) => s.streak >= 30),
    Achievement('scan_first', '📸', 'Ojo de nutricionista', 'Escanea tu primera comida con IA.',
        (s) => s.totalFoodsLogged >= 1),
    Achievement('scan_20', '🍽️', 'Registro al día', 'Escanea 20 comidas.',
        (s) => s.totalFoodsLogged >= 20),
    Achievement('water_7', '💧', 'Bien hidratado', 'Toma agua 7 días distintos.',
        (s) => s.totalWaterDays >= 7),
    Achievement('weight_5', '📈', 'Seguimiento real', 'Registra tu peso 5 veces.',
        (s) => s.weights.length >= 5),
    Achievement('level_5', '🏆', 'Nivel 5', 'Alcanza el nivel 5 en VigoriaFit.',
        (s) => s.level >= 5),
    Achievement('level_10', '👑', 'Leyenda VigoriaFit', 'Alcanza el nivel 10 en VigoriaFit.',
        (s) => s.level >= 10),
  ];

  static List<Achievement> unlocked(AppStore s) =>
      all.where((a) => a.check(s)).toList();

  static List<Achievement> locked(AppStore s) =>
      all.where((a) => !a.check(s)).toList();
}
