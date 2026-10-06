/// Un registro de "hoy levanté X kg" en un ejercicio puntual, para ver
/// progreso (sobrecarga progresiva) a lo largo del tiempo. `sets`/`reps` son
/// opcionales porque los registros antiguos solo guardaban el peso.
class ExerciseWeightEntry {
  final DateTime date;
  final double kg;
  final int? sets;
  final int? reps;

  ExerciseWeightEntry(this.date, this.kg, {this.sets, this.reps});

  Map<String, dynamic> toMap() => {
        'd': date.toIso8601String(),
        'k': kg,
        if (sets != null) 's': sets,
        if (reps != null) 'r': reps,
      };

  factory ExerciseWeightEntry.fromMap(Map<String, dynamic> m) =>
      ExerciseWeightEntry(
        DateTime.parse(m['d'] as String),
        (m['k'] as num).toDouble(),
        sets: (m['s'] as num?)?.toInt(),
        reps: (m['r'] as num?)?.toInt(),
      );
}

/// Sugerencia de progresión automática (sobrecarga progresiva) para un
/// ejercicio, calculada a partir de su historial de pesos.
class ExerciseSuggestion {
  final String message;
  /// Peso sugerido para la próxima vez, o null si aún no hay suficiente
  /// historial para sugerir un número.
  final double? kg;

  ExerciseSuggestion(this.message, this.kg);
}
