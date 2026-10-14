# Bitácora Sprint 2 — Perfil, Persistencia y Funcionamiento ante Desconexiones

Este documento registra los cambios técnicos, decisiones de arquitectura y casos de prueba completados durante el Sprint 2 para el seguimiento del equipo y trazabilidad en Azure DevOps / GitHub.

---

## 📋 Resumen de Tareas del Sprint 2

| Paso | Tarea | Elementos Azure | Estado |
| :---: | :--- | :---: | :---: |
| **1** | Completar el onboarding y la edición del perfil conectados a Firestore. Separar perfil básico de antecedentes privados. | #97, #120 | ✅ Completado |
| **2** | Definir qué información se guarda en Firebase y qué permanece únicamente en el dispositivo. | #113 | ✅ Completado |
| **3** | Migrar los datos locales necesarios a la cuenta correcta, evitando trasladar automáticamente información cuya propiedad sea incierta. | #108 | ✅ Completado |
| **4** | Implementar escrituras y reintentos sin duplicación; distinguir guardado pendiente, confirmado y fallido. | #112 | ✅ Completado |
| **5** | Añadir estados de carga, error, datos vacíos y reintento en los flujos de perfil y guardado. | #123 | ✅ Completado |
| **6** | Completar preferencias de tema y unidades, con persistencia. | #124 | ✅ Completado |
| **7** | Corregir el fallo que vuelve a mostrar alimentos descartados cuando el filtro no encuentra alternativas. | Bug #98 | ✅ Completado |
| **8** | Preparar las reglas de filtrado documentadas y los casos de prueba que utilizarán los módulos posteriores. | US37–US39 | ✅ Completado |

---

## 🛠️ Detalle de Avances por Paso

### Paso 1: Onboarding y edición de perfil con separación de datos básicos y privados (#97, #120)

- **Colección Base (`/users/{uid}`)**: Almacena el perfil básico (`name`, `goal`, `level`, `daysPerWeek`, `hasGym`, `onboarded`, `createdAt`, `updatedAt`). Cumple con la regla de validación de esquema `validBasic`.
- **Subcolección Privada (`/users/{uid}/private/health_profile`)**: Aísla los antecedentes médicos y métricas corporales privadas (`age`, `heightCm`, `weightKg`, `targetWeightKg`, `conditions`, `allergies`, `updatedAt`). Cumple con `validHealth`.
- **Representación legible de condiciones y alergias**:
  - Se modificó la persistencia para almacenar strings descriptivos en lugar de índices numéricos (`0, 1, 2...`).
  - Ejemplo de condiciones: `['diabetes', 'hipertension', 'lesionRodilla']`.
  - Ejemplo de alergias: `['lactosa', 'gluten', 'frutosSecos']`.
  - Se añadió fallback bidireccional en `Profile.fromMap` para garantizar retrocompatibilidad si existen datos legacy.
