import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/exercise_log.dart';
import '../models/logs.dart';
import '../models/profile.dart';
import '../models/week_plan.dart';
import 'notifications.dart';
import 'auth_service.dart';
import 'account_preferences.dart';
import 'profile_repository.dart';
import 'firebase_profile_repository.dart';

/// Perfil remoto por UID y registros locales separados por cuenta.
class AppStore extends ChangeNotifier {
  AppStore({
    required AccountAuth auth,
    required ProfileRepository profiles,
    Future<void> Function()? clearReminders,
  }) : _auth = auth,
       _profiles = profiles,
       _clearReminders =
           clearReminders ??
           (() async {
             await Notifications.cancelWorkout();
             await Notifications.cancelWater();
           });
  static final AppStore instance = AppStore(
    auth: FirebaseAccountAuth(),
    profiles: FirebaseProfileRepository(),
  );
  final AccountAuth _auth;
  final ProfileRepository _profiles;
  final Future<void> Function() _clearReminders;
  StreamSubscription<AccountIdentity?>? _authSubscription;
  AccountIdentity? _account;
  AccountPreferences? _accountPrefs;
  Future<void> _transition = Future.value();
  Future<void> _reminderTransition = Future.value();
  int _epoch = 0;
  bool _sessionInitialized = false;
  String? _sessionError;
  String? get sessionError => _sessionError;
  String? get currentUid => _account?.uid;

  static const _kProfile = 'brio_profile_v1';
  static const _kOnboarded = 'brio_onboarded_v1';
  static const _kTheme = 'brio_theme_v1';
  static const _kLogs = 'brio_daylogs_v1';
  static const _kWeights = 'brio_weights_v1';
  static const _kWorkoutReminder = 'brio_reminder_workout_v1';
  static const _kWorkoutHour = 'brio_reminder_workout_hour_v1';
  static const _kWorkoutMinute = 'brio_reminder_workout_min_v1';
  static const _kWaterReminder = 'brio_reminder_water_v1';
  static const _kWeekPlan = 'brio_weekplan_v1';
  static const _kExerciseWeights = 'brio_exercise_weights_v1';
  static const _kGroupId = 'brio_group_id_v1';
  static const _kGroupCode = 'brio_group_code_v1';

  Profile _profile = Profile();
  bool _onboarded = false;
  ThemeMode _themeMode = ThemeMode.system;
  final Map<String, DayLog> _logs = {};
  final List<WeightEntry> _weights = [];
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
  bool get authed => _account != null;
  String? get currentEmail => _account?.email;

  Future<void> load() async {
    _authSubscription ??= _auth.changes.listen((user) {
      unawaited(_acceptSession(user));
    });
    await _acceptSession(_auth.current);
  }

  Future<void> _acceptSession(AccountIdentity? user, {bool force = false}) {
    if (!force && _sessionInitialized && user?.uid == _account?.uid)
      return _transition;
    _sessionInitialized = true;
    final epoch = ++_epoch;
    _account = user;
    _accountPrefs = null;
    _profile = Profile();
    _onboarded = false;
    _themeMode = ThemeMode.system;
    _logs.clear();
    _weights.clear();
    _exerciseWeights.clear();
    _weekPlan = null;
    _groupId = null;
    _groupCode = null;
    _isTrainer = false;
    _localUserId = user?.uid ?? '';
    _workoutReminderOn = false;
    _waterReminderOn = false;
    _workoutHour = 18;
    _workoutMinute = 0;
    _loaded = false;
    _sessionError = null;
    notifyListeners();
    return _transition = _restoreAccount(user, epoch);
  }

  Future<void> _restoreAccount(AccountIdentity? user, int epoch) async {
    try {
      await _updateReminders(cancelOnly: true);
      if (epoch != _epoch) return;
      if (user != null) {
        final storage = await SharedPreferences.getInstance();
        if (epoch != _epoch) return;
        final p = AccountPreferences(storage, user.uid);
        _accountPrefs = p;
        _readAccountCache(p);
        final remote = await _profiles.loadOrCreate(user);
        if (epoch != _epoch) return;
        _profile = remote.profile;
        _onboarded = remote.onboarded;
        _isTrainer = remote.trainer;
        await p.setString(_kProfile, _profile.toJson());
        await p.setBool(_kOnboarded, remote.onboarded);
        if (epoch == _epoch) await _updateReminders();
      }
    } catch (_) {
      if (epoch != _epoch) return;
      _sessionError =
          'No pudimos recuperar tu perfil. Revisa la conexión y vuelve a intentar.';
    } finally {
      if (epoch == _epoch) {
        _loaded = true;
        notifyListeners();
      }
    }
  }

