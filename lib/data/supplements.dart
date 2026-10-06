import '../models/profile.dart';

/// Un suplemento con su para qué sirve y cuándo tomarlo (información educativa).
class Supplement {
  final String name;
  final String emoji;
  final String benefit;
  final String timing;
  final List<Goal> goals;
  /// Clave de la foto en assets/supplements/<image>.jpg
  final String image;
  /// Condiciones con las que este suplemento requiere precaución (se muestra
  /// con aviso, no se oculta). Orientativo, no reemplaza a un profesional.
  final List<HealthCondition> cautionFor;
  final String? cautionNote;

  const Supplement(this.name, this.emoji, this.benefit, this.timing,
      this.goals, this.image,
      {this.cautionFor = const [], this.cautionNote});
}

/// Guía de suplementos de VigoriaFit. Información orientativa; ante dudas de salud,
/// consulta a un profesional.
class Supplements {
  Supplements._();

  static const List<Supplement> all = [
    Supplement(
      'Proteína de suero (whey)',
      '🥛',
      'Ayuda a llegar a tu proteína diaria y a recuperar el músculo.',
      'Después de entrenar o entre comidas.',
      [Goal.gainMuscle, Goal.loseFat, Goal.maintain],
      'whey_protein',
      cautionFor: [HealthCondition.enfermedadRenal],
      cautionNote: 'Con enfermedad renal, el exceso de proteína puede sobrecargar '
          'los riñones — consulta la dosis con tu médico.',
    ),
    Supplement(
      'Creatina monohidrato',
      '⚡',
      'Mejora fuerza y rendimiento. Es de los más estudiados y seguros.',
      '3-5 g al día, a cualquier hora (constante).',
      [Goal.gainMuscle, Goal.maintain],
      'creatine',
      cautionFor: [HealthCondition.enfermedadRenal],
      cautionNote: 'Se procesa por los riñones — con enfermedad renal, consulta '
          'antes de usarla.',
    ),
    Supplement(
      'Cafeína',
      '☕',
      'Da energía y foco antes de entrenar.',
      '30-45 min antes del ejercicio.',
      [Goal.loseFat, Goal.gainMuscle],
      'caffeine',
      cautionFor: [HealthCondition.hipertension],
      cautionNote: 'Puede subir la presión arterial de forma temporal — con '
          'hipertensión, mejor evitarla o consultar antes.',
    ),
    Supplement(
      'Omega-3',
      '🐟',
      'Apoya el corazón, articulaciones y recuperación.',
      'Con una comida del día.',
      [Goal.health, Goal.maintain, Goal.loseFat],
      'omega3',
    ),
    Supplement(
      'Multivitamínico',
      '💊',
      'Cubre vacíos de tu dieta si comes poco variado.',
      'Con el desayuno.',
      [Goal.health, Goal.maintain],
      'multivitamin',
    ),
    Supplement(
      'Vitamina D',
      '☀️',
      'Importante si tomas poco sol; apoya huesos y ánimo.',
      'Con una comida con grasa.',
      [Goal.health, Goal.maintain],
      'vitamin_d',
    ),
    Supplement(
      'Magnesio',
      '🌙',
      'Ayuda a la recuperación muscular y al sueño.',
      'En la noche.',
      [Goal.health, Goal.gainMuscle],
      'magnesium',
      cautionFor: [HealthCondition.enfermedadRenal],
      cautionNote: 'Con enfermedad renal el cuerpo elimina peor el magnesio — '
          'consulta antes de tomarlo.',
    ),
  ];

  /// Suplementos sugeridos para un objetivo, priorizando los que calzan.
  static List<Supplement> forGoal(Goal g) {
    final match = all.where((s) => s.goals.contains(g)).toList();
    final rest = all.where((s) => !s.goals.contains(g)).toList();
    return [...match, ...rest];
  }
}
