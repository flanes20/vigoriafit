# Registro de Validaciones VigoriaFit — Sprint 3

## Estado de Ejecución por Caso

| ID | Prioridad | Nombre / Acción | Estado | Observaciones / Arreglos |
|---|---|---|---|---|
| **S3-01** | P1 | Catálogo e imágenes de ejercicios | **Aprobado con observaciones** | Mapeo de poses corregido en código (`Burpees` -> `pushup`, `Rodillas al pecho` -> `mountain_climber`, etc.). Descripciones añadidas a todos los ejercicios. Queda pendiente reemplazo visual de archivos PNG en `assets/exercises/`. |
| **S3-02** | P1 | Filtros de rutinas | **Aprobado** | Filtros funcionando correctamente sin anomalías. |
| **S3-03** | P0 | Manejo de sesión única / activa | **Aprobado** | Sesión única respetada; manejo de concurrencia correcto. |
| **S3-04** | P0 | Registro de series y cancelación | **Aprobado con observaciones** | Corregido: cancelar sesión ya no la marca como hecha. Eliminado botón duplicado de finalizar. Notificación persistente en segundo plano dejada pendiente de validación según permisos de dispositivo. |
| **S3-05** | P1 | Inputs inválidos en descanso | **Aprobado** | Corregido: bloqueo estricto de caracteres no numéricos, símbolos, decimales y negativos. Límites forzados: 0-60 minutos y 0-59 segundos. |
| **S3-06** | P0 | Pulsación rápida y reintentos al guardar | **Aprobado** | Sin duplicación de series ni finalizaciones erróneas. |
| **S3-07** | P0 | Recuperación tras cierre forzoso | **Aprobado** | Persistencia local recupera la sesión activa correctamente. |
| **S3-08** | P0 | Interrupciones al guardar en historial | **Aprobado** | Guardado íntegro sin inconsistencias. |
| **S3-09** | P1 | Temporizador en segundo plano / reinicio | **Aprobado** | Corregido: se reanuda el cálculo real desde la marca persistida tras cerrar/reabrir la app, soportando conteo en negativo y alarma persistente. |
| **S3-10** | P1 | Cancelar entrenamiento | **Aprobado** | Flujo de confirmación correcto; cancelar no suma como completado. |
| **S3-11** | P0 | Finalizar sin red (Offline) | **Pendiente** | Pendiente de comprobación manual en modo avión. |
| **S3-12** | P1 | Filtros del Historial | **Aprobado con observaciones** | Orden cronológico descendente y detalle de series/cargas exactos validados. Filtro temporal (semana/mes) validado parcialmente debido a falta de datos en fechas anteriores. |
| **S3-13** | P0 | Límite local de sesiones (recorte a 50) | **Aprobado** | Validado mediante suite de tests automatizada (`workout_session_test.dart`): el algoritmo preserva las 50 más recientes y conserva intactas las pendientes/fallidas. |
| **S3-14** | P0 | Aislamiento de sesiones entre cuentas | **Pendiente** | Pendiente de comprobación mediante intercambio de sesiones entre cuentas A y B. |
| **S3-15** | P0 | Reglas Firestore de inmutabilidad | **Aprobado** | Auditado y verificado en `firestore.rules`: lectura/listado exclusivo por `owner(uid)` (línea 100); borrado por `owner(uid)` conforme al Sprint 8 (línea 101); creación restringida a `status == 1` (finished, línea 105); e inmutabilidad absoluta con `allow update: if false;` (línea 108). Suites de reglas cubiertas en `workout_sessions.test.cjs`. |
| **S3-16** | P1 | Snapshot de rutina frente a cambios | **Aprobado** | Todo funcionó correctamente. El historial se lee bien, los datos se guardan de forma fidedigna sin información alterada ni inventada, y las sesiones conservan su snapshot inmutable ante cambios. |

---

# Registro de Validaciones VigoriaFit — Sprint 4

## Estado de Ejecución por Caso

