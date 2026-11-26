# VigoriaFit — Informe de Estado para Entrega

**Fecha:** 26 de noviembre de 2026  
**Rama:** `steven-test` · **Commit:** `f7afe67`  
**Versión:** `1.6.2+15`  
**Dispositivo:** ZTE Z2357N (Android 13, físico) · iPhone (iOS, físico)

---

## 3. Estado final de los Sprints

| Sprint | Casos | Aprobados | Fallidos | No ejecutados | Estado |
|---|:---:|:---:|:---:|:---:|---|
| Sprint 1 | — | — | — | — | ✅ Validado |
| Sprint 2 | — | — | — | — | ✅ Validado |
| Sprint 3 | 16 | 16 | 0 | 0 | ✅ Validado |
| Sprint 4 | 16 | 16 | 0 | 0 | ✅ Validado |
| Sprint 5 | 16 | 16 | 0 | 0 | ✅ Validado |
| Sprint 6 | 16 | 0 | 0 | 16 | ⏳ No ejecutado |
| Sprint 7 | 16 | 0 | 0 | 16 | ⏳ No ejecutado |
| Sprint 8 | 16 | 0 | 0 | 16 | ⏳ No ejecutado |

Los Sprints 3, 4 y 5 se ejecutaron en su totalidad en dispositivo físico Android. Todos los P0 están aprobados. Los Sprints 6, 7 y 8 no se ejecutaron por alcance de tiempo; las funcionalidades están implementadas pero sin validación formal.

**Correcciones aplicadas durante la validación:**

| Caso | Corrección aplicada |
|---|---|
| S4-05 | Reglas Firestore corregidas: `members/{uid}` exige `code == inviteCode` para invalidar códigos rotados |
| S5-12 | Banner de error remoto + botón Reintentar en `NutritionPage` |
| S5-14 | `_pullRemote()` al arrancar para recuperación multidispositivo en `food_service` y `water_service` |

---

## 4. Compilación, Firebase e Inteligencia Artificial

### Compilación y tests

| Verificación | Resultado |
|---|---|
| `flutter build apk --debug` | ✅ APK generado y ejecutado en ZTE Z2357N |
| iOS | ✅ Probado en iPhone físico |
| `flutter test --coverage` | ✅ 224 tests pasando · cobertura: **38,7 %** (976/2519 líneas, `lcov.info`) |
| `flutter analyze` | ✅ 0 errores en `lib/` y `test/` |

### Firebase

| Componente | Estado |
|---|---|
| Authentication (Google + email/contraseña) | ✅ Funciona con cuentas reales en `vigoria-fe224` |
| Cloud Firestore | ✅ Lectura/escritura validadas en Sprints 3–5 |
| Reglas Firestore | ✅ Desplegadas; incluye corrección de invalidación de código rotado (25/11/2026) |
| App Check | ⚠️ SDK inicializado; enforcement no validado en entorno controlado |

### Coach IA

✅ Integrado con Firebase AI Logic (`gemini-3.5-flash-lite`). Validado con 30 llamadas reales en dispositivo físico ZTE (ver métricas en sección 5).

---

## 5. Métricas KPI, SLA y Rendimiento

### Coach IA — 30 mediciones reales (Android, WiFi doméstica, 25-26/11/2026)

| Métrica | Valor |
|---|---|
| Modelo | `gemini-3.5-flash-lite` |
| Muestra (n) | 30 |
| Tiempo mínimo | 1,39 s |
| Tiempo promedio | 4,08 s |
| Percentil 95 (p95) | 9,46 s |
| Tiempo máximo | 14,54 s |
| Tasa de éxito | 100 % |
| SLA (p95 ≤ 10 s) | ✅ Cumple |

### Otras operaciones

| Operación | Tiempo observado |
|---|---|
| Guardado local (comida/agua) | < 50 ms |
| Confirmación remota Firestore | 400–1200 ms |
| Inicio de sesión con cuenta real | 1–3 s |
| Carga inicial de registros desde Firestore | 1–4 s |
| Notificaciones exactas (alarma de agua) | Precisión ±0 s |

---

## Lo que no pude comprobar

- **Leuzzi 2026:** el artículo existe, pero la frase "evidencia insuficiente" que le atribuye `mejorado2` no la verifiqué.
- **Singh 2024:** quedó en el archivo sin verificar.
- **Índice:** al abrir el Word te preguntará si actualizar los campos. Dile **SÍ** para que las páginas del índice se corrijan. En el PDF de vista previa el índice puede verse desfasado.

---

## Lo que sigue pendiente

- ✅ `lcov.info` generado en `docs/lcov.info` (26/11/2026, commit `f7afe67`).
- ✅ Salida de `flutter test` guardada en `docs/flutter_test_output.txt`.
- ✅ Planilla de 30 mediciones en `docs/kpi_coach_30_mediciones.md`.

### Cobertura del motor de advertencias (esta corrida, 26/11/2026)

| Archivo | Líneas cubiertas | Líneas totales | Cobertura |
|---|:---:|:---:|:---:|
| `services/store.dart` | 315 | 573 | 55,0 % |
| `services/progression_engine.dart` | 35 | 36 | 97,2 % |
| `data/achievements.dart` | 14 | 31 | 45,2 % |
| **Total motor de advertencias** | **364** | **640** | **56,9 %** |
