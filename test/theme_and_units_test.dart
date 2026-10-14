import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vigoriafit/models/units.dart';
import 'package:vigoriafit/services/store.dart';

/// Tests del Paso 6 (#124) — Preferencias de tema y unidades, con persistencia.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Paso 6 (#124) — Preferencias de tema y unidades con persistencia', () {
    late AppStore store;

    setUp(() {
      store = AppStore.instance;
    });

    test('1. Preferencia de tema: persistencia, reactividad y restauración al iniciar', () async {
      SharedPreferences.setMockInitialValues({
        'brio_theme_v1': 0, // system
      });

      await store.load();
      expect(store.themeMode, ThemeMode.system);

      // Cambiar a modo oscuro
      await store.setThemeMode(ThemeMode.dark);
      expect(store.themeMode, ThemeMode.dark);

      // Verificar que se persistió en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('brio_theme_v1'), ThemeMode.dark.index);

      // Simular reinicio de la aplicación con load()
      await store.load();
      expect(store.themeMode, ThemeMode.dark);

      // Cambiar a modo claro
      await store.setThemeMode(ThemeMode.light);
      expect(store.themeMode, ThemeMode.light);
      expect(prefs.getInt('brio_theme_v1'), ThemeMode.light.index);
    });

    test('2. Preferencia de unidades: persistencia y restauración al iniciar', () async {
      SharedPreferences.setMockInitialValues({
        'brio_unit_system_v1': 0, // metric por defecto
      });

      await store.load();
      expect(store.unitSystem, UnitSystem.metric);

      // Cambiar a sistema imperial
      await store.setUnitSystem(UnitSystem.imperial);
      expect(store.unitSystem, UnitSystem.imperial);

      // Verificar persistencia en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('brio_unit_system_v1'), UnitSystem.imperial.index);

      // Simular reinicio de la aplicación
      await store.load();
      expect(store.unitSystem, UnitSystem.imperial);

      // Regresar a métrico
      await store.setUnitSystem(UnitSystem.metric);
      expect(store.unitSystem, UnitSystem.metric);
      expect(prefs.getInt('brio_unit_system_v1'), UnitSystem.metric.index);
    });

    test('3. Conversiones y formateo de peso métrico vs imperial', () async {
      await store.setUnitSystem(UnitSystem.metric);

      // Formateo en métrico (kg)
      expect(store.formatWeight(70.0), '70 kg');
      expect(store.formatWeight(72.5), '72.5 kg');
      expect(store.formatWeightDiff(1.5), '+1.5 kg');
      expect(store.formatWeightDiff(-2.0), '-2.0 kg');
      expect(store.formatWeightDiff(0.0), '0.0 kg');

      // Cambiar a imperial (lb)
      await store.setUnitSystem(UnitSystem.imperial);
      expect(store.formatWeight(70.0), contains('lb'));
      // 70 kg * 2.20462262 ≈ 154.3 lb
      expect(store.formatWeight(70.0), '154.3 lb');
      expect(store.formatWeightDiff(1.0), '+2.2 lb');
      expect(store.formatWeightDiff(-2.0), '-4.4 lb');
    });

    test('4. Conversiones y formateo de estatura métrico vs imperial', () async {
      await store.setUnitSystem(UnitSystem.metric);
      expect(store.formatHeight(175.0), '175 cm');
      expect(store.formatHeight(180.0), '180 cm');

      await store.setUnitSystem(UnitSystem.imperial);
      // 175 cm / 2.54 = 68.89 in ≈ 69 in = 5'9"
      expect(store.formatHeight(175.0), "5'9\"");
      // 183 cm / 2.54 = 72.04 in ≈ 72 in = 6'0"
      expect(store.formatHeight(183.0), "6'0\"");
    });

    test('5. Integridad de conversión bidireccional (Round-trip)', () {
      const originalKg = 82.5;
      final lbs = UnitHelper.kgToLbs(originalKg);
      final backToKg = UnitHelper.lbsToKg(lbs);
      expect(backToKg, closeTo(originalKg, 0.0001));

      const originalCm = 178.0;
      final inches = UnitHelper.cmToInches(originalCm);
      final backToCm = UnitHelper.inchesToCm(inches);
      expect(backToCm, closeTo(originalCm, 0.0001));
    });

    test('6. Preferencias de dispositivo se conservan tras logout', () async {
      SharedPreferences.setMockInitialValues({
        'brio_theme_v1': ThemeMode.dark.index,
        'brio_unit_system_v1': UnitSystem.imperial.index,
        'brio_session_v1': 'user@domain.com',
        'brio_local_user_id_v1': 'uid_session',
      });

      await store.load();
      expect(store.themeMode, ThemeMode.dark);
      expect(store.unitSystem, UnitSystem.imperial);

      // Cerrar sesión
      await store.logout();

      // Las preferencias globales de dispositivo persisten
      expect(store.themeMode, ThemeMode.dark);
      expect(store.unitSystem, UnitSystem.imperial);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('brio_theme_v1'), ThemeMode.dark.index);
      expect(prefs.getInt('brio_unit_system_v1'), UnitSystem.imperial.index);
    });
  });
}
