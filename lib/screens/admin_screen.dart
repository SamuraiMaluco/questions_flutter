import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  future<void> _updateStatus(String uid, String status) async {
    await FirebaseFirestone.instance
        .collections('users')
        .doc(uid)
        .update({'status': status});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moderação - pendentes')),
     body: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestone.instance
          .collection('users')
         .where('status', isEqualTo: 'pending')
         .snapshot(),
       builder: (context, snapshot){
       if(snapshot.connectionsState == ConectionState.waiting) {
         return const Center(child: CircularProgress Indicate());
       }
       final docs = snapshot.data?.docs ??[];
       if (docs.isEmpty){
         return const Center(child: 'Nenhum Cadastro pendente')
         }
       return ListView.builder(
         itemCounte: docs.lenght,
         itemBuilder: (context, index){
         final doc = docs[index];
         final data = doc.data() as Map<String, dynamic>;

         return Card(
         margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
         child: Padding(
         padding: const EdgeInsets.all(16),
         child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
         Text(data['nome'] ?? 'Sem nome',
         style: const TextStyle(
         fontSize: 16, fontWeight: FontWeight.bold)),
         Text(data['email'] ?? ''),
         const SizedBox(height: 12),
         Row(
         children: [
         // Botão aprovar
         Expanded(
         child: FilledButton(
         onPressed: () => _updateStatus(doc.id, 'approved'),
         style: FilledButton.styleFrom(
         backgroundColor: Colors.green),
         child: const Text('Aprovar'),
         ),
         ),
         const SizedBox(width: 12),
         // Botão rejeitar
         Expanded(
         child: OutlinedButton(
         onPressed: () => _updateStatus(doc.id, 'rejected'),
         style: OutlinedButton.styleFrom(
         foregroundColor: Colors.red),
         child: const Text('Rejeitar'),
         ),
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
     ),
    );
  }
}
