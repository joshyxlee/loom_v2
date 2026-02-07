class Question {
  const Question({
    required this.id,
    required this.subject,
    required this.prompt,
    required this.options,
    required this.answerIndex,
    required this.explanation,
    required this.difficulty,
  });

  final String id;
  final String subject;
  final String prompt;
  final List<String> options;
  final int answerIndex;
  final String explanation;
  final int difficulty; // 1-5

  bool isCorrect(int index) => index == answerIndex;

  factory Question.fromJson(Map<String, dynamic> json) {
    final options = (json['options'] as List?)?.map((e) => e.toString()).toList() ?? const [];
    return Question(
      id: json['id']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      prompt: json['prompt']?.toString() ?? '',
      options: options,
      answerIndex: json['answerIndex'] is int
          ? json['answerIndex'] as int
          : int.tryParse('${json['answerIndex']}') ?? 0,
      explanation: json['explanation']?.toString() ?? '',
      difficulty: json['difficulty'] is int
          ? json['difficulty'] as int
          : int.tryParse('${json['difficulty']}') ?? 1,
    );
  }
}
