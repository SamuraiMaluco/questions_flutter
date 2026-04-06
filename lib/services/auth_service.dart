import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  String? validateEmail(String email) {
    if (email.isEmpty) {
      return 'Informe o e-mail';
    }

    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(email)) {
      return 'E-mail inválido';
    }

    return null;
  }

  String? validatePassword(String password) {
    if (password.isEmpty) {
      return 'Informe a senha';
    }

    if (password.length < 6) {
      return 'A senha deve ter pelo menos 6 caracteres';
    }

    return null;
  }

  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'Usuário não encontrado';
        case 'wrong-password':
        case 'invalid-credential':
          return 'E-mail ou senha inválidos';
        case 'invalid-email':
          return 'E-mail inválido';
        default:
          return 'Erro ao entrar: ${e.message}';
      }
    } catch (_) {
      return 'Erro inesperado ao entrar';
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<String?> getUserRole(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();

      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null) return null;

      final role = data['role']?.toString().trim().toLowerCase();
      final status = data['status']?.toString().trim().toLowerCase();

      // Admin sempre vai para a tela do admin
      if (role == 'admin') return 'admin';

      // Usuário comum retorna o status (pending, approved, rejected)
      return status ?? 'pending';
    } catch (_) {
      return null;
    }
  }

  Future<String?> registerUser({
    required String email,
    required String password,
    Map<String, dynamic>? profileData,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _db.collection('users').doc(credential.user!.uid).set({
        'email': email,
        'role': profileData?['role'] ?? 'user',
        'status': profileData?['status'] ?? 'pending',
        'ativo': profileData?['ativo'] ?? true,
        ...?profileData,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'Este e-mail já está em uso';
        case 'invalid-email':
          return 'E-mail inválido';
        case 'weak-password':
          return 'Senha fraca';
        default:
          return 'Erro ao cadastrar: ${e.message}';
      }
    } catch (_) {
      return 'Erro inesperado ao cadastrar';
    }
  }
}