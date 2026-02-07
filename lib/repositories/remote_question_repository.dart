import '../models/question.dart';
import 'question_repository.dart';

/// Placeholder for future remote API-backed question source.
class RemoteQuestionRepository implements QuestionRepository {
  @override
  Future<void> init() async {
    // TODO: Implement remote initialization.
  }

  @override
  Future<List<Question>> getSession({
    required String subject,
    required int count,
  }) async {
    throw UnimplementedError('RemoteQuestionRepository not implemented yet');
  }
}
