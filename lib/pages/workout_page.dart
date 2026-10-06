import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/workouts.dart';
import '../models/place.dart';
import '../models/profile.dart';
import '../models/workout.dart';
import '../services/store.dart';
import '../services/trainer_service.dart';
import 'places_page.dart';
import 'workout_detail_page.dart';

class WorkoutTab extends StatelessWidget {
  const WorkoutTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStore.instance,
      builder: (context, _) {
        final s = AppStore.instance;
        final p = s.profile;
        final list = Workouts.forProfile(p);
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Entrenamientos',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink)),
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const PlacesPage(initialKind: PlaceKind.gym))),
                      icon: const Icon(Icons.place_rounded, size: 16),
                      label: const Text('Gimnasios cerca'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.brand),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(p.hasGym ? Icons.fitness_center_rounded : Icons.home_rounded,
                        size: 15, color: AppColors.muted),
                    const SizedBox(width: 6),
                    Text(
                        p.hasGym
                            ? 'Rutinas para gimnasio · ${p.goal.label}'
                            : 'Rutinas en casa · ${p.goal.label}',
                        style: TextStyle(fontSize: 13, color: AppColors.muted)),
                  ],
                ),
                if (s.inGroup && !s.isTrainer) ...[
                  const SizedBox(height: 14),
                  _assignedBanner(context, s),
                ],
                const SizedBox(height: 18),
                ...list.map((w) => _card(context, w, s.isWorkoutDoneToday(w.id))),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _assignedBanner(BuildContext context, AppStore s) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: TrainerService.getGroup(s.groupId!),
      builder: (context, snap) {
        final assignedId = snap.data?['assignedWorkoutId'] as String?;
        final assignedTitle = snap.data?['assignedWorkoutTitle'] as String?;
        final trainerName = snap.data?['trainerName'] as String?;
        if (assignedId == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              final w = Workouts.byId(assignedId);
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => WorkoutDetailPage(workout: w)));
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.brand, AppColors.brandDark],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(Icons.assignment_turned_in_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            trainerName != null
                                ? 'Tu entrenador $trainerName te asignó:'
                                : 'Tu entrenador te asignó:',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(assignedTitle ?? '',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _card(BuildContext context, Workout w, bool done) {
    final recommended = w.goal == AppStore.instance.profile.goal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => WorkoutDetailPage(workout: w))),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: done ? AppColors.mintSoft : AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                    done
                        ? Icons.check_circle_rounded
                        : Icons.fitness_center_rounded,
                    color: done ? AppColors.success : AppColors.brand),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(w.title,
                              style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink)),
                        ),
                        if (recommended) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.brandSoft,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('Para ti',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.brandDark,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text('${w.minutes} min · ${w.exercises.length} ejercicios · ${w.focus}',
                        style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.faint),
            ],
          ),
        ),
      ),
    );
  }
}
