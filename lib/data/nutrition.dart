import '../models/profile.dart';

enum MealType { desayuno, almuerzo, snack, cena }

extension MealTypeX on MealType {
  String get label => switch (this) {
    MealType.desayuno => 'Desayuno',
    MealType.almuerzo => 'Almuerzo',
    MealType.snack => 'Snack',
    MealType.cena => 'Cena',
  };
  String get emoji => switch (this) {
    MealType.desayuno => '🌅',
    MealType.almuerzo => '🍽️',
    MealType.snack => '🍎',
    MealType.cena => '🌙',
  };
}

/// Una idea de comida con calorías y proteína aproximadas.
class MealIdea {
  final String name;
  final int kcal;
  final int protein; // g
  final MealType type;
  final List<Goal> goals;

  /// Clave de la foto en assets/food/[image].jpg
  final String image;

  /// Alérgenos que contiene (para ocultarla si el usuario es alérgico).
  final List<Allergy> allergens;

  /// Notas dietéticas simples usadas para condiciones de salud
  /// (`highSugar`, `highPotassium`). Orientativo, no clínico.
  final List<String> dietFlags;

  const MealIdea(
    this.name,
    this.kcal,
    this.protein,
    this.type,
    this.goals,
    this.image, {
    this.allergens = const [],
    this.dietFlags = const [],
  });
}

/// Ideas de comida con base chilena, orientativas.
class Nutrition {
  Nutrition._();

