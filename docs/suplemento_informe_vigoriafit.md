# VigoriaFit — Suplemento de Informe (26/11/2026)

**Rama:** `steven-test` · **Commit:** `f7afe67` · **Versión:** `1.6.2+15`

---

## Índice de evidencias (nuevas entradas)

| ID | Descripción | Archivo |
|---|---|---|
| E5 | Salida de `flutter test --coverage` y archivo `lcov.info` | `docs/flutter_test_output.txt` · `docs/lcov.info` |
| E13 | Planilla de 30 mediciones Coach IA (tiempos raw en ms) | `docs/kpi_coach_30_mediciones.md` |

---

## Resultados de tests — corrida 26/11/2026

| Fecha | Tests aprobados | Tests fallidos | Cobertura global | Cobertura `nutrition.dart` (RNF06) |
|---|:---:|:---:|:---:|:---:|
| 26/11/2026 | 226 | 0 | 39,1 % (986/2.519 líneas) | ✅ **89,3 %** (25/28 líneas) — RNF06 cumplido |

> Evidencia: E5 (`lcov.info`, commit `f7afe67`).

---

## Cobertura por componente (RNF06 — advertencias y progresión por separado)

| Componente | Archivo | LH | LF | Cobertura |
|---|---|:---:|:---:|:---:|
| Motor de advertencias | `lib/data/nutrition.dart` | 25 | 28 | ✅ **89,3 %** — RNF06 cumplido |
| Motor de progresión | `lib/services/progression_engine.dart` | 35 | 36 | **97,2 %** |

> Nota: `store.dart` y `achievements.dart` no forman parte del motor de advertencias y se excluyen de esta tabla.

---

## Sprints 3–8 — Tabla de casos

| Sprint | Casos | Aprobados | Fallidos | No ejecutados |
|---|:---:|:---:|:---:|:---:|
| Sprint 3 | 16 | 16 | 0 | 0 |
| Sprint 4 | 16 | 16 | 0 | 0 |
| Sprint 5 | 16 | 16 | 0 | 0 |
| Sprint 6 | 16 | 0 | 0 | 16 |
| Sprint 7 | 16 | 0 | 0 | 16 |
| Sprint 8 | 16 | 0 | 0 | 16 |

Los Sprints 3 a 5 se ejecutaron en dispositivo físico Android (ZTE Z2357N). Los Sprints 6, 7 y 8 no se ejecutaron por alcance de tiempo.

---

## Métricas Coach IA (RNF — p95 ≤ 10 s)

| Métrica | Valor |
|---|---|
| Modelo | `gemini-3.5-flash-lite` |
| Muestra (n) | 30 |
| Mínimo | 1,39 s |
| Promedio | 4,08 s |
| Percentil 95 (p95) | **8,17 s** — método PERCENTIL.INC: interpola entre pos. 28 (6.582 ms) y pos. 29 (9.463 ms) en orden ascendente, índice = 0,95 × (30−1) = 27,55 |
| Máximo | 14,54 s |
| Tasa de éxito | 100 % |
| Umbral SLA (p95 ≤ 10 s) | ✅ Cumple (margen: 1,83 s) |

> Evidencia: E13 (`docs/kpi_coach_30_mediciones.md`). Verificación: n=30, suma=122.445 ms, promedio=4.082 ms. p95 con PERCENTIL.INC = 6.582 + 0,55 × (9.463 − 6.582) = **8.167 ms**. Nearest-rank daría 9.463 ms (pos. 29); ambos métodos cumplen el SLA.

---

## Correcciones aplicadas en Sprints 3–5

| Caso | Corrección |
|---|---|
| S4-05 | Reglas Firestore: `members/{uid}` exige `code == inviteCode` para invalidar códigos rotados |
| S5-12 | Banner de error remoto + botón Reintentar en `NutritionPage` |
| S5-14 | `_pullRemote()` al arrancar para recuperación multidispositivo (`food_service`, `water_service`) |

---

## Compilación, Firebase y App Check

| Verificación | Resultado |
|---|---|
| `flutter build apk --debug` | ✅ APK generado y ejecutado en ZTE Z2357N |
| iOS | ✅ Probado en iPhone físico |
| Authentication (Google + email/contraseña) | ✅ Proyecto `vigoria-fe224` |
| Cloud Firestore | ✅ Lectura/escritura validadas en Sprints 3–5 |
| Reglas Firestore | ✅ Desplegadas; invalidación de código rotado activa |
| App Check | ⚠️ SDK inicializado; enforcement no validado en entorno controlado |

---

## Sigue pendiente

- Piloto con usuarios externos.
- Configuración de CI/CD.
- Respaldos formales.
