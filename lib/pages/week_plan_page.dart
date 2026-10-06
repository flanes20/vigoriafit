import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/week_plan.dart';
import '../services/coach.dart';
import '../services/store.dart';

/// Plan semanal generado por IA: 7 días con enfoque de entrenamiento y tip de
/// alimentación, personalizados al perfil del usuario.
class WeekPlanPage extends StatefulWidget {
  const WeekPlanPage({super.key});

  @override
  State<WeekPlanPage> createState() => _WeekPlanPageState();
}

class _WeekPlanPageState extends State<WeekPlanPage> {
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    if (AppStore.instance.weekPlan == null) _generate();
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    final plan = await Coach.generateWeekPlan();
    await AppStore.instance.saveWeekPlan(plan);
    if (mounted) setState(() => _generating = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStore.instance,
      builder: (context, _) {
        final plan = AppStore.instance.weekPlan;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Plan semanal',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            actions: [
              IconButton(
                onPressed: _generating ? null : _generate,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Generar de nuevo',
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: _generating
                ? _loading()
                : plan == null
                    ? _empty()
                    : _plan(plan),
          ),
        );
      },
    );
  }

  Widget _loading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
                strokeWidth: 3, color: AppColors.brand),
          ),
          const SizedBox(height: 16),
          Text('Armando tu semana con IA…',
              style: TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month_rounded, size: 46, color: AppColors.faint),
            const SizedBox(height: 12),
            Text('No pude generar tu plan. Intenta de nuevo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _generate, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }

  Widget _plan(WeekPlan plan) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Row(
          children: [
            const Text('🗓️', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  'Tu semana, armada por IA según tu objetivo. Puedes '
                  'regenerarla cuando quieras.',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.35)),
            ),
          ],
        ),
        const SizedBox(height: 18),
        ...plan.days.map(_dayCard),
      ],
    );
  }

  Widget _dayCard(DayPlan d) {
    final isRest = d.focus.toLowerCase().contains('descanso');
    final today = _isToday(d.day);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: today ? AppColors.brandSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: today ? AppColors.brand : AppColors.line,
            width: today ? 1.4 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isRest ? AppColors.mintSoft : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                    isRest ? Icons.self_improvement_rounded : Icons.bolt_rounded,
                    color: isRest ? AppColors.mint : AppColors.brand,
                    size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(d.day,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink)),
                        if (today) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.brand,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('HOY',
                                style: TextStyle(
                                    fontSize: 9.5,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ],
                    ),
                    Text(d.focus,
                        style:
                            TextStyle(fontSize: 12.5, color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _tipRow(Icons.fitness_center_rounded, d.workoutTip, AppColors.brand),
          const SizedBox(height: 6),
          _tipRow(Icons.restaurant_rounded, d.mealTip, AppColors.mint),
        ],
      ),
    );
  }

  Widget _tipRow(IconData icon, String text, Color color) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 12.5, color: AppColors.ink, height: 1.3)),
        ),
      ],
    );
  }

  bool _isToday(String dayName) {
    const names = [
      'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
    ];
    final idx = DateTime.now().weekday - 1; // 0 = Lunes
    return idx >= 0 && idx < names.length && names[idx] == dayName;
  }
}