  Future<void> retryProfile() => _acceptSession(_auth.current, force: true);

  void _readAccountCache(AccountPreferences p) {
    final pj = p.getString(_kProfile);
    if (pj != null) _profile = Profile.fromJson(pj);
    _onboarded = p.getBool(_kOnboarded) ?? false;
    _themeMode = ThemeMode.values[(p.getInt(_kTheme) ?? 0).clamp(0, 2)];
    _logs
      ..clear()
      ..addEntries(
        (p.getStringList(_kLogs) ?? [])
            .map(DayLog.fromJson)
            .map((l) => MapEntry(l.dateKey, l)),
      );
    _weights
      ..clear()
      ..addAll((p.getStringList(_kWeights) ?? []).map(WeightEntry.fromJson));
    _weights.sort((a, b) => a.date.compareTo(b.date));
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
    _groupId = p.getString(_kGroupId);
    _groupCode = p.getString(_kGroupCode);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  // ── Rol entrenador / grupos ──────────────────────────────────────────────
  Future<void> setIsTrainer(bool value) async {
    if (value != _isTrainer) {
      throw StateError(
        'El rol de entrenador debe ser habilitado por un administrador.',
      );
    }
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

  Future<void> logExerciseWeight(
    String exerciseName,
    double kg, {
    int? sets,
    int? reps,
  }) async {
    final list = _exerciseWeights.putIfAbsent(exerciseName, () => []);
    list.add(ExerciseWeightEntry(DateTime.now(), kg, sets: sets, reps: reps));
    if (list.length > 20) list.removeRange(0, list.length - 20);
    notifyListeners();
    await _persistExerciseWeights();
  }

  /// Corrige un registro ya guardado (por si el usuario se equivocó al
  /// tipear). Se identifica por su fecha/hora exacta, que es única por
  /// registro.
  Future<void> updateExerciseEntry(
    String exerciseName,
    DateTime date, {
    required double kg,
    int? sets,
    int? reps,
  }) async {
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
    final encoded = jsonEncode(
      _exerciseWeights.map(
        (name, list) => MapEntry(name, list.map((e) => e.toMap()).toList()),
      ),
    );
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
        'Registra una vez más para que te sugiera cuánto subir. 💪',
        null,
      );
    }
    final last = history.last.kg;
    final prev = history[history.length - 2].kg;
    final step = last >= 10 ? 2.5 : 1.0;
    if (last > prev) {
      return ExerciseSuggestion(
        'Subiste a ${_fmtKg(last)} kg. Mantén ese peso una vez más antes de volver a subir.',
        last,
      );
    }
    final next = last + step;
    return ExerciseSuggestion(
      'Llevas ${_fmtKg(last)} kg. Prueba con ${_fmtKg(next)} kg la próxima vez. 📈',
      next,
    );
  }

  String _fmtKg(double kg) =>
      kg == kg.roundToDouble() ? kg.toInt().toString() : kg.toStringAsFixed(1);

  // ── Recordatorios ────────────────────────────────────────────────────────
  Future<void> _updateReminders({bool cancelOnly = false}) {
    final epoch = _epoch;
    final workout = !cancelOnly && _workoutReminderOn;
    final water = !cancelOnly && _waterReminderOn;
    final hour = _workoutHour;
    final minute = _workoutMinute;
    // Serialize platform calls: a previous account cannot schedule after logout.
    return _reminderTransition = _reminderTransition.catchError((_) {}).then((
      _,
    ) async {
      if (epoch != _epoch) return;
      await _clearReminders();
      if (epoch != _epoch) return;
      if (workout) await Notifications.scheduleWorkout(hour, minute);
      if (epoch != _epoch) return;
      if (water) await Notifications.scheduleWater();
    });
  }

