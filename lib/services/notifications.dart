import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Recordatorios de VigoriaFit: entrenar y tomar agua, todos los días a horas fijas.
///
/// Usa notificaciones locales (no requiere servidor). La zona horaria se fija
/// a Chile continental, ya que la app está pensada para estudiantes chilenos.
class Notifications {
  Notifications._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  // IDs fijos por tipo de recordatorio (permiten cancelar/reprogramar cada uno).
  static const _idWorkout = 100;
  static const _idWaterBase = 201;
  static const _maxWaterAlarms = 6;
  static const _idRestTimer = 300;

  static Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('America/Santiago'));
    } catch (_) {
      // Si la zona no está disponible, seguimos con la del sistema.
    }
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _plugin.initialize(initSettings);
    _ready = true;
  }

  /// Pide permiso de notificaciones (Android 13+) y alarmas exactas. Devuelve true si se otorgó.
  static Future<bool> requestPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    return granted ?? true;
  }

  static Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    await init();
    final sysNow = DateTime.now();
    var target = DateTime(sysNow.year, sysNow.month, sysNow.day, hour, minute);
    if (!target.isAfter(sysNow)) target = target.add(const Duration(days: 1));
    final when = tz.TZDateTime.now(tz.local).add(target.difference(sysNow));

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'brio_reminders',
        'Recordatorios de VigoriaFit',
        channelDescription: 'Avisos para entrenar y tomar agua',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // se repite cada día
      );
    } catch (_) {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  /// Programa el recordatorio diario de entrenar a la hora indicada.
  static Future<void> scheduleWorkout(int hour, int minute) => _scheduleDaily(
        id: _idWorkout,
        hour: hour,
        minute: minute,
        title: '💪 Hora de entrenar',
        body: 'Tu rutina de hoy te espera. ¡Unos minutos y listo!',
      );

  static Future<void> cancelWorkout() => _plugin.cancel(_idWorkout);

  /// Programa los recordatorios diarios de agua según la lista de horarios configurada (máx. 6).
  static Future<void> scheduleWater(List<TimeOfDay> times) async {
    final count = times.length.clamp(0, _maxWaterAlarms);
    for (int i = 0; i < count; i++) {
      final t = times[i];
      await _scheduleDaily(
        id: _idWaterBase + i,
        hour: t.hour,
        minute: t.minute,
        title: '💧 Toma agua',
        body: 'Recuerda hidratarte para cumplir tu meta diaria.',
      );
    }
  }

  static Future<void> cancelWater() async {
    for (int i = 0; i < _maxWaterAlarms; i++) {
      await _plugin.cancel(_idWaterBase + i);
    }
  }

  /// Muestra notificación inmediata cuando se completa el descanso
  static Future<void> showRestFinishedNotification({String title = '⏰ ¡Descanso terminado!', String body = 'Toca para continuar con tu siguiente serie.'}) async {
    await init();
    const androidDetails = AndroidNotificationDetails(
      'brio_rest_timer',
      'Temporizador de descanso',
      channelDescription: 'Aviso de finalización del tiempo de descanso',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true,
      autoCancel: true,
      playSound: true,
    );
    await _plugin.show(
      _idRestTimer,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  /// Cancela la notificación de descanso
  static Future<void> cancelRestNotification() async {
    await _plugin.cancel(_idRestTimer);
  }
}
