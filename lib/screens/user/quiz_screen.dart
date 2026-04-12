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
  Set<String> _skipped = {}; // ← questões puladas
  int _currentPage = 0;
  bool _isLoading = true;
  bool _showPanel = false; // ← controla mini painel

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _textController.dispose();
    super.dispose();
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

  int get _correctSoFar => _results.values.where((v) => v).length;
  int get _answeredSoFar => _results.length;

  // porcentagem de acerto até agora
  int get _scorePercent => _answeredSoFar > 0
      ? (_correctSoFar / _answeredSoFar * 100).round()
      : 0;

  void _nextQuestion(String answer) {
    final question = _questions[_currentPage];
    final isCorrect = _checkAnswer(question, answer);

    setState(() {
      _answers[question.id] = answer;
      _results[question.id] = isCorrect;
      _skipped.remove(question.id); // remove de puladas se respondeu
    });

    _textController.clear();
    _advance();
  }

  // ── pular questão ────────────────────────────────────
  void _skipQuestion() {
    final question = _questions[_currentPage];
    setState(() {
      _skipped.add(question.id);
      _answers.remove(question.id);
      _results.remove(question.id);
    });
    _textController.clear();
    _advance();
  }

  void _advance() {
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

  void _resetQuiz() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        scrollable: true,
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
                _skipped = {};
                _currentPage = 0;
                _showPanel = false;
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
    final skippedCount = _skipped.length;
    final score = totalQuestions > 0
        ? (correctCount / totalQuestions * 100).round()
        : 0;

    await _db
        .collection('questionnaires')
        .doc(widget.questionnaireId)
        .collection('responses')
        .doc(uid)
        .set({
      'userId': uid,
      'questionnaireId': widget.questionnaireId,
      'questionnaireTitle': widget.questionnaireTitle,
      'answers': _answers,
      'results': _results,
      'skipped': _skipped.toList(),
      'score': score,
      'correctCount': correctCount,
      'skippedCount': skippedCount,
      'totalQuestions': totalQuestions,
      'submittedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      _showReportDialog(score, correctCount, skippedCount, totalQuestions);
    }
  }

  void _showReportDialog(
      int score, int correct, int skipped, int total) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        scrollable: true,
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
            Text('$correct de $total acertos',
                style: const TextStyle(fontSize: 16)),
            if (skipped > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '$skipped não respondida${skipped > 1 ? 's' : ''}',
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 13),
                ),
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
              final isSkipped = _skipped.contains(q.id);
              final isCorrect = _results[q.id] ?? false;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isSkipped
                          ? Icons.remove_circle_outline
                          : isCorrect
                          ? Icons.check_circle
                          : Icons.cancel,
                      color: isSkipped
                          ? Colors.grey
                          : isCorrect
                          ? Colors.green
                          : Colors.red,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isSkipped
                            ? 'Pergunta ${i + 1} — não respondida'
                            : 'Pergunta ${i + 1}',
                        style: TextStyle(
                          fontSize: 13,
                          color:
                          isSkipped ? Colors.grey : Colors.black,
                        ),
                      ),
                    ),
                    if (!isCorrect && !isSkipped)
                      Flexible(
                        child: Text(
                          'Correto: ${q.correctAnswer}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
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
          body: Center(child: CircularProgressIndicator()));
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.questionnaireTitle)),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Este questionário ainda não possui perguntas.',
                textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.questionnaireTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // ── mini painel de desempenho ─────────────────
          GestureDetector(
            onTap: () => setState(() => _showPanel = !_showPanel),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _answeredSoFar > 0
                    ? (_scorePercent >= 70
                    ? Colors.green.shade50
                    : Colors.orange.shade50)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _answeredSoFar > 0
                      ? (_scorePercent >= 70
                      ? Colors.green
                      : Colors.orange)
                      : Colors.grey,
                ),
              ),
              child: Text(
                _answeredSoFar > 0
                    ? '$_correctSoFar/$_answeredSoFar ✓  $_scorePercent%'
                    : '0/0',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _answeredSoFar > 0
                      ? (_scorePercent >= 70
                      ? Colors.green.shade700
                      : Colors.orange.shade700)
                      : Colors.grey,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reiniciar',
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

      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _questions.length,
            itemBuilder: (context, index) {
              final question = _questions[index];
              final previousResult = _results[question.id];
              final isSkipped = _skipped.contains(question.id);
              return _QuestionSlide(
                question: question,
                questionNumber: index + 1,
                totalQuestions: _questions.length,
                textController: _textController,
                onAnswer: _nextQuestion,
                onSkip: _skipQuestion,
                onBack: index > 0 ? _previousQuestion : null,
                previousResult: previousResult,
                isSkipped: isSkipped,
              );
            },
          ),

          // ── mini painel expansível ────────────────────
          if (_showPanel)
            Positioned(
              top: 0,
              right: 0,
              left: 0,
              child: GestureDetector(
                onTap: () => setState(() => _showPanel = false),
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Desempenho atual',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _PanelStat(
                            label: 'Acertos',
                            value: '$_correctSoFar',
                            color: Colors.green,
                          ),
                          _PanelStat(
                            label: 'Erros',
                            value:
                            '${_answeredSoFar - _correctSoFar}',
                            color: Colors.red,
                          ),
                          _PanelStat(
                            label: 'Puladas',
                            value: '${_skipped.length}',
                            color: Colors.grey,
                          ),
                          _PanelStat(
                            label: 'Aproveitamento',
                            value: '$_scorePercent%',
                            color: _scorePercent >= 70
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _scorePercent / 100,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation(
                            _scorePercent >= 70
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Toque para fechar',
                          style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── widget do mini painel ────────────────────────────────
class _PanelStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _PanelStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}

class _QuestionSlide extends StatelessWidget {
  final Question question;
  final int questionNumber;
  final int totalQuestions;
  final TextEditingController textController;
  final void Function(String) onAnswer;
  final VoidCallback onSkip; // ← novo
  final VoidCallback? onBack;
  final bool? previousResult;
  final bool isSkipped; // ← novo

  const _QuestionSlide({
    required this.question,
    required this.questionNumber,
    required this.totalQuestions,
    required this.textController,
    required this.onAnswer,
    required this.onSkip,
    this.onBack,
    this.previousResult,
    this.isSkipped = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: true,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).padding.bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Pergunta $questionNumber de $totalQuestions',
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 13),
                ),
                const Spacer(),
                if (isSkipped)
                  const Icon(Icons.remove_circle_outline,
                      color: Colors.grey, size: 20)
                else if (previousResult != null)
                  Icon(
                    previousResult! ? Icons.check_circle : Icons.cancel,
                    color:
                    previousResult! ? Colors.green : Colors.red,
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              question.text,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            _buildAnswerWidget(context),
            const SizedBox(height: 8),

            // ── botões de navegação ──────────────────────
            Row(
              children: [
                if (onBack != null)
                  TextButton.icon(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Voltar'),
                  ),
                const Spacer(),
                // ── botão pular ──────────────────────────
                TextButton.icon(
                  onPressed: onSkip,
                  icon: const Icon(Icons.skip_next, size: 16,
                      color: Colors.grey),
                  label: const Text('Pular',
                      style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ],
        ),
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: question.options
              .map((option) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton(
              onPressed: () => onAnswer(option),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                alignment: Alignment.centerLeft,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                option,
                style: const TextStyle(fontSize: 15),
                softWrap: true,
                overflow: TextOverflow.visible,
                textAlign: TextAlign.left,
              ),
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
                contentPadding: EdgeInsets.all(16),
              ),
              minLines: 4,
              maxLines: 10,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                if (textController.text.trim().isNotEmpty) {
                  onAnswer(textController.text.trim());
                }
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
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