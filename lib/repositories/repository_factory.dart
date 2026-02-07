import 'local_question_repository.dart';
import 'question_repository.dart';
import 'remote_question_repository.dart';

enum RepositorySource { local, remote }

class RepositoryFactory {
  RepositoryFactory({required this.source});

  final RepositorySource source;

  QuestionRepository create() {
    switch (source) {
      case RepositorySource.remote:
        return RemoteQuestionRepository();
      case RepositorySource.local:
      default:
        return LocalQuestionRepository(assetPath: 'assets/questions/fun_facts.json');
    }
  }
}
