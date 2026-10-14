import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vigoriafit/services/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Paso 3 (#108): Migración de datos locales y protección de propiedad incierta', () {
    test('Migración legítima: usuario anónimo crea cuenta nueva y sus datos se transfieren a su UID', () async {
      SharedPreferences.setMockInitialValues({
        'anon_123_profile_v1': jsonEncode({'name': 'Carlos', 'age': 28, 'goal': 1}),
        'anon_123_onboarded_v1': true,
        'anon_123_weights_v1': [jsonEncode({'date': '2026-10-13T10:00:00.000', 'kg': 75.5})],
        'anon_123_reminder_workout_v1': true,
        'anon_123_reminder_workout_hour_v1': 19,
        'anon_123_reminder_workout_min_v1': 30,
      });

      final store = AppStore.instance;
      await store.migrateLocalDataToUser('anon_123', 'user_real_uid');

      final prefs = await SharedPreferences.getInstance();

      // Las claves bajo el nuevo UID deben contener la información
      expect(prefs.getString('user_real_uid_profile_v1'), contains('Carlos'));
      expect(prefs.getBool('user_real_uid_onboarded_v1'), isTrue);
      expect(prefs.getStringList('user_real_uid_weights_v1'), isNotEmpty);
      expect(prefs.getBool('user_real_uid_reminder_workout_v1'), isTrue);
      expect(prefs.getInt('user_real_uid_reminder_workout_hour_v1'), 19);
      expect(prefs.getInt('user_real_uid_reminder_workout_min_v1'), 30);

      // Las claves bajo anon_123 deben haber sido eliminadas (no dejar huérfanos)
      expect(prefs.containsKey('anon_123_profile_v1'), isFalse);
      expect(prefs.containsKey('anon_123_onboarded_v1'), isFalse);
      expect(prefs.containsKey('anon_123_weights_v1'), isFalse);
      expect(prefs.containsKey('anon_123_reminder_workout_v1'), isFalse);
    });

    test('Propiedad incierta: al iniciar sesión en cuenta existente no se transfieren datos anónimos ajenos', () async {
      SharedPreferences.setMockInitialValues({
        // Datos dejados por un invitado
        'anon_temp_profile_v1': jsonEncode({'name': 'Invitado Desconocido', 'goal': 0}),
        'anon_temp_onboarded_v1': true,
        // Datos legítimos de la cuenta que inicia sesión
        'user_existing_profile_v1': jsonEncode({'name': 'Laura', 'goal': 2}),
        'user_existing_onboarded_v1': true,
      });

      final store = AppStore.instance;
      // En lugar de migrar anon_temp a user_existing, se limpia anon_temp
      await store.clearLocalUserData('anon_temp');

      final prefs = await SharedPreferences.getInstance();

      // La cuenta existente conserva sus datos originales intactos
      expect(prefs.getString('user_existing_profile_v1'), contains('Laura'));

      // Los datos anónimos inciertos fueron descartados
      expect(prefs.containsKey('anon_temp_profile_v1'), isFalse);
      expect(prefs.containsKey('anon_temp_onboarded_v1'), isFalse);
    });

    test('Migración legacy: solo se migran datos sin prefijo si el email coincide con certeza', () async {
      SharedPreferences.setMockInitialValues({
        'brio_session_v1': 'juan@correo.com',
        'profile_v1': jsonEncode({'name': 'Juan Legacy', 'goal': 1}),
        'onboarded_v1': true,
      });

      final store = AppStore.instance;

      // 1. Intentar migrar con un email diferente (propiedad incierta) -> NO debe migrar
      await store.migrateLegacyUnprefixedDataToUser('uid_pedro', targetEmail: 'pedro@otro.com');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('uid_pedro_profile_v1'), isFalse);

      // 2. Migrar con el email que coincide con certeza -> Sí debe migrar
      await store.migrateLegacyUnprefixedDataToUser('uid_juan', targetEmail: 'juan@correo.com');
      expect(prefs.getString('uid_juan_profile_v1'), contains('Juan Legacy'));
      expect(prefs.getBool('uid_juan_onboarded_v1'), isTrue);

      // Las claves legacy sin prefijo deben haber sido removidas
      expect(prefs.containsKey('profile_v1'), isFalse);
      expect(prefs.containsKey('onboarded_v1'), isFalse);
    });

    test('Aislamiento tras logout: se limpian datos en memoria y se aísla nuevo usuario anónimo', () async {
      SharedPreferences.setMockInitialValues({
        'brio_session_v1': 'usuario@correo.com',
        'brio_local_user_id_v1': 'user_auth_123',
        'user_auth_123_profile_v1': jsonEncode({'name': 'Usuario Autenticado'}),
      });

      final store = AppStore.instance;

      // Ejecutar logout
      await store.logout();

      final prefs = await SharedPreferences.getInstance();
      expect(store.authed, isFalse);
      expect(store.currentEmail, isNull);
      expect(prefs.containsKey('brio_session_v1'), isFalse);

      // El _localUserId ya no debe ser el UID del usuario que cerró sesión
      expect(store.localUserId, isNot('user_auth_123'));

      // Los datos del usuario cerrado siguen a salvo bajo su prefijo en SharedPreferences
      expect(prefs.containsKey('user_auth_123_profile_v1'), isTrue);
    });
  });
}
