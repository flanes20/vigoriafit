import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/exercise_log.dart';
import '../models/logs.dart';
import '../models/profile.dart';
import '../models/week_plan.dart';
import 'notifications.dart';

/// Almacén central de VigoriaFit. Guarda el perfil, los registros diarios (agua y
/// entrenamientos), el historial de peso y los ajustes en el dispositivo, y
/// avisa a la UI cuando algo cambia.
class AppStore extends ChangeNotifier {
  AppStore._();
  static final AppStore instance = AppStore._();

  static const _kProfile = 'brio_profile_v1';
  static const _kOnboarded = 'brio_onboarded_v1';
  static const _kTheme = 'brio_theme_v1';
  static const _kLogs = 'brio_daylogs_v1';
  static const _kWeights = 'brio_weights_v1';
  static const _kAccounts = 'brio_accounts_v1';
  static const _kSession = 'brio_session_v1';
  static const _kWorkoutReminder = 'brio_reminder_workout_v1';
  static const _kWorkoutHour = 'brio_reminder_workout_hour_v1';
  static const _kWorkoutMinute = 'brio_reminder_workout_min_v1';
  static const _kWaterReminder = 'brio_reminder_water_v1';
  static const _kWeekPlan = 'brio_weekplan_v1';
  static const _kExerciseWeights = 'brio_exercise_weights_v1';
  static const _kLocalUserId = 'brio_local_user_id_v1';
  static const _kIsTrainer = 'brio_is_trainer_v1';
  static const _kGroupId = 'brio_group_id_v1';
  static const _kGroupCode = 'brio_group_code_v1';

  Profile _profile = Profile();
  bool _onboarded = false;
  ThemeMode _themeMode = ThemeMode.system;
  final Map<String, DayLog> _logs = {};
  final List<WeightEntry> _weights = [];
  Map<String, dynamic> _accounts = {}; // email -> {name, salt, hash, provider}
  String? _sessionEmail;
  bool _workoutReminderOn = false;
  int _workoutHour = 18;
  int _workoutMinute = 0;
  bool _waterReminderOn = false;
  WeekPlan? _weekPlan;
  final Map<String, List<ExerciseWeightEntry>> _exerciseWeights = {};
  String _localUserId = '';
  bool _isTrainer = false;
  String? _groupId;
  String? _groupCode;
  bool _loaded = false;

  Profile get profile => _profile;
  bool get onboarded => _onboarded;
  ThemeMode get themeMode => _themeMode;
  bool get loaded => _loaded;
  List<WeightEntry> get weights => List.unmodifiable(_weights);
  bool get workoutReminderOn => _workoutReminderOn;
  int get workoutHour => _workoutHour;
  int get workoutMinute => _workoutMinute;
  bool get waterReminderOn => _waterReminderOn;
  WeekPlan? get weekPlan => _weekPlan;

  // ── Rol entrenador / grupos ──────────────────────────────────────────────
  String get localUserId => _localUserId;
  bool get isTrainer => _isTrainer;
  String? get groupId => _groupId;
  String? get groupCode => _groupCode;
  bool get inGroup => _groupId != null;