- **Flujos integrados**:
  1. `completeOnboarding(profile)` en [onboarding_page.dart](file:///d:/vigoriafit/lib/pages/onboarding_page.dart): Graba ambos documentos de forma coherente.
  2. `saveProfile(profile)` en [settings_page.dart](file:///d:/vigoriafit/lib/pages/settings_page.dart): Actualiza las modificaciones respetando el esquema.
  3. `_loadUserProfileFromFirestore(uid)`: Reconstruye el perfil completo en memoria y caché local combinando la información básica y de salud.

---

### Paso 2: Límite de datos Firebase vs. Dispositivo (#113)

#### Decisión de arquitectura

| Dato | Firebase | Solo dispositivo | Justificación |
|---|---|---|---|
| `name`, `goal`, `level`, `daysPerWeek`, `hasGym`, `onboarded` | ✅ `users/{uid}` | Caché local | Perfil básico, comparte con entrenador |
| `age`, `heightCm`, `weightKg`, `targetWeightKg`, `conditions`, `allergies` | ✅ `users/{uid}/private/health_profile` | Caché local | Sensible — subcolección privada |
| Logs diarios (agua, entrenamientos) | ❌ | ✅ SharedPreferences `daylogs_v1` | Volumen alto, no requiere sincronización entre dispositivos aún |
| Historial de pesos | ❌ | ✅ SharedPreferences `weights_v1` | Ídem — candidato a fase futura |
| Plan semanal | ❌ | ✅ SharedPreferences `weekplan_v1` | Generado localmente por el coach |
| Pesos por ejercicio | ❌ | ✅ SharedPreferences `exercise_weights_v1` | Preferencia de entrenamiento personal |
| Tema (dark/light/system) | ❌ | ✅ SharedPreferences `brio_theme_v1` | Preferencia UI global del dispositivo |
| Recordatorios (workout/water) | ❌ | ✅ SharedPreferences `reminder_*` | Dependen del sistema de notificaciones local |
| `groupId` / `groupCode` | Derivado de Firestore `/groups` | Caché local `group_id_v1` | Fuente de verdad = Firestore |
| `isTrainer` | Custom claim Firebase Auth token | Caché local `is_trainer_v1` | No se escribe manualmente; viene del token |

#### Cambios aplicados

- **`Profile.toMap()`**: Condiciones y alergias ahora se serializan como **nombres de enum** (`'diabetes'`, `'lactosa'`) en lugar de índices enteros. Esto hace que los datos locales en SharedPreferences sean idénticos al formato de Firestore.
- **`Profile.fromMap()`**: Acepta tanto `String` (formato nuevo) como `int` (formato legacy) para retrocompatibilidad total con datos ya almacenados en dispositivos existentes.
- Toda la lógica de persistencia local mantiene la clave prefijada con UID (`_uk()`) para aislar datos entre cuentas.

---

### Paso 3: Migración de datos locales a la cuenta correcta y protección de propiedad incierta (#108)

#### Contexto y problemática resuelta
Cuando un usuario utiliza la aplicación en modo invitado o completa su onboarding antes de autenticarse, sus datos se almacenan bajo un identificador anónimo temporal (`_localUserId`).
Anteriormente:
1. Al iniciar sesión en una cuenta existente, el estado temporal en memoria sobreescribía los datos remotos de Firestore antes de haberlos cargado, contaminando la cuenta con información cuya propiedad era incierta.
2. Al registrar una cuenta nueva, los datos locales (pesos, registros diarios, plan semanal, pesos de ejercicios, recordatorios) no se transferían al nuevo UID en `SharedPreferences`, perdiéndose al reiniciar la app.
3. Al cerrar sesión (`logout`), el identificador local no se renovaba, lo que permitía que una sesión anónima posterior tuviera acceso a los datos del usuario que había salido.

#### Criterio de propiedad cierta vs. incierta
- **Propiedad cierta (Migración autorizada)**:
  - Ocurre cuando un usuario anónimo/invitado crea una **cuenta nueva** (`register` o `loginWithProvider` con `isNew: true`).
  - El usuario formaliza la cuenta para la que configuró el perfil en este dispositivo.
  - **Acción**: `migrateLocalDataToUser(fromId, toUid)` traslada atómicamente todas las claves (`profile_v1`, `onboarded_v1`, `daylogs_v1`, `weights_v1`, `exercise_weights_v1`, `weekplan_v1`, recordatorios) al espacio de nombres del nuevo UID y elimina las claves huérfanas de `fromId`. Inmediatamente se sincronizan ambos documentos (`/users/{uid}` y `/users/{uid}/private/health_profile`) con Firestore.
- **Propiedad incierta (Migración denegada y protección activa)**:
  - Ocurre cuando se inicia sesión en una **cuenta existente** (`login` o `loginWithProvider` con `isNew: false`).
  - La cuenta ya tiene su propia identidad e historial en la nube. Los datos anónimos del dispositivo podrían ser de otra persona o de una prueba.
  - **Acción**:
    1. Se limpia el estado en memoria (`_resetMemoryState()`).
    2. Se descartan y eliminan los datos anónimos huérfanos con `clearLocalUserData(oldLocalId)`.
    3. Se cargan los datos legítimos de la cuenta desde `SharedPreferences` (`_loadUserDataFromPrefs(user.uid)`) y Firestore (`_loadUserProfileFromFirestore(user.uid)`).
    4. **Nunca se sobreescribe Firestore** con datos del dispositivo de propiedad incierta.
- **Migración de datos legacy (sin prefijo de UID)**:
  - `migrateLegacyUnprefixedDataToUser`: Se verifica si el correo de la sesión guardada (`brio_session_v1`) coincide exactamente con el correo autenticado. Si coincide, se transfieren al prefijo `${uid}_*` y se limpian las claves sin prefijo. Si no coincide, no se migran.
- **Aislamiento en logout**:
  - `logout()` limpia la memoria, elimina la sesión y genera un **nuevo identificador anónimo único** (`_newLocalId()`). Si la app se usa después sin sesión, el invitado comienza en un sandbox completamente limpio.

#### Casos de prueba automatizados
Se creó la suite de pruebas unitarias en [test/user_data_migration_test.dart](file:///d:/vigoriafit/test/user_data_migration_test.dart) (4/4 pruebas aprobadas):
1. `Migración legítima: usuario anónimo crea cuenta nueva y sus datos se transfieren a su UID`.
2. `Propiedad incierta: al iniciar sesión en cuenta existente no se transfieren datos anónimos ajenos`.
3. `Migración legacy: solo se migran datos sin prefijo si el email coincide con certeza`.
4. `Aislamiento tras logout: se limpian datos en memoria y se aísla nuevo usuario anónimo`.

---

### Paso 4: Escrituras y reintentos sin duplicación; distinción de guardado pendiente, confirmado y fallido (#112)

#### 1. Distinción de estados con `SyncStatus`
Se introdujo el enum `SyncStatus` en [lib/services/store.dart](file:///d:/vigoriafit/lib/services/store.dart):
- **`SyncStatus.synced` (Confirmado)**: Los datos se guardaron tanto en el almacenamiento local como en Firestore de forma confirmada.
- **`SyncStatus.pending` (Pendiente)**: Los datos se guardaron de inmediato en el dispositivo (`SharedPreferences`) y la solicitud a la nube se encuentra en cola o proceso.
- **`SyncStatus.failed` (Fallido)**: La llamada a Firestore falló o se agotó el tiempo de espera (timeout de 8s). Los datos están completamente seguros en el dispositivo y marcados para reintento.

#### 2. Idempotencia y prevención de duplicados
- Todas las operaciones remotas en Firestore se dirigen a identificadores de documento deterministas: `/users/{uid}` y `/users/{uid}/private/health_profile`.
- Cualquier reintento (sea manual por el usuario o automático en reconexión) ejecuta operaciones `set()` sobre los mismos documentos, garantizando que **no se generen registros duplicados** bajo ninguna circunstancia.
- La escritura local en `SharedPreferences` se realiza **antes** de la llamada a la red, asegurando que si la conexión se interrumpe abruptamente durante el guardado, la información no se pierda.

#### 3. Mecanismo de reintentos manual y automático
- **`retryPendingSync()`**: Método expuesto en `AppStore` para reintentar la sincronización pendiente de forma segura.
- **Reintento automático en reinicio**: En `load()`, si existe la bandera persistente `${uid}_pending_sync_v1`, la aplicación detecta el estado pendiente y programa la sincronización con la nube en segundo plano sin bloquear el arranque.
- **Feedback interactivo en UI**:
  - En [lib/pages/settings_page.dart](file:///d:/vigoriafit/lib/pages/settings_page.dart), al guardar perfil se notifica si la confirmación fue en la nube o si quedó guardada en el dispositivo pendiente de conexión.
  - Se implementó `_syncStatusBanner()`: un banner reactivo que aparece si la sincronización está pendiente o falló, mostrando el motivo y ofreciendo un botón directo de **"Reintentar"**.

- **Prioridad Offline-First ante reinicio**: Si la app arranca y detecta un guardado local pendiente (`hasPendingSync == true`), la verdad local del dispositivo tiene prioridad absoluta. `_loadUserProfileFromFirestore` se inhibe para no pisar el perfil con datos remotos desactualizados (o incompletos si `health_profile` no existe en Firestore), y se invoca `retryPendingSync()` para empujar los cambios locales a la nube.
- **Robustez en `Profile.fromMap`**: Normalización estricta de tipos numéricos (`(m['heightCm'] as num?)?.toDouble()`, etc.) y deduplicación de listas (`.toSet().toList()`).

#### Casos de prueba automatizados
Se creó la suite [test/write_retry_sync_test.dart](file:///d:/vigoriafit/test/write_retry_sync_test.dart) (5/5 pruebas aprobadas):
1. `saveProfile persiste de inmediato en el dispositivo antes de Firestore`.
2. `Distinción de estados: pending, failed y synced`.
3. `Escrituras y reintentos son idempotentes (no duplican información)`.
4. `Detección de guardado pendiente al reiniciar la app (load)`.
5. `Reinicio con guardado offline pendiente restaura íntegramente todos los atributos (nombre, peso, condiciones, alergias, medidas, objetivo y nivel)`.

---

### Paso 5: Estados de carga, error, datos vacíos y reintento en los flujos de perfil y guardado (#123)

#### 1. Estados reactivos en `AppStore`
Se introdujeron propiedades reactivas observables con `ListenableBuilder`:
- **`isProfileLoading`**: Indica cuando la aplicación está consultando y trayendo el perfil remoto desde Firestore (`users/{uid}` y `users/{uid}/private/health_profile`).
- **`profileLoadError`**: Almacena el mensaje descriptivo en caso de falla de red o timeout al descargar el perfil remoto.
- **`reloadProfileFromCloud()`**: Permite reintentar explícitamente la descarga del perfil desde Firestore en cualquier momento.
- **`isSaving` / `SyncStatus`**: Estado de guardado local y sincronización con feedback visual diferenciado.

#### 2. Gestión de Estados en Pantallas
- **[settings_page.dart](file:///d:/vigoriafit/lib/pages/settings_page.dart)**:
  - **Carga de perfil**: Banner reactivo con `CircularProgressIndicator` cuando `isProfileLoading == true` ("Cargando perfil desde la nube…").
  - **Error con reintento**: Banner de advertencia cuando `profileLoadError != null` con botón directo de **"Reintentar"** que invoca `reloadProfileFromCloud()` y sincroniza el formulario local mediante `Profile.copyFrom()`.
  - **Guardado en curso**: El botón principal muestra spinner de progreso y deshabilita acciones concurrentes.
  - **Estados vacíos**:
    - Si el usuario no ha registrado condiciones médicas: mensaje `✓ Sin condiciones médicas registradas`.
    - Si no ha registrado alergias/intolerancias: mensaje `✓ Sin alergias o intolerancias alimentarias registradas`.
    - Validación de campo de nombre vacío con mensaje de error inline (`_nameError`).
- **[today_page.dart](file:///d:/vigoriafit/lib/pages/today_page.dart)**:
  - Manejo de perfil con nombre vacío: saludo por defecto (`¡Hola! 👋`) sin dejar espacios vacíos ni caracteres huérfanos.
  - Banner reactivo ante sincronización pendiente/fallida con opción de **"Reintentar"**.
  - Banners de estado de carga y error de perfil remoto.
- **[onboarding_page.dart](file:///d:/vigoriafit/lib/pages/onboarding_page.dart)**:
  - Bloqueo y estado de carga (`_isSubmitting`) en el botón de confirmación final.
  - Validación de campos requeridos antes de avanzar entre pasos.
  - Captura de errores con notificación interactiva y reintento seguro.

#### 3. Casos de prueba automatizados
Se implementó la suite [test/ui_states_test.dart](file:///d:/vigoriafit/test/ui_states_test.dart) (5/5 pruebas aprobadas):
1. `Estado inicial de sincronización es synced`.
2. `Detecta pending_sync al arrancar la app`.
3. `Profile.copyFrom copia todos los campos correctamente`.
4. `saveProfile guarda localmente y marca pending ante fallo de red`.
5. `Estado de perfil vacío se muestra correctamente`.

---

### Paso 6: Preferencias de tema y unidades, con persistencia (#124)

#### 1. Persistencia de Tema (`ThemeMode`)
- **Almacenamiento**: Persistido en `SharedPreferences` bajo la clave global del dispositivo `brio_theme_v1`.
- **Modos soportados**:
  - `ThemeMode.system` (sigue el brillo del sistema operativo).
  - `ThemeMode.light` (tema claro energético).
  - `ThemeMode.dark` (tema oscuro de alto contraste).
- **Reactividad instantánea**: Al seleccionar una opción en el `_themeSelector()` de [settings_page.dart](file:///d:/vigoriafit/lib/pages/settings_page.dart), `AppStore.instance.setThemeMode()` actualiza el estado en memoria, guarda de inmediato en disco y notifica a los listeners. La aplicación (`MaterialApp` y `AppColors.dark`) cambia de tema en tiempo real sin reiniciar.
- **Aislamiento**: Al ser una preferencia global del dispositivo (definida en el Paso 2), no se elimina ni se altera al cerrar sesión (`logout`).

#### 2. Preferencias y Sistema de Unidades (`UnitSystem`)
- **Modelo y Utilidades**: Se creó [lib/models/units.dart](file:///d:/vigoriafit/lib/models/units.dart) con el enum `UnitSystem`:
  - `UnitSystem.metric`: Peso en kilogramos (`kg`) y estatura en centímetros (`cm`).
  - `UnitSystem.imperial`: Peso en libras (`lb`) y estatura en pies/pulgadas (`ft/in`).
- **Persistencia**: Clave global de dispositivo `brio_unit_system_v1` en `SharedPreferences`. Restaurada automáticamente al arrancar la app en `store.load()`.
- **Integridad de datos canónicos**:
  - En la base de datos (Firestore) y modelos internos (`Profile`, `WeightEntry`, `ExerciseWeightEntry`), los datos numéricos se mantienen **siempre en unidades canónicas métricas** (`kg`, `cm`).
  - Esto garantiza que las reglas de seguridad de Firestore (`validHealth`), cálculos de IMC, requerimientos de hidratación y macronutrientes se mantengan estrictamente consistentes y válidos, evitando pérdida de precisión o incompatibilidades de esquema.
- **Formateo y adaptabilidad en la UI**:
  - `AppStore.instance.formatWeight(kg)`: Muestra `70 kg` o `154.3 lb` según el sistema activo.
  - `AppStore.instance.formatWeightDiff(diff)`: Muestra `+1.5 kg` o `+3.3 lb`.
  - `AppStore.instance.formatHeight(cm)`: Muestra `175 cm` o `5'9"`.
  - **[SettingsPage](file:///d:/vigoriafit/lib/pages/settings_page.dart)**: Selector interactivo `_unitSelector()` con feedback visual y etiquetas de sliders dinámicas para estatura, peso actual y peso meta.
  - **[ProgressTab](file:///d:/vigoriafit/lib/pages/progress_page.dart)**: Tarjetas de estadísticas, gráfico de evolución del peso (con conversión de escala y puntos Y en imperial) y modal de registro de peso diario adaptado a la unidad activa.
  - **[WorkoutDetailPage](file:///d:/vigoriafit/lib/pages/workout_detail_page.dart)**: Historial de cargas levantadas adaptado a la unidad del usuario y conversión transparente al registrar o editar cargas en libras.

#### 3. Casos de prueba automatizados
Se creó la suite [test/theme_and_units_test.dart](file:///d:/vigoriafit/test/theme_and_units_test.dart) (6/6 pruebas aprobadas):
1. `Preferencia de tema: persistencia, reactividad y restauración al iniciar`.
2. `Preferencia de unidades: persistencia y restauración al iniciar`.
3. `Conversiones y formateo de peso métrico vs imperial`.
4. `Conversiones y formateo de estatura métrico vs imperial`.
5. `Integridad de conversión bidireccional (Round-trip)`.
6. `Preferencias de dispositivo se conservan tras logout`.

---

### Paso 7: Corrección de reaparición de alimentos descartados (Bug #98)

#### 1. Causa raíz identificada del Bug #98
En [lib/data/nutrition.dart](file:///d:/vigoriafit/lib/data/nutrition.dart):
- El método `forGoalAndType` filtraba primero las comidas por objetivo (`m.goals.contains(g)`).
- Posteriormente evaluaba `_isSafe(m, profile)`.
- Si `safe.isEmpty` (cuando no existían comidas seguras para ese objetivo específico, o ante alergias múltiples), el código ejecutaba `return list;`, devolviendo la lista original **con los alimentos no seguros**.
- En consecuencia, el generador de menús (`dayMenu`) y las vistas ([nutrition_page.dart](file:///d:/vigoriafit/lib/pages/nutrition_page.dart), [today_page.dart](file:///d:/vigoriafit/lib/pages/today_page.dart), [coach.dart](file:///d:/vigoriafit/lib/services/coach.dart)) volvían a mostrar al usuario alimentos con alérgenos (gluten, lactosa, etc.) o incompatibles con sus condiciones médicas (diabetes, afección renal).

#### 2. Solución arquitectónica implementada
1. **Regla de oro de seguridad estricta**:
   - Bajo **ninguna circunstancia** se devuelve un alimento que no cumpla con `Nutrition.isSafe(m, profile)`. Los alimentos descartados quedan irrevocablemente excluidos.
2. **Cascada de búsqueda de alternativas**:
   - **Nivel 1**: Buscar comidas seguras que coincidan exactamente con el objetivo del usuario (`goalMatches`).
   - **Nivel 2**: Si no hay opciones seguras para ese objetivo puntual, buscar comidas seguras de ese tipo de comida en **otros objetivos** (`otherGoalMatches`).
   - **Nivel 3**: Si aún así la base de datos se agota por restricciones severas acumuladas, se activa `Nutrition.safeFallbackFor(type)`: una alternativa hipoalergénica natural garantizada (libre de los 6 alérgenos comunes y sin banderas de riesgo como `highSugar`, `highPotassium`, `highSodium` o `irritant`).
3. **Ampliación del catálogo de alimentos con opciones hipoalergénicas**:
   - Se agregaron desayunos, snacks y cenas naturalmente libres de alérgenos (ej. *Bowl de chía con fruta de estación*, *Papas doradas al romero con palta*, *Bastones de apio y zanahoria con hummus*, *Salteado de zapallo italiano con pavo*) para garantizar variedad real incluso para usuarios con múltiples restricciones.
4. **Soporte de exclusiones individuales (`excludedNames`)**:
   - Se añadió soporte para descartar alimentos específicos por nombre, asegurando que si el usuario no desea un alimento, éste no vuelva a sugerirse.
5. **Propagación del perfil**:
   - Se conectó el perfil activo a todas las llamadas de generación de menú en `today_page.dart` y `coach.dart`.

#### 3. Casos de prueba automatizados
Se creó la suite [test/food_filter_safety_test.dart](file:///d:/vigoriafit/test/food_filter_safety_test.dart) (6/6 pruebas aprobadas):
1. `Alimentos descartados por alergia NUNCA se muestran en el menú`.
2. `Si el objetivo específico no tiene alternativas seguras, busca en otros objetivos antes de fallar`.
3. `Bug #98: Descarte total no reintroduce alimentos descartados`.
4. `Alimentos descartados individualmente (excludedNames) nunca se devuelven`.
5. `Filtros médicos de condiciones: diabetes y enfermedad renal descartan dietFlags de riesgo`.
6. `safeFallbackFor garantiza comidas 100% libres de alérgenos y dietFlags`.

---

### Paso 8: Reglas de filtrado documentadas y casos de prueba para módulos posteriores (US37–US39)

#### 1. Documento normativo formal
Se redactó el documento normativo [docs/reglas_de_filtrado_us37_us39.md](file:///d:/vigoriafit/docs/reglas_de_filtrado_us37_us39.md) que establece las especificaciones clínicas, biomecánicas y de seguridad que rigen los módulos posteriores de Nutrición, Suplementación y Rutinas:
- **US37 (Nutrición y Alergias)**:
  - Matriz de exclusión estricta por alérgeno (`lactosa`, `gluten`, `frutosSecos`, `mariscos`, `huevo`, `soja`).
  - Banderas dietéticas para condiciones de salud: `diabetes` (excluye `highSugar`), `afeccionRenal` (excluye `highPotassium` y `highSodium`), `gastritis` (excluye `irritant`).
  - Regla de descarte irrevocable: si un alimento contiene un alérgeno o bandera de riesgo del usuario, queda excluido al 100%, con cascada de fallback hipoalergénico universal.
- **US38 (Suplementación y Contraindicaciones Médicas)**:
  - Algoritmo de priorización por meta: los suplementos alineados al objetivo (`perderPeso`, `ganarMusculo`, `rendimiento`, `salud`) encabezan las recomendaciones.
  - Matriz de precauciones médicas (`lib/data/supplements.dart`):
    - Cafeína / Termogénicos: Contraindicados ante hipertensión o arritmia.
    - Creatina: Precaución ante afecciones renales preexistentes (requiere hidratación abundante y supervisión).
    - Proteína Whey Concentrada: Contraindicada ante intolerancia a la lactosa (recomienda aislada/vegetal).
    - Pre-entrenos con estimulantes: Incompatibles con patologías cardiovasculares.
  - Helpers clínicos: `Supplements.forProfile()`, `Supplements.hasCaution()`, `Supplements.getCautionNote()`.
- **US39 (Entrenamiento, Entorno y Lesiones Biomecánicas)**:
  - Filtrado por entorno: si `hasGym == false`, solo se recomiendan rutinas caseras/calistenia sin requerimiento de máquinas o barras de gimnasio (`lib/data/workouts.dart`).
  - Matriz de precauciones biomecánicas por lesión:
    - `lesionRodilla`: Alerta ante sentadillas profundas, saltos, zancadas o prensa pesada.
    - `lesionEspalda` / `herniaDiscal`: Alerta ante peso muerto convencional, sentadilla trasera pesada o remo con barra sin apoyo.
    - `lesionHombro`: Alerta ante press militar pesado o fondos en paralelas.
  - Helpers de compatibilidad: `Workouts.hasExerciseCaution()`, `Workouts.getConflictingConditions()`, `Workouts.isCompatibleWithEnvironment()`, `Workouts.countCautionsInWorkout()`.

#### 2. Casos de prueba automatizados
Se creó la suite [test/filtering_rules_us37_us39_test.dart](file:///d:/vigoriafit/test/filtering_rules_us37_us39_test.dart) (6/6 pruebas aprobadas):
1. `US37: Las comidas respetan estrictamente la matriz de exclusión`.
2. `US38.1: Suplementos priorizan la meta del usuario en primeras posiciones`.
3. `US38.2: Detección precisa de precauciones médicas en suplementos`.
4. `US39.1: Filtrado de rutinas según entorno (hasGym == false vs true)`.
5. `US39.2: Detección y conteo de ejercicios con advertencia por lesión de rodilla`.
6. `US39.3: Detección de ejercicios con advertencia por lesión de espalda`.

---

## 🏆 Conclusión del Sprint 2
Todos los 8 pasos del Sprint 2 han sido completados exitosamente, con **100% de pruebas unitarias aprobadas** (33/33 tests), **0 advertencias ni errores en `flutter analyze`**, separación estricta de datos en Firestore, sincronización robusta offline-first e interfaces preparadas y validadas para los sprints posteriores.
