import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AccountIdentity {
  final String uid;
  final String? email;
  final String name;
  const AccountIdentity(this.uid, this.email, this.name);
}

abstract class AccountAuth {
  AccountIdentity? get current;
  Stream<AccountIdentity?> get changes;
  Future<void> register(String name, String email, String password);
  Future<void> signIn(String email, String password);
  Future<void> signInWithGoogle();
  Future<void> signOut();
}

class FirebaseAccountAuth implements AccountAuth {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  AccountIdentity? _identity(User? user) => user == null
      ? null
      : AccountIdentity(user.uid, user.email, user.displayName ?? '');
  @override
  AccountIdentity? get current => _identity(_auth.currentUser);
  @override
  Stream<AccountIdentity?> get changes =>
      _auth.authStateChanges().map(_identity);
  @override
  Future<void> register(String name, String email, String password) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await result.user!.updateDisplayName(name);
  }

  @override
  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      await _auth.signInWithPopup(GoogleAuthProvider());
      return;
    }
    final user = await GoogleSignIn().signIn();
    if (user == null) return;
    final tokens = await user.authentication;
    await _auth.signInWithCredential(
      GoogleAuthProvider.credential(
        idToken: tokens.idToken,
        accessToken: tokens.accessToken,
      ),
    );
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    // Firebase is the authority; a provider cleanup failure must not retain app data.
    if (!kIsWeb) {
      try {
        await GoogleSignIn().signOut();
      } catch (_) {
        /* Firebase session is closed. */
      }
    }
  }
}

String accountError(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'email-already-in-use' =>
        'Este correo ya tiene una cuenta. Inicia sesión.',
      'invalid-email' => 'Revisa el formato del correo.',
      'weak-password' => 'La contraseña no cumple los requisitos de seguridad.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'Correo o contraseña incorrectos.',
      'network-request-failed' => 'No hay conexión. Inténtalo nuevamente.',
      'too-many-requests' =>
        'Demasiados intentos. Espera antes de volver a intentar.',
      'operation-not-allowed' =>
        'Este método de acceso todavía no está habilitado.',
      'user-disabled' => 'Esta cuenta está deshabilitada.',
      _ => 'No se pudo completar el acceso. Inténtalo nuevamente.',
    };
  }
  return 'No se pudo completar la operación. Comprueba tu conexión e inténtalo nuevamente.';
}
