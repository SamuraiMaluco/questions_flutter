import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/question.dart';

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
  Map<String, bool> _results = {};
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

  bool _checkAnswer(Question question, String answer) {
    final correct = question.correctAnswer.trim().toLowerCase();
    final given = answer.trim().toLowerCase();
    if (correct.isEmpty) return true;
    return given == correct;
  }

  void _nextQuestion(String answer) {
    final question = _questions[_currentPage];
    final isCorrect = _checkAnswer(question, answer);

    setState(() {
      _answers[question.id] = answer;
      _results[question.id] = isCorrect;
    });

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

  void _previousQuestion() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage--);
    }
  }

  // ── Botão 3: reset do questionário ────────────────────────
  void _resetQuiz() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reiniciar questionário'),
        content: const Text(
            'Tem certeza que quer apagar suas respostas e começar do zero?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _answers = {};
                _results = {};
                _currentPage = 0;
              });
              _textController.clear();
              _pageController.jumpToPage(0);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitAnswers() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final totalQuestions = _questions.length;
    final correctCount = _results.values.where((v) => v).length;
    final score = totalQuestions > 0
        ? (correctCount / totalQuestions * 100).round()
        : 0;

    await _db
        .collection('questionnaires')
        .doc(widget.questionnaireId)
        .collection('responses')
        .doc(uid)
        .set({
      'answers': _answers,
      'results': _results,
      'score': score,
      'correctCount': correctCount,
      'totalQuestions': totalQuestions,
      'submittedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      _showReportDialog(score, correctCount, totalQuestions);
    }
  }

  void _showReportDialog(int score, int correct, int total) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Resultado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: score >= 70 ? Colors.green : Colors.orange,
              ),
              child: Center(
                child: Text(
                  '$score%',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '$correct de $total acertos',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              score >= 70 ? 'Bom trabalho!' : 'Continue praticando!',
              style: TextStyle(
                color: score >= 70 ? Colors.green : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(_questions.length, (i) {
              final q = _questions[i];
              final isCorrect = _results[q.id] ?? false;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      isCorrect ? Icons.check_circle : Icons.cancel,
                      color: isCorrect ? Colors.green : Colors.red,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pergunta ${i + 1}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    if (!isCorrect)
                      Text(
                        'Correto: ${q.correctAnswer}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Voltar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.questionnaireTitle),
        actions: [
          // ── Botão 3: reset ──────────────────────────────
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reiniciar questionário',
            onPressed: _resetQuiz,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentPage + 1) / _questions.length,
            backgroundColor: Colors.grey.shade200,
          ),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
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

class _QuestionSlide extends StatelessWidget {
  final Question question;
  final int questionNumber;
  final int totalQuestions;
  final TextEditingController textController;
  final void Function(String) onAnswer;
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
          Text(
            'Pergunta $questionNumber de $totalQuestions',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Text(
            question.text,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(child: _buildAnswerWidget(context)),
          // ── Botão 4: retroceder ─────────────────────────
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
              child: Text(option,
                  style: const TextStyle(fontSize: 16)),
            ),
          ))
              .toList(),
        );
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
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}