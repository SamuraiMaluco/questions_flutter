class AppVersion {
  // Muda esses valores a cada atualização
  static const String version = '1.0.0';
  static const String buildNumber = '1';

  // Histórico de mudanças — adiciona no topo sempre
  static const List<Map<String, String>> changelog = [
    {
      'version': '1.0.0',
      'date': '2026-04',
      'title': 'Lançamento inicial',
      'changes': '• Cadastro em formato de bot\n'
          '• Questionários em slides\n'
          '• Painel de moderação do admin\n'
          '• Correção automática com gabarito\n'
          '• Relatório de desempenho',
    },
  ];
}