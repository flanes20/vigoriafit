# Sprint 1: cuentas, perfil y aislamiento de datos

## Estado y alcance

Implementación local del 5 de octubre de 2026. Proyecto configurado en Android y `.firebaserc`: **vigoria-fe224**. El ID procede de `android/app/google-services.json`; no es `vigoria-224`.

| Paso / Azure | Resultado local | Verificación pendiente |
| --- | --- | --- |
| 1 / #95 | ID y configuración del cliente identificados | Acceso remoto, miembros del equipo, servicios y edición de Firestore |
| 2 / #94, US40 | Dependencias resueltas, pruebas y guía reproducible | SDK Android en este Mac y ejecución por los tres integrantes |
| 3 / #113 | Modelo y reglas versionados | Comparar con colecciones y reglas existentes antes de desplegar |
| 4 / #104 | Registro y acceso por Firebase Authentication; se elimina la autenticación local | Proveedor correo/contraseña habilitado y prueba real Android |
| 5 / #105 | Restauración de sesión de Firebase, cierre y reinicio de navegación | Prueba de cierre/reapertura en Android |
| 6 / #106, #107, #121 | Perfil básico y privado por UID; lectura remota y guardado transaccional | Prueba con dos cuentas reales |
| 7 / #100 | Caché local por UID, memoria y recordatorios separados | Prueba manual en un teléfono compartido |
| 8 / #110 | Reglas de propietario y entrenador, pruebas de acceso indebido | Despliegue y validación en la base real |

La CLI reconoce una cuenta, pero las consultas remotas devolvieron HTTP 401. No se han modificado servicios, usuarios, permisos IAM ni reglas en producción. Los resultados locales no acreditan que el entorno remoto esté configurado.

## Entorno reproducible

Versión comprobada: Flutter **3.41.9**, Dart **3.11.5**. El mínimo declarado es Dart `^3.11.0`; conservar `pubspec.lock`. No ejecutar actualizaciones de dependencias como requisito para empezar.

1. Clonar el repositorio e instalar esa versión de Flutter.
2. Instalar Android Studio y su SDK. Ejecutar `flutter doctor -v`, corregir Android toolchain y aceptar las licencias con `flutter doctor --android-licenses`.
3. Ejecutar `flutter pub get`.
4. Copiar `lib/core/secrets.example.dart` a `lib/core/secrets.dart` sin sobrescribir un archivo existente. Para este sprint se puede dejar la clave de Gemini vacía. El archivo está ignorado por Git.
5. Ejecutar `flutter test --no-pub` y `flutter analyze --no-pub`.
6. Conectar un Android o iniciar un emulador; ejecutar `flutter devices` y `flutter run -d ID_DEL_DISPOSITIVO`.

La configuración entregada es Android. No basta ejecutar en macOS o web para comprobarla: esas plataformas necesitan sus propias configuraciones Firebase. En este Mac falta el SDK Android, por lo que no se ha construido ni ejecutado un APK.

Para las reglas se usó Firebase CLI **15.32.1** y Java **21**. Las dependencias JavaScript quedan fijadas en `package-lock.json`:

```sh
npm ci
npx firebase-tools@15.32.1 emulators:exec --only firestore --project demo-vigoriafit "npm run test:rules"
```

El identificador `demo-vigoriafit` corresponde a pruebas locales. Los tests conectan explícitamente con `127.0.0.1:8080`; no escriben en `vigoria-fe224`. El puerto debe estar libre. Java 21 debe estar disponible en PATH. La app Android normal no apunta automáticamente a estos emuladores.

## Configuración remota que debe verificarse

1. Completar `npx firebase-tools@15.32.1 login --reauth --no-localhost` en el mismo Mac si la sesión está vencida. No guardar tokens ni credenciales administrativas en el repositorio.
2. Consultar `projects:list` y `firestore:databases:list --project vigoria-fe224`. Comprobar base `(default)`, edición y API compatible con el SDK Core usado por la aplicación.
3. Revisar en configuración del proyecto los accesos individuales de los tres integrantes. No compartir una cuenta ni conceder Owner como solución general. La identidad de los otros integrantes y sus accesos aún no están verificados.
4. En Authentication, comprobar/habilitar correo y contraseña. Conservar los demás proveedores existentes. Google requiere además su configuración Android y huellas de firma; el flujo está conservado en el código, pero no verificado en un dispositivo.
5. Leer las reglas remotas y las estructuras existentes. Conservar una copia antes de reemplazarlas. Las reglas nuevas rechazan cualquier colección no declarada.
6. Resolver grupos antiguos sin `trainerId` y miembros cuyo ID no sea un UID. No asignarles un propietario por deducción. Requieren validación del responsable o recreación controlada. No borrar datos históricos.
7. Una vez comparadas las reglas y resueltas incompatibilidades, desplegar únicamente reglas:

```sh
npx firebase-tools@15.32.1 deploy --only firestore:rules --project vigoria-fe224
```

No desplegar indiscriminadamente todos los servicios. `firestore.indexes.json` está vacío porque estas operaciones no requieren índices compuestos nuevos; eso no confirma que no existan índices remotos útiles.

## Modelo inicial de Firestore

Las siguientes son colecciones/documentos, no tablas SQL. El correo y la contraseña pertenecen a Authentication; no se duplican contraseñas en Firestore ni en preferencias.

### `users/{uid}`

| Campo | Tipo | Descripción |
| --- | --- | --- |
| name | string, máximo 120 | Nombre mostrado |
| goal | integer 0–3 | Índice del enum Goal del modelo |
| level | integer 0–2 | Índice del enum Level |
| daysPerWeek | integer 1–7 | Frecuencia elegida |
| hasGym | boolean | Disponibilidad de gimnasio |
| onboarded | boolean | Perfil inicial completado |
| createdAt | timestamp | Fecha del servidor, inmutable |
| updatedAt | timestamp | Fecha del servidor |

