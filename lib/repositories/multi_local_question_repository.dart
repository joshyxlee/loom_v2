import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;

import '../models/question.dart';
import '../services/seen_store.dart';
import 'question_repository.dart';

class MultiLocalQuestionRepository implements QuestionRepository {
  MultiLocalQuestionRepository({required this.assetPaths, required this.seenStore});

  final List<String> assetPaths;
  final SeenStore seenStore;
  final Map<String, List<Question>> _cache = {};

  @override
  Future<void> init() async {
    for (final path in assetPaths) {
      final raw = await rootBundle.loadString(path);
      final data = json.decode(raw);
      if (data is! List) continue;
      final questions = data.map((e) => Question.fromJson(e as Map<String, dynamic>)).toList();
      for (final q in questions) {
        _cache.putIfAbsent(q.subject, () => []).add(q);
      }
    }
  }

  @override
  Future<List<Question>> getSession({required String subject, required int count}) async {
    final pool = _cache[subject] ?? const [];
    if (pool.isEmpty) return const [];

    final seen = seenStore.load(subject);
    var unseen = pool.where((q) => q.id.isNotEmpty && !seen.contains(q.id)).toList();
    if (unseen.length < count) {
      await seenStore.reset(subject);
      unseen = pool;
    }

    final rng = Random(DateTime.now().millisecondsSinceEpoch);
    unseen.shuffle(rng);
    final session = unseen.take(count).toList();
    await seenStore.save(subject, session.map((q) => q.id));
    return session;
  }
}
