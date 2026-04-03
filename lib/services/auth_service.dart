import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  // Valida o e-mail antes de enviar
  String? validateEmail(String email) {
    final regex = RegExp(r'^[\w.-]+@[\w.-]+\.\w{2,}$');
    if (email.isEmpty) return 'E-mail obrigatório';
    if (!regex.hasMatch(email)) return 'E-mail inválido';
    return null; // null significa que está ok
  }

  // Valida a senha
  String? validatePassword(String password) {
    if (password.length < 8) return 'Mínimo de 8 caracteres';
    if (!password.contains(RegExp(r'[A-Z]'))) return 'Precisa de uma letra maiúscula';
    if (!password.contains(RegExp(r'[0-9]'))) return 'Precisa de um número';
    return null;
  }

  // Cria a conta e salva como "pendente" no Firestore
  Future<String?> registerUser({
    required String email,
    required String password,
    required Map<String, String> profileData,
  }) async {
    try {
      // 1. Cria o usuário no Firebase Auth
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Salva os dados do perfil no Firestore com status pendente
      await _db.collection('users').doc(credential.user!.uid).set({
        ...profileData,
        'email': email,
        'status': 'pending',        // pendente até admin aprovar
        'createdAt': FieldValue.serverTimestamp(),
      });

      return null; // null = sucesso
    } on FirebaseAuthException catch (e) {
      // Traduz os erros do Firebase para português
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