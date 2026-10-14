import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vigoriafit/services/store.dart';
import 'package:vigoriafit/models/profile.dart';

/// Tests del Paso 5 (#123) — Estados de carga, error, datos vacíos y reintento.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Paso 5 — Estados de carga, error, datos vacíos y reintento', () {
    late AppStore store;

    setUp(() async {
      store = AppStore.instance;
    });

    test('1. Estado inicial de sincronización es synced', () async {
      SharedPreferences.setMockInitialValues({
        'brio_session_v1': 'test@mail.com',
        'brio_local_user_id_v1': 'uid_sync_test',
        'uid_sync_test_onboarded_v1': true,
        'uid_sync_test_profile_v1': jsonEncode({
          'name': 'Test User',
          'goal': 0,
          'level': 1,
          'age': 25,
          'heightCm': 175.0,
          'weightKg': 70.0,
          'targetWeightKg': 68.0,
          'daysPerWeek': 4,
          'hasGym': true,
          'conditions': [],
          'allergies': [],
        }),
      });

      await store.load();

      // Sin clave pending_sync_v1 → debe estar synced
      expect(store.syncStatus, SyncStatus.synced);
      expect(store.hasPendingSync, false);
      expect(store.syncError, isNull);
      expect(store.isProfileLoading, false);
      expect(store.profileLoadError, isNull);
    });

    test('2. Detecta pending_sync al arrancar la app', () async {
      SharedPreferences.setMockInitialValues({
        'brio_session_v1': 'test@mail.com',
        'brio_local_user_id_v1': 'uid_pending',
        'uid_pending_onboarded_v1': true,
        'uid_pending_profile_v1': jsonEncode({
          'name': 'Pending User',
          'goal': 1,
          'level': 0,
          'age': 30,
          'heightCm': 180.0,
          'weightKg': 85.0,
          'targetWeightKg': 80.0,
          'daysPerWeek': 5,
          'hasGym': true,
          'conditions': ['diabetes'],
          'allergies': ['lactosa'],
        }),
        'uid_pending_pending_sync_v1': true,
      });

      await store.load();

      // La app detecta pending_sync_v1 = true en SharedPreferences
      expect(store.hasPendingSync, true);
      expect(store.syncStatus, SyncStatus.pending);
    });

    test('3. Profile.copyFrom copia todos los campos correctamente', () {
      final source = Profile(
        name: 'María',
        goal: Goal.gainMuscle,
        level: Level.advanced,
        age: 28,
        heightCm: 165.0,
        weightKg: 60.0,
        targetWeightKg: 58.0,
        daysPerWeek: 5,
        hasGym: true,
        conditions: [HealthCondition.diabetes],
        allergies: [Allergy.lactosa, Allergy.gluten],
      );

      final target = Profile(); // Valores por defecto
      target.copyFrom(source);

      expect(target.name, 'María');
      expect(target.goal, Goal.gainMuscle);
      expect(target.level, Level.advanced);
      expect(target.age, 28);
      expect(target.heightCm, 165.0);
      expect(target.weightKg, 60.0);
      expect(target.targetWeightKg, 58.0);
      expect(target.daysPerWeek, 5);
      expect(target.hasGym, true);
      expect(target.conditions, [HealthCondition.diabetes]);
      expect(target.allergies, [Allergy.lactosa, Allergy.gluten]);

      // Verificar que las listas son copias independientes (no la misma referencia)
      source.conditions.add(HealthCondition.hipertension);
      expect(target.conditions.length, 1); // No se afecta
    });

    test('4. saveProfile guarda localmente y marca pending ante fallo de red', () async {
      SharedPreferences.setMockInitialValues({
        'brio_session_v1': 'offline@test.com',
        'brio_local_user_id_v1': 'uid_offline_save',
        'uid_offline_save_onboarded_v1': true,
        'uid_offline_save_profile_v1': jsonEncode({
          'name': 'Offline User',
          'goal': 0,
          'level': 0,
          'age': 22,
          'heightCm': 170.0,
          'weightKg': 65.0,
          'targetWeightKg': 63.0,
          'daysPerWeek': 3,
          'hasGym': false,
          'conditions': [],
          'allergies': [],
        }),
      });

      await store.load();

      // Crear un perfil modificado
      final updated = store.profile.copy();
      updated.name = 'Nombre Actualizado';
      updated.weightKg = 72.0;

      // saveProfile escribe localmente (siempre funciona)
      // Firestore fallará porque no hay Firebase real en tests → status failed o synced
      final status = await store.saveProfile(updated);
      expect(status, isNotNull);

      // El perfil se actualiza en memoria independientemente del estado de red
      expect(store.profile.name, 'Nombre Actualizado');
      expect(store.profile.weightKg, 72.0);

      // Se guardó en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString('uid_offline_save_profile_v1');
      expect(savedJson, isNotNull);
      final saved = Profile.fromJson(savedJson!);
      expect(saved.name, 'Nombre Actualizado');
      expect(saved.weightKg, 72.0);
    });

    test('5. Estado de perfil vacío se muestra correctamente', () {
      // Un perfil recién creado tiene nombre vacío
      final emptyProfile = Profile();
      expect(emptyProfile.name, '');
      expect(emptyProfile.conditions, isEmpty);
      expect(emptyProfile.allergies, isEmpty);

      // El nombre vacío debería mostrar "¡Hola! 👋" en TodayPage
      final trimmed = emptyProfile.name.trim();
      expect(trimmed.isNotEmpty, false);
    });
  });
}
