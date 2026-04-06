import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ModerationScreen extends StatelessWidget {
  const ModerationScreen({super.key});

  Future<void> _updateStatus(
      BuildContext context,
      String uid,
      String status,
      ) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'status': status});

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Status atualizado para $status'),
      ),
    );
  }

  Future<void> _deleteUser(
      BuildContext context,
      String uid,
      String nome,
      ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover usuário'),
        content: Text('Tem certeza que deseja remover "$nome" permanentemente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .delete();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Usuário "$nome" removido com sucesso.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gerenciar usuários'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pendentes'),
              Tab(text: 'Aprovados'),
              Tab(text: 'Rejeitados'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _UserList(
              status: 'pending',
              onApprove: (uid) => _updateStatus(context, uid, 'approved'),
              onReject: (uid) => _updateStatus(context, uid, 'rejected'),
              onDelete: (uid, nome) => _deleteUser(context, uid, nome),
            ),
            _UserList(
              status: 'approved',
              onApprove: null,
              onReject: (uid) => _updateStatus(context, uid, 'pending'),
              rejectLabel: 'Revogar',
              onDelete: (uid, nome) => _deleteUser(context, uid, nome),
            ),
            _UserList(
              status: 'rejected',
              onApprove: (uid) => _updateStatus(context, uid, 'approved'),
              onReject: null,
              onDelete: (uid, nome) => _deleteUser(context, uid, nome),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserList extends StatelessWidget {
  final String status;
  final void Function(String uid)? onApprove;
  final void Function(String uid)? onReject;
  final void Function(String uid, String nome) onDelete;
  final String rejectLabel;

  const _UserList({
    required this.status,
    required this.onApprove,
    required this.onReject,
    required this.onDelete,
    this.rejectLabel = 'Rejeitar',
  });

  String _statusLabel() {
    switch (status) {
      case 'pending':
        return 'pendente';
      case 'approved':
        return 'aprovado';
      case 'rejected':
        return 'rejeitado';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final allDocs = snapshot.data?.docs ?? [];

        final docs = allDocs
            .where((d) => (d.data() as Map<String, dynamic>)['role'] != 'admin')
            .toList();

        if (docs.isEmpty) {
          return Center(
            child: Text('Nenhum usuário ${_statusLabel()}'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final nome = data['q_nome'] ?? data['name'] ?? 'Sem nome';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nome,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['email'] ?? '',
                      style: const TextStyle(color: Colors.grey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (onApprove != null)
                          FilledButton(
                            onPressed: () => onApprove!(doc.id),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: const Text('Aprovar'),
                          ),
                        if (onReject != null)
                          OutlinedButton(
                            onPressed: () => onReject!(doc.id),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                            ),
                            child: Text(rejectLabel),
                          ),
                        OutlinedButton(
                          onPressed: () => onDelete(doc.id, nome),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Remover'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}