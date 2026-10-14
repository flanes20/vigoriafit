import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/profile.dart';
import '../models/units.dart';
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
  bool _isSaving = false;
  bool _isRetrying = false;
  bool _isReloadingProfile = false;
  String? _nameError;

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
    final trimmed = _name.text.trim();
    if (trimmed.isEmpty) {
      setState(() => _nameError = 'El nombre no puede estar vacío');
      return;
    }

    setState(() {
      _nameError = null;
      _isSaving = true;
    });

    _p.name = trimmed;
    try {
      final status = await AppStore.instance.saveProfile(_p);
      if (mounted) {
        if (status == SyncStatus.synced) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Guardado confirmado en la nube ✅'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Guardado en este dispositivo. Pendiente de sincronizar (sin conexión) ⚠️',
              ),
              backgroundColor: AppColors.warn,
              duration: Duration(seconds: 4),
            ),
          );
        }
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: AppColors.warn,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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

  Widget _syncStatusBanner() {
    final s = AppStore.instance;
    if (!s.hasPendingSync) return const SizedBox.shrink();

    final isFailed = s.syncStatus == SyncStatus.failed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isFailed
              ? AppColors.warn.withValues(alpha: 0.12)
              : AppColors.brandSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isFailed
                ? AppColors.warn.withValues(alpha: 0.3)
                : AppColors.brand.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isFailed ? Icons.cloud_off_rounded : Icons.sync_rounded,
              color: isFailed ? AppColors.warn : AppColors.brand,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFailed ? 'Guardado pendiente' : 'Sincronizando con la nube…',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isFailed ? AppColors.warn : AppColors.brandDark,
                    ),
                  ),
                  Text(
                    s.syncError ??
                        'Tus cambios están a salvo en tu teléfono. Se sincronizarán automáticamente.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.ink.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _isRetrying
                  ? null
                  : () async {
                      setState(() => _isRetrying = true);
                      try {
                        final ok = await s.retryPendingSync();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok
                                  ? '¡Sincronizado con éxito! ☁️'
                                  : 'Sigue sin conexión. Tus datos siguen seguros localmente.'),
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isRetrying = false);
                      }
                    },
              child: _isRetrying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Reintentar',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cloudProfileStatusBanner() {
    final s = AppStore.instance;
    if (s.isProfileLoading) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.brandSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: const [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cargando perfil desde la nube…',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (s.profileLoadError != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warn.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warn.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.warn, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.profileLoadError!,
                  style: const TextStyle(fontSize: 12, color: AppColors.warn),
                ),
              ),
              TextButton(
                onPressed: _isReloadingProfile
                    ? null
                    : () async {
                        setState(() => _isReloadingProfile = true);
                        try {
                          await s.reloadProfileFromCloud();
                          if (mounted) {
                            setState(() {
                              _p.copyFrom(s.profile);
                              _name.text = _p.name;
                            });
                          }
                        } finally {
                          if (mounted) setState(() => _isReloadingProfile = false);
                        }
                      },
                child: _isReloadingProfile
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Reintentar',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _body(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ajustes',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          _syncStatusBanner(),
          _label('Apariencia'),
          const SizedBox(height: 10),
          _themeSelector(),
          const SizedBox(height: 26),

          _label('Unidades'),
          const SizedBox(height: 10),
          _unitSelector(),
          const SizedBox(height: 26),

          _trainerSection(),
          const SizedBox(height: 26),

          _label('Recordatorios'),
          const SizedBox(height: 10),
          _reminders(),
          const SizedBox(height: 26),

          _label('Tu perfil'),
          const SizedBox(height: 10),
          _cloudProfileStatusBanner(),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            onChanged: (v) {
              if (_nameError != null && v.trim().isNotEmpty) {
                setState(() => _nameError = null);
              }
            },
            decoration: InputDecoration(
              labelText: 'Nombre',
              prefixIcon: const Icon(Icons.person_rounded),
              errorText: _nameError,
            ),
          ),
          const SizedBox(height: 18),

          _sub('Objetivo'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: Goal.values
                .map(
                  (g) => _chip(
                    '${g.emoji} ${g.label}',
                    _p.goal == g,
                    () => setState(() => _p.goal = g),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),

          _sub('Nivel'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: Level.values
                .map(
                  (l) => _chip(
                    l.label,
                    _p.level == l,
                    () => setState(() => _p.level = l),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _p.hasGym,
            activeThumbColor: AppColors.brand,
            title: Text(
              'Tengo acceso a gimnasio',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            onChanged: (v) => setState(() => _p.hasGym = v),
          ),
          _sliderTile(
            'Días por semana',
            _p.daysPerWeek.toDouble(),
            1,
            7,
            (v) => setState(() => _p.daysPerWeek = v.round()),
            '${_p.daysPerWeek}',
          ),

          const SizedBox(height: 26),
          _sub('Tu cuerpo'),
          const SizedBox(height: 8),
          _sliderTile(
            'Edad',
            _p.age.toDouble(),
            12,
            90,
            (v) => setState(() => _p.age = v.round()),
            '${_p.age} años',
          ),
          _sliderTile(
            'Estatura',
            _p.heightCm,
            130,
            220,
            (v) => setState(() => _p.heightCm = v),
            AppStore.instance.formatHeight(_p.heightCm),
          ),
          _sliderTile(
            'Peso actual',
            _p.weightKg,
            35,
            200,
            (v) => setState(() => _p.weightKg = v),
            AppStore.instance.formatWeight(_p.weightKg),
          ),
          _sliderTile(
            'Peso meta',
            _p.targetWeightKg,
            35,
            200,
            (v) => setState(() => _p.targetWeightKg = v),
            AppStore.instance.formatWeight(_p.targetWeightKg),
          ),

          const SizedBox(height: 26),
          _sub('Condiciones de salud'),
          const SizedBox(height: 4),
          Text(
            'Ajusta comidas, suplementos y ejercicios para que sean seguros.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: HealthCondition.values.map((c) {
              final selected = _p.conditions.contains(c);
              return _chip(
                c.label,
                selected,
                () => setState(() {
                  if (selected) {
                    _p.conditions.remove(c);
                  } else {
                    _p.conditions.add(c);
                  }
                }),
              );
            }).toList(),
          ),
          if (_p.conditions.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '✓ Sin condiciones médicas registradas',
                style: TextStyle(fontSize: 12, color: AppColors.muted, fontStyle: FontStyle.italic),
              ),
            ),
          const SizedBox(height: 18),
          _sub('Alergias / intolerancias'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: Allergy.values.map((a) {
              final selected = _p.allergies.contains(a);
              return _chip(
                a.label,
                selected,
                () => setState(() {
                  if (selected) {
                    _p.allergies.remove(a);
                  } else {
                    _p.allergies.add(a);
                  }
                }),
              );
            }).toList(),
          ),
          if (_p.allergies.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '✓ Sin alergias o intolerancias alimentarias registradas',
                style: TextStyle(fontSize: 12, color: AppColors.muted, fontStyle: FontStyle.italic),
              ),
            ),

          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_isSaving ? 'Guardando cambios…' : 'Guardar cambios'),
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
                      fontSize: 12,
                      color: AppColors.ink,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Ilustraciones de ejercicios: wger.de / Everkinetic (CC BY-SA)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: AppColors.faint),
            ),
          ),
          const SizedBox(height: 20),
          if (AppStore.instance.currentEmail != null)
            Center(
              child: Text(
                'Sesión: ${AppStore.instance.currentEmail}',
                style: TextStyle(fontSize: 12, color: AppColors.faint),
              ),
            ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Cerrar sesión'),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '¿Cerrar sesión?',
          style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
        content: Text(
          '¿Estás seguro de que deseas salir? Tu cuenta y datos guardados permanecerán seguros en Firebase.',
          style: TextStyle(color: AppColors.ink),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancelar', style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              Navigator.of(context).popUntil((r) => r.isFirst);
              await AppStore.instance.logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cerrar sesión'),
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
                activeThumbColor: AppColors.brand,
                title: Text(
                  'Recordar entrenar',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                subtitle: Text(
                  'Todos los días a las ${time.format(context)} · toca para cambiar la hora',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                onChanged: (v) async {
                  if (v) {
                    final ok = await Notifications.requestPermission();
                    if (!ok) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Activa las notificaciones en Ajustes del sistema.',
                            ),
                          ),
                        );
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
                    context: context,
                    initialTime: time,
                  );
                  if (picked != null) {
                    // Mantiene el estado activado/desactivado actual: solo
                    // cambia la hora, no fuerza a encender el recordatorio.
                    await s.setWorkoutReminder(
                      s.workoutReminderOn,
                      hour: picked.hour,
                      minute: picked.minute,
                    );
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
                activeThumbColor: AppColors.brand,
                title: Text(
                  'Recordar tomar agua',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                subtitle: Text(
                  '3 avisos al día (11:00, 15:30, 19:00)',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                onChanged: (v) async {
                  if (v) {
                    final ok = await Notifications.requestPermission();
                    if (!ok) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Activa las notificaciones en Ajustes del sistema.',
                            ),
                          ),
                        );
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
              activeThumbColor: AppColors.brand,
              title: Text(
                'Soy entrenador',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              subtitle: Text(
                'Crea un grupo y asigna rutinas a tus alumnos.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              onChanged: (v) => s.setIsTrainer(v),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => s.isTrainer
                        ? const TrainerPage()
                        : const JoinGroupPage(),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: const BorderSide(color: AppColors.brand),
                  foregroundColor: AppColors.brand,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: Icon(
                  s.isTrainer ? Icons.groups_rounded : Icons.group_add_rounded,
                  size: 18,
                ),
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
                    child: Text(
                      _themeLabels[m]!,
                      style: TextStyle(
                        color: active ? Colors.white : AppColors.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _unitSelector() {
    return ListenableBuilder(
      listenable: AppStore.instance,
      builder: (context, _) {
        final current = AppStore.instance.unitSystem;
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: UnitSystem.values.map((u) {
              final active = u == current;
              return Expanded(
                child: GestureDetector(
                  onTap: () => AppStore.instance.setUnitSystem(u),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active ? AppColors.brand : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          u.label,
                          style: TextStyle(
                            color: active ? Colors.white : AppColors.ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          u.description,
                          style: TextStyle(
                            color: active
                                ? Colors.white.withValues(alpha: 0.85)
                                : AppColors.muted,
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
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
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.brandDark : AppColors.ink,
          ),
        ),
      ),
    );
  }

  Widget _sliderTile(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
    String display,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          Text(
            display,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.brand,
            ),
          ),
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

  Widget _label(String t) => Text(
    t,
    style: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w800,
      color: AppColors.ink,
    ),
  );

  Widget _sub(String t) => Text(
    t,
    style: TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w700,
      color: AppColors.muted,
    ),
  );
}
