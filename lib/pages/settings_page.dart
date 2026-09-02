import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/profile.dart';
import '../services/notifications.dart';
import '../services/store.dart';
import 'join_group_page.dart';
import 'trainer_page.dart';

const _themeLabels = {
  ThemeMode.system: 'Sistema',
  ThemeMode.light: 'Claro',
  ThemeMode.dark: 'Oscuro',
};

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final Profile _p;
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _p = AppStore.instance.profile.copy();
    _name = TextEditingController(text: _p.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    _p.name = _name.text.trim().isEmpty ? _p.name : _name.text.trim();
    await AppStore.instance.saveProfile(_p);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Guardado ✅')));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Todo el contenido escucha AppStore para que, si el usuario cambia de
    // tema aquí mismo, los colores (etiquetas, fondos) se actualicen al
    // instante en vez de quedarse con los del tema anterior.
    return ListenableBuilder(
      listenable: AppStore.instance,
      builder: (context, _) => _body(context),
    );
  }

  Widget _body(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          _label('Apariencia'),
          const SizedBox(height: 10),
          _themeSelector(),
          const SizedBox(height: 26),

          _trainerSection(),
          const SizedBox(height: 26),

          _label('Recordatorios'),
          const SizedBox(height: 10),
          _reminders(),
          const SizedBox(height: 26),

          _label('Tu perfil'),
          const SizedBox(height: 10),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              prefixIcon: Icon(Icons.person_rounded),
            ),
          ),
          const SizedBox(height: 18),

          _sub('Objetivo'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: Goal.values
                .map((g) => _chip('${g.emoji} ${g.label}', _p.goal == g,
                    () => setState(() => _p.goal = g)))
                .toList(),
          ),
          const SizedBox(height: 18),

          _sub('Nivel'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: Level.values
                .map((l) => _chip(l.label, _p.level == l,
                    () => setState(() => _p.level = l)))
                .toList(),
          ),
          const SizedBox(height: 8),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _p.hasGym,
            activeColor: AppColors.brand,
            title: Text('Tengo acceso a gimnasio',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.ink)),
            onChanged: (v) => setState(() => _p.hasGym = v),
          ),
          _sliderTile('Días por semana', _p.daysPerWeek.toDouble(), 1, 7,
              (v) => setState(() => _p.daysPerWeek = v.round()),
              '${_p.daysPerWeek}'),

          const SizedBox(height: 26),
          _sub('Tu cuerpo'),
          const SizedBox(height: 8),
          _sliderTile('Edad', _p.age.toDouble(), 12, 90,
              (v) => setState(() => _p.age = v.round()), '${_p.age} años'),
          _sliderTile('Estatura', _p.heightCm, 130, 220,
              (v) => setState(() => _p.heightCm = v), '${_p.heightCm.round()} cm'),
          _sliderTile('Peso actual', _p.weightKg, 35, 200,
              (v) => setState(() => _p.weightKg = v), '${_p.weightKg.round()} kg'),
          _sliderTile('Peso meta', _p.targetWeightKg, 35, 200,
              (v) => setState(() => _p.targetWeightKg = v),
              '${_p.targetWeightKg.round()} kg'),

          const SizedBox(height: 26),
          _sub('Condiciones de salud'),
          const SizedBox(height: 4),
          Text('Ajusta comidas, suplementos y ejercicios para que sean seguros.',
              style: TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: HealthCondition.values.map((c) {
              final selected = _p.conditions.contains(c);
              return _chip(c.label, selected, () => setState(() {
                    if (selected) {
                      _p.conditions.remove(c);
                    } else {
                      _p.conditions.add(c);
                    }
                  }));
            }).toList(),
          ),
          const SizedBox(height: 18),
          _sub('Alergias / intolerancias'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: Allergy.values.map((a) {
              final selected = _p.allergies.contains(a);
              return _chip(a.label, selected, () => setState(() {
                    if (selected) {
                      _p.allergies.remove(a);
                    } else {
                      _p.allergies.add(a);
                    }
                  }));
            }).toList(),
          ),

          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Guardar cambios'),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.mintSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Text('🤖', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      'El Coach usa IA real (Google Gemini). Sus consejos son '
                      'orientativos y no reemplazan a un profesional de la salud.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.ink, height: 1.35)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
                'Ilustraciones de ejercicios: wger.de / Everkinetic (CC BY-SA)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: AppColors.faint)),
          ),
          const SizedBox(height: 20),
          if (AppStore.instance.currentEmail != null)
            Center(
              child: Text('Sesión: ${AppStore.instance.currentEmail}',
                  style: TextStyle(fontSize: 12, color: AppColors.faint)),
            ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).popUntil((r) => r.isFirst);
              AppStore.instance.logout();
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Cerrar sesión'),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          ),
        ],
      ),
    );
  }

  Widget _reminders() {
    return ListenableBuilder(
      listenable: AppStore.instance,
      builder: (context, _) {
        final s = AppStore.instance;
        final time = TimeOfDay(hour: s.workoutHour, minute: s.workoutMinute);
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: s.workoutReminderOn,
                activeColor: AppColors.brand,
                title: Text('Recordar entrenar',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: AppColors.ink)),
                subtitle: Text('Todos los días a las ${time.format(context)} · toca para cambiar la hora',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
                onChanged: (v) async {
                  if (v) {
                    final ok = await Notifications.requestPermission();
                    if (!ok) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Activa las notificaciones en Ajustes del sistema.')));
                      }
                      return;
                    }
                  }
                  await s.setWorkoutReminder(v);
                },
              ),
            ),
            Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    final picked = await showTimePicker(
                        context: context, initialTime: time);
                    if (picked != null) {
                      // Mantiene el estado activado/desactivado actual: solo
                      // cambia la hora, no fuerza a encender el recordatorio.
                      await s.setWorkoutReminder(s.workoutReminderOn,
                          hour: picked.hour, minute: picked.minute);
                    }
                  },
                  icon: const Icon(Icons.schedule_rounded, size: 16),
                  label: const Text('Cambiar hora'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.brand),
                ),
              ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: s.waterReminderOn,
                activeColor: AppColors.brand,
                title: Text('Recordar tomar agua',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: AppColors.ink)),
                subtitle: Text('3 avisos al día (11:00, 15:30, 19:00)',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
                onChanged: (v) async {
                  if (v) {
                    final ok = await Notifications.requestPermission();
                    if (!ok) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Activa las notificaciones en Ajustes del sistema.')));
                      }
                      return;
                    }
                  }
                  await s.setWaterReminder(v);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _trainerSection() {
    return ListenableBuilder(
      listenable: AppStore.instance,
      builder: (context, _) {
        final s = AppStore.instance;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Modo entrenador'),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: s.isTrainer,
              activeColor: AppColors.brand,
              title: Text('Soy entrenador',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
              subtitle: Text('Crea un grupo y asigna rutinas a tus alumnos.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
              onChanged: (v) => s.setIsTrainer(v),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => s.isTrainer ? const TrainerPage() : const JoinGroupPage())),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: const BorderSide(color: AppColors.brand),
                  foregroundColor: AppColors.brand,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: Icon(s.isTrainer ? Icons.groups_rounded : Icons.group_add_rounded, size: 18),
                label: Text(s.isTrainer ? 'Panel de entrenador' : 'Mi grupo'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _themeSelector() {
    return ListenableBuilder(
      listenable: AppStore.instance,
      builder: (context, _) {
        final current = AppStore.instance.themeMode;
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: ThemeMode.values.map((m) {
              final active = m == current;
              return Expanded(
                child: GestureDetector(
                  onTap: () => AppStore.instance.setThemeMode(m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active ? AppColors.brand : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(_themeLabels[m]!,
                        style: TextStyle(
                            color: active ? Colors.white : AppColors.muted,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5)),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandSoft : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.brand : AppColors.line,
              width: selected ? 1.4 : 1),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.brandDark : AppColors.ink)),
      ),
    );
  }

  Widget _sliderTile(String label, double value, double min, double max,
      ValueChanged<double> onChanged, String display) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.ink)),
          ),
          Text(display,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: AppColors.brand)),
          SizedBox(
            width: 160,
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: (max - min).round(),
              activeColor: AppColors.brand,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink));

  Widget _sub(String t) => Text(t,
      style: TextStyle(
          fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.muted));
}
