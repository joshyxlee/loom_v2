import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/question.dart';
import '../services/seen_store.dart';
import 'question_repository.dart';

class MultiLocalQuestionRepository implements QuestionRepository {
  MultiLocalQuestionRepository({required this.assetPaths, required this.seenStore});

  final List<String> assetPaths;
  final SeenStore seenStore;
  final Map<String, List<Question>> _cache = {};
  final Set<String> _justDepletedSubjects = {};

  bool consumeDepletedNotice(String subject) {
    if (_justDepletedSubjects.contains(subject)) {
      _justDepletedSubjects.remove(subject);
      return true;
    }
    return false;
  }

  @override
  Future<void> init() async {
    if (kDebugMode) {
      debugPrint('QBank assets: ${assetPaths.join(', ')}');
    }
    for (final path in assetPaths) {
      final raw = await rootBundle.loadString(path);
      final data = json.decode(raw);
      if (data is! List) continue;
      final questions = data.map((e) => Question.fromJson(e as Map<String, dynamic>)).toList();
      for (final q in questions) {
        if (kDebugMode && q.id == 'fun_v3_0012') {
          final qPreview = q.prompt.length > 40 ? q.prompt.substring(0, 40) : q.prompt;
          final ePreview = q.explanation.length > 40
              ? q.explanation.substring(0, 40)
              : q.explanation;
          debugPrint('QBank fun_v3_0012 source=$path');
          debugPrint('QBank fun_v3_0012 question=$qPreview');
          debugPrint('QBank fun_v3_0012 explanation=$ePreview');
        }
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
    if (unseen.isEmpty) {
      _justDepletedSubjects.add(subject);
      await seenStore.reset(subject);
      unseen = pool;
    }

    final rng = Random(DateTime.now().millisecondsSinceEpoch);
    final targetCount = unseen.length < count ? unseen.length : count;
    final easy = unseen.where((q) => q.difficulty == 'easy').toList()..shuffle(rng);
    final medium = unseen.where((q) => q.difficulty == 'medium').toList()..shuffle(rng);
    final hard = unseen.where((q) => q.difficulty == 'hard').toList()..shuffle(rng);

    Question? takeOne(List<Question> source) {
      if (source.isEmpty) return null;
      return source.removeAt(0);
    }

    final session = <Question>[];
    while (session.length < targetCount) {
      Question? pick;
      if (session.isEmpty) {
        pick = takeOne(easy) ?? takeOne(medium) ?? takeOne(hard);
      } else if (session.length < 3) {
        pick = takeOne(medium) ?? takeOne(easy) ?? takeOne(hard);
      } else {
        pick = takeOne(hard) ?? takeOne(medium) ?? takeOne(easy);
      }
      if (pick == null) break;
      session.add(pick);
    }

    if (session.length < targetCount) {
      final fallback = List<Question>.from(unseen)..shuffle(rng);
      for (final q in fallback) {
        if (session.length >= targetCount) break;
        if (session.any((e) => e.id == q.id)) continue;
        session.add(q);
      }
    }

    final ordered = session.take(targetCount).map((q) => q.shuffled(rng)).toList();
    await seenStore.save(subject, ordered.map((q) => q.id));
    return ordered;
  }
}
