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
import '../models/units.dart';
import '../models/week_plan.dart';
import 'notifications.dart';

/// Estado de sincronización de datos con Firestore en la nube (#112).
enum SyncStatus {
  /// Confirmado: guardado exitosamente tanto en el dispositivo como en Firestore.
  synced,

  /// Pendiente: guardado localmente, en proceso de envío a la nube.
  pending,

  /// Fallido: guardado en el dispositivo, pero la escritura remota falló (sin conexión/error).
  failed,
}

/// Almacén central de VigoriaFit. Guarda el perfil, los registros diarios (agua y
/// entrenamientos), el historial de peso y los ajustes en el dispositivo, y
/// avisa a la UI cuando algo cambia.
class AppStore extends ChangeNotifier {
  AppStore._();
  static final AppStore instance = AppStore._();

  // ── Claves GLOBALES (del dispositivo, no por usuario) ────────────────────
  static const _kSession = 'brio_session_v1';
  static const _kLocalUserId = 'brio_local_user_id_v1';
  static const _kTheme = 'brio_theme_v1';
  static const _kUnitSystem = 'brio_unit_system_v1';

  // ── Claves POR USUARIO (se prefijan con UID en _uk()) ────────────────────
  static const _kProfile = 'profile_v1';
  static const _kOnboarded = 'onboarded_v1';
  static const _kLogs = 'daylogs_v1';
  static const _kWeights = 'weights_v1';
  static const _kWorkoutReminder = 'reminder_workout_v1';
  static const _kWorkoutHour = 'reminder_workout_hour_v1';
  static const _kWorkoutMinute = 'reminder_workout_min_v1';
  static const _kWaterReminder = 'reminder_water_v1';
  static const _kWeekPlan = 'weekplan_v1';
  static const _kExerciseWeights = 'exercise_weights_v1';
  static const _kIsTrainer = 'is_trainer_v1';
  static const _kGroupId = 'group_id_v1';
  static const _kGroupCode = 'group_code_v1';
  static const _kPendingSync = 'pending_sync_v1';

  static const _kUserKeys = [
    _kProfile,
    _kOnboarded,
    _kLogs,
    _kWeights,
    _kWorkoutReminder,
    _kWorkoutHour,
    _kWorkoutMinute,
    _kWaterReminder,
    _kWeekPlan,
    _kExerciseWeights,
    _kIsTrainer,
    _kGroupId,
    _kGroupCode,
    _kPendingSync,
  ];

  bool _authActionInProgress = false;

  SyncStatus _syncStatus = SyncStatus.synced;
  String? _syncError;
  bool _isProfileLoading = false;
  String? _profileLoadError;

  Profile _profile = Profile();
  bool _onboarded = false;
  ThemeMode _themeMode = ThemeMode.system;
  UnitSystem _unitSystem = UnitSystem.metric;
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
  UnitSystem get unitSystem => _unitSystem;
  bool get loaded => _loaded;
  List<WeightEntry> get weights => List.unmodifiable(_weights);
  bool get workoutReminderOn => _workoutReminderOn;
  int get workoutHour => _workoutHour;
  int get workoutMinute => _workoutMinute;
  bool get waterReminderOn => _waterReminderOn;
  WeekPlan? get weekPlan => _weekPlan;
  SyncStatus get syncStatus => _syncStatus;
  String? get syncError => _syncError;
  bool get hasPendingSync =>
      _syncStatus == SyncStatus.pending || _syncStatus == SyncStatus.failed;
  bool get isProfileLoading => _isProfileLoading;
  String? get profileLoadError => _profileLoadError;

  /// Helper de formateo de peso según la preferencia activa de unidades (#124).
  String formatWeight(double kg, {int decimals = 1}) =>
      UnitHelper.formatWeight(kg, system: _unitSystem, decimals: decimals);

  /// Helper de formateo de diferencia de peso según la preferencia activa (#124).
  String formatWeightDiff(double kgDiff, {int decimals = 1}) =>
      UnitHelper.formatWeightDiff(kgDiff, system: _unitSystem, decimals: decimals);

  /// Helper de formateo de estatura según la preferencia activa (#124).
  String formatHeight(double cm) =>
      UnitHelper.formatHeight(cm, system: _unitSystem);