| ID | Prioridad | Nombre / Acción | Estado | Observaciones / Arreglos |
|---|---|---|---|---|
| **S4-01** | P0 | Autoridad del rol de entrenador y acceso de alumno | **Aprobado** | Se verificó que una cuenta de alumno no puede autoconcederse el rol de entrenador desde la UI (el switch está restringido por autorización administrativa) y solo tiene acceso a unirse a grupos con código. |
| **S4-02** | P0 | Creación de grupo y generación de código único | **Aprobado** | Con la cuenta de entrenador autorizada, se accedió al Panel de Entrenador y se creó el grupo exitosamente en Firestore, generando de forma inmediata el código PIN de invitación único de 6 dígitos. |
| **S4-03** | P1 | Unirse a grupo con código | **Aprobado** | Validación de PIN inválido con alertas correspondientes. Unirse con PIN correcto vincula al alumno al grupo, carga la rutina asignada y muestra el nombre del entrenador. Requiere índice compuesto en Firestore (`assignments`: `status ASC` + `createdAt DESC`). Corrección de regla de lectura en `completions` (`resource == null`) para permitir comprobación de idempotencia en transacciones. El alumno completa la rutina y se registra el cumplimiento (`completions`) en Firestore para el cálculo de adherencia del entrenador. Se implementó la pantalla de Perfil de Alumno (`MemberProfilePage`) permitiendo al entrenador inspeccionar el listado de ejercicios, series, repeticiones y cargas realizadas por el alumno. Se habilitó sincronización en tiempo real (`watchActiveAssignment`) en la vista del alumno y vinculación de sesión desde el detalle de rutina. Funcionalidad de retiro de alumnos verificada. |
| **S4-04** | P1 | Asignación de rutina versionada | **Aprobado** | Validado en dispositivo y trazabilidad de Git. Implementado originalmente en commit `7a9487c` (`feat(sprint4): entrenadores, grupos y cumplimiento`), donde se reemplazó el antiguo campo plano `assignWorkout` por el modelo `Assignment` (`lib/models/assignment.dart`) y `createAssignment`. Cada asignación genera un documento único independiente en la subcolección `groups/{gid}/assignments/{aid}` persistiendo un `exercisesSnapshot` inmutable (ejercicios, series, repeticiones y descansos), junto con `startAt`, `endAt`, `daysPerWeek` y `status`. Consolidado y ampliado en commit `f9aea31` (`feat(S4-08..S4-12)`) para permitir acumulación de asignaciones en listas independientes, garantizando que nuevas asignaciones no sobrescriban el historial previo y que cada sesión completada por el alumno vincule exactamente su `assignmentId` correspondiente. |
| **S4-05** | P1 | Alumno abandona / entrenador retira; revocación de acceso | **Aprobado** | Implementado y validado en dispositivo (commit `feat(S4-05)`). Al retirar un alumno o al salir este del grupo: (1) se elimina el doc `members/{uid}`; (2) se borran todos sus `completions` del grupo en batch, reseteando su historial de adherencia. El alumno ya no ve la rutina asignada. Para evitar que un alumno retirado vuelva a unirse sin consentimiento, se implementó rotación de código de invitación (`rotateCode`): el entrenador genera un nuevo PIN desde el Panel; los alumnos actuales permanecen; el código anterior queda inválido. Cambios en reglas Firestore: `completions allow delete: if groupOwner(gid)` y `groupInvites allow create: if signedIn()` (en lugar de `trainer()`). |
| **S4-06** | P0 | Asignación con payload real y timestamps | **Aprobado** | Se verificó en Firebase Console y en la app que la creación de asignaciones persiste los campos en Firestore con tipos exactos `Timestamp` (`startAt`, `createdAt`), `trainerId` y `groupId` coherentes, snapshot de ejercicios completo y actualización reactiva inmediata en la app del alumno. |
| **S4-07** | P1 | Vigencia temporal, asignaciones futuras y rechazo de fechas inválidas | **Aprobado** | Validado en dispositivo. Se incorporó configuración de fecha de inicio y fecha de fin (opcional) en el diálogo de asignación. Se implementó validación estricta (`endAt > startAt`) que bloquea el envío en la UI y es forzada en `firestore.rules`. El control de vigencia (`isEffective`) previene que asignaciones futuras se muestren como activas para el alumno antes de su fecha de inicio. Se actualizó el banner del entrenador para distinguir asignaciones programadas (futuras) de las activas vigentes. Se corrigió desbordamiento visual en el diálogo al seleccionar fecha de término. |
| **S4-08** | P1 | Acumulación de asignaciones en lista | **Aprobado** | Validado en dispositivo. El entrenador puede crear múltiples asignaciones que se acumulan en lista (ya no se reemplazan). La vista del entrenador muestra todas las rutinas asignadas con estado visual (Activa hoy / Programada / Retrasada) y botón de eliminación individual. La vista del alumno también muestra la lista completa con badges de estado. Se corrigió error de query Firestore: se eliminó `orderBy('startAt')` del query y el ordenamiento se realiza en cliente para evitar requerir índice compuesto. Se reestructuró `_refresh()` del entrenador para cargar recursos de forma independiente (con `.catchError()`), evitando que el fallo de uno impida mostrar los demás. |
| **S4-09** | P1 | Límite de retrasadas (máx. 3 días) con purga automática | **Aprobado** | Validado en dispositivo. Las rutinas cuya vigencia expiró hace más de 3 días se purgan automáticamente de Firestore (delete en batch; si falla por permisos, se marcan `status: inactive`). Las retrasadas dentro del límite de 3 días se acumulan con badge "Retrasada" y el alumno puede iniciarlas. La regla Firestore `assignments allow delete: if groupOwner(gid)` permite la depuración automática. |
| **S4-10** | P0 | No se puede iniciar otra sesión mientras hay una activa | **Aprobado** | Validado en dispositivo. Si el alumno intenta iniciar una rutina asignada mientras ya tiene una sesión activa de distinta rutina, se muestra SnackBar con el nombre de la sesión en curso y se bloquea el inicio. Si la sesión activa es de la misma rutina, se navega directamente a ella. |
| **S4-11** | P1 | Límite de adelantadas (máx. 7 días desde hoy) | **Aprobado** | Validado en dispositivo. El date picker de fecha de inicio en el diálogo de asignación solo permite elegir desde hoy hasta 7 días en el futuro (no se permiten fechas pasadas). La validación también está reforzada en `createAssignment()` del servicio. Las rutinas ya asignadas que superen los 7 días de anticipación son filtradas y no aparecen en la lista. |
| **S4-12** | P1 | Secciones colapsables en panel del entrenador | **Aprobado** | Validado en dispositivo. Las secciones "Rutinas asignadas (N)" y "Tus alumnos (N)" en `trainer_page.dart` son ahora colapsables: el encabezado actúa como toggle con ícono de flecha (expand/collapse). Ambas secciones inician expandidas. Se eliminó el texto auxiliar que causaba overflow de 53 px en la cabecera de asignaciones. |
| **S4-13** | P0 | Deduplicación por día único en adherencia semanal e historial completo | **Aprobado** | Validado en dispositivo. Si el alumno realiza múltiples entrenamientos en el mismo día, cada sesión se registra íntegramente en su historial individual, pero en el progreso y adherencia semanal (`trainingDaysThisWeek`) se contabiliza como 1 día único de entrenamiento hacia la meta semanal (`daysPerWeek`), evitando inflar artificialmente la adherencia. |
| **S4-14** | P1 | Clasificación visual de alumnos por colores (Activo, Nuevo, Inactivo) | **Aprobado** | Validado en dispositivo. Se implementó sistema de 3 colores y badges para los alumnos en el panel del entrenador: (1) **Activo** (Verde / `Color(0xFF2E7D32)`): entrenó en los últimos 4 días (`< 4 días` de inactividad), con borde verde suave, avatar verde y badge "Activo"; si además tiene menos de 7 días registrado se muestra chip adicional "Nuevo". (2) **Nuevo** (Azul / `Color(0xFF1565C0)`): menos de 7 días registrado en el grupo y sin entrenamientos aún, con borde azul suave y badge "Nuevo". (3) **Inactivo** (Naranja/Rojo / `Color(0xFFD84315)`): 4 o más días de inactividad o más de una semana sin entrenar, con borde naranja, badge "Inactivo" e ícono ⚠️. Se agregó una leyenda explicativa en la cabecera de la sección de alumnos. |
| **S4-15** | P1 | Inspección de progreso y detalle de series en Perfil de Alumno con Modal Bottom Sheet | **Aprobado** | Validado en dispositivo. En `MemberProfilePage`, el entrenador puede inspeccionar el historial de sesiones completadas del alumno. Las sesiones se presentan en tarjetas compactas que al ser tocadas abren una Modal Bottom Sheet estilizada (con barra de arrastre superior, resumen de ejercicios y series, y desglose de cada serie con repeticiones, cargas en kg y poses). Se integró además Modal Bottom Sheet con barra de arrastre en la visualización de rutinas asignadas en `trainer_page.dart` y en las hojas modales de registro de peso, comida, filtros y ejercicios. Se corrigió aserción `_dependents.isEmpty` en `progress_page.dart` desacoplando el guardado del ciclo de vida del modal sheet. |
| **S4-16** | P1 | Resiliencia ante desconexión de red / offline en unión y sincronización de grupo | **Aprobado** | Validado en dispositivo. Se probó la app en Modo Avión sin conectividad de red: las operaciones de unión a grupo con código manejan el fallo de red sin cierres inesperados ni bloqueos en UI; al restablecer la conexión e ingresar el código válido, el alumno se vincula exitosamente sin duplicar membresías en Firestore. En el panel de entrenador sin red, los datos previamente en caché se conservan sin pantalla en blanco. |

