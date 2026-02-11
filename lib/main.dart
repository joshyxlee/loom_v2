import 'dart:ui';

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
import 'widgets/design_system.dart';
import 'widgets/loom_card.dart';
import 'widgets/loom_button.dart';
import 'widgets/loom_section.dart';
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
    return MaterialApp(
      title: 'Loom v2',
      theme: LoomTheme.lightTheme(),
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

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
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
    final streakDays = snapshot.streakDays;
    final creditsTotal =
        widget.coreDataStore.creditsBySubject.values.fold<int>(0, (sum, v) => sum + v);
    final knowledgeBalance = widget.progressService.snapshot.totalXp + creditsTotal;
    final dailyPlus = widget.progressService.snapshot.dailyXp;
    final currentLevelXp = widget.progressService.currentLevelXp(snapshot.level);
    final nextLevelXp = widget.progressService.nextLevelXp(snapshot.level);
    final remainingToNext = (nextLevelXp - snapshot.totalXp).clamp(0, nextLevelXp);
    final levelProgress = nextLevelXp == currentLevelXp
        ? 1.0
        : ((snapshot.totalXp - currentLevelXp) / (nextLevelXp - currentLevelXp))
            .clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: null,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: LoomSpacing.screen),
            child: TokenChip(
              label: 'Tokens $creditsTotal',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _PlaceholderScreen(title: '商城'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _HomeBottomNav(onTap: (index) {
        if (index == 0) return;
        if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdvancedChallengeScreen(
                subjects: subjects,
                onStartSubject: (subject) => _startSubject(context, subject),
              ),
            ),
          );
          return;
        }
        if (index == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LeaderboardScreen(
                knowledgeBalance: knowledgeBalance,
              ),
            ),
          );
          return;
        }
        if (index == 4) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SettingsScreen(onReset: _resetAll),
            ),
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _PlaceholderScreen(
              title: ['主線', '分科', '排行', '商城', '設定'][index],
            ),
          ),
        );
      }),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            LoomSpacing.screen,
            LoomSpacing.sm,
            LoomSpacing.screen,
            LoomSpacing.md,
          ),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      LoomCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '今天再 5 題，火會繼續燒',
                              style: LoomTypography.secondary
                                  .copyWith(color: LoomColors.textSecondary),
                            ),
                            const SizedBox(height: LoomSpacing.base),
                            LoomProgressIndicator(
                              activeCount: streakDays.clamp(0, 7),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: LoomSpacing.md),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: LoomCard(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('我的知識存款',
                                  style: LoomTypography.sectionTitle
                                      .copyWith(color: LoomColors.textSecondary)),
                              const SizedBox(height: LoomSpacing.base),
                              Text(
                                '\$${knowledgeBalance.toString()}',
                                textAlign: TextAlign.center,
                                style: LoomTypography.bigNumber.copyWith(
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                  color: LoomColors.primaryStrong,
                                ),
                              ),
                              const SizedBox(height: LoomSpacing.base),
                              Text(
                                '今天 +$dailyPlus',
                                style: LoomTypography.secondary
                                    .copyWith(color: LoomColors.textSecondary),
                              ),
                              const SizedBox(height: LoomSpacing.sm),
                              Text(
                                '距離下一個里程碑還差 $remainingToNext',
                                textAlign: TextAlign.center,
                                style: LoomTypography.secondary
                                    .copyWith(color: LoomColors.textSecondary),
                              ),
                              const SizedBox(height: LoomSpacing.base),
                              SizedBox(
                                height: 2,
                                child: LinearProgressIndicator(
                                  value: levelProgress,
                                  color: LoomColors.primary,
                                  backgroundColor: LoomColors.divider,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: LoomSpacing.base),
                      SizedBox(
                        height: 64,
                        child: LoomPrimaryButton(
                          label: '開始變聰明！',
                          onPressed: () => _startSubject(context, primarySubject),
                        ),
                      ),
                    ],
                  ),
                ),
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

class _HomeBottomNav extends StatelessWidget {
  const _HomeBottomNav({required this.onTap});

