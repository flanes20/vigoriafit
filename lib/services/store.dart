import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

  // ── Claves GLOBALES (del dispositivo, no por usuario) ────────────────────
  static const _kSession     = 'brio_session_v1';
  static const _kLocalUserId = 'brio_local_user_id_v1';
  static const _kTheme       = 'brio_theme_v1';

  // ── Claves POR USUARIO (se prefijan con UID en _uk()) ────────────────────
  static const _kProfile         = 'profile_v1';
  static const _kOnboarded       = 'onboarded_v1';
  static const _kLogs            = 'daylogs_v1';
  static const _kWeights         = 'weights_v1';
  static const _kWorkoutReminder = 'reminder_workout_v1';
  static const _kWorkoutHour     = 'reminder_workout_hour_v1';
  static const _kWorkoutMinute   = 'reminder_workout_min_v1';
  static const _kWaterReminder   = 'reminder_water_v1';
  static const _kWeekPlan        = 'weekplan_v1';
  static const _kExerciseWeights = 'exercise_weights_v1';
  static const _kIsTrainer       = 'is_trainer_v1';
  static const _kGroupId         = 'group_id_v1';
  static const _kGroupCode       = 'group_code_v1';

  Profile _profile = Profile();
  bool _onboarded = false;
  ThemeMode _themeMode = ThemeMode.system;
  final Map<String, DayLog> _logs = {};
  final List<WeightEntry> _weights = [];
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

  // ── Identificador de usuario unificado con Firebase Auth ─────────────────
  String get userId => FirebaseAuth.instance.currentUser?.uid ?? _localUserId;
  String get localUserId => userId;
  bool get isTrainer => _isTrainer;
  String? get groupId => _groupId;
  String? get groupCode => _groupCode;
  bool get inGroup => _groupId != null;

  // ── Sesión / autenticación ───────────────────────────────────────────────
  bool get authed => _sessionEmail != null;
  String? get currentEmail => _sessionEmail;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();

    // 1. Ajuste global: tema (es del dispositivo, no del usuario)
    _themeMode = ThemeMode.values[(p.getInt(_kTheme) ?? 0).clamp(0, 2)];

    // 2. Resolver el usuario activo (Firebase tiene prioridad sobre el ID local)
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser != null && fbUser.email != null) {
      _localUserId  = fbUser.uid;
      _sessionEmail = fbUser.email;
    } else {
      _localUserId = p.getString(_kLocalUserId) ?? '';
      if (_localUserId.isEmpty) {
        _localUserId = _newLocalId();
        await p.setString(_kLocalUserId, _localUserId);
      }
      _sessionEmail = p.getString(_kSession);
    }

    // 3. Cargar datos propios del usuario activo desde SharedPreferences
    await _loadUserDataFromPrefs(_localUserId);

    // 4. Arrancar listener reactivo; si hay sesión Firebase, sincronizar desde Firestore
    _loaded = true;
    _initAuthListener();
    if (fbUser != null) {
      _loadUserProfileFromFirestore(fbUser.uid);
    }
    notifyListeners();
  }

  String _newLocalId() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  /// Devuelve la clave de SharedPreferences prefijada con el UID del usuario
  /// activo, aislando sus datos de los de cualquier otro usuario en el mismo
  /// dispositivo.
  String _uk(String key) {
    final id = _localUserId.isNotEmpty ? _localUserId : 'anon';
    return '${id}_$key';
  }

  /// Resetea todo el estado en memoria al estado inicial (sin datos de usuario).
  /// Se invoca al cerrar sesión o antes de cargar los datos de otro usuario.
  void _resetMemoryState() {
    _profile        = Profile();
    _onboarded      = false;
    _logs.clear();
    _weights.clear();
    _weekPlan       = null;
    _exerciseWeights.clear();
    _isTrainer      = false;
    _groupId        = null;
    _groupCode      = null;
    _sessionEmail   = null;
  }

  /// Carga desde SharedPreferences los datos específicos del usuario [uid].
  /// Al cambiar de cuenta se llama primero a [_resetMemoryState] y luego a éste.
  Future<void> _loadUserDataFromPrefs(String uid) async {
    final p      = await SharedPreferences.getInstance();
    final prefix = uid.isNotEmpty ? uid : 'anon';
    String uk(String key) => '${prefix}_$key';

    final pj = p.getString(uk(_kProfile));
    _profile   = pj != null ? Profile.fromJson(pj) : Profile();
    _onboarded = p.getBool(uk(_kOnboarded)) ?? false;

    _logs
      ..clear()
      ..addEntries((p.getStringList(uk(_kLogs)) ?? [])
          .map(DayLog.fromJson)
          .map((l) => MapEntry(l.dateKey, l)));

    _weights
      ..clear()
      ..addAll((p.getStringList(uk(_kWeights)) ?? []).map(WeightEntry.fromJson));
    _weights.sort((a, b) => a.date.compareTo(b.date));

    _workoutReminderOn = p.getBool(uk(_kWorkoutReminder)) ?? false;
    _workoutHour       = p.getInt(uk(_kWorkoutHour))      ?? 18;
    _workoutMinute     = p.getInt(uk(_kWorkoutMinute))    ?? 0;
    _waterReminderOn   = p.getBool(uk(_kWaterReminder))   ?? false;

    final wpj  = p.getString(uk(_kWeekPlan));
    _weekPlan  = wpj != null ? WeekPlan.fromJson(wpj) : null;

    final ewj  = p.getString(uk(_kExerciseWeights));
    _exerciseWeights.clear();
    if (ewj != null) {
      final decoded = jsonDecode(ewj) as Map<String, dynamic>;
      decoded.forEach((name, list) {
        _exerciseWeights[name] = (list as List)
            .map((e) => ExerciseWeightEntry.fromMap(e as Map<String, dynamic>))
            .toList();
      });
    }

    _isTrainer = p.getBool(uk(_kIsTrainer)) ?? false;
    _groupId   = p.getString(uk(_kGroupId));
    _groupCode = p.getString(uk(_kGroupCode));
  }

  // ── Rol entrenador / grupos ──────────────────────────────────────────────
  Future<void> setIsTrainer(bool v) async {
    _isTrainer = v;
    notifyListeners();
    await _prefs((p) => p.setBool(_uk(_kIsTrainer), v));
  }

  Future<void> setMyGroup(String groupId, String code) async {
    _groupId = groupId;
    _groupCode = code;
    notifyListeners();
    await _prefs((p) async {
      await p.setString(_uk(_kGroupId), groupId);
      await p.setString(_uk(_kGroupCode), code);
    });
  }

  Future<void> leaveGroup() async {
    _groupId = null;
    _groupCode = null;
    notifyListeners();
    await _prefs((p) async {
      await p.remove(_uk(_kGroupId));
      await p.remove(_uk(_kGroupCode));
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
    await _prefs((p) => p.setString(_uk(_kExerciseWeights), encoded));
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
      await p.setBool(_uk(_kWorkoutReminder), on);
      await p.setInt(_uk(_kWorkoutHour), _workoutHour);
      await p.setInt(_uk(_kWorkoutMinute), _workoutMinute);
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
    await _prefs((p) => p.setBool(_uk(_kWaterReminder), on));
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
    await _prefs((p) => p.setString(_uk(_kWeekPlan), plan.toJson()));
  }

  bool _validEmail(String e) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e.trim());

  /// Registra una cuenta nueva con Firebase Authentication.
  /// Devuelve null si todo ok, o un mensaje de error descriptivo en español.
  Future<String?> register(String name, String email, String password) async {
    name = name.trim();
    email = email.trim().toLowerCase();
    if (name.isEmpty) return 'Escribe tu nombre.';
    if (!_validEmail(email)) return 'Ese correo no parece válido.';
    if (password.length < 6) return 'La contraseña debe tener al menos 6 caracteres.';

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user;
      if (user != null) {
        await user.updateDisplayName(name);
        _localUserId = user.uid;
        _sessionEmail = user.email ?? email;
        _profile.name = name;

        // Crear documento de usuario en Firestore con createdAt (solo la primera vez)
        await _syncUserToFirestore(user.uid, name, email, isNew: true);
      }

      notifyListeners();
      await _prefs((p) async {
        await p.setString(_kSession, email);              // global
        await p.setString(_kLocalUserId, _localUserId);   // global
        await p.setString(_uk(_kProfile), _profile.toJson()); // por usuario
      });
      return null;
    } on FirebaseAuthException catch (e) {
      return _authErrorMessage(e);
    } catch (e) {
      return 'No se pudo crear la cuenta: $e';
    }
  }

  /// Inicia sesión con correo y contraseña en Firebase Authentication.
  /// Devuelve null si ok, o un mensaje de error descriptivo en español.
  Future<String?> login(String email, String password) async {
    email = email.trim().toLowerCase();
    if (!_validEmail(email)) return 'Ese correo no parece válido.';
    if (password.isEmpty) return 'Ingresa tu contraseña.';

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user;
      if (user != null) {
        _localUserId = user.uid;
        _sessionEmail = user.email ?? email;
        if (user.displayName != null && user.displayName!.isNotEmpty) {
          _profile.name = user.displayName!;
        }
        // Vincula el perfil público con el UID de Firebase Auth
        await _syncUserToFirestore(user.uid, _profile.name, email);
        // Recupera el perfil privado desde Firestore usando el UID (punto 6)
        await _loadUserProfileFromFirestore(user.uid);
      }

      notifyListeners();
      await _prefs((p) async {
        await p.setString(_kSession, email);              // global
        await p.setString(_kLocalUserId, _localUserId);   // global
        await p.setString(_uk(_kProfile), _profile.toJson()); // por usuario
      });
      return null;
    } on FirebaseAuthException catch (e) {
      return _authErrorMessage(e);
    } catch (e) {
      return 'No se pudo iniciar sesión: $e';
    }
  }

  /// Envía correo de recuperación de contraseña con Firebase Authentication.
  Future<String?> sendPasswordReset(String email) async {
    email = email.trim().toLowerCase();
    if (!_validEmail(email)) return 'Ingresa un correo electrónico válido.';
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return _authErrorMessage(e);
    } catch (e) {
      return 'Error al enviar recuperación: $e';
    }
  }

  /// Sincroniza datos base del usuario en Firestore (colección usuarios).
  /// [isNew] = true agrega createdAt solo al crear la cuenta por primera vez.
  Future<void> _syncUserToFirestore(String uid, String name, String email,
      {bool isNew = false}) async {
    try {
      final data = <String, dynamic>{
        'uid': uid,
        'displayName': name,
        'email': email,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (isNew) {
        // createdAt solo se escribe si el documento no existe aún
        data['createdAt'] = FieldValue.serverTimestamp();
      }
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Firestore] Error al sincronizar usuario $uid: $e');
    }
  }

  /// Mapea los códigos de error de FirebaseAuth a mensajes claros en español.
  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Ya existe una cuenta registrada con este correo.';
      case 'invalid-email':
        return 'El formato del correo electrónico no es válido.';
      case 'weak-password':
        return 'La contraseña es muy débil (mínimo 6 caracteres).';
      case 'user-not-found':
        return 'No existe ninguna cuenta asociada a este correo.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada por el administrador.';
      case 'too-many-requests':
        return 'Demasiados intentos fallidos. Inténtalo más tarde.';
      case 'network-request-failed':
        return 'Error de conexión. Revisa tu conexión a internet.';
      case 'operation-not-allowed':
        return 'El acceso por correo/contraseña no está habilitado en Firebase Console.';
      default:
        return e.message ?? 'Error de autenticación (${e.code}).';
    }
  }

  /// Inicia/registra sesión con un proveedor externo (ej. Google) y sincroniza con Firestore.
  Future<void> loginWithProvider(String email, String name,
      {String provider = 'google'}) async {
    email = email.trim().toLowerCase();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // Seguridad: no continuar sin usuario autenticado
    final uid = user.uid;

    // Detectar si es un usuario nuevo (primera vez que entra con este proveedor)
    final isNew = user.metadata.creationTime != null &&
        user.metadata.lastSignInTime != null &&
        user.metadata.lastSignInTime!
                .difference(user.metadata.creationTime!)
                .inSeconds
                .abs() <
            30;

    _localUserId = uid;
    _sessionEmail = user.email ?? email;
    if (_profile.name.isEmpty) _profile.name = name;

    // Sincroniza perfil público en usuarios/{uid}; isNew=true solo al crear cuenta
    await _syncUserToFirestore(uid, _profile.name, _sessionEmail!, isNew: isNew);
    // Carga perfil privado desde Firestore si ya existía (ej. usuario que vuelve)
    await _loadUserProfileFromFirestore(uid);

    notifyListeners();
    await _prefs((p) async {
      await p.setString(_kSession, _sessionEmail!);       // global
      await p.setString(_kLocalUserId, _localUserId);     // global
      await p.setString(_uk(_kProfile), _profile.toJson()); // por usuario
    });
  }

  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    // Limpiar estado en memoria; los datos del usuario quedan en SharedPreferences
    // bajo su UID para que pueda recuperarlos si vuelve a iniciar sesión.
    _resetMemoryState();
    _localUserId = '';
    notifyListeners();
    await _prefs((p) => p.remove(_kSession));
  }

  bool _authListenerInitialized = false;

  /// Escucha reactivamente cambios en el estado de autenticación de Firebase.
  /// Detecta cambio de usuario y carga los datos correctos para cada cuenta.
  void _initAuthListener() {
    if (_authListenerInitialized) return;
    _authListenerInitialized = true;
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        final isNewUser = _localUserId != user.uid;
        if (isNewUser) {
          // Cambio de cuenta: limpiar estado anterior y cargar datos del nuevo usuario
          _resetMemoryState();
          _localUserId = user.uid;
          await _loadUserDataFromPrefs(user.uid);
        }
        _sessionEmail = user.email;
        _localUserId  = user.uid;
        if (user.displayName != null &&
            user.displayName!.isNotEmpty &&
            _profile.name.isEmpty) {
          _profile.name = user.displayName!;
        }
        // Sincroniza con Firestore (si hay conexión, sobreescribe con datos en la nube)
        await _loadUserProfileFromFirestore(user.uid);
      } else {
        // Sin sesión: limpiar todo el estado en memoria
        _resetMemoryState();
        _localUserId = '';
      }
      notifyListeners();
    });
  }

  /// Carga el perfil privado del usuario desde Firestore si existe.
  /// Solo aplica los datos si el perfil en Firestore es más completo que el local
  /// (es decir, si el usuario ya completó el onboarding en otro dispositivo).
  Future<void> _loadUserProfileFromFirestore(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .collection('perfil_privado')
          .doc('datos')
          .get();
      if (doc.exists && doc.data() != null) {
        // Filtramos campos de Firestore que Profile.fromMap no entiende (Timestamp, etc.)
        final raw = doc.data()!;
        final data = Map<String, dynamic>.from(raw)
          ..remove('updatedAt')
          ..remove('createdAt');
        _profile = Profile.fromMap(data);
        _onboarded = true;
        notifyListeners();
        await _prefs((p) async {
          await p.setString(_uk(_kProfile), _profile.toJson());
          await p.setBool(_uk(_kOnboarded), true);
        });
      }
    } catch (_) {
      // Si no hay conexión, se mantiene el perfil local en caché
    }
  }

  /// Sincroniza el perfil actual con la colección privada en Firestore.
  /// Usa [userId] (que prioriza el UID de Firebase) en vez de _localUserId.
  Future<void> _syncProfileToFirestore() async {
    final uid = userId; // ← CORRECCIÓN: usar getter unificado, no _localUserId
    if (uid.isEmpty) return;
    try {
      // Actualiza perfil público (nombre visible)
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'displayName': _profile.name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Guarda/actualiza perfil privado completo
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .collection('perfil_privado')
          .doc('datos')
          .set({
        ..._profile.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Firestore] Error al sincronizar perfil de $uid: $e');
    }
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
      await p.setString(_uk(_kProfile),  profile.toJson());
      await p.setBool(_uk(_kOnboarded),  true);
      await p.setStringList(_uk(_kWeights), _weights.map((e) => e.toJson()).toList());
    });
    await _syncProfileToFirestore();
  }

  Future<void> saveProfile(Profile profile) async {
    _profile = profile;
    notifyListeners();
    await _prefs((p) => p.setString(_uk(_kProfile), profile.toJson()));
    await _syncProfileToFirestore();
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
        p.setStringList(_uk(_kLogs), _logs.values.map((e) => e.toJson()).toList()));
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
      await p.setStringList(_uk(_kWeights), _weights.map((e) => e.toJson()).toList());
      await p.setString(_uk(_kProfile), _profile.toJson());
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