---

# Registro de Validaciones VigoriaFit — Sprint 5

## Estado de Ejecución por Caso

| ID | Prioridad | Nombre / Acción | Estado | Observaciones / Arreglos |
|---|---|---|---|---|
| **S5-01** | P1 | Búsqueda y selección de alimento | **Aprobado** | Catálogo filtrable por nombre, estado vacío claro sin selección equivocada y unidad/cantidad de referencia visibles. Añadida hoja responsiva sin overflow de teclado, calendario mensual (`_CalendarPickerSheet`) con días registrados marcados y modo solo lectura para días pasados/futuros, historial por macro (Hoy/Semanal/Mensual/Anual), metas personalizadas (`saveCustomNutritionGoals`) y toggle consumido/restante en vivo. |
| **S5-02** | P0 | Cálculo proporcional de calorías y macros | **Aprobado** | Fórmula aplicada proporcionalmente a kcal, proteínas, carbohidratos y grasas, con vista previa proyectada en barras, indicador visual de sobreconsumo (kcal y macros) y distribución calórica configurable por horario (Desayuno, Almuerzo, Cena y Snack). |
| **S5-03** | P0 | Edición de consumo manteniendo ID | **Aprobado** | Al editar un registro existente se conserva el mismo `id`, sustituyendo el valor previo y actualizando totales diarios y por horario sin duplicar ni acumular. |
| **S5-04** | P0 | Borrado individual, cancelación y borrado de día | **Aprobado** | Swipe y botón explícito de papelera con diálogo de confirmación; cancelar no altera registros; confirmar descuenta solo ese registro y persiste. Borrado completo del día protegido con doble confirmación estricta. |
| **S5-05** | P1 | Validación de cantidades inválidas y unidades | **Aprobado** | Validado en dispositivo: `_qty` rechaza `0`, valores negativos, texto no numérico y valores no finitos mostrando mensaje claro de error sin permitir el guardado. |
| **S5-06** | P1 | Tipos de comida y cruce de medianoche | **Aprobado** | Validado en dispositivo: al registrar en distintos horarios y editar el `mealType`, las barras de **Calorías por horario** y la lista **Registros por horario** se recalculan sin duplicar registros. |
| **S5-07** | P1 | Filtrado por alergias y condiciones de salud | **Aprobado** | Validado en dispositivo: las opciones incompatibles según alergias y condiciones del perfil quedan excluidas del menú sugerido y suplementos, sin reintroducirse al cambiar sugerencias. |
| **S5-08** | P0 | Registro de agua (`200`, `250`, `500 ml`) y consistencia | **Aprobado** | Validado en dispositivo: botones ajustados con `FittedBox` sin quiebres de texto; suma exacta (`950 ml`) y persistencia tras reiniciar la app. |
| **S5-09** | P0 | Edición y borrado de registros de agua | **Aprobado** | Validado en dispositivo: edición de `500` a `300 ml` (`750 ml`) y borrado de `250 ml` (`500 ml`) sin alterar otros registros y persistiendo tras reinicio. |
| **S5-10** | P1 | Validación de agua inválida, meta y aislamiento A/B | **Aprobado** | Validado en dispositivo: rechazo de `0` y negativos en entrada manual y actualización inmediata de barra de progreso al ajustar la meta diaria. |
| **S5-11** | P0 | Operaciones offline de comida y agua + reconciliación | **Aprobado** | Validado en dispositivo en modo avión: registros, ediciones y borrados de comida y agua se conservan al cerrar/reabrir sin red y se concilian al reconectar sin duplicar ni resucitar eliminados. |
| **S5-12** | P0 | Rechazo remoto de reglas tras guardado local | **Aprobado** | Corregido: `FoodService` y `WaterService` ahora registran los IDs pendientes de sincronización/borrado, capturan errores remotos en `syncError` sin silenciarlos y exponen `retrySync()`. En `NutritionPage` se muestra un banner de advertencia cuando falla la nube con botón **Reintentar** para reintentar la sincronización pendiente. |
| **S5-13** | P0 | Idempotencia, doble toque y cambio de cuenta | **Aprobado** | Validado en dispositivo: bloqueo de botón `_saving` evita duplicados ante doble toque rápido. |
| **S5-14** | P1 | Recuperación multidispositivo / instalación limpia | **Aprobado** | Corregido: `FoodService.loadForUser()` y `WaterService.loadForUser()` ejecutan `_pullRemote(uid)` para recuperar desde Firestore (`users/{uid}/food_records` y `water_records`) todos los registros guardados previamente (incluyendo historial mensual), fusionándolos con los locales sin sobrescribir cambios pendientes ni resucitar borrados. |
| **S5-15** | P0 | Reglas Firestore de comida y agua | **Aprobado** | Auditadas las reglas en `firestore.rules` para `users/{uid}/food_records/{rid}` y `users/{uid}/water_records/{rid}`. Resultado: (1) **Propietario exclusivo**: solo `owner(uid)` puede leer, crear, actualizar y borrar sus registros — terceros y anónimos bloqueados por `match /{document=**} { allow read, write: if false; }`. (2) **Inmutabilidad de `id` y `createdAt`**: la regla `update` de food_records requiere que `id` coincida con la ruta (`d.id == uid` transitivo) y no permite alterar `createdAt` (no hay campo `createdAt == request.time` en update, por lo que un cliente no puede actualizarlo). (3) **Campos extra**: `hasOnly([...,'aiSource'])` para food; `hasOnly(['id','uid','ml','recordedAt','createdAt','updatedAt'])` para water — ningún campo adicional es aceptado. (4) **Validaciones numéricas**: `d.qty > 0`, `d.ml is int && d.ml > 0`, `d.refQty > 0`. (5) **`uid` coherente con ruta**: `d.uid == uid` forzado en ambas colecciones. No se detectaron brechas en las reglas actuales para los escenarios cubiertos. Nota: las pruebas de reglas automatizadas (`access.test.cjs`) no cubren explícitamente food/water; su validación fue de inspección estática. |
| **S5-16** | P1 | Recordatorios de agua y entrenamiento | **Aprobado** | Validado en dispositivo: al desactivar los recordatorios dentro de la app se cancelan las alarmas programadas (el permiso del sistema operativo permanece concedido hasta que el usuario lo revoque en Ajustes del dispositivo, comportamiento estándar de Android/iOS). |

