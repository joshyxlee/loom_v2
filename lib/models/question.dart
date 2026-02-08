import 'dart:math';

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
  final String difficulty; // easy | medium | hard

  bool isCorrect(int index) => index == answerIndex;

  int get difficultyValue {
    switch (difficulty) {
      case 'hard':
        return 5;
      case 'medium':
        return 3;
      case 'easy':
      default:
        return 1;
    }
  }

  Question shuffled(Random rng) {
    if (options.length <= 1) return this;
    final indices = List<int>.generate(options.length, (i) => i)..shuffle(rng);
    final shuffledOptions = indices.map((i) => options[i]).toList();
    final newAnswerIndex = indices.indexOf(answerIndex);
    return Question(
      id: id,
      subject: subject,
      prompt: prompt,
      options: shuffledOptions,
      answerIndex: newAnswerIndex < 0 ? 0 : newAnswerIndex,
      explanation: explanation,
      difficulty: difficulty,
    );
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    final options = (json['options'] as List?)?.map((e) => e.toString()).toList() ?? const [];
    final rawDifficulty = json['difficulty'];
    String difficulty;
    if (rawDifficulty is String) {
      final value = rawDifficulty.toLowerCase();
      difficulty = (value == 'easy' || value == 'medium' || value == 'hard') ? value : 'easy';
    } else if (rawDifficulty is int) {
      if (rawDifficulty >= 3) {
        difficulty = 'hard';
      } else if (rawDifficulty == 2) {
        difficulty = 'medium';
      } else {
        difficulty = 'easy';
      }
    } else {
      difficulty = 'easy';
    }

    return Question(
      id: json['id']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      prompt: json['prompt']?.toString() ?? '',
      options: options,
      answerIndex: json['answerIndex'] is int
          ? json['answerIndex'] as int
          : int.tryParse('${json['answerIndex']}') ?? 0,
      explanation: json['explanation']?.toString() ?? '',
      difficulty: difficulty,
    );
  }
}
