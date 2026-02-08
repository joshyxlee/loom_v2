import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;

import '../models/question.dart';
import 'question_repository.dart';

class LocalQuestionRepository implements QuestionRepository {
  LocalQuestionRepository({required this.assetPath});

  final String assetPath;
  List<Question> _cache = const [];

  @override
  Future<void> init() async {
    final raw = await rootBundle.loadString(assetPath);
    final data = json.decode(raw);
    if (data is! List) {
      throw FormatException('Question pack must be a JSON array');
    }
    _cache = data.map((e) => Question.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Question>> getSession({
    required String subject,
    required int count,
  }) async {
    final pool = _cache.where((q) => q.subject == subject).toList();
    pool.shuffle();
    return pool.take(count).map((q) => q.shuffled(Random())).toList();
  }
}
