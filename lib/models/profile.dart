import 'dart:convert';
import 'package:flutter/material.dart';

/// Objetivo de salud del usuario. Define rutinas, metas y consejos.
enum Goal { loseFat, gainMuscle, maintain, health }

extension GoalX on Goal {
  String get label => switch (this) {
        Goal.loseFat => 'Bajar grasa',
        Goal.gainMuscle => 'Subir masa',
        Goal.maintain => 'Mantenerme',
        Goal.health => 'Salud general',
      };

  String get emoji => switch (this) {
        Goal.loseFat => '🔥',
        Goal.gainMuscle => '💪',
        Goal.maintain => '⚖️',
        Goal.health => '🌱',
      };

  IconData get icon => switch (this) {
        Goal.loseFat => Icons.local_fire_department_rounded,
        Goal.gainMuscle => Icons.fitness_center_rounded,
        Goal.maintain => Icons.balance_rounded,
        Goal.health => Icons.favorite_rounded,
      };

  String get desc => switch (this) {
        Goal.loseFat => 'Perder grasa cuidando tu masa muscular.',
        Goal.gainMuscle => 'Ganar músculo y fuerza de a poco.',
        Goal.maintain => 'Mantener tu peso y estar activo.',
        Goal.health => 'Sentirte mejor, con más energía.',
      };
}

/// Nivel de experiencia entrenando.
enum Level { beginner, intermediate, advanced }

extension LevelX on Level {
  String get label => switch (this) {
        Level.beginner => 'Principiante',
        Level.intermediate => 'Intermedio',
        Level.advanced => 'Avanzado',
      };

  String get desc => switch (this) {
        Level.beginner => 'Recién parto o vuelvo después de harto.',
        Level.intermediate => 'Entreno hace algunos meses.',
        Level.advanced => 'Llevo años, sé lo que hago.',
      };
}

/// Condición de salud que el usuario puede marcar en su perfil. Se usa para
/// filtrar comidas/suplementos/ejercicios y darle contexto al Coach — es
/// orientativo, no reemplaza a un profesional de la salud.
enum HealthCondition {
  diabetes,
  prediabetes,
  hipertension,
  colesterolAlto,
  hipotiroidismo,
  gastritisReflujo,
  enfermedadRenal,
  lesionRodilla,
  lesionEspalda,
}

extension HealthConditionX on HealthCondition {
  String get label => switch (this) {
        HealthCondition.diabetes => 'Diabetes',
        HealthCondition.prediabetes => 'Prediabetes',
        HealthCondition.hipertension => 'Hipertensión',
        HealthCondition.colesterolAlto => 'Colesterol alto',
        HealthCondition.hipotiroidismo => 'Hipotiroidismo',
        HealthCondition.gastritisReflujo => 'Gastritis / reflujo',
        HealthCondition.enfermedadRenal => 'Enfermedad renal',
        HealthCondition.lesionRodilla => 'Lesión de rodilla',
        HealthCondition.lesionEspalda => 'Lesión de espalda',
      };
}

/// Alergia o intolerancia alimentaria.
enum Allergy { lactosa, gluten, frutosSecos, mariscos, huevo, soya }

extension AllergyX on Allergy {
  String get label => switch (this) {
        Allergy.lactosa => 'Lactosa',
        Allergy.gluten => 'Gluten',
        Allergy.frutosSecos => 'Frutos secos',
        Allergy.mariscos => 'Mariscos',
        Allergy.huevo => 'Huevo',
        Allergy.soya => 'Soya',
      };
}

/// Perfil del usuario: datos y preferencias que personalizan toda la app.
class Profile {
  String name;
  Goal goal;
  Level level;
  int age;
  double heightCm;
  double weightKg;
  double targetWeightKg;
  int daysPerWeek;
  bool hasGym;
  List<HealthCondition> conditions;
  List<Allergy> allergies;
  int? customKcal;
  int? customProtein;
  int? customCarbs;
  int? customFat;

  Profile({
    this.name = '',
    this.goal = Goal.health,
    this.level = Level.beginner,
    this.age = 20,
    this.heightCm = 170,
    this.weightKg = 70,
    this.targetWeightKg = 70,
    this.daysPerWeek = 3,
    this.hasGym = false,
    List<HealthCondition>? conditions,
    List<Allergy>? allergies,
    this.customKcal,
    this.customProtein,
    this.customCarbs,
    this.customFat,
  })  : conditions = conditions ?? [],
        allergies = allergies ?? [];

