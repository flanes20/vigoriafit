# Sprint 4 — Entrenadores, grupos y cumplimiento

## Azure items implementados

| ID | Título |
|----|--------|
| #107 | Modelo `Assignment` versionado |
| #109 | `TrainerService.createAssignment` |
| #111 | `TrainerService.getActiveAssignment` / `watchActiveAssignment` |
| #173 | Integración de `assignmentId` y `groupId` en `WorkoutSession` |
| #188 | `logCompletion` idempotente (sessionId como doc ID) |
| #189 | Llamada a `logCompletion` desde `_syncSession` |
| #190 | UI: asignación activa en `join_group_page.dart` |
| #191 | UI: botón "Iniciar rutina asignada" con `assignmentId` y `groupId` |
| #192 | UI: banner de asignación activa en `trainer_page.dart` |
| #193 | UI: creación de asignación versioned (reemplaza `assignWorkout`) |
| #194 | UI: botón "Retirar" por miembro (`removeMember`) |
| #195 | Reglas Firestore para `assignments` y `completions` idempotentes |

## Acceptance tests verificados

| ID | Descripción | Estado |
|----|-------------|--------|
| #248 | Solo el dueño del grupo puede administrarlo (no-owner bloqueado) | ✅ test Firestore `ordinary user cannot create a trainer group` |
| #252 | Código de invitación válido/inválido | ✅ test Firestore `invitation lookup allows join` |
| #253 | El alumno ve la rutina asignada por su entrenador | ✅ `join_group_page.dart` muestra assignment activo |
| #254 | Solo se registra un completion por sesión (idempotencia) | ✅ test Firestore `completion ownership` + regla `allow update: if false` |

## Modelo de datos

### `Assignment` (`lib/models/assignment.dart`)

```
groups/{gid}/assignments/{aid}
  groupId: string        — referencia al grupo
  trainerId: string      — UID del entrenador (Auth)
  workoutId: string      — ID del catálogo de rutinas
  workoutTitle: string   — snapshot del título (200 chars)
  exercisesSnapshot: []  — snapshot de ejercicios al momento de asignar
  startAt: timestamp     — inicio de la planificación
  endAt?: timestamp      — fin opcional
  daysPerWeek: int 1–7  — frecuencia semanal
  timezone: string       — 'America/Santiago'
  status: 'active'|'inactive'
  createdAt: timestamp
```

**Versionado:** cada llamada a `createAssignment` genera un documento nuevo. El historial de asignaciones se conserva completo. Solo `status` puede modificarse después de crear.

### `WorkoutSession` (campos nuevos)

```
users/{uid}/workout_sessions/{sessionId}
  ...campos existentes...
  aid?: string  — assignmentId (si viene de una asignación)
  gid?: string  — groupId (si viene de un grupo)
```

### `Completion` (idempotente)

```
groups/{gid}/completions/{sessionId}
  sessionId: string     — doc ID == sessionId (garantía de idempotencia)
  userId: string
  userName: string
  workoutId: string
  workoutTitle: string
  completedAt: timestamp
  assignmentId?: string
```

## Permisos (reglas Firestore)

| Recurso | Crear | Leer | Actualizar | Borrar |
|---------|-------|------|------------|--------|
| `groups/{gid}` | trainer (claim) | owner \| member | groupOwner (solo campos de asignación legacy) | ❌ |
| `groups/{gid}/members/{uid}` | owner (con código válido) | owner \| groupOwner | ❌ | owner \| groupOwner |
| `groups/{gid}/assignments/{aid}` | groupOwner + validación completa | groupOwner \| member | groupOwner (solo `status`) | groupOwner |
| `groups/{gid}/completions/{sid}` | member (sid==sessionId, userId==auth.uid) | groupOwner \| owner-del-completion | ❌ | groupOwner |

**El claim `trainer`** viene exclusivamente del JWT de Firebase Auth (`request.auth.token.get('trainer', false)`). No es un campo en el perfil del usuario.

## Flujo session → completion

```
startSession(workout, uid, prefs, assignmentId?, groupId?)
  → WorkoutSession creado con aid + gid

finishSession()
  → _syncSession() escribe en users/{uid}/workout_sessions/{id}
  → si session.groupId != null:
      TrainerService.logCompletion(groupId, sessionId, uid, userName, workout, assignmentId?)
        → transacción: si doc no existe → set; si existe → return (idempotente)
```

## Idempotencia de completions

El `sessionId` (UUID generado en cliente) actúa como ID del documento en `completions`. Las reglas verifican `sid == request.resource.data.sessionId` y `allow update: if false`. Un reintento de sync:
1. La transacción en `logCompletion` lee el doc primero; si existe, retorna sin error.
2. Si la transacción llega a Firestore igualmente, las reglas bloquean el `update`.

## Tests

- `test/firestore/access.test.cjs` — 12 tests de reglas Firestore (node:test + @firebase/rules-unit-testing)
- `test/` — 98 tests Flutter (unit)

## Acumulación de asignaciones y políticas temporales (S4-08 a S4-12)

- **Acumulación en lista (S4-08):** El entrenador puede asignar múltiples rutinas al grupo sin sobrescribir las anteriores. Tanto el panel del entrenador como la pantalla del alumno consumen la lista reactiva de asignaciones vigentes (`watchGroupAssignments`).
- **Retención y purga de retrasadas (S4-09):** Las asignaciones con vigencia expirada se conservan como "Retrasadas" hasta un máximo de 3 días hacia el pasado para que los alumnos puedan ponerse al día. Superados los 3 días de retraso, se depuran y eliminan automáticamente de Firestore.
- **Exclusión de sesión concurrente (S4-10):** El alumno no puede iniciar una sesión de rutina asignada si ya cuenta con una sesión activa en curso de otra rutina.
- **Límite de adelantadas (S4-11):** Las asignaciones futuras solo pueden programarse hasta 7 días a partir del día actual (no se permite programar fechas en el pasado).
- **Secciones colapsables y UI limpia (S4-12):** En el panel del entrenador, las listas de asignaciones y de alumnos cuentan con encabezados colapsables/desplegables para optimizar el espacio visual en pantalla.
- **Deduplicación de entrenamientos por día único (S4-13):** Si un alumno entrena múltiples veces en un mismo día, cada entrenamiento queda guardado en su historial, pero hacia la meta semanal solo cuenta 1 día único de adherencia.
- **Clasificación visual de alumnos por colores (S4-14):** Los alumnos se categorizan en 3 estados con código de colores, bordes y badges: Activo (verde, inactividad < 4 días), Nuevo (azul, < 7 días en el grupo) e Inactivo (naranja con alerta ⚠️, inactividad ≥ 4 días o > 7 días sin entrenar). Incluye leyenda informativa.
- **Inspección de progreso y detalle de series en Perfil de Alumno con Modal Bottom Sheet (S4-15):** En `MemberProfilePage`, el entrenador puede inspeccionar el historial de sesiones completadas del alumno mediante Modal Bottom Sheets estilizadas con barra de arrastre superior, resumen de series/ejercicios y desglose de repeticiones y cargas en kg. También se unificó la barra de arrastre en todas las hojas modales del sistema (rutinas asignadas, registro de peso, comida, filtros y ejercicios).
- **Resiliencia ante desconexión de red / offline en grupo (S4-16):** Las operaciones de unión a grupo con código y sincronización del panel manejan interrupciones de red (modo avión) sin bloqueos ni cierres inesperados; la reconexión posterior no genera duplicados de membresía en Firestore y los datos en caché se preservan de manera coherente.
