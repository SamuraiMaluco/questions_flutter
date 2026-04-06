import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'quiz_screen.dart';

class UserQuestionnaireListScreen extends StatelessWidget {
  const UserQuestionnaireListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(FirebaseAuth.instance.currentUser!.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Text('Questionários');
            final data =
            snapshot.data!.data() as Map<String, dynamic>?;
            final nome =
                data?['q_nome'] ?? data?['name'] ?? 'Usuário';
            return Text('Olá, $nome!');
          },
        ),
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
              child: Text('Nenhum questionário disponível ainda.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    data['title'] ?? '',
                    style:
                    const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(data['description'] ?? ''),
                  trailing:
                  const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuizScreen(
                        questionnaireId: doc.id,
                        questionnaireTitle: data['title'] ?? '',
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