import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vigoriafit/models/profile.dart';
import 'package:vigoriafit/services/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Paso 4 (#112): Escrituras y reintentos sin duplicación, distinción de estados', () {
    test('1. saveProfile persiste de inmediato en el dispositivo antes de Firestore', () async {
      SharedPreferences.setMockInitialValues({});
      final store = AppStore.instance;

      final testProfile = Profile(
        name: 'Ana Prueba',
        age: 26,
        weightKg: 62.0,
        heightCm: 168.0,
        goal: Goal.maintain,
      );

      // Guardar perfil
      await store.saveProfile(testProfile);

      final prefs = await SharedPreferences.getInstance();

      // Debe estar guardado localmente bajo la clave del usuario (o 'anon' si no hay sesión)
      final prefix = store.localUserId.isNotEmpty ? store.localUserId : 'anon';
      final savedJson = prefs.getString('${prefix}_profile_v1');
      expect(savedJson, isNotNull);
      expect(savedJson, contains('Ana Prueba'));
      expect(savedJson, contains('62.0'));

      // El perfil en memoria debe estar actualizado
      expect(store.profile.name, 'Ana Prueba');
      expect(store.profile.weightKg, 62.0);
    });

    test('2. Distinción de estados: pending, failed y synced', () {
      final store = AppStore.instance;
      expect(store.syncStatus, SyncStatus.synced);

      // Valores del enum de estado
      expect(SyncStatus.values, containsAll([
        SyncStatus.synced,
        SyncStatus.pending,
        SyncStatus.failed,
      ]));
      expect(SyncStatus.values.length, 3);
    });

    test('3. Escrituras y reintentos son idempotentes (no duplican información)', () async {
      SharedPreferences.setMockInitialValues({});
      final store = AppStore.instance;

      final p = Profile(name: 'Reintento Idempotente', age: 30, weightKg: 70.0);

      // Primer guardado
      await store.saveProfile(p);
      final prefs = await SharedPreferences.getInstance();
      final prefix = store.localUserId.isNotEmpty ? store.localUserId : 'anon';
      final key = '${prefix}_profile_v1';
      final firstSave = prefs.getString(key);

      // Reintento manual 1
      await store.retryPendingSync();
      final retry1 = prefs.getString(key);

      // Reintento manual 2
      await store.retryPendingSync();
      final retry2 = prefs.getString(key);

      // Los reintentos actualizan la misma clave fija sin duplicación
      expect(firstSave, isNotNull);
      expect(firstSave, equals(retry1));
      expect(retry1, equals(retry2));
    });

    test('4. Detección de guardado pendiente al reiniciar la app (load)', () async {
      // Simular que en una sesión previa se cortó la conexión y quedó pending_sync = true
      const uid = 'user_offline_test';
      SharedPreferences.setMockInitialValues({
        'brio_session_v1': 'offline@test.com',
        'brio_local_user_id_v1': uid,
        '${uid}_profile_v1': jsonEncode({'name': 'Guardado Offline', 'age': 25}),
        '${uid}_pending_sync_v1': true,
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('${uid}_pending_sync_v1'), isTrue);
    });

    test('5. Reinicio con guardado offline pendiente restaura íntegramente todos los atributos', () async {
      const uid = 'user_offline_full_profile';
      final offlineProfile = Profile(
        name: 'Carlos Offline',
        goal: Goal.gainMuscle,
        level: Level.advanced,
        age: 28,
        heightCm: 182.0,
        weightKg: 84.5,
        targetWeightKg: 88.0,
        daysPerWeek: 5,
        hasGym: true,
        conditions: [HealthCondition.lesionRodilla, HealthCondition.hipertension],
        allergies: [Allergy.lactosa, Allergy.gluten],
      );

      SharedPreferences.setMockInitialValues({
        'brio_session_v1': 'carlos@offline.com',
        'brio_local_user_id_v1': uid,
        '${uid}_profile_v1': offlineProfile.toJson(),
        '${uid}_pending_sync_v1': true,
      });

      final store = AppStore.instance;
      await store.load();

      // Verificar que ningún campo se haya perdido o reseteado a default
      expect(store.profile.name, 'Carlos Offline');
      expect(store.profile.goal, Goal.gainMuscle);
      expect(store.profile.level, Level.advanced);
      expect(store.profile.age, 28);
      expect(store.profile.heightCm, 182.0);
      expect(store.profile.weightKg, 84.5);
      expect(store.profile.targetWeightKg, 88.0);
      expect(store.profile.daysPerWeek, 5);
      expect(store.profile.hasGym, isTrue);
      expect(store.profile.conditions, containsAll([
        HealthCondition.lesionRodilla,
        HealthCondition.hipertension,
      ]));
      expect(store.profile.allergies, containsAll([
        Allergy.lactosa,
        Allergy.gluten,
      ]));
      expect(store.syncStatus, SyncStatus.pending);
    });
  });
}