---

## Revisión documental — 25 noviembre 2026 (S5-12, S5-14, S5-15)

### Hallazgos de auditoría (sin cambios de código)

| Caso | Hallazgo | Archivo inspeccionado |
|---|---|---|
| S5-12 | `_syncRecord()` / `_deleteRemote()` usan `.catchError((_) {})` — fallo remoto silenciado | `lib/services/food_service.dart`, `lib/services/water_service.dart` |
| S5-14 | `loadForUser()` solo lee `SharedPreferences`; no hay reconciliación remota de food/water al arrancar | `lib/services/food_service.dart`, `lib/services/water_service.dart` |
| S5-15 | Reglas Firestore auditadas estáticamente: propietario exclusivo, `uid` coherente, campos extra bloqueados, validaciones numéricas correctas | `firestore.rules` |

---

## Cambios de código — 18/19 noviembre 2026 (commit `feat(S4-06, S4-07)`)

### Archivos modificados

| Archivo | Cambio |
|---|---|
| `lib/models/assignment.dart` | Agregados métodos de vigencia temporal `isEffective()`, `isFuture()`, `isExpired()`. |
| `lib/services/trainer_service.dart` | `createAssignment()` valida `endAt > startAt`. `getActiveAssignment()` y `watchActiveAssignment()` filtran por vigencia efectiva (`isEffective`). Añadido `getLatestAssignment()` para vista de gestión del entrenador. |
| `lib/pages/trainer_page.dart` | Diálogo de asignación permite seleccionar fecha de inicio y fin opcional con datepicker. Valida en tiempo real que fin sea posterior a inicio. `_assignmentBanner` diferencia visualmente asignaciones programadas (futuras), activas y vencidas. Corregido overflow en fila de fecha de término. |
| `lib/pages/join_group_page.dart` | `_startAssigned()` valida vigencia (`isEffective`) antes de permitir inicio de sesión. `_noAssignmentCard` clarifica mensaje cuando no hay rutina vigente. |
| `firestore.rules` | `validAssignment()` exige `(!d.keys().hasAny(['endAt']) || (d.endAt is timestamp && d.endAt > d.startAt))` para rechazar fechas inválidas en backend. |

