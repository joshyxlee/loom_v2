import 'package:flutter/material.dart';

import 'models/question.dart';
import 'repositories/repository_factory.dart';
import 'repositories/question_repository.dart';
import 'services/progress_service.dart';
import 'services/tree_growth.dart';
import 'services/seen_store.dart';

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
  final ProgressService _progressService = ProgressService();
  final SeenStore _seenStore = SeenStore();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _seenStore.init();
    _repository = RepositoryFactory(
      source: RepositorySource.local,
      seenStore: _seenStore,
    ).create();
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
          ? HomeScreen(repository: _repository, progressService: _progressService)
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.repository, required this.progressService});

  final QuestionRepository repository;
  final ProgressService progressService;

  @override
  Widget build(BuildContext context) {
    progressService.ensureDailyState();
    final snapshot = progressService.snapshot;
    final stage = TreeGrowth.stageForLevel(snapshot.level);
    return Scaffold(
      appBar: AppBar(title: const Text('Loom v2')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('等級 Lv.${snapshot.level}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('樹階段：${stage.name}'),
            const SizedBox(height: 4),
            Text('總 XP：${snapshot.totalXp}'),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final current = progressService.currentLevelXp(snapshot.level);
                final next = progressService.nextLevelXp(snapshot.level);
                final progress = (snapshot.totalXp - current) / (next - current);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('升級進度：${snapshot.totalXp - current} / ${next - current}'),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Text('每日目標：${snapshot.dailyAnswered}/${snapshot.dailyTarget}'),
            const SizedBox(height: 4),
            Text('連續天數：${snapshot.streakDays} 倍率 x${snapshot.dailyBonusMultiplier.toStringAsFixed(2)}'),
            const Spacer(),
            if (snapshot.dailyAnswered >= snapshot.dailyTarget) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('今日目標已完成！額外加成已生效'),
              ),
              const SizedBox(height: 12),
            ],
            Center(
              child: FilledButton(
                onPressed: () async {
                  final questions = await repository.getSession(subject: 'funFacts', count: 5);
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuizScreen(
                        questions: questions,
                        progressService: progressService,
                      ),
                    ),
                  );
                },
                child: const Text('開始答題'),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.questions, required this.progressService});

  final List<Question> questions;
  final ProgressService progressService;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _index = 0;
  int? _selected;
  int _lastXp = 0;
  bool _dailyTargetJustCompleted = false;

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
                            final result = widget.progressService.recordAnswer(
                              isCorrect: question.isCorrect(i),
                              difficulty: question.difficulty,
                            );
                            _lastXp = result.gainedXp;
                            _dailyTargetJustCompleted = result.completedDailyTarget;
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
              Text('本題 XP：+$_lastXp', style: Theme.of(context).textTheme.bodyMedium),
              if (_dailyTargetJustCompleted) ...[
                const SizedBox(height: 6),
                const Text('🎉 今日目標達成！', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
              const SizedBox(height: 8),
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
                      _lastXp = 0;
                      _dailyTargetJustCompleted = false;
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
