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
import 'widgets/pokedex_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const _onboardingKey = 'onboarding_done';
  bool _showOnboarding = true;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _loadOnboardingFlag();
  }

  Future<void> _loadOnboardingFlag() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(_onboardingKey) ?? false;
    if (!mounted) return;
    setState(() {
      _showOnboarding = !done;
      _ready = true;
    });
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    if (!mounted) return;
    setState(() => _showOnboarding = false);
  }

  Future<void> _startFirstRound(BuildContext context) async {
    await _completeOnboarding();
    final subject = subjects.first;
    final questions = await widget.repository.getSession(subject: subject.key, count: 5);
    if (!mounted) return;
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
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_showOnboarding) {
      return OnboardingFlow(
        onStart: () => _startFirstRound(context),
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

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  bool _showPetDetails = false;
  bool _showDailyNarrative = false;
  String _dailyNarrative = '';
  late final AnimationController _petBreathController;
  late final Animation<double> _petBreathScale;

  @override
  void initState() {
    super.initState();
    _petBreathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _petBreathScale = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _petBreathController, curve: Curves.easeInOut),
    );
    _loadDailyNarrative();
  }

  Future<void> _loadDailyNarrative() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
    final lastShown = prefs.getString('daily_narrative_date');
    if (lastShown == todayKey) return;
    final options = [
      '今天的判斷更準了。',
      '今天比較不會被迷思帶走。',
      '今天反應比昨天更快。',
    ];
    final rng = Random(DateTime.now().millisecondsSinceEpoch);
    setState(() {
      _dailyNarrative = options[rng.nextInt(options.length)];
      _showDailyNarrative = true;
    });
    await prefs.setString('daily_narrative_date', todayKey);
  }

  @override
  void dispose() {
    _petBreathController.dispose();
    super.dispose();
  }

  String _resolvePetTypeLabel() {
    final credits = widget.coreDataStore.creditsBySubject;
    final total = credits.values.fold<int>(0, (sum, v) => sum + v);
    if (total < 200) return 'Balanced';
    if (credits.isEmpty) return 'Balanced';
    final entries = credits.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.first;
    final ratio = total == 0 ? 0.0 : top.value / total;
    if (ratio < 0.4) return 'Balanced';
    final matches = widget.coreDataStore.subjects.where((s) => s.subjectId == top.key).toList();
    return matches.isNotEmpty ? matches.first.displayName : 'Unknown';
  }

  int _nextStageLevel(int stage) {
    switch (stage) {
      case 0:
        return 5;
      case 1:
        return 10;
      case 2:
        return 20;
      case 3:
        return 40;
      default:
        return 40;
    }
  }

  int _nextStageNumber(int stage) {
    switch (stage) {
      case 0:
        return 1;
      case 1:
        return 2;
      case 2:
        return 3;
      case 3:
        return 4;
      default:
        return 4;
    }
  }

  int _levelsToNextStage(int stage, int level) {
    final target = _nextStageLevel(stage);
    final diff = target - level;
    return diff > 0 ? diff : 0;
  }

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

  Future<void> _resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await widget.coreDataStore.init(defaultSubjects: defaultSubjects);
    widget.progressService.resetAll();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => OnboardingGate(
          repository: widget.repository,
          progressService: widget.progressService,
          coreDataStore: widget.coreDataStore,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    widget.progressService.ensureDailyState();
    final snapshot = widget.progressService.snapshot;
    final primarySubject = subjects.first;
    final petStage = widget.coreDataStore.activePet.currentStage;
    final bond = widget.coreDataStore.activePet.currentBond;
    final playerLevel = widget.coreDataStore.player.playerLevel;
    final petTypeLabel = _resolvePetTypeLabel();
    final remainingRounds = snapshot.dailyAnswered >= snapshot.dailyTarget
        ? 0
        : ((snapshot.dailyTarget - snapshot.dailyAnswered) / 5).ceil();
    final isDone = remainingRounds == 0;
    final ctaLabel = isDone ? '再玩一回合' : '開始今日回合';
    final nextStageLevel = _nextStageLevel(petStage);
    final progress = petStage >= 4
        ? 1.0
        : ((playerLevel - (petStage == 0 ? 1 : _nextStageLevel(petStage - 1))) /
                (nextStageLevel - (petStage == 0 ? 1 : _nextStageLevel(petStage - 1))))
            .clamp(0.0, 1.0);
    final dailyTargetForFlame = 5;
    final remainingForFlame =
        (dailyTargetForFlame - snapshot.dailyAnswered).clamp(0, dailyTargetForFlame);
    final flameLit = snapshot.dailyAnswered >= dailyTargetForFlame;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(() => _showPetDetails = !_showPetDetails),
                            icon: const Icon(Icons.info_outline, size: 18, color: Colors.black54),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: _resetAll,
                            icon: const Icon(Icons.settings, size: 18, color: Colors.black54),
                          ),
                        ],
                      ),
                      ScaleTransition(
                        scale: _petBreathScale,
                        child: Container(
                          width: 200,
                          height: 200,
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
                            child: Icon(Icons.pets, size: 120, color: Color(0xFF3CC77A)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('你的學習夥伴正在成長中',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        petStage >= 4 ? '再多玩幾題，羈絆就會更深' : '再玩一點就會有新變化',
                        style: const TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                      if (_showPetDetails) ...[
                        const SizedBox(height: 8),
                        Text('Lv $playerLevel · XP ${snapshot.totalXp}',
                            style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        Text('Bond $bond/10 · Stage $petStage · $petTypeLabel',
                            style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        Text('每日目標：${snapshot.dailyAnswered}/${snapshot.dailyTarget}',
                            style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ],
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_showDailyNarrative) ...[
                    _CardSection(
                      color: const Color(0xFFF1F2F4),
                      child: Text(
                        _dailyNarrative,
                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: () => _startSubject(context, primarySubject),
                      child: Text(ctaLabel, style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _CardSection(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('再玩一點就會有變化',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(
                          petStage >= 4
                              ? '接下來的進展會體現在你們的羈絆上'
                              : '下一次成長就在前面',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: LinearProgressIndicator(value: progress),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _CardSection(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('今天再 $remainingForFlame 題，就能點亮今天的火焰 🔥',
                            style: const TextStyle(color: Colors.black54)),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(7, (index) {
                            final isFilled = index == 0 ? flameLit : false;
                            return Text(isFilled ? '🔥' : '▢',
                                style: const TextStyle(fontSize: 16));
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _CardSection(
                    child: Row(
                      children: [
                        const Text('圖鑑',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        const SizedBox(width: 8),
                        if (playerLevel >= 40)
                          Text('${widget.coreDataStore.pokedexEntries.length} collected',
                              style: const TextStyle(color: Colors.black45, fontSize: 12))
                        else
                          const Text('Lv40 後開放',
                              style: TextStyle(color: Colors.black45, fontSize: 12)),
                        const Spacer(),
                        TextButton(
                          onPressed: playerLevel >= 40
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          PokedexScreen(coreDataStore: widget.coreDataStore),
                                    ),
                                  );
                                }
                              : null,
                          child: const Text('查看', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('選擇養成方向',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 6),
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
                  const SizedBox(height: 4),
                  const Text('專攻一科，夥伴的樣子會跟著改變',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.black45)),
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
  bool _levelUpMoment = false;
  bool _isJudging = false;
  bool _showFeedback = false;
  String _resultLine = '';
  double _petBounceScale = 1.0;
  bool _showResultDialog = false;
  bool _lastIsCorrect = false;

  // moment texts removed

  static const _correctResultTexts = [
    '答對了！',
    '這題你抓到了',
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

  void _triggerMoment({required bool isCorrect, required bool leveledUp}) {}

  String _pickResultLine(bool isCorrect) {
    if (!isCorrect) return '沒事，這題很多人會錯';
    final rng = Random(DateTime.now().millisecondsSinceEpoch);
    return _correctResultTexts[rng.nextInt(_correctResultTexts.length)];
  }

  Future<void> _handleCoreGrowth({required String subjectId, required bool isCorrect}) async {
    final previousStage = widget.coreDataStore.activePet.currentStage;
    final previousLevel = widget.coreDataStore.player.playerLevel;
    await widget.coreDataStore.recordAnswer(subjectId: subjectId, isCorrect: isCorrect);
    if (!mounted) return;
    final newStage = widget.coreDataStore.activePet.currentStage;
    final newLevel = widget.coreDataStore.player.playerLevel;
    if (newStage > previousStage) {
      final extra = newStage == 4 && previousLevel < 40 && newLevel >= 40
          ? '\n你的夥伴已完全成長，但你們的關係，才正要開始。'
          : '';
      final content = '進化！你的夥伴進入 Stage $newStage\n圖鑑已新增一筆收藏$extra';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(content)),
      );
    }
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
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Row(
                  children: [
                    AnimatedScale(
                      scale: _petBounceScale,
                      duration: const Duration(milliseconds: 140),
                      child: const Icon(Icons.pets, size: 18, color: Color(0xFF3CC77A)),
                    ),
                    const SizedBox(width: 6),
                    Text('題目 ${_index + 1} / ${widget.questions.length}',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: (_index + 1) / widget.questions.length,
                ),
                // quick hint removed
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
                      isLocked: _selected != null,
                      isCorrectOption: question.isCorrect(i),
                      onTap: () {
                        final isCorrect = question.isCorrect(i);
                        setState(() {
                          _selected = i;
                          _lastLevel = widget.progressService.snapshot.level;
                          final result = widget.progressService.recordAnswer(
                            isCorrect: isCorrect,
                            difficulty: question.difficultyValue,
                          );
                          _lastXp = result.gainedXp;
                          _dailyTargetJustCompleted = result.completedDailyTarget;
                          _isJudging = true;
                          _showFeedback = false;
                          _resultLine = _pickResultLine(isCorrect);
                          _lastIsCorrect = isCorrect;
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
                          // moment removed
                        });

                        setState(() {
                          _showResultDialog = true;
                          _lastIsCorrect = isCorrect;
                        });

                        Future.delayed(const Duration(milliseconds: 800), () {
                          if (!mounted) return;
                          setState(() {
                            _showResultDialog = false;
                            _isJudging = false;
                            _showFeedback = true;
                          });
                        });

                        _handleCoreGrowth(
                          subjectId: question.subject,
                          isCorrect: question.isCorrect(i),
                        );
                      },
                    ),
                  );
                }),
                const SizedBox(height: 8),
                if (_selected != null && _showFeedback)
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
                          _isJudging = false;
                          _showFeedback = false;
                          _showResultDialog = false;
                          _petBounceScale = 1.0;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            if (_showResultDialog)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _showResultDialog ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Center(
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.86,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                          decoration: BoxDecoration(
                            color: _lastIsCorrect ? Colors.green : Colors.red.shade400,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            _resultLine,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox.shrink(),
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
    required this.isLocked,
    required this.isCorrectOption,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final bool isLocked;
  final bool isCorrectOption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final showCorrect = isLocked && isCorrectOption;
    final showWrong = isLocked && selected && !isCorrectOption;
    final bgColor = showCorrect
        ? Colors.green.shade100
        : showWrong
            ? Colors.red.shade100
            : Colors.white;
    final borderColor = showCorrect
        ? Colors.green.shade400
        : showWrong
            ? Colors.red.shade400
            : Colors.grey.shade300;

    return OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        backgroundColor: bgColor,
        side: BorderSide(color: borderColor),
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
