import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/workout.dart';

/// Un alumno dentro de un grupo, con su adherencia calculada.
class GroupMember {
  final String userId;
  final String name;
  final DateTime joinedAt;
  DateTime? lastWorkoutAt;
  int workoutsThisWeek = 0;

  GroupMember({required this.userId, required this.name, required this.joinedAt});
}

/// Rol entrenador: crear un grupo, que alumnos se unan con un código, asignar
/// rutinas del catálogo existente al grupo, y ver la adherencia de cada
/// alumno (entrenamientos que de verdad completaron).
///
/// Usa Cloud Firestore. No depende de Firebase Auth (el login local por
/// correo no pasa por Firebase) — cada dispositivo tiene un
/// [AppStore.localUserId] generado una vez, que es el identificador dentro
/// del grupo.
class TrainerService {
  TrainerService._();

  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groups');

  /// Crea un grupo nuevo y devuelve (groupId, código de 6 dígitos).
  static Future<(String, String)> createGroup(String trainerName) async {
    final code = _newCode();
    final doc = await _groups.add({
      'trainerName': trainerName,
      'code': code,
      'createdAt': FieldValue.serverTimestamp(),
      'assignedWorkoutId': null,
      'assignedWorkoutTitle': null,
    });
    return (doc.id, code);
  }

  /// Busca un grupo por código y agrega al alumno como miembro. Devuelve el
  /// groupId, o null si el código no existe.
  static Future<String?> joinGroup(
      String code, String userId, String userName) async {
    final q = await _groups.where('code', isEqualTo: code.trim()).limit(1).get();
    if (q.docs.isEmpty) return null;
    final groupId = q.docs.first.id;
    await _groups.doc(groupId).collection('members').doc(userId).set({
      'name': userName,
      'joinedAt': FieldValue.serverTimestamp(),
    });
    return groupId;
  }

  static Future<void> assignWorkout(String groupId, Workout w) async {
    await _groups.doc(groupId).update({
      'assignedWorkoutId': w.id,
      'assignedWorkoutTitle': w.title,
      'assignedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Escucha en vivo el grupo (para que el alumno vea si le asignaron algo
  /// nuevo sin tener que salir y volver a entrar).
  static Stream<DocumentSnapshot<Map<String, dynamic>>> watchGroup(String groupId) =>
      _groups.doc(groupId).snapshots();

  static Future<Map<String, dynamic>?> getGroup(String groupId) async {
    final doc = await _groups.doc(groupId).get();
    return doc.data();
  }

  /// Registra que un alumno completó un entrenamiento (para la adherencia
  /// que ve el entrenador).
  static Future<void> logCompletion(
      String groupId, String userId, String userName, Workout w) async {
    await _groups.doc(groupId).collection('completions').add({
      'userId': userId,
      'userName': userName,
      'workoutId': w.id,
      'workoutTitle': w.title,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Trae los miembros del grupo con su adherencia (entrenamientos en los
  /// últimos 7 días y fecha del último).
  static Future<List<GroupMember>> membersWithAdherence(String groupId) async {
    final membersSnap = await _groups.doc(groupId).collection('members').get();
    final members = <String, GroupMember>{};
    for (final d in membersSnap.docs) {
      final data = d.data();
      final joined = (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      members[d.id] = GroupMember(userId: d.id, name: data['name'] ?? '—', joinedAt: joined);
    }
    if (members.isEmpty) return [];

    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final compSnap = await _groups
        .doc(groupId)
        .collection('completions')
        .where('completedAt', isGreaterThan: Timestamp.fromDate(weekAgo))
        .get();
    for (final d in compSnap.docs) {
      final data = d.data();
      final m = members[data['userId']];
      if (m == null) continue;
      m.workoutsThisWeek++;
      final at = (data['completedAt'] as Timestamp?)?.toDate();
      if (at != null && (m.lastWorkoutAt == null || at.isAfter(m.lastWorkoutAt!))) {
        m.lastWorkoutAt = at;
      }
    }
    final list = members.values.toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  static String _newCode() {
    final r = Random.secure();
    return List.generate(6, (_) => r.nextInt(10)).join();
  }
}