  static const List<MealIdea> all = [
    // Desayunos
    MealIdea(
      'Huevos revueltos con palta y pan integral',
      380,
      22,
      MealType.desayuno,
      [Goal.gainMuscle, Goal.maintain, Goal.health],
      'eggs_avocado_toast',
      allergens: [Allergy.huevo, Allergy.gluten],
    ),
    MealIdea(
      'Yogurt natural con avena y fruta',
      300,
      18,
      MealType.desayuno,
      [Goal.loseFat, Goal.health, Goal.maintain],
      'yogurt_oats_fruit',
      allergens: [Allergy.lactosa],
    ),
    MealIdea(
      'Tostadas integrales con queso fresco y tomate',
      320,
      16,
      MealType.desayuno,
      [Goal.loseFat, Goal.maintain],
      'toast_cheese_tomato',
      allergens: [Allergy.gluten, Allergy.lactosa],
    ),
    MealIdea(
      'Batido de plátano, leche y avena',
      350,
      20,
      MealType.desayuno,
      [Goal.gainMuscle],
      'banana_oat_smoothie',
      allergens: [Allergy.lactosa],
      dietFlags: ['highSugar'],
    ),
    MealIdea(
      'Bowl de chía con fruta de estación y semillas',
      290,
      12,
      MealType.desayuno,
      [Goal.health, Goal.loseFat, Goal.maintain, Goal.gainMuscle],
      'yogurt_oats_fruit',
    ),
    MealIdea(
      'Papas doradas al romero con palta y tomate cherry',
      340,
      10,
      MealType.desayuno,
      [Goal.gainMuscle, Goal.maintain, Goal.health],
      'toast_cheese_tomato',
    ),
    // Almuerzos
    MealIdea(
      'Pollo a la plancha con arroz y ensalada',
      520,
      40,
      MealType.almuerzo,
      [Goal.gainMuscle, Goal.maintain, Goal.health, Goal.loseFat],
      'chicken_rice_salad',
    ),
    MealIdea(
      'Carne magra con puré de papas y verduras',
      560,
      38,
      MealType.almuerzo,
      [Goal.gainMuscle, Goal.maintain],
      'beef_mash_veggies',
      allergens: [Allergy.lactosa],
    ),
    MealIdea(
      'Ensalada grande con atún y huevo',
      380,
      32,
      MealType.almuerzo,
      [Goal.loseFat, Goal.health],
      'tuna_egg_salad',
      allergens: [Allergy.huevo, Allergy.mariscos],
    ),
    MealIdea(
      'Porotos con riendas (porción moderada)',
      450,
      20,
      MealType.almuerzo,
      [Goal.maintain, Goal.health],
      'beans_stew',
      dietFlags: ['highPotassium'],
    ),
    MealIdea(
      'Salmón al horno con quinoa y brócoli',
      540,
      36,
      MealType.almuerzo,
      [Goal.health, Goal.gainMuscle, Goal.maintain],
      'salmon_quinoa_broccoli',
    ),
    // Snacks
    MealIdea(
      'Puñado de almendras',
      160,
      6,
      MealType.snack,
      [Goal.health, Goal.maintain, Goal.gainMuscle],
      'almonds',
      allergens: [Allergy.frutosSecos],
    ),
    MealIdea(
      'Manzana con mantequilla de maní',
      200,
      6,
      MealType.snack,
      [Goal.maintain, Goal.health],
      'apple_peanut_butter',
      allergens: [Allergy.frutosSecos],
    ),
    MealIdea(
      'Yogurt griego con miel',
      180,
      15,
      MealType.snack,
      [Goal.gainMuscle, Goal.loseFat],
      'greek_yogurt_honey',
      allergens: [Allergy.lactosa],
      dietFlags: ['highSugar'],
    ),
    MealIdea('Zanahoria y apio con hummus', 130, 5, MealType.snack, [
      Goal.loseFat,
      Goal.health,
      Goal.maintain,
      Goal.gainMuscle,
    ], 'carrot_celery_hummus'),
    MealIdea(
      'Mix de frutas frescas con semillas de girasol',
      150,
      5,
      MealType.snack,
      [Goal.health, Goal.maintain, Goal.loseFat],
      'apple_peanut_butter',
    ),
    // Cenas
    MealIdea(
      'Tortilla de verduras con ensalada',
      340,
      20,
      MealType.cena,
      [Goal.loseFat, Goal.health, Goal.maintain],
      'veggie_omelette',
      allergens: [Allergy.huevo],
    ),
    MealIdea(
      'Pechuga de pollo con verduras salteadas',
      400,
      38,
      MealType.cena,
      [Goal.gainMuscle, Goal.loseFat, Goal.health, Goal.maintain],
      'chicken_sauteed_veggies',
    ),
    MealIdea(
      'Sopa de verduras con pan integral',
      300,
      12,
      MealType.cena,
      [Goal.loseFat, Goal.health],
      'veggie_soup_bread',
      allergens: [Allergy.gluten],
    ),
    MealIdea(
      'Salteado de zapallo italiano, champiñones y pavo',
      320,
      32,
      MealType.cena,
      [Goal.loseFat, Goal.health, Goal.maintain, Goal.gainMuscle],
      'veggie_soup_bread',
    ),
  ];

  /// Obtiene opciones de comidas para un objetivo y tipo de comida.
  /// Garantiza que NUNCA se devuelvan alimentos descartados por alergias,
  /// condiciones médicas o exclusiones del usuario, aun cuando no existan
  /// alternativas exactas para el objetivo (#98).
  static List<MealIdea> forGoalAndType(
    Goal g,
    MealType t, {
    Profile? profile,
    Set<String>? excludedNames,
  }) {
    if (profile == null && (excludedNames == null || excludedNames.isEmpty)) {
      final list = all.where((m) => m.type == t && m.goals.contains(g)).toList();
      return list.isNotEmpty ? list : all.where((m) => m.type == t).toList();
    }

    // 1. Filtrar por tipo y objetivo, verificando seguridad estricta
    final goalMatches = all
        .where((m) =>
            m.type == t &&
            m.goals.contains(g) &&
            isSafe(m, profile, excludedNames: excludedNames))
        .toList();
    if (goalMatches.isNotEmpty) return goalMatches;

    // 2. Si no hay alternativas seguras para ese objetivo específico,
    // buscar alternativas seguras de ese tipo de comida en OTROS objetivos
    final otherGoalMatches = all
        .where((m) =>
            m.type == t &&
            isSafe(m, profile, excludedNames: excludedNames))
        .toList();
    if (otherGoalMatches.isNotEmpty) return otherGoalMatches;

    // 3. Si aún así no hay alternativas seguras en la base de datos (por ejemplo,
    // alergias múltiples severas que descartan todas las comidas existentes),
    // NUNCA devolver comidas descartadas/inseguras (#98). En su lugar,
    // devolver una alternativa segura garantizada.
    return [safeFallbackFor(t, profile)];
  }

