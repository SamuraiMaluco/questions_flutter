class Questionnaire {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Questionnaire({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    this.updatedAt,
  });

  factory Questionnaire.fromFirestore(String id, Map<String, dynamic> data) {
    return Questionnaire(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as dynamic).toDate()
          : null,
    );
  }
}