  // ── Identificador de usuario unificado con Firebase Auth ─────────────────
  String get userId {
    try {
      return FirebaseAuth.instance.currentUser?.uid ?? _localUserId;
    } catch (_) {
      return _localUserId;
    }
  }
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

    // 1. Ajuste global: tema y unidades (son del dispositivo, no del usuario)
    _themeMode = ThemeMode.values[(p.getInt(_kTheme) ?? 0).clamp(0, 2)];
    _unitSystem =
        UnitSystem.values[(p.getInt(_kUnitSystem) ?? 0).clamp(0, 1)];

    // 2. Resolver el usuario activo (Firebase tiene prioridad sobre el ID local)
    User? fbUser;
    try {
      fbUser = FirebaseAuth.instance.currentUser;
    } catch (_) {}
    if (fbUser != null && fbUser.email != null) {
      _localUserId = fbUser.uid;
      _sessionEmail = fbUser.email;
    } else {
      _sessionEmail = p.getString(_kSession);
      _localUserId = p.getString(_kLocalUserId) ?? '';
      // Garantizar un ID anónimo persistente si aún no existe uno asignado
      if (_localUserId.isEmpty) {
        _localUserId = _newLocalId();
        await p.setString(_kLocalUserId, _localUserId);
      }
    }

    // 3. Cargar datos propios del usuario activo desde SharedPreferences
    await _loadUserDataFromPrefs(_localUserId);

    // 4. Si hay usuario autenticado y existen datos legacy sin prefijo con propiedad cierta, migrarlos
    if (fbUser != null && fbUser.email != null) {
      await migrateLegacyUnprefixedDataToUser(fbUser.uid, targetEmail: fbUser.email!);
      await _loadUserDataFromPrefs(fbUser.uid);
    }

    // 5. Verificar si hay sincronización pendiente guardada en este dispositivo
    final hadPending = p.getBool(_uk(_kPendingSync)) ?? false;
    if (hadPending) {
      _syncStatus = SyncStatus.pending;
    }

    // 6. Arrancar listener reactivo y sincronizar con Firestore
    _loaded = true;
    _initAuthListener();
    if (fbUser != null) {
      if (hadPending) {
        // Los datos del dispositivo son más recientes que los de la nube:
        // subimos los datos locales pendientes en vez de sobreescribirlos
        retryPendingSync();
      } else {
        _loadUserProfileFromFirestore(fbUser.uid);
      }
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
    _profile = Profile();
    _onboarded = false;
    _logs.clear();
    _weights.clear();
    _weekPlan = null;
    _exerciseWeights.clear();
    _isTrainer = false;
    _groupId = null;
    _groupCode = null;
    _sessionEmail = null;
    _syncStatus = SyncStatus.synced;
    _syncError = null;
  }

  /// Carga desde SharedPreferences los datos específicos del usuario [uid].
  /// Al cambiar de cuenta se llama primero a [_resetMemoryState] y luego a éste.
  Future<void> _loadUserDataFromPrefs(String uid) async {
    final p = await SharedPreferences.getInstance();
    final prefix = uid.isNotEmpty ? uid : 'anon';
    String uk(String key) => '${prefix}_$key';

    final pj = p.getString(uk(_kProfile));
    _profile = pj != null ? Profile.fromJson(pj) : Profile();
    _onboarded = p.getBool(uk(_kOnboarded)) ?? false;

    _logs
      ..clear()
      ..addEntries(
        (p.getStringList(uk(_kLogs)) ?? [])
            .map(DayLog.fromJson)
            .map((l) => MapEntry(l.dateKey, l)),
      );

    _weights
      ..clear()
      ..addAll(
        (p.getStringList(uk(_kWeights)) ?? []).map(WeightEntry.fromJson),
      );
    _weights.sort((a, b) => a.date.compareTo(b.date));

    _workoutReminderOn = p.getBool(uk(_kWorkoutReminder)) ?? false;
    _workoutHour = p.getInt(uk(_kWorkoutHour)) ?? 18;
    _workoutMinute = p.getInt(uk(_kWorkoutMinute)) ?? 0;
    _waterReminderOn = p.getBool(uk(_kWaterReminder)) ?? false;

    final wpj = p.getString(uk(_kWeekPlan));
    _weekPlan = wpj != null ? WeekPlan.fromJson(wpj) : null;

    final ewj = p.getString(uk(_kExerciseWeights));
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
    _groupId = p.getString(uk(_kGroupId));
    _groupCode = p.getString(uk(_kGroupCode));
  }

