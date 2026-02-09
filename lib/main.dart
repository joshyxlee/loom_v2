import 'dart:math';

import 'package:flutter/material.dart';

import 'models/question.dart';
import 'models/subject.dart';
import 'data/subjects.dart';
import 'repositories/repository_factory.dart';
import 'repositories/question_repository.dart';
import 'services/progress_service.dart';
import 'services/tree_growth.dart';
import 'services/seen_store.dart';
import 'services/core_data_store.dart';
import 'widgets/session_summary_card.dart';
import 'widgets/onboarding.dart';

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
  final CoreDataStore _coreDataStore = CoreDataStore();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _seenStore.init();
    await _coreDataStore.init(defaultSubjects: defaultSubjects);
    setSubjects(_coreDataStore.subjects);
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
          ? OnboardingGate(
              repository: _repository,
              progressService: _progressService,
              coreDataStore: _coreDataStore,
            )
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}

class OnboardingGate extends StatefulWidget {
  const OnboardingGate({
    super.key,
    required this.repository,
    required this.progressService,
    required this.coreDataStore,
  });

  final QuestionRepository repository;
  final ProgressService progressService;
  final CoreDataStore coreDataStore;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  bool _showOnboarding = true;

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding) {
      return OnboardingFlow(
        onFinish: () => setState(() => _showOnboarding = false),
      );
    }
    return HomeScreen(
      repository: widget.repository,
      progressService: widget.progressService,
      coreDataStore: widget.coreDataStore,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.progressService,
    required this.coreDataStore,
  });

  final QuestionRepository repository;
  final ProgressService progressService;
  final CoreDataStore coreDataStore;

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
          coreDataStore: widget.coreDataStore,
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
    final isDone = remainingRounds == 0;
    final ctaLabel = isDone ? '再玩一回合' : '開始今日回合';
    final current = widget.progressService.currentLevelXp(snapshot.level);
    final next = widget.progressService.nextLevelXp(snapshot.level);
    final progress = ((snapshot.totalXp - current) / (next - current)).clamp(0.0, 1.0);
    final nextStageHint = progress < 0.35
        ? '再答幾題，樹就會有變化'
        : progress < 0.7
            ? '再走一段，就接近下一階段'
            : '快到了，下一階段就在眼前';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.park, size: 120, color: Color(0xFF3CC77A)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(stage.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(nextStageHint, style: const TextStyle(fontSize: 15, color: Colors.black54)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 220,
                      child: LinearProgressIndicator(value: progress),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: () => _startSubject(context, primarySubject),
                      child: Text(ctaLabel, style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _CardSection(
                    color: const Color(0xFFF1F2F4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('累計 XP：${snapshot.totalXp}',
                            style: const TextStyle(fontSize: 14, color: Colors.black54)),
                        const SizedBox(height: 4),
                        Text('每日目標：${snapshot.dailyAnswered}/${snapshot.dailyTarget}',
                            style: const TextStyle(fontSize: 14, color: Colors.black54)),
                        const SizedBox(height: 4),
                        Text('連續天數：${snapshot.streakDays} 倍率 x${snapshot.dailyBonusMultiplier.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 14, color: Colors.black54)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    children: subjects.map((subject) {
                      return TextButton(
                        onPressed: () => _startSubject(context, subject),
                        child: Text(subject.title,
                            style: const TextStyle(fontSize: 14, color: Colors.black54)),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ],
          ),
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
    required this.coreDataStore,
    required this.subjectTitle,
    required this.subject,
    required this.repository,
  });

  final List<Question> questions;
  final ProgressService progressService;
  final CoreDataStore coreDataStore;
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
  bool _levelUpPulse = false;
  double _levelProgress = 0.0;
  int _progressAnimMs = 350;
  bool _showMoment = false;
  bool _showXpBurst = false;
  bool _levelUpMoment = false;
  String _momentText = '';
  double _momentOpacity = 0.0;
  Offset _momentOffset = const Offset(0, 0.1);

  static const _correctMomentTexts = [
    '變強了。',
    '又更近一步。',
    '這題有算進去。',
  ];

  static const _wrongMomentTexts = [
    '還在累積中。',
    '沒關係，繼續。',
  ];

  @override
  void initState() {
    super.initState();
    _levelProgress = _currentLevelProgress();
  }

  double _currentLevelProgress() {
    final snapshot = widget.progressService.snapshot;
    final current = widget.progressService.currentLevelXp(snapshot.level);
    final next = widget.progressService.nextLevelXp(snapshot.level);
    return ((snapshot.totalXp - current) / (next - current)).clamp(0.0, 1.0);
  }

  void _triggerMoment({required bool isCorrect, required bool leveledUp}) {
    final rng = Random(DateTime.now().millisecondsSinceEpoch);
    _momentText = isCorrect
        ? _correctMomentTexts[rng.nextInt(_correctMomentTexts.length)]
        : _wrongMomentTexts[rng.nextInt(_wrongMomentTexts.length)];
    _showMoment = true;
    _showXpBurst = isCorrect;
    _levelUpMoment = leveledUp;
    _momentOpacity = 1.0;
    _momentOffset = const Offset(0, -0.12);
    setState(() {});
    Future.delayed(const Duration(milliseconds: 750), () {
      if (!mounted) return;
      setState(() {
        _momentOpacity = 0.0;
      });
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _showMoment = false;
        _showXpBurst = false;
        _levelUpMoment = false;
        _momentOffset = const Offset(0, 0.1);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[_index];
    return Scaffold(
      appBar: AppBar(title: Text(widget.subjectTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('題目 ${_index + 1} / ${widget.questions.length}',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: (_index + 1) / widget.questions.length,
                ),
                const SizedBox(height: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: _levelProgress),
                  duration: Duration(milliseconds: _progressAnimMs),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return LinearProgressIndicator(
                      value: value,
                      minHeight: 6,
                      color: const Color(0xFF3CC77A),
                      backgroundColor: Colors.green.withOpacity(0.12),
                    );
                  },
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
                          difficulty: question.difficultyValue,
                        );
                        widget.coreDataStore.recordAnswer(
                          subjectId: question.subject,
                          isCorrect: isCorrect,
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
                        final leveledUp = widget.progressService.snapshot.level > _lastLevel;
                        if (leveledUp) {
                          _levelUpPulse = true;
                          _progressAnimMs = 300;
                          _levelProgress = 1.0;
                          Future.delayed(const Duration(milliseconds: 350), () {
                            if (!mounted) return;
                            setState(() {
                              _levelProgress = _currentLevelProgress();
                              _progressAnimMs = 350;
                            });
                          });
                          Future.delayed(const Duration(milliseconds: 450), () {
                            if (!mounted) return;
                            setState(() => _levelUpPulse = false);
                          });
                        } else {
                          _progressAnimMs = 350;
                          _levelProgress = _currentLevelProgress();
                        }
                        _triggerMoment(isCorrect: isCorrect, leveledUp: leveledUp);
                      }),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                if (_selected != null)
                  _FeedbackCard(
                    xp: _lastXp,
                    explanation: question.explanation,
                    isCorrect: question.isCorrect(_selected!),
                    levelUp: widget.progressService.snapshot.level > _lastLevel,
                    streakHit: _streakJustHit,
                    dailyHit: _dailyTargetJustCompleted,
                    isLast: _index + 1 >= widget.questions.length,
                    levelUpPulse: _levelUpPulse,
                    onNext: () {
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
                              coreDataStore: widget.coreDataStore,
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
                          _levelUpPulse = false;
                        });
                      }
                    },
                  ),
              ],
            ),
            if (_showMoment)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _momentOpacity,
                    duration: const Duration(milliseconds: 200),
                    child: AnimatedSlide(
                      offset: _momentOffset,
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOut,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_levelUpMoment)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 6),
                                child: Text('升級了。',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ),
                            if (_showXpBurst)
                              Text('+$_lastXp XP',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF3CC77A),
                                  )),
                            const SizedBox(height: 6),
                            Text(_momentText,
                                style: const TextStyle(fontSize: 16, color: Colors.black54)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
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
    required super.coreDataStore,
  });
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.xp,
    required this.explanation,
    required this.isCorrect,
    required this.levelUp,
    required this.streakHit,
    required this.dailyHit,
    required this.isLast,
    required this.onNext,
    required this.levelUpPulse,
  });

  final int xp;
  final String explanation;
  final bool isCorrect;
  final bool levelUp;
  final bool streakHit;
  final bool dailyHit;
  final bool isLast;
  final VoidCallback onNext;
  final bool levelUpPulse;

  @override
  Widget build(BuildContext context) {
    final titleText = isCorrect ? '答對了！太強啦！' : '差一點！這題真的容易錯';
    final titleColor = isCorrect ? const Color(0xFF2E7D32) : const Color(0xFF8D6E63);
    final titleBg = isCorrect ? const Color(0xFFE7F8EE) : const Color(0xFFF6F1E9);

    return AnimatedScale(
      scale: levelUpPulse ? 1.04 : 1.0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: titleBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                titleText,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text('本題 +$xp XP', style: Theme.of(context).textTheme.bodyMedium),
            if (levelUp) ...[
              const SizedBox(height: 6),
              const Text('🌱 升級完成', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
            if (streakHit) ...[
              const SizedBox(height: 6),
              const Text('🔥 連勝 x3', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
            if (dailyHit) ...[
              const SizedBox(height: 6),
              const Text('🎉 今日達標', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
            const SizedBox(height: 8),
            Text(explanation, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onNext,
              child: Text(isLast ? '回到主選單' : '下一題'),
            ),
          ],
        ),
      ),
    );
  }
}
