import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/question.dart';
import '../services/auth_service.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final List<Question> _questions = [];
  final Map<String, String> _answers = {};
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AuthService _authService = AuthService();

  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isSending = false;
  String? _fieldError;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final String raw =
    await rootBundle.loadString('assets/questions.json');
    final List<dynamic> data = jsonDecode(raw);
    setState(() {
      _questions.addAll(data.map((e) => Question.fromJson(e)));
      _isLoading = false;
    });
  }

  void _submitAnswer() {
    final answer = _controller.text.trim();
    if (answer.isEmpty) return;

    final currentQuestion = _questions[_currentIndex];

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

    setState(() {
      _fieldError = null;
      _answers[currentQuestion.id] = answer;
    });

    _controller.clear();

    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
    } else {
      _sendRegistration();
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendRegistration() async {
    setState(() => _isSending = true);

    final email = _answers['q_email'] ?? '';
    final password = _answers['q_password'] ?? '';

    final profileData = Map<String, String>.from(_answers)
      ..remove('q_email')
      ..remove('q_password');

    final error = await _authService.registerUser(
      email: email,
      password: password,
      profileData: profileData,
    );

    if (mounted) {
      setState(() => _isSending = false);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Cadastro enviado!'),
            content: const Text(
                'Aguarde o administrador aprovar seu acesso.'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context, '/', (route) => false),
                child: const Text('Ok'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _currentIndex + 1,
              itemBuilder: (context, index) {
                final question = _questions[index];
                final answer = _answers[question.id];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BotBubble(text: question.text),
                    const SizedBox(height: 8),
                    if (answer != null)
                      _UserBubble(
                        text: question.type == 'password'
                            ? '••••••••'
                            : answer,
                      ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ),
          if (_isSending)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      obscureText:
                      _questions[_currentIndex].type == 'password',
                      decoration: InputDecoration(
                        hintText: 'Digite sua resposta...',
                        border: const OutlineInputBorder(),
                        errorText: _fieldError,
                      ),
                      onSubmitted: (_) => _submitAnswer(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _submitAnswer,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BotBubble extends StatelessWidget {
  final String text;
  const _BotBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}