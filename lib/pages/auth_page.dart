import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/theme.dart';
import '../services/store.dart';

/// Pantalla de acceso: iniciar sesión o crear cuenta (correo + contraseña),
/// con botón de Google.
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _register = true; // true = crear cuenta, false = iniciar sesión
  bool _busy = false;
  bool _hide = true;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final s = AppStore.instance;
    final err = _register
        ? await s.register(_name.text, _email.text, _pass.text)
        : await s.login(_email.text, _pass.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) _snack(err);
    // Si no hay error, el "gate" de main.dart cambia de pantalla solo.
  }

  Future<void> _google() async {
    setState(() => _busy = true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // El usuario cerró el selector de cuenta sin elegir ninguna.
        setState(() => _busy = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCred.user;
      if (user == null || user.email == null) {
        throw Exception('No pude obtener tu cuenta de Google.');
      }
      await AppStore.instance
          .loginWithProvider(user.email!, user.displayName ?? googleUser.displayName ?? 'Usuario');
      // Si no hubo error, el "gate" de main.dart cambia de pantalla solo.
    } catch (e) {
      _snack('No se pudo iniciar sesión con Google. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.brand, AppColors.brandDark]),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child:
                      const Icon(Icons.bolt_rounded, color: Colors.white, size: 48),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text('VigoriaFit',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
              ),
              Center(
                child: Text('Tu vida saludable, con IA',
                    style: TextStyle(fontSize: 14, color: AppColors.muted)),
              ),
              const SizedBox(height: 28),

              // Selector entrar / crear cuenta
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    _tab('Crear cuenta', true),
                    _tab('Iniciar sesión', false),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (_register) ...[
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Correo',
                  prefixIcon: Icon(Icons.mail_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pass,
                obscureText: _hide,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_hide
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white))
                      : Text(_register ? 'Crear cuenta' : 'Entrar'),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: Divider(color: AppColors.line)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('o',
                        style: TextStyle(fontSize: 12, color: AppColors.faint)),
                  ),
                  Expanded(child: Divider(color: AppColors.line)),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _google,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: AppColors.line),
                    foregroundColor: AppColors.ink,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                  label: const Text('Continuar con Google',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                    'Tus datos se guardan en tu teléfono, de forma segura.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: AppColors.faint)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(String label, bool isRegister) {
    final active = _register == isRegister;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _register = isRegister),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: active ? Border.all(color: AppColors.line) : null,
          ),
          child: Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: active ? AppColors.ink : AppColors.muted)),
        ),
      ),
    );
  }
}