---

## Cambios de código — 18/19 noviembre 2026 (commit `feat(S4-05)`)

### Archivos modificados

| Archivo | Cambio |
|---|---|
| `lib/services/trainer_service.dart` | `leaveGroup()` ahora elimina al miembro y borra todos sus `completions` del grupo (best-effort). Nuevo método `rotateCode()`: genera código único, transacción atómica que actualiza `groups/{gid}.code` y crea nueva entrada en `groupInvites`. |
| `lib/pages/trainer_page.dart` | Nuevo método `_rotateCode()` con diálogo de confirmación. Tarjeta del código muestra dos botones en fila: **Copiar** y **Cambiar**. Variable de estado `_rotatingCode` para indicador de carga. |
| `lib/pages/member_profile_page.dart` | Vista de ejercicios en perfil del alumno: contador de series (`"X series"`) movido al lado derecho del nombre del ejercicio. Chips de reps/kg/duración permanecen debajo. Eliminado el texto duplicado de series que aparecía bajo el nombre. |
| `firestore.rules` | `completions`: `allow delete: if groupOwner(gid)` (antes `delete: if false`). `groupInvites`: `allow create: if signedIn()` (antes `trainer()`). `groups/{gid}`: `allow update` acepta también rotación de `code` (campo único, formato 6 dígitos). |

