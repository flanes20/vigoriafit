import '../models/profile.dart';
import '../models/workout.dart';

/// Catálogo de rutinas de VigoriaFit y selección según el perfil del usuario.
class Workouts {
  Workouts._();

  static const List<Workout> all = [
    // ── En casa (sin gym) ──────────────────────────────────────────────────
    Workout(
      id: 'home_fullbody',
      title: 'Full body en casa',
      focus: 'Cuerpo completo · sin equipo',
      minutes: 30,
      needsGym: false,
      goal: Goal.health,
      exercises: [
        Exercise('Sentadillas', '3 x 15', '', 'squat'),
        Exercise('Flexiones (o de rodillas)', '3 x 10', '', 'pushup'),
        Exercise('Plancha', '3 x 30 seg', '', 'plank'),
        Exercise('Zancadas', '3 x 12 c/pierna', '', 'lunge'),
        Exercise('Puente de glúteo', '3 x 15', '', 'glute_bridge'),
        Exercise('Mountain climbers', '3 x 30 seg', '', 'mountain_climber',
            [HealthCondition.lesionRodilla]),
      ],
    ),
    Workout(
      id: 'home_hiit',
      title: 'HIIT quema grasa',
      focus: 'Cardio intenso · sin equipo',
      minutes: 20,
      needsGym: false,
      goal: Goal.loseFat,
      exercises: [
        Exercise('Jumping jacks', '40 seg', 'Descansa 20 seg entre cada uno',
            'jumping_jack', [HealthCondition.lesionRodilla]),
        Exercise('Burpees', '40 seg', '', 'squat', [HealthCondition.lesionRodilla]),
        Exercise('Rodillas al pecho', '40 seg', '', 'run', [HealthCondition.lesionRodilla]),
        Exercise('Sentadilla con salto', '40 seg', '', 'squat',
            [HealthCondition.lesionRodilla]),
        Exercise('Plancha con toque de hombro', '40 seg', '', 'plank'),
        Exercise('Repetir el circuito', '4 vueltas', '', 'run'),
      ],
    ),
    Workout(
      id: 'home_core',
      title: 'Core y abdomen',
      focus: 'Zona media · sin equipo',
      minutes: 15,
      needsGym: false,
      goal: Goal.maintain,
      exercises: [
        Exercise('Crunch', '3 x 20', '', 'crunch'),
        Exercise('Elevación de piernas', '3 x 15', '', 'crunch'),
        Exercise('Plancha lateral', '3 x 25 seg c/lado', '', 'plank'),
        Exercise('Bicicleta', '3 x 30 seg', '', 'crunch'),
        Exercise('Plancha', '3 x 40 seg', '', 'plank'),
      ],
    ),
    // ── En gimnasio ────────────────────────────────────────────────────────
    Workout(
      id: 'gym_upper',
      title: 'Tren superior',
      focus: 'Pecho, espalda y brazos · gym',
      minutes: 50,
      needsGym: true,
      goal: Goal.gainMuscle,
      exercises: [
        Exercise('Press banca', '4 x 8-10', '', 'bench_press'),
        Exercise('Remo con barra', '4 x 10', '', 'row', [HealthCondition.lesionEspalda]),
        Exercise('Press militar', '3 x 10', '', 'shoulder_press'),
        Exercise('Jalón al pecho', '3 x 12', '', 'row'),
        Exercise('Curl bíceps', '3 x 12', '', 'bicep_curl'),
        Exercise('Extensión tríceps polea', '3 x 12', '', 'bicep_curl'),
      ],
    ),
    Workout(
      id: 'gym_lower',
      title: 'Tren inferior',
      focus: 'Piernas y glúteo · gym',
      minutes: 50,
      needsGym: true,
      goal: Goal.gainMuscle,
      exercises: [
        Exercise('Sentadilla con barra', '4 x 8-10', '', 'squat'),
        Exercise('Prensa', '4 x 12', '', 'squat'),
        Exercise('Peso muerto rumano', '3 x 10', '', 'deadlift',
            [HealthCondition.lesionEspalda]),
        Exercise('Extensión de cuádriceps', '3 x 15', '', 'calf_raise'),
        Exercise('Curl femoral', '3 x 15', '', 'calf_raise'),
        Exercise('Elevación de gemelos', '4 x 20', '', 'calf_raise'),
      ],
    ),
    Workout(
      id: 'gym_fullbody',
      title: 'Full body gym',
      focus: 'Cuerpo completo · gym',
      minutes: 45,
      needsGym: true,
      goal: Goal.health,
      exercises: [
        Exercise('Sentadilla', '3 x 10', '', 'squat'),
        Exercise('Press banca', '3 x 10', '', 'bench_press'),
        Exercise('Remo máquina', '3 x 12', '', 'row'),
        Exercise('Press hombro mancuernas', '3 x 12', '', 'shoulder_press'),
        Exercise('Plancha', '3 x 40 seg', '', 'plank'),
        Exercise('Cardio (cinta/elíptica)', '10 min', '', 'run'),
      ],
    ),
    Workout(
      id: 'gym_cardio',
      title: 'Cardio + tonificación',
      focus: 'Quema grasa · gym',
      minutes: 40,
      needsGym: true,
      goal: Goal.loseFat,
      exercises: [
        Exercise('Cinta o elíptica', '15 min', 'Ritmo moderado-alto', 'run'),
        Exercise('Sentadilla goblet', '3 x 15', '', 'squat'),
        Exercise('Remo máquina', '3 x 15', '', 'row'),
        Exercise('Press hombro', '3 x 12', '', 'shoulder_press'),
        Exercise('Abdominales en máquina', '3 x 20', '', 'crunch'),
      ],
    ),
    Workout(
      id: 'home_mobility',
      title: 'Movilidad y estiramiento',
      focus: 'Recuperación · sin equipo',
      minutes: 15,
      needsGym: false,
      goal: Goal.health,
      exercises: [
        Exercise('Estiramiento de cuello y hombros', '2 min', '', 'stretch'),
        Exercise('Gato-camello', '10 reps', '', 'cat_cow'),
        Exercise('Estiramiento de isquiotibiales', '30 seg c/lado', '', 'stretch'),
        Exercise('Rotación de cadera', '10 c/lado', '', 'cat_cow'),
        Exercise('Respiración profunda', '2 min', '', 'breathing'),
      ],
    ),
  ];

  static Workout byId(String id) =>
      all.firstWhere((w) => w.id == id, orElse: () => all.first);

  /// Rutinas recomendadas para el perfil: filtra por lugar (gym/casa) y ordena
  /// poniendo primero las que calzan con el objetivo del usuario.
  static List<Workout> forProfile(Profile p) {
    final pool = all.where((w) => p.hasGym || !w.needsGym).toList();
    pool.sort((a, b) {
      final aw = a.goal == p.goal ? 0 : 1;
      final bw = b.goal == p.goal ? 0 : 1;
      return aw.compareTo(bw);
    });
    return pool;
  }

  /// Rutina "de hoy": la primera recomendada para el perfil.
  static Workout todayFor(Profile p) => forProfile(p).first;
}
