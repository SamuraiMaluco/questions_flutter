import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class PendingScreen extends StatelessWidget {
  final bool isRejected;
  const PendingScreen({super.key, this.isRejected = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isRejected ? Icons.cancel_outlined : Icons.hourglass_top,
                size: 72,
                color: isRejected ? Colors.red : Colors.orange,
              ),
              const SizedBox(height: 24),
              Text(
                isRejected ? 'Acesso negado' : 'Aguardando aprovação',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isRejected
                    ? 'Seu cadastro não foi aprovado. Entre em contato com o administrador.'
                    : 'Seu cadastro está sendo analisado. Você será notificado quando o administrador aprovar sua conta.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 15),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () async {
                  await AuthService().logout();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sair'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}