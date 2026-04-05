import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

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
          return 'E-mail não cadastrado';
        case 'wrong-password':
          return 'Senha incorreta';
        case 'invalid-credential':
          return 'E-mail ou senha inválidos';
        default:
          return 'Erro ao entrar: ${e.message}';
      }
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<String?> getUserRole(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    if (data['role'] == 'admin') return 'admin';
    return data['status'] ?? 'pending';
  }

  String? validateEmail(String email) {
    final regex = RegExp(r'^[\w.-]+@[\w.-]+\.\w{2,}$');
    if (email.isEmpty) return 'E-mail obrigatório';
    if (!regex.hasMatch(email)) return 'E-mail inválido';
    return null;
  }

  String? validatePassword(String password) {
    if (password.length < 8) return 'Mínimo de 8 caracteres';
    if (!password.contains(RegExp(r'[A-Z]'))) return 'Precisa de uma letra maiúscula';
    if (!password.contains(RegExp(r'[0-9]'))) return 'Precisa de um número';
    return null;
  }

  Future<String?> registerUser({
    required String email,
    required String password,
    required Map<String, String> profileData,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _db.collection('users').doc(credential.user!.uid).set({
        ...profileData,
        'email': email,
        'role': 'user',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'Este e-mail já está cadastrado';
        case 'weak-password':
          return 'Senha muito fraca';
        default:
          return 'Erro ao cadastrar: ${e.message}';
      }
    }
  }
}