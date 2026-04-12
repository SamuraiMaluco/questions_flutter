import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late String uid;
  List<QueryDocumentSnapshot> _responses = [];
  bool _loadingResponses = true;
  String? _responseError;

  @override
  void initState() {
    super.initState();
    uid = FirebaseAuth.instance.currentUser!.uid;
    _loadResponses();
  }

  Future<void> _loadResponses() async {
    setState(() {
      _loadingResponses = true;
      _responseError = null;
    });

    try {
      final snap = await FirebaseFirestore.instance
          .collectionGroup('responses')
          .where('userId', isEqualTo: uid)
          .orderBy('submittedAt', descending: true)
          .limit(5)
          .get();

      setState(() {
        _responses = snap.docs;
        _loadingResponses = false;
      });

      // debug — mostra quantos docs encontrou
      debugPrint('Respostas encontradas: ${snap.docs.length}');
      for (final doc in snap.docs) {
        debugPrint('Doc: ${doc.id} — ${doc.data()}');
      }
    } catch (e) {
      setState(() {
        _responseError = e.toString();
        _loadingResponses = false;
      });
      debugPrint('Erro ao buscar respostas: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meu perfil')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data =
          snapshot.data!.data() as Map<String, dynamic>?;
          final nome =
              data?['q_nome'] ?? data?['name'] ?? 'Usuário';
          final email = data?['email'] ?? '';

          return RefreshIndicator(
            onRefresh: _loadResponses, // ← arrasta para atualizar
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(context).padding.bottom + 24,
              ),
              children: [

                // Avatar
                Center(
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.deepPurple.shade100,
                    child: Text(
                      nome.isNotEmpty ? nome[0].toUpperCase() : 'U',
                      style: TextStyle(
                        fontSize: 40,
                        color: Colors.deepPurple.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    nome,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    email,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 32),

                Row(
                  children: [
                    const Text(
                      'Últimos questionários',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    // botão manual de atualizar
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      tooltip: 'Atualizar',
                      onPressed: _loadResponses,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Arraste para baixo para atualizar',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
                const SizedBox(height: 12),

                // ── área de respostas ──────────────────────
                if (_loadingResponses)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_responseError != null)
                  Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Erro ao carregar histórico:',
                            style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _responseError!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_responses.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Nenhum questionário respondido ainda.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: _responses.map((doc) {
                        final d = doc.data() as Map<String, dynamic>;
                        final score = d['score'] ?? 0;
                        final correct = d['correctCount'] ?? 0;
                        final total = d['totalQuestions'] ?? 0;
                        final skipped = d['skippedCount'] ?? 0;
                        final title = d['questionnaireTitle'] ??
                            'Questionário';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: score >= 70
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                              child: Text(
                                '$score%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: score >= 70
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700,
                                ),
                              ),
                            ),
                            title: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              skipped > 0
                                  ? '$correct/$total acertos · $skipped pulada${skipped > 1 ? 's' : ''}'
                                  : '$correct de $total acertos',
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                const SizedBox(height: 32),

                OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Sair'),
                        content: const Text(
                            'Tem certeza que deseja sair?'),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(context, false),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.pop(context, true),
                            style: FilledButton.styleFrom(
                                backgroundColor: Colors.red),
                            child: const Text('Sair'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await AuthService().logout();
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sair da conta'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}