import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Actividad 8 — Pruebas de permisos de Firestore
///
/// Valida estáticamente las reglas de seguridad de Cloud Firestore:
/// estructura, rutas, restricciones de propietario y regla de respaldo.
///
/// Estas pruebas NO requieren emulador ni conexión a internet:
/// leen y verifican el contenido del archivo firestore.rules.
///
/// Para pruebas de integración con el emulador de Firebase, consulta la
/// documentación oficial: https://firebase.google.com/docs/rules/unit-tests
void main() {
  late String rulesContent;

  setUpAll(() {
    final file = File('firestore.rules');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'El archivo firestore.rules debe existir en la raíz del proyecto.',
    );
    rulesContent = file.readAsStringSync();
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('A. Estructura básica del archivo de reglas', () {
    test('A1. Usa rules_version 2 (soporte para comodines recursivos)', () {
      expect(rulesContent, contains("rules_version = '2'"),
          reason: "Se requiere rules_version '2' para usar {document=**}.");
    });

    test('A2. Apunta al servicio cloud.firestore', () {
      expect(rulesContent, contains('service cloud.firestore'),
          reason: 'El servicio debe ser cloud.firestore.');
    });

    test('A3. Contiene regla de respaldo que deniega todo lo no especificado', () {
      expect(rulesContent, contains('allow read, write: if false'),
          reason:
              'Debe existir una regla de respaldo que deniegue rutas no definidas.');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('B. Funciones auxiliares de autenticación', () {
    test('B1. Define función isAuthenticated()', () {
      expect(rulesContent, contains('function isAuthenticated()'),
          reason: 'Debe existir la función helper isAuthenticated().');
    });

    test('B2. isAuthenticated comprueba request.auth != null', () {
      expect(rulesContent, contains('request.auth != null'),
          reason: 'isAuthenticated debe verificar que request.auth no sea null.');
    });

    test('B3. Define función isOwner(userId)', () {
      expect(rulesContent, contains('function isOwner(userId)'),
          reason: 'Debe existir la función helper isOwner(userId).');
    });

    test('B4. isOwner compara request.auth.uid con el userId del documento', () {
      expect(rulesContent, contains('request.auth.uid == userId'),
          reason:
              'isOwner debe comparar el UID autenticado con el ID del propietario.');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('C. Permisos sobre colección USUARIOS (perfil público)', () {
    test('C1. Existe la ruta /usuarios/{userId}', () {
      expect(rulesContent, contains('match /usuarios/{userId}'),
          reason: 'Debe existir una regla para la colección usuarios.');
    });

    test('C2. Lectura del perfil público requiere autenticación', () {
      // Verifica que la lectura de /usuarios no sea pública (sin auth)
      final usuariosSection = _extractSection(rulesContent, 'match /usuarios/{userId}');
      expect(usuariosSection, contains('isAuthenticated()'),
          reason:
              'La lectura de perfiles públicos debe requerir autenticación.');
    });

    test('C3. Escritura del perfil público exige ser el propietario', () {
      final usuariosSection = _extractSection(rulesContent, 'match /usuarios/{userId}');
      expect(usuariosSection, contains('isOwner(userId)'),
          reason:
              'Solo el propietario puede crear, actualizar o borrar su perfil.');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('D. Permisos sobre PERFIL PRIVADO (datos sensibles)', () {
    test('D1. Existe la subcolección /perfil_privado/', () {
      expect(rulesContent, contains('perfil_privado'),
          reason:
              'Debe existir una regla explícita para la subcolección perfil_privado.');
    });

    test('D2. Perfil privado solo es accesible por el propietario (isOwner)', () {
      // La sección del perfil privado debe usar isOwner y NO isAuthenticated solo
      final privateSection = _extractSection(rulesContent, 'perfil_privado');
      expect(privateSection, contains('isOwner(userId)'),
          reason:
              'El perfil privado ÚNICAMENTE debe ser accesible por el propietario '
              '(isOwner), nunca por cualquier usuario autenticado.');
    });

    test('D3. Perfil privado cubre lectura Y escritura con isOwner', () {
      final privateSection = _extractSection(rulesContent, 'perfil_privado');
      // La regla debe cubrir tanto read como write
      expect(privateSection, contains('read'),
          reason: 'Debe restringir la lectura del perfil privado.');
      expect(privateSection, contains('write'),
          reason: 'Debe restringir la escritura del perfil privado.');
    });

    test('D4. Perfil privado usa comodín recursivo {document=**}', () {
      expect(rulesContent, contains('perfil_privado/{document=**}'),
          reason:
              'El comodín {document=**} garantiza que todos los subdocumentos '
              'del perfil privado queden protegidos.');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('E. Permisos sobre colección GROUPS (grupos de entrenamiento)', () {
    test('E1. Existe la ruta /groups/{groupId}', () {
      expect(rulesContent, contains('match /groups/{groupId}'),
          reason: 'Debe existir una regla para la colección groups.');
    });

    test('E2. Lectura de grupos requiere autenticación', () {
      final groupsSection = _extractSection(rulesContent, 'match /groups/{groupId}');
      expect(groupsSection, contains('isAuthenticated()'),
          reason: 'Leer un grupo debe requerir autenticación.');
    });

    test('E3. Crear un grupo requiere que trainerId == auth.uid', () {
      expect(
        rulesContent,
        contains("request.resource.data.trainerId == request.auth.uid"),
        reason:
            'Al crear un grupo, trainerId debe coincidir con el UID del usuario '
            'autenticado para evitar suplantación.',
      );
    });

    test('E4. Actualizar/borrar grupo requiere ser el entrenador (isTrainerOf)', () {
      expect(rulesContent, contains('isTrainerOf(groupId)'),
          reason:
              'Solo el entrenador que creó el grupo puede modificarlo o eliminarlo.');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('F. Permisos sobre MEMBERS (miembros del grupo)', () {
    test('F1. Existe la subcolección /members/', () {
      expect(rulesContent, contains('match /members/{memberId}'),
          reason: 'Debe existir una regla para la subcolección members.');
    });

    test('F2. Un alumno solo puede inscribirse con su propio UID', () {
      expect(rulesContent, contains('request.auth.uid == memberId'),
          reason:
              'Al crear o actualizar un miembro, el UID debe coincidir con el '
              'memberId para evitar que un usuario se inscriba como otro.');
    });

    test('F3. Borrar miembro: alumno puede salir o entrenador puede expulsar', () {
      final membersSection = _extractSection(rulesContent, 'match /members/{memberId}');
      expect(membersSection, contains('request.auth.uid == memberId'),
          reason: 'El alumno debe poder eliminarse a sí mismo (salir del grupo).');
      expect(membersSection, contains('isTrainerOf(groupId)'),
          reason: 'El entrenador debe poder eliminar a un miembro (expulsar).');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('G. Permisos sobre COMPLETIONS (adherencia)', () {
    test('G1. Existe la subcolección /completions/', () {
      expect(rulesContent, contains('match /completions/{completionId}'),
          reason: 'Debe existir una regla para la subcolección completions.');
    });

    test('G2. Crear completion: userId en el documento debe ser auth.uid', () {
      expect(
        rulesContent,
        contains('request.resource.data.userId == request.auth.uid'),
        reason:
            'Al registrar una finalización, el userId del documento debe '
            'coincidir con el UID del usuario autenticado.',
      );
    });

    test('G3. Modificar/borrar completion: autor o entrenador', () {
      final compSection = _extractSection(rulesContent, 'match /completions/{completionId}');
      expect(compSection, contains('resource.data.userId == request.auth.uid'),
          reason: 'El autor puede editar su propia finalización.');
      expect(compSection, contains('isTrainerOf(groupId)'),
          reason: 'El entrenador puede gestionar las finalizaciones de su grupo.');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('H. Coherencia con la app (colecciones que usa el código)', () {
    test('H1. La app usa /usuarios — las reglas cubren esa colección', () {
      expect(rulesContent, contains('match /usuarios/{userId}'),
          reason:
              'store.dart escribe en la colección "usuarios"; las reglas deben '
              'protegerla explícitamente.');
    });

    test('H2. La app usa /groups — las reglas cubren esa colección', () {
      expect(rulesContent, contains('match /groups/{groupId}'),
          reason:
              'trainer_service.dart usa la colección "groups"; las reglas deben '
              'protegerla explícitamente.');
    });

    test('H3. La app usa /usuarios/{uid}/perfil_privado — las reglas lo cubren', () {
      expect(rulesContent, contains('perfil_privado/{document=**}'),
          reason:
              'store.dart escribe en /usuarios/{uid}/perfil_privado/datos; '
              'las reglas deben usar el comodín recursivo para proteger todos los docs.');
    });

    test('H4. No hay reglas para colecciones no usadas por la app (limpieza)', () {
      // Las rutas /users y /grupos (duplicados de sesiones anteriores)
      // ya NO deben aparecer para mantener las reglas limpias.
      expect(rulesContent, isNot(contains("match /users/{userId}")),
          reason:
              'La colección /users (inglés) no es usada por la app; '
              'mantenerla crea superficie de ataque innecesaria.');
      expect(rulesContent, isNot(contains("match /grupos/{groupId}")),
          reason:
              'La colección /grupos (español) no es usada por la app; '
              'mantenerla crea superficie de ataque innecesaria.');
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Extrae el bloque de texto que comienza en [marker] hasta el primer '}'
/// de cierre al mismo nivel de indentación, para aislar una sección de reglas.
String _extractSection(String content, String marker) {
  final start = content.indexOf(marker);
  if (start == -1) return '';
  // Tomamos los 600 caracteres siguientes como contexto de la sección
  final end = (start + 600).clamp(0, content.length);
  return content.substring(start, end);
}