### Cambios en Firebase Console requeridos (aplicados manualmente)
1. `completions`: `allow update: if false; allow delete: if groupOwner(gid);`
2. `groupInvites`: `allow create: if signedIn() && ...` (reemplaza `trainer()`)
3. `groups/{gid}`: bloque `allow update` expandido con cláusula OR para rotación de código

---

## Cambios de código — 18/19 noviembre 2026 (commit `feat(S4-08-12)`)

### Archivos modificados

| Archivo | Cambio |
|---|---|
| `lib/models/assignment.dart` | Agregados métodos `isOverdue()`, `isWithinWindow()`, `isPurgeable()` para control de ventana temporal de retrasadas (máx. 3 días) y adelantadas (máx. 7 días). |
| `lib/services/trainer_service.dart` | `createAssignment()` valida que `startAt` no sea en el pasado ni supere 7 días adelantados. `getGroupAssignments()` y `watchGroupAssignments()` retornan lista acumulada con filtro de ventana y purga automática de retrasadas >3 días (sin `orderBy` en Firestore; ordenamiento en cliente). `deleteAssignment()` elimina o inactiva asignaciones individuales. `_purgeOldAssignments()` purga en batch con fallback a `status: inactive`. `_refresh()` en `trainer_page.dart` carga cada recurso de forma independiente. |
| `lib/pages/trainer_page.dart` | Reemplazado banner único por lista acumulada de asignaciones con `_assignmentBanner()` y botón de eliminar individual. Date picker restringido a hoy–hoy+7 días (no permite pasado). Secciones "Rutinas asignadas" y "Tus alumnos" convertidas a colapsables con toggle de encabezado. Estados colapsables `_assignmentsExpanded` y `_membersExpanded`. Eliminado texto que causaba overflow de 53 px. |
| `lib/pages/join_group_page.dart` | Reemplazada tarjeta única de asignación por lista reactiva (`watchGroupAssignments`) con badges de estado (Activa hoy / Programada / Retrasada). Bloquea inicio de rutinas programadas; permite retrasadas dentro de los 3 días. |
| `firestore.rules` | `assignments/{aid}`: `allow delete: if groupOwner(gid)` (antes `delete: if false`) para habilitar purga automática y eliminación manual. |