Solo el propietario puede leer este documento. No hay listado general de usuarios. `uid` es el ID del documento, no un correo ni un identificador generado en el teléfono.

### `users/{uid}/private/health_profile`

| Campo | Tipo | Descripción |
| --- | --- | --- |
| age | integer 12–120 | Edad; conserva compatibilidad con el selector actual, no determina por sí sola la elegibilidad del servicio |
| heightCm | number 80–250 | Estatura |
| weightKg | number 20–500 | Peso actual |
| targetWeightKg | number 20–500 | Peso objetivo |
| conditions | list de integer 0–8, hasta 9 | Valores del enum de condiciones |
| allergies | list de integer 0–5, hasta 6 | Valores del enum de alergias |
| updatedAt | timestamp | Fecha del servidor |

Solo el dueño tiene acceso, incluido frente a entrenadores de su grupo. Los límites numéricos son validaciones de formato, no recomendaciones de salud. Mantener estable el orden de los enums o migrar los valores al modificarlo.

### Grupos e invitaciones

| Ruta | Campos |
| --- | --- |
| `groups/{groupId}` | trainerId: string UID; trainerName: string; code: string de seis dígitos; createdAt: timestamp; assignedWorkoutId: string/null; assignedWorkoutTitle: string/null; assignedAt: timestamp opcional |
| `groupInvites/{code}` | groupId: string; trainerId: string UID; createdAt: timestamp |
| `groups/{groupId}/members/{uid}` | name: string; joinedAt: timestamp; inviteCode: string |
| `groups/{groupId}/completions/{id}` | userId: string UID; userName: string; workoutId: string; workoutTitle: string; completedAt: timestamp |

Crear grupo e invitación es una transacción que evita colisiones de código. Los usuarios autenticados pueden consultar un código concreto, pero no listar invitaciones. El ingreso crea únicamente su propia membresía. El entrenador propietario puede consultar miembros y cumplimiento; un alumno puede salir y leer su grupo mientras sea miembro.

El permiso de entrenador procede de una **custom claim `trainer: true`** de Firebase Authentication, establecida mediante una herramienta administrativa confiable fuera de la app. Antes de asignarla se debe confirmar la identidad del entrenador. Preservar cualquier otra claim existente. Renovar el token o volver a iniciar sesión tras un cambio. El interruptor del teléfono ya no otorga privilegios. Todavía no se ha asignado esta claim a ninguna cuenta desde esta implementación.

## Separación de cuentas y migración

Las claves locales utilizan `vigoria_v2_<UID>_<clave>`. Cambiar de usuario borra inmediatamente el estado en memoria, reinicia la navegación y reemplaza los recordatorios. Una respuesta tardía de la cuenta anterior no sustituye el perfil actual. El primer acceso y el guardado de perfil requieren conexión; si Firestore falla, la pantalla ofrece reintentar o cerrar sesión.

Las cuentas locales anteriores no se convierten automáticamente en cuentas Firebase. Tampoco se reasignan perfiles de salud, grupos o registros antiguos sin identidad verificable. Las claves antiguas se conservan sin usarse: no se borran ni se atribuyen al siguiente usuario que inicia sesión. Una migración de esos datos requiere identificar al propietario y diseñar un procedimiento separado.

El perfil y el peso actual se sincronizan. Historial de peso, comidas, agua, entrenamientos, plan semanal y preferencias siguen guardados localmente por UID: no están aún respaldados entre dispositivos. SharedPreferences no constituye almacenamiento cifrado; el aislamiento entre cuentas no reemplaza una revisión de almacenamiento local antes de usar datos sensibles reales.

## Pruebas y aceptación

Las pruebas de Flutter cubren sesión persistente simulada, cambio de cuentas, aislamiento de caché, rechazo de credenciales antiguas, respuesta remota tardía, errores de carga/guardado y persistencia del peso. Son pruebas con adaptadores falsos, no una prueba de los proveedores reales de Authentication.

Las diez pruebas del emulador cubren creación válida, acceso anónimo/cruzado denegado, privacidad frente al entrenador, campos y roles inyectados, tipos/rangos, documentos privados huérfanos, suplantación de entrenador, invitaciones, asignación de rutinas y permisos de cumplimiento/salida. Los mensajes `PERMISSION_DENIED` de los intentos prohibidos son resultados esperados.

Para cerrar el sprint, cada integrante debe registrar fecha, versión y resultado de este recorrido Android:

1. Crear cuenta A, completar perfil, cerrar y reabrir la app: misma cuenta y mismo perfil.
2. Registrar agua y un peso; cerrar sesión: desaparecen perfil, grupo y navegación anterior.
3. Crear cuenta B: no aparecen datos de A. Volver a A: se recuperan sus propios datos.
4. Cambiar perfil con red: persistir al reiniciar. Sin red: mostrar error recuperable, sin anunciar un guardado remoto exitoso.
5. Intentar leer/escribir datos ajenos mediante SDK: denegado por reglas, aunque se evite la interfaz.
6. Con una cuenta autorizada como entrenador, crear grupo e ingresar con un alumno; comprobar asignación y salida. El entrenador no puede leer el perfil privado del alumno.

No marcar todo el sprint Done antes de verificar el entorno real. Fuera de este alcance quedan eliminación integral de cuentas, recuperación de contraseña desde la interfaz, invitaciones con caducidad y protección contra intentos masivos, sincronización completa de historiales y evitar duplicados de cumplimiento. El registro de cumplimiento todavía genera un ID por envío y no garantiza idempotencia.