  /// Verifica si una comida es segura para el perfil médico y de alergias del usuario.
  static bool isSafe(
    MealIdea m,
    Profile? p, {
    Set<String>? excludedNames,
  }) {
    if (excludedNames != null && excludedNames.contains(m.name)) return false;
    if (p == null) return true;

    // Filtro por alergias (lactosa, gluten, frutos secos, mariscos, huevo, soya)
    if (m.allergens.any(p.allergies.contains)) return false;

    // Filtros por condiciones de salud
    if (m.dietFlags.contains('highSugar') &&
        (p.conditions.contains(HealthCondition.diabetes) ||
            p.conditions.contains(HealthCondition.prediabetes))) {
      return false;
    }
    if (m.dietFlags.contains('highPotassium') &&
        p.conditions.contains(HealthCondition.enfermedadRenal)) {
      return false;
    }
    if (m.dietFlags.contains('highSodium') &&
        p.conditions.contains(HealthCondition.hipertension)) {
      return false;
    }
    if (m.dietFlags.contains('irritant') &&
        p.conditions.contains(HealthCondition.gastritisReflujo)) {
      return false;
    }
    return true;
  }

  /// Alternativa segura universal en caso de descarte total por múltiples restricciones.
  static MealIdea safeFallbackFor(MealType t, [Profile? profile]) {
    switch (t) {
      case MealType.desayuno:
        return const MealIdea(
          'Bowl de chía con fruta fresca y semillas',
          320,
          12,
          MealType.desayuno,
          Goal.values,
          'banana_oat_smoothie',
          allergens: [],
          dietFlags: [],
        );
      case MealType.almuerzo:
        return const MealIdea(
          'Pechuga a la plancha con arroz blanco y ensalada verde',
          480,
          38,
          MealType.almuerzo,
          Goal.values,
          'chicken_rice_salad',
          allergens: [],
          dietFlags: [],
        );
      case MealType.snack:
        return const MealIdea(
          'Fruta fresca picada con semillas de zapallo',
          140,
          5,
          MealType.snack,
          Goal.values,
          'carrot_celery_hummus',
          allergens: [],
          dietFlags: [],
        );
      case MealType.cena:
        return const MealIdea(
          'Pollo al horno con verduras al vapor',
          380,
          36,
          MealType.cena,
          Goal.values,
          'chicken_sauteed_veggies',
          allergens: [],
          dietFlags: [],
        );
    }
  }

  /// Un menú del día (1 idea por tipo de comida) para el objetivo, filtrado
  /// estrictamente por alergias/condiciones y descartes del usuario (#98).
  static Map<MealType, MealIdea> dayMenu(
    Goal g, {
    int seed = 0,
    Profile? profile,
    Set<String>? excludedNames,
  }) {
    final menu = <MealType, MealIdea>{};
    for (final t in MealType.values) {
      final opts = forGoalAndType(
        g,
        t,
        profile: profile,
        excludedNames: excludedNames,
      );
      menu[t] = opts[seed % opts.length];
    }
    return menu;
  }

  static const List<String> tips = [
    'Toma agua antes de cada comida: ayuda a la saciedad. 💧',
    'Prioriza proteína en cada comida para cuidar tu músculo.',
    'Verduras a la mitad del plato: llenan y aportan fibra. 🥦',
    'El mejor "quemagrasa" es dormir bien y moverte a diario.',
    'No existe la comida prohibida: es cosa de porciones y frecuencia.',
    'Camina 8.000-10.000 pasos al día; suma más de lo que crees. 🚶',
  ];
}
