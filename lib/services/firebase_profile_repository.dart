import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/profile.dart';
import 'auth_service.dart';
import 'profile_repository.dart';

/// Core Firestore API, default database; private fields never go in users/{uid}.
class FirebaseProfileRepository implements ProfileRepository {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  static const _basicFields = [
    'name',
    'goal',
    'level',
    'daysPerWeek',
    'hasGym',
  ];
  Map<String, dynamic> _basic(Profile profile) => Map.fromEntries(
    profile.toMap().entries.where((entry) => _basicFields.contains(entry.key)),
  );
  Map<String, dynamic> _private(Profile profile) => Map.fromEntries(
    profile.toMap().entries.where((entry) => !_basicFields.contains(entry.key)),
  );

  @override
  Future<AccountProfile> loadOrCreate(AccountIdentity user) async {
    final ref = _db.collection('users').doc(user.uid);
    final health = ref.collection('private').doc('health_profile');

    // Try to fetch from server first; fall back to local cache if offline.
    Future<DocumentSnapshot<Map<String, dynamic>>> getWithFallback(
      DocumentReference<Map<String, dynamic>> docRef,
    ) async {
      try {
        return await docRef
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 12));
      } catch (_) {
        // Network unavailable – use the Firestore offline cache.
        return docRef.get(const GetOptions(source: Source.cache));
      }
    }

    final values = await Future.wait([
      getWithFallback(ref),
      getWithFallback(health),
    ]);
    var base = values[0].data();
    var private = values[1].data();
    if (base == null || private == null) {
      // Documents don't exist yet – create them with a batch so the write
      // is queued offline and sent as soon as connectivity is restored.
      final batch = _db.batch();
      final initial = Profile(name: user.name);
      if (base == null) {
        batch.set(ref, {
          ..._basic(initial),
          'onboarded': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        base = {..._basic(initial), 'onboarded': false};
      }
      if (private == null) {
        batch.set(health, {
          ..._private(initial),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        private = _private(initial);
      }
      await batch.commit();
    }
    final current = FirebaseAuth.instance.currentUser;
    if (current?.uid != user.uid) throw StateError('La sesión cambió.');
    final token = await current!.getIdTokenResult();
    return AccountProfile(
      Profile.fromMap({...base, ...private}),
      onboarded: base['onboarded'] == true,
      trainer: token.claims?['trainer'] == true,
    );
  }

  @override
  Future<void> save(
    String uid,
    Profile profile, {
    required bool onboarded,
  }) async {
    final ref = _db.collection('users').doc(uid);
    // Use a WriteBatch instead of a transaction so writes are queued offline
    // by the Firestore SDK and sent automatically when connectivity resumes.
    // This avoids the "no internet" false-positive errors the transaction caused.
    final batch = _db.batch();
    batch.set(
      ref,
      {
        ..._basic(profile),
        'onboarded': onboarded,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      ref.collection('private').doc('health_profile'),
      {
        ..._private(profile),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }
}
