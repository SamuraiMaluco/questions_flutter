class Question {
  final String id;
  final String text;
  final String type;
  final int order;
  final List<String> options;
  final String correctAnswer;

  Question({
    required this.id,
    required this.text,
    required this.type,
    required this.order,
    this.options = const [],
    this.correctAnswer = '',
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      type: json['type'] ?? 'text',
      order: json['order'] ?? 0,
      options: List<String>.from(json['options'] ?? []),
      correctAnswer: json['correctAnswer'] ?? '',
    );
  }

  factory Question.fromFirestore(String id, Map<String, dynamic> data) {
    return Question(
      id: id,
      text: data['text'] ?? '',
      type: data['type'] ?? 'text',
      order: data['order'] ?? 0,
      options: List<String>.from(data['options'] ?? []),
      correctAnswer: data['correctAnswer'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'text': text,
    'type': type,
    'order': order,
    'options': options,
    'correctAnswer': correctAnswer,
  };
}