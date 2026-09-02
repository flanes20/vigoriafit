import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/workouts.dart';
import '../services/store.dart';
import '../services/trainer_service.dart';
import 'workout_detail_page.dart';

/// El alumno ingresa el código de 6 dígitos que le dio su entrenador para
/// unirse al grupo, y desde acá ve qué rutina le asignaron.
class JoinGroupPage extends StatefulWidget {
  const JoinGroupPage({super.key});

  @override
  State<JoinGroupPage> createState() => _JoinGroupPageState();
}

class _JoinGroupPageState extends State<JoinGroupPage> {
  final _codeCtrl = TextEditingController();
  bool _busy = false;
  Map<String, dynamic>? _group;

  @override
  void initState() {
    super.initState();
    if (AppStore.instance.inGroup) _loadGroup();
  }

  Future<void> _loadGroup() async {
    final groupId = AppStore.instance.groupId;
    if (groupId == null) return;
    final g = await TrainerService.getGroup(groupId);
    if (mounted) setState(() => _group = g);
  }

  Future<void> _join() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('El código tiene 6 dígitos.')));
      return;
    }
    setState(() => _busy = true);
    try {
      final s = AppStore.instance;
      final groupId = await TrainerService.joinGroup(code, s.localUserId, s.profile.name);
      if (groupId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('No encontré ese código. Revísalo.')));
        }
        return;
      }
      await s.setMyGroup(groupId, code);
      await _loadGroup();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No pude unirme. Revisa tu internet.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    await AppStore.instance.leaveGroup();
    setState(() => _group = null);
  }

  @override
  Widget build(BuildContext context) {
    final inGroup = AppStore.instance.inGroup;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi grupo',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
      ),
      body: SafeArea(
        top: false,
        child: inGroup ? _groupView() : _joinView(),
      ),
    );
  }

  Widget _joinView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.groups_rounded, size: 48, color: AppColors.brand),
            const SizedBox(height: 16),
            Text('Únete al grupo de tu entrenador',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 8),
            Text('Pídele el código de 6 dígitos e ingrésalo aquí.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: AppColors.muted)),
            const SizedBox(height: 22),
            TextField(
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 6),
              decoration: const InputDecoration(counterText: '', hintText: '000000'),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _join,
                child: _busy
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : const Text('Unirme'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupView() {
    final assignedId = _group?['assignedWorkoutId'] as String?;
    final assignedTitle = _group?['assignedWorkoutTitle'] as String?;
    final trainerName = _group?['trainerName'] as String?;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.brandSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.person_rounded, color: AppColors.brandDark),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Entrenador: ${trainerName ?? '—'}',
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.brandDark)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('Rutina asignada',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
        const SizedBox(height: 8),
        if (assignedId == null)
          Text('Tu entrenador todavía no te asignó nada.',
              style: TextStyle(fontSize: 13, color: AppColors.muted))
        else
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              final w = Workouts.byId(assignedId);
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => WorkoutDetailPage(workout: w)));
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  const Icon(Icons.fitness_center_rounded, color: AppColors.brand),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(assignedTitle ?? '',
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppColors.faint),
                ],
              ),
            ),
          ),
        const SizedBox(height: 30),
        TextButton.icon(
          onPressed: _leave,
          icon: const Icon(Icons.logout_rounded, size: 16),
          label: const Text('Salir del grupo'),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
        ),
      ],
    );
  }
}
