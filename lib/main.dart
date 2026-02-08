import 'package:flutter/material.dart';

import 'models/question.dart';
import 'models/subject.dart';
import 'data/subjects.dart';
import 'repositories/repository_factory.dart';
import 'repositories/question_repository.dart';
import 'services/progress_service.dart';
import 'services/tree_growth.dart';
import 'services/seen_store.dart';
import 'widgets/session_summary_card.dart';

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
    final colorScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF3CC77A));
    return MaterialApp(
      title: 'Loom v2',
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          bodyMedium: TextStyle(fontSize: 16),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
      ),
      home: _ready
          ? HomeScreen(repository: _repository, progressService: _progressService)
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository, required this.progressService});

  final QuestionRepository repository;
  final ProgressService progressService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _startSubject(BuildContext context, Subject subject) async {
    final questions = await widget.repository.getSession(subject: subject.key, count: 5);
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          questions: questions,
          progressService: widget.progressService,
          subjectTitle: subject.title,
          subject: subject,
          repository: widget.repository,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    widget.progressService.ensureDailyState();
    final snapshot = widget.progressService.snapshot;
    final stage = TreeGrowth.stageForLevel(snapshot.level);
    final primarySubject = subjects.first;
    final remainingRounds = snapshot.dailyAnswered >= snapshot.dailyTarget
        ? 0
        : ((snapshot.dailyTarget - snapshot.dailyAnswered) / 5).ceil();
    final todayLine = remainingRounds > 0
        ? '再完成 $remainingRounds 回合即可達標'
        : '今天已完成，想再玩一回合嗎？';

    return Scaffold(
      appBar: AppBar(title: const Text('Loom v2')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  _CardSection(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('今天該做什麼', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 6),
                        Text(todayLine),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _CardSection(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('等級 Lv.${snapshot.level}', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text('樹階段：${stage.name}'),
                        const SizedBox(height: 4),
                        Text('總 XP：${snapshot.totalXp}'),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final current = widget.progressService.currentLevelXp(snapshot.level);
                            final next = widget.progressService.nextLevelXp(snapshot.level);
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('科目', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...subjects.map((subject) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _SubjectButton(
                          title: subject.title,
                          onTap: () => _startSubject(context, subject),
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _startSubject(context, primarySubject),
              child: const Text('開始今日回合'),
            ),
          ],
        ),
      ),
    );
  }
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.questions,
    required this.progressService,
    required this.subjectTitle,
    required this.subject,
    required this.repository,
  });

  final List<Question> questions;
  final ProgressService progressService;
  final String subjectTitle;
  final Subject subject;
  final QuestionRepository repository;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _CardSection extends StatelessWidget {
  const _CardSection({required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SubjectButton extends StatelessWidget {
  const _SubjectButton({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

class _QuizScreenState extends State<QuizScreen> {
  int _index = 0;
  int? _selected;
  int _lastXp = 0;
  bool _dailyTargetJustCompleted = false;
  int _lastLevel = 1;
  int _correctStreak = 0;
  bool _streakJustHit = false;

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[_index];
    return Scaffold(
      appBar: AppBar(title: Text(widget.subjectTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('題目 ${_index + 1} / ${widget.questions.length}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: (_index + 1) / widget.questions.length,
            ),
            const SizedBox(height: 12),
            Text(
              question.prompt,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 6),
            Text('ID: ${question.id}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
            const SizedBox(height: 18),
            ...List.generate(question.options.length, (i) {
              final option = question.options[i];
              final selected = _selected == i;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AnswerOption(
                  label: option,
                  selected: selected,
                  enabled: _selected == null,
                  onTap: () => setState(() {
                    _selected = i;
                    _lastLevel = widget.progressService.snapshot.level;
                    final isCorrect = question.isCorrect(i);
                    final result = widget.progressService.recordAnswer(
                      isCorrect: isCorrect,
                      difficulty: question.difficulty,
                    );
                    _lastXp = result.gainedXp;
                    _dailyTargetJustCompleted = result.completedDailyTarget;
                    if (isCorrect) {
                      _correctStreak += 1;
                      _streakJustHit = _correctStreak == 3;
                    } else {
                      _correctStreak = 0;
                      _streakJustHit = false;
                    }
                  }),
                ),
              );
            }),
            const Spacer(),
            if (_selected != null) ...[
              Text('本題 XP：+$_lastXp', style: Theme.of(context).textTheme.bodyMedium),
              if (widget.progressService.snapshot.level > _lastLevel) ...[
                const SizedBox(height: 6),
                const Text('🌱 升級啦！', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
              if (_streakJustHit) ...[
                const SizedBox(height: 6),
                const Text('🔥 連勝 x3！', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
              if (_dailyTargetJustCompleted) ...[
                const SizedBox(height: 6),
                const Text('🎉 今日目標達成！', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
              const SizedBox(height: 8),
              Text(
                question.explanation,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _selected == null
                  ? null
                  : () {
                      if (_index + 1 >= widget.questions.length) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _SessionSummaryCard(
                              subject: widget.subject,
                              totalQuestions: widget.questions.length,
                              dailyAnswered: widget.progressService.snapshot.dailyAnswered,
                              dailyTarget: widget.progressService.snapshot.dailyTarget,
                              repository: widget.repository,
                              progressService: widget.progressService,
                            ),
                          ),
                        );
                      } else {
                        setState(() {
                          _index += 1;
                          _selected = null;
                          _lastXp = 0;
                          _dailyTargetJustCompleted = false;
                          _streakJustHit = false;
                        });
                      }
                    },
              child: Text(_index + 1 >= widget.questions.length ? '回到主選單' : '下一題'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerOption extends StatelessWidget {
  const _AnswerOption({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? Colors.green.withOpacity(0.1) : Colors.white,
        side: BorderSide(color: selected ? Colors.green : Colors.grey.shade300),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _SessionSummaryCard extends SessionSummaryCard {
  const _SessionSummaryCard({
    required super.subject,
    required super.totalQuestions,
    required super.dailyAnswered,
    required super.dailyTarget,
    required super.repository,
    required super.progressService,
  });
}