  final void Function(int index) onTap;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 0,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: LoomColors.primary,
      unselectedItemColor: LoomColors.textSecondary,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: '主線'),
        BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: '分科'),
        BottomNavigationBarItem(icon: Icon(Icons.leaderboard), label: '排行'),
        BottomNavigationBarItem(icon: Icon(Icons.storefront), label: '商城'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: '設定'),
      ],
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text('Soon', style: LoomTypography.body),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: Padding(
        padding: const EdgeInsets.all(LoomSpacing.screen),
        child: LoomPrimaryButton(
          label: '刷新',
          onPressed: () {
            onReset();
            Navigator.pop(context);
          },
        ),
      ),
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

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, required this.knowledgeBalance});

  final int knowledgeBalance;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  static const _fakeEntries = [
    ['小宇', 12450],
    ['阿凱', 11890],
    ['米米', 11020],
    ['Kevin', 10350],
    ['雨晴', 9870],
    ['Leo', 9450],
    ['阿達', 9100],
    ['小嵐', 8750],
    ['Yuki', 8420],
    ['阿哲', 8050],
  ];

  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final title = _tabIndex == 0 ? '總榜' : '本週';
    return Scaffold(
      appBar: AppBar(title: const Text('看看你現在站在哪 🏆')),
      body: ListView(
        padding: const EdgeInsets.all(LoomSpacing.screen),
        children: [
          LoomSectionHeader(
            title: '排行榜',
            subtitle: '看看你目前的相對位置',
          ),
          const SizedBox(height: LoomSpacing.sm),
          Row(
            children: [
              Expanded(
                child: LoomSecondaryButton(
                  label: '總榜',
                  onPressed: () => setState(() => _tabIndex = 0),
                ),
              ),
              const SizedBox(width: LoomSpacing.base),
              Expanded(
                child: LoomSecondaryButton(
                  label: '本週',
                  onPressed: () => setState(() => _tabIndex = 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: LoomSpacing.md),
          _LeaderboardSection(title: title, entries: _fakeEntries),
          const SizedBox(height: LoomSpacing.lg),
        ],
      ),
    );
  }
}

class _LeaderboardSection extends StatelessWidget {
  const _LeaderboardSection({required this.title, required this.entries});

  final String title;
  final List<List<Object>> entries;

  @override
  Widget build(BuildContext context) {
    return LoomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: LoomTypography.sectionTitle),
          const SizedBox(height: LoomSpacing.base),
          ...List.generate(entries.length, (index) {
            final entry = entries[index];
            final isTop = index < 3;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: LoomSpacing.base),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${index + 1}',
                      style: LoomTypography.body.copyWith(
                        color: isTop ? LoomColors.primary : LoomColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: LoomSpacing.base),
                  Expanded(
                    child: Text(entry[0].toString(), style: LoomTypography.body),
                  ),
                  Text(
                    '${entry[1]}',
                    style: LoomTypography.body.copyWith(
                      color: LoomColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class AdvancedChallengeScreen extends StatelessWidget {
  const AdvancedChallengeScreen({
    super.key,
    required this.subjects,
    required this.onStartSubject,
  });

  final List<Subject> subjects;
  final void Function(Subject subject) onStartSubject;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('試試你能不能撐過 10 題 ⚔️')),
      body: ListView(
        padding: const EdgeInsets.all(LoomSpacing.screen),
        children: [
          LoomSectionHeader(
            title: '選一個科目',
            subtitle: '挑戰連續 10 題，感覺一下自己的實力',
          ),
          const SizedBox(height: LoomSpacing.md),
          ...subjects.map((subject) {
            return Padding(
              padding: const EdgeInsets.only(bottom: LoomSpacing.sm),
              child: InkWell(
                borderRadius: BorderRadius.circular(LoomRadius.card),
                onTap: () => onStartSubject(subject),
                child: LoomCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(subject.title, style: LoomTypography.body),
                            const SizedBox(height: LoomSpacing.base),
                            Text(
                              '選一個科目，挑戰連續 10 題',
                              style: LoomTypography.secondary
                                  .copyWith(color: LoomColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: LoomColors.textSecondary),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _QuizScreenState extends State<QuizScreen> {
  int _index = 0;
  int? _selected;
  int _lastXp = 0;
  int _sessionXp = 0;
  bool _dailyTargetJustCompleted = false;
  int _lastLevel = 1;
  bool _showSessionReward = false;
  int _correctStreak = 0;
  bool _streakJustHit = false;
  bool _levelUpPulse = false;
  double _levelProgress = 0.0;
  int _progressAnimMs = 350;
  bool _levelUpMoment = false;
  bool _isJudging = false;
  bool _showFeedback = false;
  double _petBounceScale = 1.0;
  bool _lastIsCorrect = false;

  // moment texts removed

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

  Future<void> _handleCoreGrowth({required String subjectId, required bool isCorrect}) async {
    final previousStage = widget.coreDataStore.activePet.currentStage;
    final previousLevel = widget.coreDataStore.player.playerLevel;
    await widget.coreDataStore.recordAnswer(subjectId: subjectId, isCorrect: isCorrect);
    if (!mounted) return;
    final newStage = widget.coreDataStore.activePet.currentStage;
    final newLevel = widget.coreDataStore.player.playerLevel;
    if (newStage > previousStage) {
      final extra = newStage == 4 && previousLevel < 40 && newLevel >= 40
          ? '\n你的累積已經很紮實，新的內容即將開放。'
          : '';
      final content = '知識里程碑達成\n圖鑑已新增一筆收藏$extra';
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
                        setState(() {
                          _showSessionReward = true;
                        });
                        Future.delayed(const Duration(milliseconds: 700), () {
                          if (!mounted) return;
                          Navigator.popUntil(context, (route) => route.isFirst);
                        });
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
                          _petBounceScale = 1.0;
                        });
                      }
                    },
                  ),
                const SizedBox(height: LoomSpacing.sm),
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
                          _sessionXp += result.gainedXp;
                          _dailyTargetJustCompleted = result.completedDailyTarget;
                          _isJudging = true;
                          _showFeedback = false;
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
                          _isJudging = false;
                          _showFeedback = true;
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
                ],
              ),
            ),
            if (_showSessionReward)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: Colors.black87,
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.8, end: 1.0),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: child,
                          );
                        },
                        child: Text(
                          '+$_sessionXp 知識存款',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
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
    final bannerColor = isCorrect ? LoomColors.success : LoomColors.danger;
    return AnimatedScale(
      scale: levelUpPulse ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(LoomSizes.cardPadding),
        decoration: BoxDecoration(
          color: bannerColor,
          borderRadius: BorderRadius.circular(LoomRadius.card),
          boxShadow: LoomElevation.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCorrect ? '答對了！' : '可惜！',
              style: LoomTypography.sectionTitle.copyWith(color: Colors.white),
            ),
            const SizedBox(height: LoomSpacing.base),
            Text(
              isCorrect ? '繼續保持這個節奏' : '再試一次就會更穩',
              style: LoomTypography.body.copyWith(color: Colors.white),
            ),
            const SizedBox(height: LoomSpacing.base),
            Text('本題 +$xp XP',
                style: LoomTypography.secondary.copyWith(color: Colors.white)),
            if (levelUp) ...[
              const SizedBox(height: LoomSpacing.base),
              Text('升級完成', style: LoomTypography.body.copyWith(color: Colors.white)),
            ],
            if (streakHit) ...[
              const SizedBox(height: LoomSpacing.base),
              Text('連勝 x3', style: LoomTypography.body.copyWith(color: Colors.white)),
            ],
            if (dailyHit) ...[
              const SizedBox(height: LoomSpacing.base),
              Text('今日達標', style: LoomTypography.body.copyWith(color: Colors.white)),
            ],
            const SizedBox(height: LoomSpacing.sm),
            Text(explanation, style: LoomTypography.body.copyWith(color: Colors.white)),
            const SizedBox(height: LoomSpacing.sm),
            LoomPrimaryButton(
              label: isLast ? '回到主選單' : '下一題',
              onPressed: onNext,
            ),
          ],
        ),
      ),
    );
  }
}
