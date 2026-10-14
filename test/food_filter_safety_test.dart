import 'package:flutter_test/flutter_test.dart';
import 'package:vigoriafit/data/nutrition.dart';
import 'package:vigoriafit/models/profile.dart';

/// Tests del Paso 7 (Bug #98) — Corrección del fallo que vuelve a mostrar
/// alimentos descartados cuando el filtro no encuentra alternativas.
void main() {
  group('Paso 7 (Bug #98) — Filtrado estricto de alimentos y descarte seguro', () {
    test('1. Alimentos descartados por alergia NUNCA se muestran en el menú', () {
      final allergicProfile = Profile(
        allergies: [Allergy.lactosa, Allergy.gluten],
      );

      // Para todos los objetivos y comidas del día
      for (final goal in Goal.values) {
        final menu = Nutrition.dayMenu(goal, profile: allergicProfile);
        for (final entry in menu.entries) {
          final meal = entry.value;

          // Ninguna comida del menú puede tener lactosa ni gluten
          expect(
            meal.allergens.contains(Allergy.lactosa),
            isFalse,
            reason: '${meal.name} contiene lactosa y debió descartarse.',
          );
          expect(
            meal.allergens.contains(Allergy.gluten),
            isFalse,
            reason: '${meal.name} contiene gluten y debió descartarse.',
          );
          expect(
            Nutrition.isSafe(meal, allergicProfile),
            isTrue,
            reason: '${meal.name} no es segura para el perfil.',
          );
        }
      }
    });

    test('2. Si el objetivo específico no tiene alternativas seguras, busca en otros objetivos antes de fallar', () {
      // Perfil con alergia a huevo y gluten, con meta ganar músculo
      final profile = Profile(
        goal: Goal.gainMuscle,
        allergies: [Allergy.huevo, Allergy.gluten],
      );

      // Desayunos para gainMuscle originalmente tenían huevos revueltos (huevo+gluten)
      // Debe encontrar alternativas seguras de desayuno (por ejemplo bowl de chía o batido)
      final options = Nutrition.forGoalAndType(
        Goal.gainMuscle,
        MealType.desayuno,
        profile: profile,
      );

      expect(options, isNotEmpty);
      for (final m in options) {
        expect(m.allergens.contains(Allergy.huevo), isFalse);
        expect(m.allergens.contains(Allergy.gluten), isFalse);
      }
    });

    test('3. Bug #98: Descarte total no reintroduce alimentos descartados', () {
      // Perfil con TODAS las alergias activas
      final multiAllergicProfile = Profile(
        allergies: Allergy.values.toList(),
        conditions: [HealthCondition.diabetes, HealthCondition.enfermedadRenal],
      );

      // En el pasado, si no había alternativas, retornaba la lista original con alérgenos.
      // Ahora debe retornar opciones estrictamente seguras o el fallback hipoalergénico.
      for (final type in MealType.values) {
        final options = Nutrition.forGoalAndType(
          Goal.loseFat,
          type,
          profile: multiAllergicProfile,
        );

        expect(options, isNotEmpty);
        for (final meal in options) {
          // NUNCA debe contener ninguno de los alérgenos descartados
          for (final a in multiAllergicProfile.allergies) {
            expect(
              meal.allergens.contains(a),
              isFalse,
              reason: 'Fallo Bug #98: ${meal.name} contiene $a descartado.',
            );
          }
          // NUNCA debe violar condiciones médicas
          expect(meal.dietFlags.contains('highSugar'), isFalse);
          expect(meal.dietFlags.contains('highPotassium'), isFalse);
          expect(Nutrition.isSafe(meal, multiAllergicProfile), isTrue);
        }
      }
    });

    test('4. Alimentos descartados individualmente (excludedNames) nunca se devuelven', () {
      final p = Profile();
      const disliked = 'Huevos revueltos con palta y pan integral';

      final options = Nutrition.forGoalAndType(
        Goal.maintain,
        MealType.desayuno,
        profile: p,
        excludedNames: {disliked},
      );

      expect(options.any((m) => m.name == disliked), isFalse);

      final menu = Nutrition.dayMenu(
        Goal.maintain,
        profile: p,
        excludedNames: {disliked},
      );
      expect(menu[MealType.desayuno]!.name, isNot(equals(disliked)));
    });

    test('5. Filtros médicos de condiciones: diabetes y enfermedad renal descartan dietFlags de riesgo', () {
      final diabeticProfile = Profile(
        conditions: [HealthCondition.diabetes],
      );
      final renalProfile = Profile(
        conditions: [HealthCondition.enfermedadRenal],
      );

      // Comidas con highSugar descartadas para diabetes
      final diabeticBreakfasts = Nutrition.forGoalAndType(
        Goal.gainMuscle,
        MealType.desayuno,
        profile: diabeticProfile,
      );
      for (final m in diabeticBreakfasts) {
        expect(m.dietFlags.contains('highSugar'), isFalse);
      }

      // Comidas con highPotassium descartadas para renal
      final renalLunches = Nutrition.forGoalAndType(
        Goal.maintain,
        MealType.almuerzo,
        profile: renalProfile,
      );
      for (final m in renalLunches) {
        expect(m.dietFlags.contains('highPotassium'), isFalse);
      }
    });

    test('6. safeFallbackFor garantiza comidas 100% libres de alérgenos y dietFlags', () {
      for (final type in MealType.values) {
        final fallback = Nutrition.safeFallbackFor(type);
        expect(fallback.type, type);
        expect(fallback.allergens, isEmpty);
        expect(fallback.dietFlags, isEmpty);
        expect(fallback.name, isNotEmpty);
        expect(fallback.kcal, greaterThan(0));
        expect(fallback.protein, greaterThan(0));
      }
    });
  });
}