  /// Migra los datos locales generados durante una sesión anónima/invitada hacia
  /// el UID de la nueva cuenta [toUid].
  /// Esta migración se realiza únicamente cuando la propiedad de los datos es CIERTA
  /// (es decir, el usuario configuró sus datos en este dispositivo y procede a registrarse).
  Future<void> migrateLocalDataToUser(String fromId, String toUid) async {
    if (fromId.isEmpty || fromId == toUid) return;
    final p = await SharedPreferences.getInstance();
    for (final key in _kUserKeys) {
      final oldKey = '${fromId}_$key';
      final newKey = '${toUid}_$key';

      if (!p.containsKey(oldKey)) continue;

      if (key == _kLogs || key == _kWeights) {
        final val = p.getStringList(oldKey);
        if (val != null) {
          await p.setStringList(newKey, val);
          await p.remove(oldKey);
        }
      } else if (key == _kOnboarded ||
          key == _kWorkoutReminder ||
          key == _kWaterReminder ||
          key == _kIsTrainer) {
        final val = p.getBool(oldKey);
        if (val != null) {
          await p.setBool(newKey, val);
          await p.remove(oldKey);
        }
      } else if (key == _kWorkoutHour || key == _kWorkoutMinute) {
        final val = p.getInt(oldKey);
        if (val != null) {
          await p.setInt(newKey, val);
          await p.remove(oldKey);
        }
      } else {
        final val = p.getString(oldKey);
        if (val != null) {
          await p.setString(newKey, val);
          await p.remove(oldKey);
        }
      }
    }
    await p.setString(_kLocalUserId, toUid);
  }

  /// Limpia los datos locales huérfanos asociados a un UID específico.
  /// Se usa para descartar datos anónimos cuya propiedad sea incierta (por ejemplo,
  /// al iniciar sesión con una cuenta existente diferente).
  Future<void> clearLocalUserData(String uid) async {
    if (uid.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    for (final key in _kUserKeys) {
      await p.remove('${uid}_$key');
    }
  }

  /// Migra datos legacy almacenados sin prefijo de UID al espacio de nombres del usuario [toUid].
  /// Solo se invoca si la sesión anterior del dispositivo coincide de manera cierta con [targetEmail].
  Future<void> migrateLegacyUnprefixedDataToUser(
    String toUid, {
    required String targetEmail,
  }) async {
    if (toUid.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    final savedEmail = p.getString(_kSession);
    if (savedEmail == null ||
        savedEmail.toLowerCase() != targetEmail.toLowerCase()) {
      // Propiedad incierta: no migrar automáticamente datos que podrían pertenecer a otro usuario
      return;
    }

    for (final key in _kUserKeys) {
      final oldKey = key; // sin prefijo
      final newKey = '${toUid}_$key';

      if (!p.containsKey(oldKey)) continue;

      // Si la cuenta ya tiene datos propios en newKey, preservarlos y solo limpiar la clave legacy
      if (p.containsKey(newKey)) {
        await p.remove(oldKey);
        continue;
      }

      if (key == _kLogs || key == _kWeights) {
        final val = p.getStringList(oldKey);
        if (val != null) {
          await p.setStringList(newKey, val);
          await p.remove(oldKey);
        }
      } else if (key == _kOnboarded ||
          key == _kWorkoutReminder ||
          key == _kWaterReminder ||
          key == _kIsTrainer) {
        final val = p.getBool(oldKey);
        if (val != null) {
          await p.setBool(newKey, val);
          await p.remove(oldKey);
        }
      } else if (key == _kWorkoutHour || key == _kWorkoutMinute) {
        final val = p.getInt(oldKey);
        if (val != null) {
          await p.setInt(newKey, val);
          await p.remove(oldKey);
        }
      } else {
        final val = p.getString(oldKey);
        if (val != null) {
          await p.setString(newKey, val);
          await p.remove(oldKey);
        }
      }
    }
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
    if (password.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }

    _authActionInProgress = true;
    final wasAnonymous = _sessionEmail == null;
    final oldLocalId = _localUserId;

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

        // Propiedad cierta: migrar datos locales del onboarding anónimo al nuevo usuario
        if (wasAnonymous && oldLocalId.isNotEmpty && oldLocalId != user.uid) {
          await migrateLocalDataToUser(oldLocalId, user.uid);
        }

        // Sincronizar en Firestore tanto datos básicos (/users/{uid}) como privados (/users/{uid}/private/health_profile)
        await _syncProfileToFirestore();
      }

      notifyListeners();
      await _prefs((p) async {
        await p.setString(_kSession, email); // global
        await p.setString(_kLocalUserId, _localUserId); // global
        await p.setString(_uk(_kProfile), _profile.toJson()); // por usuario
      });
      return null;
    } on FirebaseAuthException catch (e) {
      return _authErrorMessage(e);
    } catch (e) {
      return 'No se pudo crear la cuenta: $e';
    } finally {
      _authActionInProgress = false;
    }
  }

