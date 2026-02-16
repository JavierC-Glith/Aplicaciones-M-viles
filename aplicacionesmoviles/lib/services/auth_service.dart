import 'package:firebase_auth/firebase_auth.dart';

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthException(_mapErrorToMessage(error));
    } catch (_) {
      throw AuthException(
        'Ocurrió un error inesperado. Por favor, intenta de nuevo.',
      );
    }
  }

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.sendEmailVerification();
      return credential;
    } on FirebaseAuthException catch (error) {
      throw AuthException(_mapErrorToMessage(error));
    } catch (_) {
      throw AuthException(
        'Ocurrió un error inesperado. Por favor, intenta de nuevo.',
      );
    }
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  String _mapErrorToMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'El correo electrónico no tiene un formato válido.';
      case 'user-disabled':
        return 'Esta cuenta está deshabilitada. Contacta al administrador.';
      case 'user-not-found':
        return 'No existe un usuario con ese correo.';
      case 'wrong-password':
        return 'La contraseña es incorrecta.';
      case 'email-already-in-use':
        return 'El correo ya está registrado. Inicia sesión en su lugar.';
      case 'weak-password':
        return 'La contraseña es demasiado débil. Usa al menos 6 caracteres.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera un momento e inténtalo nuevamente.';
      default:
        return 'No pudimos completar la operación. Inténtalo más tarde.';
    }
  }
}