  // ── Sesión / autenticación ───────────────────────────────────────────────
  bool get authed => _sessionEmail != null;
  String? get currentEmail => _sessionEmail;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final pj = p.getString(_kProfile);
    if (pj != null) _profile = Profile.fromJson(pj);
    _onboarded = p.getBool(_kOnboarded) ?? false;
    _themeMode = ThemeMode.values[(p.getInt(_kTheme) ?? 0).clamp(0, 2)];
    _logs
      ..clear()
      ..addEntries((p.getStringList(_kLogs) ?? [])
          .map(DayLog.fromJson)
          .map((l) => MapEntry(l.dateKey, l)));
    _weights
      ..clear()
      ..addAll((p.getStringList(_kWeights) ?? []).map(WeightEntry.fromJson));
    _weights.sort((a, b) => a.date.compareTo(b.date));
    final aj = p.getString(_kAccounts);
    _accounts = aj != null ? jsonDecode(aj) as Map<String, dynamic> : {};
    _sessionEmail = p.getString(_kSession);
    _workoutReminderOn = p.getBool(_kWorkoutReminder) ?? false;
    _workoutHour = p.getInt(_kWorkoutHour) ?? 18;
    _workoutMinute = p.getInt(_kWorkoutMinute) ?? 0;
    _waterReminderOn = p.getBool(_kWaterReminder) ?? false;
    final wpj = p.getString(_kWeekPlan);
    _weekPlan = wpj != null ? WeekPlan.fromJson(wpj) : null;
    final ewj = p.getString(_kExerciseWeights);
    _exerciseWeights.clear();
    if (ewj != null) {
      final decoded = jsonDecode(ewj) as Map<String, dynamic>;
      decoded.forEach((name, list) {
        _exerciseWeights[name] = (list as List)
            .map((e) => ExerciseWeightEntry.fromMap(e as Map<String, dynamic>))
            .toList();
      });
    }
    _localUserId = p.getString(_kLocalUserId) ?? '';
    if (_localUserId.isEmpty) {
      _localUserId = _newLocalId();
      await p.setString(_kLocalUserId, _localUserId);
    }
    _isTrainer = p.getBool(_kIsTrainer) ?? false;
    _groupId = p.getString(_kGroupId);
    _groupCode = p.getString(_kGroupCode);
    _loaded = true;
    notifyListeners();
  }

  String _newLocalId() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  // ── Rol entrenador / grupos ──────────────────────────────────────────────
  Future<void> setIsTrainer(bool v) async {
    _isTrainer = v;
    notifyListeners();
    await _prefs((p) => p.setBool(_kIsTrainer, v));
  }

  Future<void> setMyGroup(String groupId, String code) async {
    _groupId = groupId;
    _groupCode = code;
    notifyListeners();
    await _prefs((p) async {
      await p.setString(_kGroupId, groupId);
      await p.setString(_kGroupCode, code);
    });
  }

  Future<void> leaveGroup() async {
    _groupId = null;
    _groupCode = null;
    notifyListeners();
    await _prefs((p) async {
      await p.remove(_kGroupId);
      await p.remove(_kGroupCode);
    });
  }

  // ── Progreso por ejercicio (sobrecarga progresiva) ─────────────────────────
  /// Historial de pesos registrados para un ejercicio, más reciente primero.
  List<ExerciseWeightEntry> exerciseWeightHistory(String exerciseName) {
    final list = _exerciseWeights[exerciseName] ?? const [];
    return list.reversed.toList();
  }

  double? lastExerciseWeight(String exerciseName) {
    final list = _exerciseWeights[exerciseName];
    if (list == null || list.isEmpty) return null;
    return list.last.kg;
  }

  Future<void> logExerciseWeight(String exerciseName, double kg,
      {int? sets, int? reps}) async {
    final list = _exerciseWeights.putIfAbsent(exerciseName, () => []);
    list.add(ExerciseWeightEntry(DateTime.now(), kg, sets: sets, reps: reps));
    if (list.length > 20) list.removeRange(0, list.length - 20);
    notifyListeners();
    await _persistExerciseWeights();
  }

  /// Corrige un registro ya guardado (por si el usuario se equivocó al
  /// tipear). Se identifica por su fecha/hora exacta, que es única por
  /// registro.
  Future<void> updateExerciseEntry(String exerciseName, DateTime date,
      {required double kg, int? sets, int? reps}) async {
    final list = _exerciseWeights[exerciseName];
    if (list == null) return;
    final i = list.indexWhere((e) => e.date == date);
    if (i < 0) return;
    list[i] = ExerciseWeightEntry(date, kg, sets: sets, reps: reps);
    notifyListeners();
    await _persistExerciseWeights();
  }

  Future<void> deleteExerciseEntry(String exerciseName, DateTime date) async {
    final list = _exerciseWeights[exerciseName];
    if (list == null) return;
    list.removeWhere((e) => e.date == date);
    notifyListeners();
    await _persistExerciseWeights();
  }

  Future<void> _persistExerciseWeights() async {
    final encoded = jsonEncode(_exerciseWeights
        .map((name, list) => MapEntry(name, list.map((e) => e.toMap()).toList())));
    await _prefs((p) => p.setString(_kExerciseWeights, encoded));
  }

  /// Progresión automática: compara los últimos 2 registros de peso de un
  /// ejercicio y sugiere el próximo paso (sobrecarga progresiva). Devuelve
  /// null si todavía no hay suficiente historial.
  ExerciseSuggestion? suggestNextWeight(String exerciseName) {
    final history = _exerciseWeights[exerciseName]; // cronológico
    if (history == null || history.isEmpty) return null;
    if (history.length == 1) {
      return ExerciseSuggestion(
          'Registra una vez más para que te sugiera cuánto subir. 💪', null);
    }
    final last = history.last.kg;
    final prev = history[history.length - 2].kg;
    final step = last >= 10 ? 2.5 : 1.0;
    if (last > prev) {
      return ExerciseSuggestion(
          'Subiste a ${_fmtKg(last)} kg. Mantén ese peso una vez más antes de volver a subir.',
          last);
    }
    final next = last + step;
    return ExerciseSuggestion(
        'Llevas ${_fmtKg(last)} kg. Prueba con ${_fmtKg(next)} kg la próxima vez. 📈',
        next);
  }

  String _fmtKg(double kg) =>
      kg == kg.roundToDouble() ? kg.toInt().toString() : kg.toStringAsFixed(1);

  // ── Recordatorios ────────────────────────────────────────────────────────
  Future<void> setWorkoutReminder(bool on, {int? hour, int? minute}) async {
    _workoutReminderOn = on;
    if (hour != null) _workoutHour = hour;
    if (minute != null) _workoutMinute = minute;
    notifyListeners();
    await _prefs((p) async {
      await p.setBool(_kWorkoutReminder, on);
      await p.setInt(_kWorkoutHour, _workoutHour);
      await p.setInt(_kWorkoutMinute, _workoutMinute);
    });
    if (on) {
      await Notifications.scheduleWorkout(_workoutHour, _workoutMinute);
    } else {
      await Notifications.cancelWorkout();
    }
  }

  Future<void> setWaterReminder(bool on) async {
    _waterReminderOn = on;
    notifyListeners();
    await _prefs((p) => p.setBool(_kWaterReminder, on));
    if (on) {
      await Notifications.scheduleWater();
    } else {
      await Notifications.cancelWater();
    }
  }

  // ── Plan semanal (IA) ────────────────────────────────────────────────────
  Future<void> saveWeekPlan(WeekPlan plan) async {
    _weekPlan = plan;
    notifyListeners();
    await _prefs((p) => p.setString(_kWeekPlan, plan.toJson()));
  }

  String _hash(String password, String salt) =>
      sha256.convert(utf8.encode('$salt::$password')).toString();

  String _newSalt() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256).toRadixString(16))
        .join();
  }

  bool _validEmail(String e) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e.trim());

  /// Registra una cuenta nueva. Devuelve null si todo ok, o un mensaje de error.
  Future<String?> register(String name, String email, String password) async {
    email = email.trim().toLowerCase();
    if (name.trim().isEmpty) return 'Escribe tu nombre.';
    if (!_validEmail(email)) return 'Ese correo no parece válido.';
    if (password.length < 6) return 'La contraseña debe tener al menos 6 caracteres.';
    if (_accounts.containsKey(email)) return 'Ya existe una cuenta con ese correo.';
    final salt = _newSalt();
    _accounts[email] = {
      'name': name.trim(),
      'salt': salt,
      'hash': _hash(password, salt),
      'provider': 'email',
    };
    _sessionEmail = email;
    _profile.name = name.trim();
    notifyListeners();
    await _prefs((p) async {
      await p.setString(_kAccounts, jsonEncode(_accounts));
      await p.setString(_kSession, email);
      await p.setString(_kProfile, _profile.toJson());
    });
    return null;
  }

  /// Inicia sesión con correo/contraseña. Devuelve null si ok, o el error.
  Future<String?> login(String email, String password) async {
    email = email.trim().toLowerCase();
    final acc = _accounts[email];
    if (acc == null) return 'No hay ninguna cuenta con ese correo.';
    if (acc['hash'] != _hash(password, acc['salt'])) {
      return 'Contraseña incorrecta.';
    }
    _sessionEmail = email;
    notifyListeners();
    await _prefs((p) => p.setString(_kSession, email));
    return null;
  }

  /// Inicia/registra sesión con un proveedor externo (ej. Google).
  Future<void> loginWithProvider(String email, String name,
      {String provider = 'google'}) async {
    email = email.trim().toLowerCase();
    _accounts[email] ??= {'name': name, 'provider': provider};
    _sessionEmail = email;
    if (_profile.name.isEmpty) _profile.name = name;
    notifyListeners();
    await _prefs((p) async {
      await p.setString(_kAccounts, jsonEncode(_accounts));
      await p.setString(_kSession, email);
      await p.setString(_kProfile, _profile.toJson());
    });
  }

  Future<void> logout() async {
    _sessionEmail = null;
    notifyListeners();
    await _prefs((p) => p.remove(_kSession));
  }

  Future<void> _prefs(Future<void> Function(SharedPreferences p) fn) async {
    final p = await SharedPreferences.getInstance();
    await fn(p);
  }

  // ── Perfil / onboarding ──────────────────────────────────────────────────
  Future<void> completeOnboarding(Profile profile) async {
    _profile = profile;
    _onboarded = true;
    // Primer registro de peso para arrancar el gráfico.
    if (_weights.isEmpty) {
      _weights.add(WeightEntry(DateTime.now(), profile.weightKg));
    }
    notifyListeners();
    await _prefs((p) async {
      await p.setString(_kProfile, profile.toJson());
      await p.setBool(_kOnboarded, true);
      await p.setStringList(_kWeights, _weights.map((e) => e.toJson()).toList());
    });
  }

  Future<void> saveProfile(Profile profile) async {
    _profile = profile;
    notifyListeners();
    await _prefs((p) => p.setString(_kProfile, profile.toJson()));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _prefs((p) => p.setInt(_kTheme, mode.index));
  }

  // ── Registros diarios ────────────────────────────────────────────────────
  DayLog logFor(DateTime d) {
    final k = dayKey(d);
    return _logs[k] ?? DayLog(k);
  }

  DayLog get today => logFor(DateTime.now());

  Future<void> _saveLog(DayLog log) async {
    _logs[log.dateKey] = log;
    notifyListeners();
    await _prefs((p) =>
        p.setStringList(_kLogs, _logs.values.map((e) => e.toJson()).toList()));
  }

  Future<void> addWater([int delta = 1]) async {
    final log = today;
    log.water = (log.water + delta).clamp(0, 30);
    await _saveLog(log);
  }

  Future<void> toggleWorkoutDone(String workoutId) async {
    final log = today;
    if (log.workouts.contains(workoutId)) {
      log.workouts.remove(workoutId);
    } else {
      log.workouts.add(workoutId);
    }
    await _saveLog(log);
  }

  bool isWorkoutDoneToday(String id) => today.workouts.contains(id);

  Future<void> addFood(FoodEntry entry) async {
    final log = today;
    log.foods.add(entry);
    await _saveLog(log);
  }

  Future<void> removeFood(int index) async {
    final log = today;
    if (index >= 0 && index < log.foods.length) {
      log.foods.removeAt(index);
      await _saveLog(log);
    }
  }

  int get kcalToday => today.kcal;
  int get proteinToday => today.protein;

  // ── Peso ─────────────────────────────────────────────────────────────────
  Future<void> addWeight(double kg) async {
    final k = dayKey(DateTime.now());
    _weights.removeWhere((w) => dayKey(w.date) == k); // 1 registro por día
    _weights.add(WeightEntry(DateTime.now(), kg));
    _weights.sort((a, b) => a.date.compareTo(b.date));
    _profile.weightKg = kg;
    notifyListeners();
    await _prefs((p) async {
      await p.setStringList(_kWeights, _weights.map((e) => e.toJson()).toList());
      await p.setString(_kProfile, _profile.toJson());
    });
  }

  // ── Métricas / rachas ────────────────────────────────────────────────────
  int get waterToday => today.water;

  /// Días seguidos (terminando hoy o ayer) con al menos un entrenamiento.
  int get streak {
    int n = 0;
    var d = DateTime.now();
    // Si hoy aún no entrena, la racha puede venir desde ayer.
    if (logFor(d).workouts.isEmpty) d = d.subtract(const Duration(days: 1));
    while (logFor(d).workouts.isNotEmpty) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  /// Entrenamientos completados en los últimos 7 días.
  int get workoutsThisWeek {
    int n = 0;
    for (int i = 0; i < 7; i++) {
      final d = DateTime.now().subtract(Duration(days: i));
      n += logFor(d).workouts.length;
    }
    return n;
  }

  double? get startWeight => _weights.isEmpty ? null : _weights.first.kg;
  double? get lastWeight => _weights.isEmpty ? null : _weights.last.kg;

  // ── Gamificación: XP, nivel y totales acumulados ─────────────────────────
  /// Entrenamientos completados en toda la historia (no solo esta semana).
  int get totalWorkoutsDone =>
      _logs.values.fold(0, (s, l) => s + l.workouts.length);

  /// Comidas registradas con el escáner IA en toda la historia.
  int get totalFoodsLogged =>
      _logs.values.fold(0, (s, l) => s + l.foods.length);

  /// Días distintos en que se tomó al menos 1 vaso de agua.
  int get totalWaterDays => _logs.values.where((l) => l.water > 0).length;

  /// Puntos de experiencia: entrenar vale más que registrar comida o agua.
  int get totalXp =>
      totalWorkoutsDone * 20 +
      totalFoodsLogged * 8 +
      totalWaterDays * 5 +
      _weights.length * 5;

  /// Nivel del usuario según su XP acumulada (curva suave, sube más de a poco).
  int get level => 1 + (sqrt(totalXp / 60)).floor();

  /// XP que faltan para el siguiente nivel (para la barra de progreso).
  int get xpForNextLevel => (60 * pow(level, 2)).round();
  int get xpForThisLevel => (60 * pow(level - 1, 2)).round();
  double get levelProgress {
    final span = xpForNextLevel - xpForThisLevel;
    if (span <= 0) return 1;
    return ((totalXp - xpForThisLevel) / span).clamp(0, 1).toDouble();
  }
}