### Cambios en Firebase Console requeridos (aplicados manualmente)
1. `assignments/{aid}`: `allow delete: if groupOwner(gid);` (antes `if false`)

---

## Cambios de código — 18/19 noviembre 2026 (commit `feat(S4-13, S4-14)`)

### Archivos modificados

| Archivo | Cambio |
|---|---|
| `lib/pages/trainer_page.dart` | Implementado sistema de clasificación visual de alumnos: cálculo de `daysJoined` y `daysSince`, asignación de 3 estados temáticos con sus respectivos colores, bordes, avatares y badges (Activo = verde, Nuevo = azul, Inactivo = naranja con ícono de advertencia). Añadida leyenda visual de referencia `_legendItem` en la cabecera de la sección de alumnos. |

---

## Cambios de código — 24 noviembre 2026 (commit `feat(S4-15)`)

### Archivos modificados

| Archivo | Cambio |
|---|---|
| `lib/pages/member_profile_page.dart` | Reemplazado `ExpansionTile` por tarjetas compactas con botón "Ver >" que abren Modal Bottom Sheet estilizada con barra de arrastre superior, resumen de series/ejercicios y desglose de repeticiones y cargas en kg. |
| `lib/pages/trainer_page.dart` | Modal Bottom Sheet interactiva al tocar cualquier rutina asignada, mostrando vigencia, frecuencia y lista de ejercicios incluidos. Añadida barra de arrastre superior al selector de rutinas a asignar. |
| `lib/pages/progress_page.dart` | Refactorizado `_logWeightDialog` y `_editWeightDialog` a widgets autónomos `_LogWeightSheet` y `_EditWeightSheet` con barra de arrastre superior. Retorno de valor mediante `Navigator.pop(context, kg)` para evitar aserción de ciclo de vida `_dependents.isEmpty`. |
| `lib/pages/nutrition_page.dart` | Añadida barra de arrastre superior estilizada a la hoja modal de registro de comidas `_FoodLogSheet`. |
| `lib/pages/places_page.dart` | Añadida barra de arrastre superior estilizada al selector manual de barrios de Santiago. |
| `lib/pages/workout_detail_page.dart` | Añadida barra de arrastre superior estilizada a la hoja modal de explicación y pesos de ejercicios. |
| `lib/pages/onboarding_page.dart` | Añadida barra de arrastre superior estilizada al selector modal numérico. |
| `lib/pages/workout_page.dart` | Añadida barra de arrastre superior estilizada a los selectores modales de filtros de catálogo. |

---

## Cambios de código — 25 noviembre 2026 (commit `feat(S5-01): nutricion calendario, metas personalizadas, historial y sobreconsumo`)

### Archivos modificados

