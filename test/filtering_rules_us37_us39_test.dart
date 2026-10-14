import 'package:flutter_test/flutter_test.dart';
import 'package:vigoriafit/data/nutrition.dart';
import 'package:vigoriafit/data/supplements.dart';
import 'package:vigoriafit/data/workouts.dart';
import 'package:vigoriafit/models/profile.dart';

/// Tests del Paso 8 (US37 – US39) — Reglas de filtrado documentadas y casos de prueba
/// para nutrición, suplementación y entrenamiento adaptativo.
void main() {
  group('Paso 8 — Reglas de filtrado US37, US38 y US39', () {
    // ─────────────────────────────────────────────────────────────────────────
    // US37: Nutrición
    // ─────────────────────────────────────────────────────────────────────────
    test('US37: Las comidas respetan estrictamente la matriz de exclusión', () {
      final p = Profile(
        allergies: [Allergy.gluten, Allergy.lactosa],
        conditions: [HealthCondition.diabetes],
      );

      final menu = Nutrition.dayMenu(Goal.loseFat, profile: p);
      for (final meal in menu.values) {
        expect(meal.allergens.contains(Allergy.gluten), isFalse);
        expect(meal.allergens.contains(Allergy.lactosa), isFalse);
        expect(meal.dietFlags.contains('highSugar'), isFalse);
        expect(Nutrition.isSafe(meal, p), isTrue);
      }
    });

    // ─────────────────────────────────────────────────────────────────────────
    // US38: Suplementos
    // ─────────────────────────────────────────────────────────────────────────
    test('US38.1: Suplementos priorizan la meta del usuario en primeras posiciones', () {
      final muscleProfile = Profile(goal: Goal.gainMuscle);
      final muscleSupps = Supplements.forProfile(muscleProfile);

      // Los primeros suplementos deben incluir creatina y whey
      final topNames = muscleSupps.take(3).map((s) => s.name).toList();
      expect(topNames.any((n) => n.contains('Creatina')), isTrue);
      expect(topNames.any((n) => n.contains('Proteína')), isTrue);
    });

    test('US38.2: Detección precisa de precauciones médicas en suplementos', () {
      final renalProfile = Profile(
        conditions: [HealthCondition.enfermedadRenal],
      );
      final hyperProfile = Profile(
        conditions: [HealthCondition.hipertension],
      );
      final healthyProfile = Profile();

      final creatine = Supplements.all.firstWhere((s) => s.name.contains('Creatina'));
      final whey = Supplements.all.firstWhere((s) => s.name.contains('Proteína'));
      final caffeine = Supplements.all.firstWhere((s) => s.name.contains('Cafeína'));
      final omega3 = Supplements.all.firstWhere((s) => s.name.contains('Omega-3'));

      // Creatina y Whey tienen precaución en enfermedad renal
      expect(Supplements.hasCaution(creatine, renalProfile), isTrue);
      expect(Supplements.hasCaution(whey, renalProfile), isTrue);
      expect(Supplements.getCautionNote(creatine, renalProfile), isNotNull);

      // Cafeína tiene precaución en hipertensión
      expect(Supplements.hasCaution(caffeine, hyperProfile), isTrue);
      expect(Supplements.getCautionNote(caffeine, hyperProfile), contains('presión'));

      // Usuario sano no tiene advertencias
      expect(Supplements.hasCaution(creatine, healthyProfile), isFalse);
      expect(Supplements.hasCaution(caffeine, healthyProfile), isFalse);
      expect(Supplements.getCautionNote(creatine, healthyProfile), isNull);

      // Omega 3 no tiene advertencias generales
      expect(Supplements.hasCaution(omega3, renalProfile), isFalse);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // US39: Entrenamientos y Lesiones
    // ─────────────────────────────────────────────────────────────────────────
    test('US39.1: Filtrado de rutinas según entorno (hasGym == false vs true)', () {
      final homeProfile = Profile(hasGym: false, goal: Goal.health);
      final gymProfile = Profile(hasGym: true, goal: Goal.gainMuscle);

      // Usuario en casa: NINGUNA rutina puede requerir gimnasio
      final homeWorkouts = Workouts.forProfile(homeProfile);
      expect(homeWorkouts, isNotEmpty);
      for (final w in homeWorkouts) {
        expect(w.needsGym, isFalse, reason: '${w.title} requiere gimnasio.');
        expect(Workouts.isCompatibleWithEnvironment(w, homeProfile), isTrue);
      }
      expect(Workouts.todayFor(homeProfile).needsGym, isFalse);

      // Usuario con gimnasio: puede acceder a rutinas de gimnasio y prioriza su meta
      final gymWorkouts = Workouts.forProfile(gymProfile);
      expect(gymWorkouts.any((w) => w.needsGym), isTrue);
      expect(Workouts.todayFor(gymProfile).goal, Goal.gainMuscle);
    });

    test('US39.2: Detección y conteo de ejercicios con advertencia por lesión de rodilla', () {
      final kneeInjuryProfile = Profile(
        conditions: [HealthCondition.lesionRodilla],
      );

      final hiitWorkout = Workouts.byId('home_hiit');
      final burpees = hiitWorkout.exercises.firstWhere((e) => e.name == 'Burpees');
      final planks = hiitWorkout.exercises.firstWhere((e) => e.name.contains('Plancha'));

      // Burpees tiene advertencia para lesión de rodilla
      expect(Workouts.hasExerciseCaution(burpees, kneeInjuryProfile), isTrue);
      final conflicts = Workouts.getConflictingConditions(burpees, kneeInjuryProfile);
      expect(conflicts, contains(HealthCondition.lesionRodilla));

      // Planchas no tienen advertencia para rodilla
      expect(Workouts.hasExerciseCaution(planks, kneeInjuryProfile), isFalse);

      // Conteo de advertencias en la rutina completa
      final cautionCount = Workouts.countCautionsInWorkout(hiitWorkout, kneeInjuryProfile);
      expect(cautionCount, greaterThanOrEqualTo(3)); // Burpees, jumping jacks, etc.
    });

    test('US39.3: Detección de ejercicios con advertencia por lesión de espalda', () {
      final backInjuryProfile = Profile(
        conditions: [HealthCondition.lesionEspalda],
      );

      final upperWorkout = Workouts.byId('gym_upper');
      final lowerWorkout = Workouts.byId('gym_lower');

      final row = upperWorkout.exercises.firstWhere((e) => e.name.contains('Remo con barra'));
      final deadlift = lowerWorkout.exercises.firstWhere((e) => e.name.contains('Peso muerto'));
      final benchPress = upperWorkout.exercises.firstWhere((e) => e.name.contains('Press banca'));

      // Remo con barra y peso muerto rumano tienen advertencia para espalda
      expect(Workouts.hasExerciseCaution(row, backInjuryProfile), isTrue);
      expect(Workouts.hasExerciseCaution(deadlift, backInjuryProfile), isTrue);

      // Press de banca es seguro para espalda
      expect(Workouts.hasExerciseCaution(benchPress, backInjuryProfile), isFalse);
    });
  });
}
