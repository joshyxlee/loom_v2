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
    final easy = unseen.where((q) => q.difficulty == 'easy').toList()..shuffle(rng);
    final medium = unseen.where((q) => q.difficulty == 'medium').toList()..shuffle(rng);
    final hard = unseen.where((q) => q.difficulty == 'hard').toList()..shuffle(rng);

    Question? takeOne(List<Question> source) {
      if (source.isEmpty) return null;
      return source.removeAt(0);
    }

    final session = <Question>[];
    final first = takeOne(easy) ?? takeOne(medium) ?? takeOne(hard);
    if (first != null) session.add(first);

    for (var i = 0; i < 2; i++) {
      final pick = takeOne(medium) ?? takeOne(easy) ?? takeOne(hard);
      if (pick != null) session.add(pick);
    }

    for (var i = 0; i < 2; i++) {
      final pick = takeOne(hard) ?? takeOne(medium) ?? takeOne(easy);
      if (pick != null) session.add(pick);
    }

    if (session.length < count) {
      final fallback = List<Question>.from(unseen)..shuffle(rng);
      for (final q in fallback) {
        if (session.length >= count) break;
        if (session.any((e) => e.id == q.id)) continue;
        session.add(q);
      }
    }

    final ordered = session.take(count).map((q) => q.shuffled(rng)).toList();
    await seenStore.save(subject, ordered.map((q) => q.id));
    return ordered;
  }
}