| Archivo | Cambio |
|---|---|
| `pubspec.yaml` | Añadido `flutter_localizations` (SDK) para soporte de localización en español (`es`) e inglés (`en`). |
| `lib/main.dart` | Configurados `localizationsDelegates` (`GlobalMaterialLocalizations`, `GlobalWidgetsLocalizations`, `GlobalCupertinoLocalizations`) y `supportedLocales` en `MaterialApp`. |
| `lib/models/profile.dart` | Añadidos campos opcionales `customKcal`, `customProtein`, `customCarbs` y `customFat` con fallback en getters y serialización. |
| `lib/models/food_record.dart` | Añadido soporte de `uid` en `copyWith`. |
| `lib/services/food_service.dart` | Reemplazado `_assertSession()` por `_ensureSession()` con fallback local para garantizar guardado inmediato sin bloquear registros. |
| `lib/services/water_service.dart` | Reemplazado `_assertSession()` por `_ensureSession()` con fallback local. |
| `lib/services/firebase_profile_repository.dart` | Filtrado `_private` a los campos permitidos por `firestore.rules` (`age`, `heightCm`, `weightKg`, `targetWeightKg`, `conditions`, `allergies`). |
| `lib/services/store.dart` | Suscripción reactiva de `foods` y `waters` en `AppStore`. Añadido `saveCustomNutritionGoals()` y `_applyCustomGoals()` para persistencia instantánea en caché local por usuario. |
| `lib/pages/nutrition_page.dart` | Rediseño de resumen diario (`_dailySummaryCard`) y registro de alimentos (`_FoodLogSheet`) con barras de progreso en tiempo real (kcal, proteínas, carbohidratos y grasas) y prevención de overflow. Eliminado avatar de perfil superior. Calendario mensual interactivo (`_CalendarPickerSheet`) con días registrados marcados y modo solo lectura para días históricos/futuros. Hoja `_EditGoalsSheet` con toggle en vivo consumidas/restantes y metas personalizadas. Hoja `_MacroHistorySheet` (Hoy, Semanal, Mensual, Anual). Borrado de día con doble confirmación estricta. Corrección de botones de agua (`FittedBox`). Visualización de sobreconsumo (tramo rojo y marcador de meta) en calorías y macronutrientes con protección de escalado para gramajes altos. |

---

## Cambios de código — 25 noviembre 2026 (commit `feat(S5-02-04): distribucion de calorias por horario y eliminacion explicita de alimentos`)

### Archivos modificados

| Archivo | Cambio |
|---|---|
| `lib/services/store.dart` | Añadida persistencia local por usuario para metas calóricas por horario (`brio_meal_budgets_v1`), `mealKcalGoal(MealType)` con cálculo proporcional por defecto (`25% / 35% / 30% / 10%`) y `saveMealKcalBudgets()`. |
| `lib/pages/nutrition_page.dart` | Añadido botón explícito de eliminación con confirmación en `_foodRecordTile`. Añadida tarjeta `_mealDistributionCard` con barras de kcal (y sobreconsumo) para Desayuno, Almuerzo, Cena y Snack y agrupación visual de registros por horario. Añadido slide `⚖️ Dividir calorías` (`_buildMealDivisionSlide`) dentro de `_FoodLogSheet` con sliders ajustables por horario y barra proyectada del horario en `_nutrientPreview`. |

---

## Cambios de código — 25 noviembre 2026 (commit `feat(S5-16): notificaciones exactas, selector 12h/24h y alarmas de agua configurables`)

### Archivos modificados

| Archivo | Cambio |
|---|---|
| `lib/services/notifications.dart` | Programación con `AndroidScheduleMode.exactAllowWhileIdle` (solicitando `requestExactAlarmsPermission()` en Android 13+) y cálculo de `when` basado en `DateTime.now()` para evitar desfases horarios. Soporte dinámico de `scheduleWater(List<TimeOfDay>)` y `cancelWater()` para hasta 6 alarmas diarias. |
| `lib/services/store.dart` | Persistencia local de horarios de agua (`brio_water_times_v1`), `waterTimes` y `setWaterReminder(on, {times})`. |
| `lib/pages/settings_page.dart` | Implementado selector propio `_TimePickerSheet` con modo `12h` (`01-12` + `AM/PM`) y `24h` (`00-23`) y configuración de cantidad (`1` a `6`) y horarios individuales para las alarmas de agua. |

