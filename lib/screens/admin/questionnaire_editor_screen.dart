import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/question.dart';

class QuestionnaireEditorScreen extends StatefulWidget {
  final String? questionnaireId;

  const QuestionnaireEditorScreen({super.key, this.questionnaireId});

  @override
  State<QuestionnaireEditorScreen> createState() =>
      _QuestionnaireEditorScreenState();
}

class _QuestionnaireEditorScreenState
    extends State<QuestionnaireEditorScreen> {
  final _db = FirebaseFirestore.instance;
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  List<Question> _questions = [];
  bool _isLoading = true;
  bool _isSaving = false;

  bool get _isEditing => widget.questionnaireId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadExisting();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadExisting() async {
    final doc = await _db
        .collection('questionnaires')
        .doc(widget.questionnaireId)
        .get();

    final data = doc.data()!;
    _titleController.text = data['title'] ?? '';
    _descController.text = data['description'] ?? '';

    final questionsSnap = await _db
        .collection('questionnaires')
        .doc(widget.questionnaireId)
        .collection('questions')
        .orderBy('order')
        .get();

    setState(() {
      _questions = questionsSnap.docs
          .map((d) => Question.fromFirestore(d.id, d.data()))
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _openQuestionDialog({Question? existing, int? index}) async {
    final textCtrl = TextEditingController(text: existing?.text ?? '');
    final correctCtrl = TextEditingController(text: existing?.correctAnswer ?? '');
    String selectedType = existing?.type ?? 'text';
    final List<TextEditingController> optionCtrls = existing?.options
        .map((o) => TextEditingController(text: o))
        .toList() ??
        [];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          scrollable: true,
          title: Text(existing == null ? 'Nova pergunta' : 'Editar pergunta'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: textCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Texto da pergunta',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tipo de resposta',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'text', label: Text('Texto')),
                    ButtonSegment(value: 'yes_no', label: Text('Sim/Não')),
                    ButtonSegment(
                        value: 'multiple_choice', label: Text('Múltipla')),
                  ],
                  selected: {selectedType},
                  onSelectionChanged: (val) =>
                      setDialogState(() => selectedType = val.first),
                ),
                const SizedBox(height: 16),

                // Gabarito — aparece para todos os tipos
                TextField(
                  controller: correctCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Resposta correta (gabarito)',
                    hintText: 'Ex: Sim / Paris / Revolução Francesa',
                    border: OutlineInputBorder(),
                  ),
                ),

                // Opções — só para múltipla escolha
                if (selectedType == 'multiple_choice') ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Opções de resposta',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...optionCtrls.asMap().entries.map(
                        (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: entry.value,
                              decoration: InputDecoration(
                                labelText: 'Opção ${entry.key + 1}',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                color: Colors.red),
                            onPressed: () => setDialogState(
                                    () => optionCtrls.removeAt(entry.key)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => setDialogState(
                            () => optionCtrls.add(TextEditingController())),
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar opção'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (textCtrl.text.trim().isEmpty) return;

                final newQuestion = Question(
                  id: existing?.id ?? '',
                  text: textCtrl.text.trim(),
                  type: selectedType,
                  order: index ?? _questions.length,
                  correctAnswer: correctCtrl.text.trim(),
                  options: optionCtrls
                      .map((c) => c.text.trim())
                      .where((o) => o.isNotEmpty)
                      .toList(),
                );

                setState(() {
                  if (index != null) {
                    _questions[index] = newQuestion;
                  } else {
                    _questions.add(newQuestion);
                  }
                });

                Navigator.pop(ctx);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveQuestionnaire() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione um título ao questionário')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final data = {
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      DocumentReference docRef;
      if (_isEditing) {
        docRef = _db.collection('questionnaires').doc(widget.questionnaireId);
        await docRef.update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        docRef = await _db.collection('questionnaires').add(data);
      }

      final oldQuestions = await docRef.collection('questions').get();
      for (final doc in oldQuestions.docs) {
        await doc.reference.delete();
      }

      for (int i = 0; i < _questions.length; i++) {
        await docRef.collection('questions').add({
          ..._questions[i].toMap(),
          'order': i,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Questionário salvo com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'yes_no':
        return 'Sim / Não';
      case 'multiple_choice':
        return 'Múltipla escolha';
      default:
        return 'Resposta em texto';
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
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar questionário' : 'Novo questionário'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton(
              onPressed: _saveQuestionnaire,
              child: const Text('Salvar'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Título do questionário',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(
              labelText: 'Descrição (opcional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Text(
                'Perguntas',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _openQuestionDialog,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_questions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Nenhuma pergunta ainda. Toque em "Adicionar".',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _questions.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = _questions.removeAt(oldIndex);
                _questions.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              final q = _questions[index];
              return Card(
                key: ValueKey(q.text + index.toString()),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(q.text),
                  subtitle: Text(_typeLabel(q.type)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () =>
                            _openQuestionDialog(existing: q, index: index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red),
                        onPressed: () =>
                            setState(() => _questions.removeAt(index)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}