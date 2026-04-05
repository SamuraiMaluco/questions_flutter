import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/questionnaire.dart';
import 'questionnaire_editor_screen.dart';

class AdminQuestionnaireListScreen extends StatelessWidget {
  const AdminQuestionnaireListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Questionários'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Moderação',
            onPressed: () => Navigator.pushNamed(context, '/admin/moderation'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const QuestionnaireEditorScreen(),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Novo questionário'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('questionnaires')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text('Nenhum questionário criado ainda.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final q = Questionnaire.fromFirestore(doc.id, data);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    q.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(q.description),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuestionnaireEditorScreen(
                        questionnaireId: q.id,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}