  /// IMC (peso / altura²).
  double get bmi => weightKg / ((heightCm / 100) * (heightCm / 100));

  String get bmiLabel {
    final v = bmi;
    if (v < 18.5) return 'Bajo peso';
    if (v < 25) return 'Peso normal';
    if (v < 30) return 'Sobrepeso';
    return 'Obesidad';
  }

  /// Estimación simple de calorías diarias (Mifflin-St Jeor, actividad media,
  /// ajustada por objetivo), o meta personalizada si el usuario la definió.
  int get dailyKcal {
    if (customKcal != null && customKcal! > 0) return customKcal!;
    final bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5;
    final maintenance = bmr * (1.2 + daysPerWeek * 0.06);
    final adj = switch (goal) {
      Goal.loseFat => -0.18,
      Goal.gainMuscle => 0.12,
      _ => 0.0,
    };
    return (maintenance * (1 + adj)).round();
  }

  /// Proteína diaria recomendada (g), según objetivo o meta personalizada.
  int get proteinGrams {
    if (customProtein != null && customProtein! > 0) return customProtein!;
    final perKg = switch (goal) {
      Goal.gainMuscle => 2.0,
      Goal.loseFat => 1.8,
      _ => 1.5,
    };
    return (weightKg * perKg).round();
  }

  /// Grasas diarias recomendadas (g) (~25% de calorías diarias, 9 kcal/g).
  int get fatGrams {
    if (customFat != null && customFat! > 0) return customFat!;
    return ((dailyKcal * 0.25) / 9).round().clamp(25, 120);
  }

  /// Carbohidratos diarios recomendados (g) (resto calórico, 4 kcal/g).
  int get carbsGrams {
    if (customCarbs != null && customCarbs! > 0) return customCarbs!;
    final rem = dailyKcal - (proteinGrams * 4) - (fatGrams * 9);
    final val = rem > 0 ? (rem / 4).round() : 50;
    return val.clamp(30, 400);
  }

  /// Vasos de agua diarios sugeridos (~2.2 L de base).
  int get waterGoal => 8;

  Map<String, dynamic> toMap() => {
        'name': name,
        'goal': goal.index,
        'level': level.index,
        'age': age,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'targetWeightKg': targetWeightKg,
        'daysPerWeek': daysPerWeek,
        'hasGym': hasGym,
        'conditions': conditions.map((c) => c.index).toList(),
        'allergies': allergies.map((a) => a.index).toList(),
        if (customKcal != null) 'customKcal': customKcal,
        if (customProtein != null) 'customProtein': customProtein,
        if (customCarbs != null) 'customCarbs': customCarbs,
        if (customFat != null) 'customFat': customFat,
      };

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        name: m['name'] ?? '',
        goal: Goal.values[(m['goal'] ?? 3).clamp(0, 3)],
        level: Level.values[(m['level'] ?? 0).clamp(0, 2)],
        age: (m['age'] ?? 20),
        heightCm: (m['heightCm'] ?? 170).toDouble(),
        weightKg: (m['weightKg'] ?? 70).toDouble(),
        targetWeightKg: (m['targetWeightKg'] ?? 70).toDouble(),
        daysPerWeek: (m['daysPerWeek'] ?? 3),
        hasGym: m['hasGym'] ?? false,
        conditions: ((m['conditions'] as List?) ?? [])
            .map((i) => HealthCondition.values[(i as int).clamp(0, HealthCondition.values.length - 1)])
            .toList(),
        allergies: ((m['allergies'] as List?) ?? [])
            .map((i) => Allergy.values[(i as int).clamp(0, Allergy.values.length - 1)])
            .toList(),
        customKcal: m['customKcal'] as int?,
        customProtein: m['customProtein'] as int?,
        customCarbs: m['customCarbs'] as int?,
        customFat: m['customFat'] as int?,
      );

  String toJson() => jsonEncode(toMap());
  factory Profile.fromJson(String s) =>
      Profile.fromMap(jsonDecode(s) as Map<String, dynamic>);

  Profile copy() => Profile.fromMap(toMap());
}