  /// Inicia sesión con correo y contraseña en Firebase Authentication.
  /// Devuelve null si ok, o un mensaje de error descriptivo en español.
  Future<String?> login(String email, String password) async {
    email = email.trim().toLowerCase();
    if (!_validEmail(email)) return 'Ese correo no parece válido.';
    if (password.isEmpty) return 'Ingresa tu contraseña.';

    _authActionInProgress = true;
    final wasAnonymous = _sessionEmail == null;
    final oldLocalId = _localUserId;

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user;
      if (user != null) {
        // Al iniciar sesión en cuenta existente, la propiedad de los datos locales anónimos
        // previos es INCIERTA. Evitamos trasladarlos automáticamente para no contaminar
        // ni sobreescribir la cuenta existente con información ajena o de pruebas.
        _resetMemoryState();
        _localUserId = user.uid;
        _sessionEmail = user.email ?? email;

        // Limpiar datos anónimos huérfanos con propiedad incierta
        if (wasAnonymous && oldLocalId.isNotEmpty && oldLocalId != user.uid) {
          await clearLocalUserData(oldLocalId);
        }

        // 1. Cargar datos locales existentes de este usuario
        await _loadUserDataFromPrefs(user.uid);

        // 2. Migrar datos legacy sin prefijo solo si la sesión previa del dispositivo coincide con certeza
        await migrateLegacyUnprefixedDataToUser(user.uid, targetEmail: email);

        // 3. Cargar perfil desde Firestore (fuente de verdad en la nube)
        await _loadUserProfileFromFirestore(user.uid);

        if (user.displayName != null &&
            user.displayName!.isNotEmpty &&
            _profile.name.isEmpty) {
          _profile.name = user.displayName!;
        }
      }

      notifyListeners();
      await _prefs((p) async {
        await p.setString(_kSession, email); // global
        await p.setString(_kLocalUserId, _localUserId); // global
        await p.setString(_uk(_kProfile), _profile.toJson()); // por usuario
      });
      return null;
    } on FirebaseAuthException catch (e) {
      return _authErrorMessage(e);
    } catch (e) {
      return 'No se pudo iniciar sesión: $e';
    } finally {
      _authActionInProgress = false;
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
  Future<void> loginWithProvider(
    String email,
    String name, {
    String provider = 'google',
  }) async {
    email = email.trim().toLowerCase();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // Seguridad: no continuar sin usuario autenticado
    final uid = user.uid;

    _authActionInProgress = true;
    final wasAnonymous = _sessionEmail == null;
    final oldLocalId = _localUserId;

    final isNew =
        user.metadata.creationTime != null &&
        user.metadata.lastSignInTime != null &&
        user.metadata.lastSignInTime!
                .difference(user.metadata.creationTime!)
                .inSeconds
                .abs() <
            30;

    try {
      if (isNew) {
        // Usuario nuevo creado con proveedor: propiedad cierta de los datos del onboarding
        _localUserId = uid;
        _sessionEmail = user.email ?? email;
        if (_profile.name.isEmpty) _profile.name = name;

        if (wasAnonymous && oldLocalId.isNotEmpty && oldLocalId != uid) {
          await migrateLocalDataToUser(oldLocalId, uid);
        }

        // Sincronizar documento principal y privado en Firestore
        await _syncProfileToFirestore();
      } else {
        // Usuario existente: propiedad incierta de los datos anónimos locales.
        // No trasladar automáticamente; cargar datos legítimos de la cuenta existente.
        _resetMemoryState();
        _localUserId = uid;
        _sessionEmail = user.email ?? email;

        if (wasAnonymous && oldLocalId.isNotEmpty && oldLocalId != uid) {
          await clearLocalUserData(oldLocalId);
        }

        await _loadUserDataFromPrefs(uid);
        await migrateLegacyUnprefixedDataToUser(uid, targetEmail: email);
        await _loadUserProfileFromFirestore(uid);

        if (_profile.name.isEmpty) _profile.name = name;
      }

      notifyListeners();
      await _prefs((p) async {
        await p.setString(_kSession, _sessionEmail!); // global
        await p.setString(_kLocalUserId, _localUserId); // global
        await p.setString(_uk(_kProfile), _profile.toJson()); // por usuario
      });
    } finally {
      _authActionInProgress = false;
    }
  }

  Future<void> logout() async {
    _authActionInProgress = true;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    // Limpiar estado en memoria; los datos del usuario quedan en SharedPreferences
    // bajo su UID para que pueda recuperarlos si vuelve a iniciar sesión.
    _resetMemoryState();
    final p = await SharedPreferences.getInstance();
    await p.remove(_kSession);

    // Generar un nuevo ID anónimo para evitar que un futuro invitado o sesión anónima
    // acceda o contamine los datos del usuario que acaba de cerrar sesión.
    _localUserId = _newLocalId();
    await p.setString(_kLocalUserId, _localUserId);

    notifyListeners();
    _authActionInProgress = false;
  }

  bool _authListenerInitialized = false;

  /// Escucha reactivamente cambios en el estado de autenticación de Firebase.
  /// Detecta cambio de usuario y carga los datos correctos para cada cuenta.
  void _initAuthListener() {
    if (_authListenerInitialized) return;
    _authListenerInitialized = true;
    try {
      FirebaseAuth.instance.authStateChanges().listen((User? user) async {
        if (_authActionInProgress) return;
        if (user != null) {
          final isNewUser = _localUserId != user.uid;
          if (isNewUser) {
            // Cambio de cuenta: limpiar estado anterior y cargar datos del nuevo usuario
            _resetMemoryState();
            _localUserId = user.uid;
            await _loadUserDataFromPrefs(user.uid);
          }
          _sessionEmail = user.email;
          _localUserId = user.uid;
          if (user.displayName != null &&
              user.displayName!.isNotEmpty &&
              _profile.name.isEmpty) {
            _profile.name = user.displayName!;
          }
          // Sincroniza con Firestore solo si NO hay cambios pendientes en este dispositivo
          if (!hasPendingSync) {
            await _loadUserProfileFromFirestore(user.uid);
          } else {
            await retryPendingSync();
          }
        } else {
          // Sin sesión: limpiar todo el estado en memoria y generar nuevo ID anónimo
          _resetMemoryState();
          final p = await SharedPreferences.getInstance();
          await p.remove(_kSession);
          _localUserId = _newLocalId();
          await p.setString(_kLocalUserId, _localUserId);
        }
        notifyListeners();
      });
    } catch (_) {
      // Firebase no está inicializado (ej. entorno de tests unitarios)
    }
  }

  /// Carga el perfil del usuario desde Firestore si existe.
  /// Ruta: users/{uid} y users/{uid}/private/health_profile
  Future<void> _loadUserProfileFromFirestore(String uid) async {
    // Si hay guardado pendiente en este dispositivo, los datos locales son
    // más recientes: NO sobreescribir con datos desactualizados de la nube.
    if (hasPendingSync) {
      debugPrint('[Firestore] Omitiendo carga remota para $uid: hay guardado local pendiente.');
      return;
    }

    _isProfileLoading = true;
    _profileLoadError = null;
    notifyListeners();

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 8));
      final healthDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('private')
          .doc('health_profile')
          .get()
          .timeout(const Duration(seconds: 8));

