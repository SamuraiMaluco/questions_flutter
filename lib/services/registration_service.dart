import 'package:flutter/material.dart';
import '../services/auth_service.dart';

// Adicione estas variáveis de estado na classe _RegistrationScreenState:
final AuthService _authService = AuthService();
String? _fieldError; // guarda o erro de validação atual

// Substitua o método _submitAnswer por este:
void _submitAnswer() {
  final answer = _controller.text.trim();
  if (answer.isEmpty) return;

  final currentQuestion = _questions[_currentIndex];

  // Valida conforme o tipo do campo
  String? error;
  if (currentQuestion.type == 'email') {
    error = _authService.validateEmail(answer);
  } else if (currentQuestion.type == 'password') {
    error = _authService.validatePassword(answer);
  }

  if (error != null) {
    setState(() => _fieldError = error);
    return;
  }

  setState(() => _fieldError = null);
  _answers[currentQuestion.id] = answer;
  _controller.clear();

  if (_currentIndex < _questions.length - 1) {
    setState(() => _currentIndex++);
  } else {
    _sendRegistration();
  }
}

// Método de envio atualizado:
Future<void> _sendRegistration() async {
  final email = _answers['q_email'] ?? '';
  final password = _answers['q_password'] ?? '';

  // Remove e-mail e senha do mapa antes de salvar no perfil público
  final profileData = Map<String, String>.from(_answers)
    ..remove('q_email')
    ..remove('q_password');

  final error = await _authService.registerUser(
    email: email,
    password: password,
    profileData: profileData,
  );

  if (mounted) {
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text('Cadastro enviado!'),
          content: Text('Aguarde o administrador aprovar seu acesso.'),
        ),
      );
    }
  }
}