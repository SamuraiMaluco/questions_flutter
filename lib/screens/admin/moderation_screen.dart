import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ModerationScreen extends StatelessWidget {
  const ModerationScreen({super.key});

  Future<void> _updateStatus(String uid, String status) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'status': status});
  }

  Future<void> _deleteUser(BuildContext context, String uid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir usuário'),
        content: const Text(
            'Tem certeza que deseja excluir este usuário permanentemente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .delete();
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
              onApprove: (uid) => _updateStatus(uid, 'approved'),
              onReject: (uid) => _updateStatus(uid, 'rejected'),
              onDelete: (uid) => _deleteUser(context, uid),
            ),
            _UserList(
              status: 'approved',
              onApprove: null,
              onReject: (uid) => _updateStatus(uid, 'rejected'),
              onDelete: (uid) => _deleteUser(context, uid),
            ),
            _UserList(
              status: 'rejected',
              onApprove: (uid) => _updateStatus(uid, 'approved'),
              onReject: null,
              onDelete: (uid) => _deleteUser(context, uid),
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
  final void Function(String uid) onDelete;

  const _UserList({
    required this.status,
    required this.onApprove,
    required this.onReject,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('status', isEqualTo: status)
          .where('role', isEqualTo: 'user')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Text('Nenhum usuário $status'),
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
                    Text(data['email'] ?? ''),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (onApprove != null)
                          Expanded(
                            child: FilledButton(
                              onPressed: () => onApprove!(doc.id),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              child: const Text('Aprovar'),
                            ),
                          ),
                        if (onApprove != null) const SizedBox(width: 8),
                        if (onReject != null)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => onReject!(doc.id),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange,
                              ),
                              child: const Text('Rejeitar'),
                            ),
                          ),
                        if (onReject != null) const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () => onDelete(doc.id),
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