      // Doble comprobación: si mientras respondía la red se produjo un guardado local
      if (hasPendingSync) {
        debugPrint('[Firestore] Cancelando aplicación de perfil remoto para $uid: hay guardado pendiente.');
        return;
      }

      if (userDoc.exists && userDoc.data() != null) {
        final uData = userDoc.data()!;
        final nameStr = uData['name'] as String?;
        if (nameStr != null && nameStr.trim().isNotEmpty) {
          _profile.name = nameStr;
        }
        if (uData['goal'] != null) {
          _profile.goal =
              Goal.values[((uData['goal'] as num).toInt()).clamp(0, 3)];
        }
        if (uData['level'] != null) {
          _profile.level =
              Level.values[((uData['level'] as num).toInt()).clamp(0, 2)];
        }
        if (uData['daysPerWeek'] != null) {
          _profile.daysPerWeek =
              ((uData['daysPerWeek'] as num).toInt()).clamp(1, 7);
        }
        if (uData['hasGym'] != null) {
          _profile.hasGym = uData['hasGym'] as bool;
        }
        if (uData['onboarded'] != null) {
          _onboarded = uData['onboarded'] as bool;
        }
      }

      if (healthDoc.exists && healthDoc.data() != null) {
        final hData = healthDoc.data()!;
        if (hData['age'] != null) {
          _profile.age = ((hData['age'] as num).toInt()).clamp(12, 120);
        }
        if (hData['heightCm'] != null) {
          _profile.heightCm =
              ((hData['heightCm'] as num).toDouble()).clamp(80, 250);
        }
        if (hData['weightKg'] != null) {
          _profile.weightKg =
              ((hData['weightKg'] as num).toDouble()).clamp(20, 500);
        }
        if (hData['targetWeightKg'] != null) {
          _profile.targetWeightKg =
              ((hData['targetWeightKg'] as num).toDouble()).clamp(20, 500);
        }
        if (hData['conditions'] != null) {
          _profile.conditions = ((hData['conditions'] as List?) ?? [])
              .map((item) {
                if (item is int) {
                  return HealthCondition.values[item.clamp(
                    0,
                    HealthCondition.values.length - 1,
                  )];
                }
                final str = item.toString();
                return HealthCondition.values.firstWhere(
                  (c) => c.name == str,
                  orElse: () => HealthCondition.diabetes,
                );
              })
              .toSet()
              .toList();
        }
        if (hData['allergies'] != null) {
          _profile.allergies = ((hData['allergies'] as List?) ?? [])
              .map((item) {
                if (item is int) {
                  return Allergy.values[item.clamp(0, Allergy.values.length - 1)];
                }
                final str = item.toString();
                return Allergy.values.firstWhere(
                  (a) => a.name == str,
                  orElse: () => Allergy.lactosa,
                );
              })
              .toSet()
              .toList();
        }
      }

