class Question {
  final String id;
  final String text;
  final String type;// texto, email, telefone

Question({
  required this.id,
  required this.text,
  required this.type,
});


//converte o JSON no que a gente quer: um questionario
factory Question.fromJson(Map<String, dynamic> json) {
  return Question(
      id: json['id'],
      text: json['text'],
      type: json['type'],
    );
  }
}