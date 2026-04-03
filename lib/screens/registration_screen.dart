import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/question.dart';
import '../services/registration_service.dart';
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

  int _currentIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  // Lê o JSON da pasta assets
  Future<void> _loadQuestions() async {
    final String raw =
    await rootBundle.loadString('assets/questions.json');
    final List<dynamic> data = jsonDecode(raw);

    setState(() {
      _questions.addAll(data.map((e) => Question.fromJson(e)));
      _isLoading = false;
    });
  }

  // Avança para a próxima pergunta ou finaliza
  void _submitAnswer() {
    final answer = _controller.text.trim();
    if (answer.isEmpty) return;

    final currentQuestion = _questions[_currentIndex];
    _answers[currentQuestion.id] = answer;
    _controller.clear();

    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
    } else {
      _sendToAdmin();
    }

    // Rola a tela para baixo automaticamente
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  // Envia os dados para o administrador
  Future<void> _sendToAdmin() async {
    final service = RegistrationService();
    await service.sendRegistration(_answers);

    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text('Cadastro enviado!'),
          content: Text(
              'Seu pedido foi enviado ao administrador. Aguarde a aprovação.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro')),
      body: Column(
        children: [
          // Histórico de perguntas e respostas
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
                    // Balão do bot (pergunta)
                    _BotBubble(text: question.text),
                    const SizedBox(height: 8),
                    // Balão do usuário (resposta), se já respondeu
                    if (answer != null) _UserBubble(text: answer),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ),

          // Campo de entrada
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Digite sua resposta...',
                      border: OutlineInputBorder(),
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

// Widget do balão do bot
class _BotBubble extends StatelessWidget {
  final String text;
  const _BotBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text),
      ),
    );
  }
}

// Widget do balão do usuário
class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}