import 'local_question_repository.dart';
import 'multi_local_question_repository.dart';
import 'question_repository.dart';
import 'remote_question_repository.dart';
import '../services/seen_store.dart';

enum RepositorySource { local, remote }

class RepositoryFactory {
  RepositoryFactory({required this.source, required this.seenStore});

  final RepositorySource source;
  final SeenStore seenStore;

  QuestionRepository create() {
    switch (source) {
      case RepositorySource.remote:
        return RemoteQuestionRepository();
      case RepositorySource.local:
      default:
        return MultiLocalQuestionRepository(
          assetPaths: const [
            'assets/questions/fun_facts.json',
            'assets/questions/world.json',
            'assets/questions/history.json',
            'assets/questions/science.json',
            'assets/questions/money.json',
          ],
          seenStore: seenStore,
        );
    }
  }
}
