import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/questionnaire.dart';

class QuizScreen extends StatefulWidget {
  final String questionnaireId;
  final String questionnaireTitle;

  const QuizScreen({
    super.key,
    required this.questionnaireId,
    required this.questionnaireTitle,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final _db = FirebaseFirestore.instance;
  final _pageController = PageController();
  final _textController = TextEditingController();

  List<Question> _questions = [];
  Map<String, dynamic> _answers = {};
  int _currentPage = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final snap = await _db
        .collection('questionnaires')
        .doc(widget.questionnaireId)
        .collection('questions')
        .orderBy('order')
        .get();

    setState(() {
      _questions = snap.docs
          .map((d) => Question.fromFirestore(d.id, d.data()))
          .toList();
      _isLoading = false;
    });
  }

  // Avança para o próximo slide
  void _nextQuestion(dynamic answer) {
    final question = _questions[_currentPage];
    setState(() => _answers[question.id] = answer);
    _textController.clear();

    if (_currentPage < _questions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage++);
    } else {
      _submitAnswers();
    }
  }

  // Volta ao slide anterior
  void _previousQuestion() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage--);
    }
  }

  // Salva as respostas no Firestore
  Future<void> _submitAnswers() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _db
        .collection('questionnaires')
        .doc(widget.questionnaireId)
        .collection('responses')
        .doc(uid)
        .set({
      'answers': _answers,
      'submittedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Concluído!'),
          content: const Text('Suas respostas foram enviadas. Obrigado!'),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context); // fecha dialog
                Navigator.pop(context); // volta para a lista
              },
              child: const Text('Voltar'),
            ),
          ],
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
      appBar: AppBar(
        title: Text(widget.questionnaireTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          // Barra de progresso no topo
          child: LinearProgressIndicator(
            value: (_currentPage + 1) / _questions.length,
            backgroundColor: Colors.grey.shade200,
          ),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // só avança pelo botão
        itemCount: _questions.length,
        itemBuilder: (context, index) {
          final question = _questions[index];
          return _QuestionSlide(
            question: question,
            questionNumber: index + 1,
            totalQuestions: _questions.length,
            textController: _textController,
            onAnswer: _nextQuestion,
            onBack: index > 0 ? _previousQuestion : null,
          );
        },
      ),
    );
  }
}

// ── Widget de cada slide ────────────────────────────────────

class _QuestionSlide extends StatelessWidget {
  final Question question;
  final int questionNumber;
  final int totalQuestions;
  final TextEditingController textController;
  final void Function(dynamic) onAnswer;
  final VoidCallback? onBack;

  const _QuestionSlide({
    required this.question,
    required this.questionNumber,
    required this.totalQuestions,
    required this.textController,
    required this.onAnswer,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Contador de perguntas
          Text(
            'Pergunta $questionNumber de $totalQuestions',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Texto da pergunta
          Text(
            question.text,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),

          // Área de resposta — muda conforme o tipo
          Expanded(child: _buildAnswerWidget(context)),

          // Botão voltar (se não for a primeira)
          if (onBack != null)
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Voltar'),
            ),
        ],
      ),
    );
  }

  Widget _buildAnswerWidget(BuildContext context) {
    switch (question.type) {

    // Sim / Não
      case 'yes_no':
        return Row(
          children: [
            Expanded(
              child: _AnswerButton(
                label: 'Sim',
                color: Colors.green,
                onTap: () => onAnswer('Sim'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _AnswerButton(
                label: 'Não',
                color: Colors.red,
                onTap: () => onAnswer('Não'),
              ),
            ),
          ],
        );

    // Múltipla escolha
      case 'multiple_choice':
        return ListView(
          children: question.options
              .map((option) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton(
              onPressed: () => onAnswer(option),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                alignment: Alignment.centerLeft,
              ),
              child: Text(option, style: const TextStyle(fontSize: 16)),
            ),
          ))
              .toList(),
        );

    // Texto livre (padrão)
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                hintText: 'Digite sua resposta...',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (textController.text.trim().isNotEmpty) {
                  onAnswer(textController.text.trim());
                }
              },
              child: const Text('Próximo'),
            ),
          ],
        );
    }
  }
}

// Botão grande para sim/não
class _AnswerButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AnswerButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }
}