      if (userDoc.exists || healthDoc.exists) {
        await _prefs((p) async {
          await p.setString(_uk(_kProfile), _profile.toJson());
          await p.setBool(_uk(_kOnboarded), _onboarded);
        });
      }
      _profileLoadError = null;
    } catch (e) {
      debugPrint('[Firestore] Error al cargar perfil de $uid: $e');
      _profileLoadError =
          'No se pudo sincronizar el perfil con la nube. Mostrando datos locales.';
    } finally {
      _isProfileLoading = false;
      notifyListeners();
    }
  }

  /// Recarga el perfil desde Firestore con estados reactivos de carga y error (#123).
  Future<void> reloadProfileFromCloud() async {
    final uid = userId;
    if (uid.isNotEmpty) {
      await _loadUserProfileFromFirestore(uid);
    }
  }

  /// Sincroniza el perfil actual con la colección users y su subcolección private/health_profile.
  /// Cumple estrictamente con las reglas validBasic y validHealth.
  /// Retorna SyncStatus.synced si se confirmó en la nube, o SyncStatus.failed si no hubo conexión.
  Future<SyncStatus> _syncProfileToFirestore() async {
    final uid = userId;
    if (uid.isEmpty) {
      _syncStatus = SyncStatus.synced;
      _syncError = null;
      return SyncStatus.synced;
    }

    _syncStatus = SyncStatus.pending;
    notifyListeners();

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final userSnap = await userRef.get().timeout(const Duration(seconds: 8));

      final displayName = _profile.name.isNotEmpty ? _profile.name : 'Usuario';
      final basicData = <String, dynamic>{
        'name': displayName.length > 120
            ? displayName.substring(0, 120)
            : displayName,
        'goal': _profile.goal.index.clamp(0, 3),
        'level': _profile.level.index.clamp(0, 2),
        'daysPerWeek': _profile.daysPerWeek.clamp(1, 7),
        'hasGym': _profile.hasGym,
        'onboarded': _onboarded,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!userSnap.exists) {
        basicData['createdAt'] = FieldValue.serverTimestamp();
      } else {
        basicData['createdAt'] =
            userSnap.data()?['createdAt'] ?? FieldValue.serverTimestamp();
      }

      // 1. Guardar o actualizar documento principal users/{uid} (idempotente)
      await userRef.set(basicData).timeout(const Duration(seconds: 8));

      // 2. Guardar subcolección privada users/{uid}/private/health_profile (idempotente)
      // Cumple validHealth con nombres legibles en condiciones y alergias
      final healthRef = userRef.collection('private').doc('health_profile');
      final healthData = <String, dynamic>{
        'age': _profile.age.clamp(12, 120),
        'heightCm': _profile.heightCm.clamp(80.0, 250.0),
        'weightKg': _profile.weightKg.clamp(20.0, 500.0),
        'targetWeightKg': _profile.targetWeightKg.clamp(20.0, 500.0),
        'conditions': _profile.conditions.map((c) => c.name).toSet().toList(),
        'allergies': _profile.allergies.map((a) => a.name).toSet().toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await healthRef.set(healthData).timeout(const Duration(seconds: 8));

      // Confirmado exitosamente en la nube
      _syncStatus = SyncStatus.synced;
      _syncError = null;
      await _prefs((p) => p.remove(_uk(_kPendingSync)));
      notifyListeners();
      return SyncStatus.synced;
    } catch (e) {
      debugPrint('[Firestore] Error al sincronizar perfil de $uid: $e');
      _syncStatus = SyncStatus.failed;
      _syncError = 'Sin conexión a internet. Guardado en este dispositivo.';
      await _prefs((p) => p.setBool(_uk(_kPendingSync), true));
      notifyListeners();
      return SyncStatus.failed;
    }
  }

  /// Reintenta sincronizar con la nube los datos guardados localmente.
  /// Es idempotente: las escrituras a users/{uid} y private/health_profile
  /// actualizan los mismos documentos deterministas sin duplicar registros.
  Future<bool> retryPendingSync() async {
    final status = await _syncProfileToFirestore();
    return status == SyncStatus.synced;
  }

  Future<void> _prefs(Future<void> Function(SharedPreferences p) fn) async {
    final p = await SharedPreferences.getInstance();
    await fn(p);
  }

  // ── Perfil / onboarding ──────────────────────────────────────────────────
  Future<SyncStatus> completeOnboarding(Profile profile) async {
    _profile = profile;
    _onboarded = true;
    _syncStatus = SyncStatus.pending;
    _syncError = null;
    // Primer registro de peso para arrancar el gráfico.
    if (_weights.isEmpty) {
      _weights.add(WeightEntry(DateTime.now(), profile.weightKg));
    }
    notifyListeners();
    await _prefs((p) async {
      await p.setString(_uk(_kProfile), profile.toJson());
      await p.setBool(_uk(_kOnboarded), true);
      await p.setStringList(
        _uk(_kWeights),
        _weights.map((e) => e.toJson()).toList(),
      );
      await p.setBool(_uk(_kPendingSync), true);
    });
    return await _syncProfileToFirestore();
  }

  Future<SyncStatus> saveProfile(Profile profile) async {
    _profile = profile;
    _syncStatus = SyncStatus.pending;
    _syncError = null;
    notifyListeners();

    // 1. Guardado local inmediato en SharedPreferences (garantiza que nunca se pierde información)
    await _prefs((p) async {
      await p.setString(_uk(_kProfile), profile.toJson());
      await p.setBool(_uk(_kPendingSync), true);
    });

    // 2. Intentar confirmación en Firestore
    return await _syncProfileToFirestore();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _prefs((p) => p.setInt(_kTheme, mode.index));
  }

  /// Cambia el sistema de unidades activo y lo persiste en el dispositivo (#124).
  Future<void> setUnitSystem(UnitSystem system) async {
    _unitSystem = system;
    notifyListeners();
    await _prefs((p) => p.setInt(_kUnitSystem, system.index));
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
      (p) => p.setStringList(
        _uk(_kLogs),
        _logs.values.map((e) => e.toJson()).toList(),
      ),
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
    final k = dayKey(DateTime.now());
    _weights.removeWhere((w) => dayKey(w.date) == k); // 1 registro por día
    _weights.add(WeightEntry(DateTime.now(), kg));
    _weights.sort((a, b) => a.date.compareTo(b.date));
    _profile.weightKg = kg;
    notifyListeners();
    await _prefs((p) async {
      await p.setStringList(
        _uk(_kWeights),
        _weights.map((e) => e.toJson()).toList(),
      );
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
