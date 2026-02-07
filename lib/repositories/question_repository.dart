import '../models/question.dart';

abstract class QuestionRepository {
  Future<void> init();

  /// Returns a session of questions for a subject.
  Future<List<Question>> getSession({
    required String subject,
    required int count,
  });
}
