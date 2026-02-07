import 'package:flutter/material.dart';

import 'models/question.dart';
import 'repositories/repository_factory.dart';
import 'repositories/question_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LoomV2App());
}

class LoomV2App extends StatefulWidget {
  const LoomV2App({super.key});

  @override
  State<LoomV2App> createState() => _LoomV2AppState();
}

class _LoomV2AppState extends State<LoomV2App> {
  late final QuestionRepository _repository;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _repository = RepositoryFactory(source: RepositorySource.local).create();
    await _repository.init();
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Loom v2',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: _ready
          ? HomeScreen(repository: _repository)
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.repository});

  final QuestionRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loom v2')),
      body: Center(
        child: FilledButton(
          onPressed: () async {
            final questions = await repository.getSession(subject: 'funFacts', count: 5);
            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QuizScreen(questions: questions),
              ),
            );
          },
          child: const Text('開始答題'),
        ),
      ),
    );
  }
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.questions});

  final List<Question> questions;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _index = 0;
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[_index];
    return Scaffold(
      appBar: AppBar(title: const Text('冷知識')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('題目 ${_index + 1} / ${widget.questions.length}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(question.prompt, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text('ID: ${question.id}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
            const SizedBox(height: 18),
            ...List.generate(question.options.length, (i) {
              final option = question.options[i];
              final selected = _selected == i;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton(
                  onPressed: _selected == null
                      ? () => setState(() {
                            _selected = i;
                          })
                      : null,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      option,
                      style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal),
                    ),
                  ),
                ),
              );
            }),
            const Spacer(),
            if (_selected != null) ...[
              Text(
                question.explanation,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  if (_index + 1 >= widget.questions.length) {
                    Navigator.pop(context);
                  } else {
                    setState(() {
                      _index += 1;
                      _selected = null;
                    });
                  }
                },
                child: Text(_index + 1 >= widget.questions.length ? '回到主選單' : '下一題'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