  Future<void> setWorkoutReminder(bool on, {int? hour, int? minute}) async {
    final epoch = _epoch;
    _workoutReminderOn = on;
    if (hour != null) _workoutHour = hour;
    if (minute != null) _workoutMinute = minute;
    final savedHour = _workoutHour;
    final savedMinute = _workoutMinute;
    notifyListeners();
    await _prefs((p) async {
      await p.setBool(_kWorkoutReminder, on);
      await p.setInt(_kWorkoutHour, savedHour);
      await p.setInt(_kWorkoutMinute, savedMinute);
    });
    if (epoch == _epoch) await _updateReminders();
  }

  Future<void> setWaterReminder(bool on) async {
    final epoch = _epoch;
    _waterReminderOn = on;
    notifyListeners();
    await _prefs((p) => p.setBool(_kWaterReminder, on));
    if (epoch == _epoch) await _updateReminders();
  }

  // ── Plan semanal (IA) ────────────────────────────────────────────────────
  Future<void> saveWeekPlan(WeekPlan plan) async {
    _weekPlan = plan;
    notifyListeners();
    await _prefs((p) => p.setString(_kWeekPlan, plan.toJson()));
  }

  Future<String?> register(String name, String email, String password) async {
    if (name.trim().isEmpty) return 'Escribe tu nombre.';
    try {
      await _auth.register(name.trim(), email.trim(), password);
      await _acceptSession(_auth.current);
      return null;
    } catch (error) {
      return accountError(error);
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      await _auth.signIn(email.trim(), password);
      await _acceptSession(_auth.current);
      return null;
    } catch (error) {
      return accountError(error);
    }
  }

  Future<String?> loginWithGoogle() async {
    try {
      await _auth.signInWithGoogle();
      await _acceptSession(_auth.current);
      return null;
    } catch (error) {
      return accountError(error);
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    await _acceptSession(null);
  }

  Future<void> _prefs(Future<void> Function(AccountPreferences p) fn) async {
    final p = _accountPrefs;
    if (p == null || !authed) throw StateError('No hay una sesión lista.');
    await fn(p);
  }

  // ── Perfil / onboarding ──────────────────────────────────────────────────
  Future<void> completeOnboarding(Profile profile) async {
    await _saveRemoteProfile(profile, onboarded: true);
  }

  Future<void> saveProfile(Profile profile) async {
    await _saveRemoteProfile(profile, onboarded: _onboarded);
  }

  Future<void> _saveRemoteProfile(
    Profile profile, {
    required bool onboarded,
  }) async {
    final uid = currentUid;
    final epoch = _epoch;
    final cache = _accountPrefs;
    if (uid == null || cache == null || !_loaded || _sessionError != null) {
      throw StateError('No hay una sesión lista.');
    }
    final snapshot = profile.copy();
    await _profiles.save(uid, snapshot, onboarded: onboarded);
    if (epoch != _epoch)
      throw StateError('La sesión cambió durante el guardado.');
    _profile = snapshot;
    _onboarded = onboarded;
    if (_weights.isEmpty && onboarded) {
      _weights.add(WeightEntry(DateTime.now(), snapshot.weightKg));
    }
    final weights = _weights.map((e) => e.toJson()).toList();
    await cache.setString(_kProfile, snapshot.toJson());
    await cache.setBool(_kOnboarded, onboarded);
    await cache.setStringList(_kWeights, weights);
    if (epoch == _epoch) notifyListeners();
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
    await _prefs(
      (p) =>
          p.setStringList(_kLogs, _logs.values.map((e) => e.toJson()).toList()),
    );
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
    final epoch = _epoch;
    final updated = _profile.copy()..weightKg = kg;
    await saveProfile(updated);
    if (epoch != _epoch) throw StateError('La sesión cambió.');
    final k = dayKey(DateTime.now());
    _weights.removeWhere((w) => dayKey(w.date) == k); // 1 registro por día
    _weights.add(WeightEntry(DateTime.now(), kg));
    _weights.sort((a, b) => a.date.compareTo(b.date));
    _profile.weightKg = kg;
    notifyListeners();
    await _prefs((p) async {
      await p.setStringList(
        _kWeights,
        _weights.map((e) => e.toJson()).toList(),
      );
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
