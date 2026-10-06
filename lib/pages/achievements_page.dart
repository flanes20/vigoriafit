import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/achievements.dart';
import '../services/store.dart';

/// Logros y nivel del usuario: gamificación para mantener la motivación.
class AchievementsPage extends StatelessWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStore.instance,
      builder: (context, _) {
        final s = AppStore.instance;
        final unlocked = Achievements.unlocked(s);
        final locked = Achievements.locked(s);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Logros',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          ),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _levelCard(s),
                const SizedBox(height: 22),
                Text('Desbloqueados (${unlocked.length}/${Achievements.all.length})',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
                const SizedBox(height: 10),
                if (unlocked.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Aún no desbloqueas ninguno. ¡Empieza hoy! 💪',
                        style: TextStyle(fontSize: 13, color: AppColors.muted)),
                  )
                else
                  ...unlocked.map((a) => _card(a, true)),
                const SizedBox(height: 22),
                Text('Por desbloquear',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
                const SizedBox(height: 10),
                ...locked.map((a) => _card(a, false)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _levelCard(AppStore s) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppColors.brand, AppColors.brandDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text('${s.level}',
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nivel ${s.level}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    Text('${s.totalXp} XP en total',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: s.levelProgress,
              minHeight: 9,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text('Faltan ${s.xpForNextLevel - s.totalXp} XP para el nivel ${s.level + 1}',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5)),
        ],
      ),
    );
  }

  Widget _card(dynamic a, bool unlocked) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: unlocked ? AppColors.brandSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: unlocked ? AppColors.brand : AppColors.line,
            width: unlocked ? 1.3 : 1),
      ),
      child: Row(
        children: [
          Opacity(
            opacity: unlocked ? 1 : 0.35,
            child: Text(a.emoji, style: const TextStyle(fontSize: 28)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title,
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: unlocked ? AppColors.ink : AppColors.muted)),
                const SizedBox(height: 2),
                Text(a.desc,
                    style: TextStyle(fontSize: 12, color: AppColors.faint)),
              ],
            ),
          ),
          if (unlocked)
            const Icon(Icons.check_circle_rounded, color: AppColors.success)
          else
            Icon(Icons.lock_outline_rounded, color: AppColors.faint, size: 20),
        ],
      ),
    );
  }
}
