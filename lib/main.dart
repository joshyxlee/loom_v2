import 'dart:ui';

import 'package:flutter/foundation.dart';
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
import 'widgets/streak_card.dart';
import 'screens/shop_screen.dart';
import 'services/token_service.dart';
import 'services/level_thresholds.dart';
import 'services/inventory_service.dart';
import 'services/shop_state_service.dart';
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
    await TokenService.instance.init();
    await InventoryService.instance.init();
    await ShopStateService.instance.init();
    await _progressService.init();
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
    final shopState = ShopStateService.instance;
    return ValueListenableBuilder<String?>(
      valueListenable: shopState.themeNotifier,
      builder: (context, themeId, _) {
        final themeData = switch (themeId) {
          'cosmetic_theme_night' => LoomTheme.nightTheme(),
          'cosmetic_theme_ocean' => LoomTheme.oceanTheme(),
          'cosmetic_theme_warm' => LoomTheme.warmTheme(),
          _ => LoomTheme.lightTheme(),
        };
        return MaterialApp(
          title: 'Loom v2',
          theme: themeData,
          home: _ready
              ? OnboardingGate(
                  repository: _repository,
                  progressService: _progressService,
                  coreDataStore: _coreDataStore,
                )
              : const Scaffold(body: Center(child: CircularProgressIndicator())),
        );
      },
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
  bool _streakDialogShown = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _showStreakSaveDialog() async {
    if (_streakDialogShown) return;
    _streakDialogShown = true;
    final tokenService = TokenService.instance;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final canSave = tokenService.canAfford(20);
        return AlertDialog(
          title: const Text('保住連續紀錄？'),
          content: const Text('用 20 Tokens 保留你的 🔥 連續天數。'),
          actions: [
            TextButton(
              onPressed: () {
                widget.progressService.resetStreak();
                widget.progressService.clearStreakSavePending();
                Navigator.pop(context);
              },
              child: const Text('放棄'),
            ),
            TextButton(
              onPressed: canSave
                  ? () {
                      tokenService.deductToken(20);
                      widget.progressService.clearStreakSavePending();
                      Navigator.pop(context);
                    }
                  : null,
              child: Text(canSave ? '保留' : 'Tokens 不夠'),
            ),
          ],
        );
      },
    );
    _streakDialogShown = false;
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

  void _awardMilestoneTokens(int previousXp, int newXp) {
    if (newXp <= previousXp) return;
    var nextLevel = widget.coreDataStore.player.playerLevel;
    if (nextLevel <= 1) return;
    final startLevel = LevelThresholds.levelForXp(previousXp);
    final endLevel = LevelThresholds.levelForXp(newXp);
    if (endLevel <= startLevel) return;
    final todayKey = widget.progressService.todayKey;
    for (var level = startLevel + 1; level <= endLevel; level++) {
      final threshold = LevelThresholds.thresholdForLevel(level);
      if (previousXp < threshold && newXp >= threshold) {
        TokenService.instance.addTokenWithCap(20, todayKey);
      }
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
    if (widget.progressService.streakSavePending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showStreakSaveDialog();
      });
    }
    final snapshot = widget.progressService.snapshot;
    final primarySubject = subjects.first;
    final streakDays = snapshot.streakDays;
    final todayAnswered = snapshot.dailyAnswered;
    final dailyTarget = snapshot.dailyTarget;
    final todayCompleted = widget.progressService.todayCompleted;
    final yesterdayCompleted = widget.progressService.yesterdayCompleted;
    final prevStreakDays = widget.progressService.prevStreakDays;
    final streakSavePending = widget.progressService.streakSavePending;
    final canSaveStreak = TokenService.instance.canAfford(20);
    final creditsTotal =
        widget.coreDataStore.creditsBySubject.values.fold<int>(0, (sum, v) => sum + v);
    final tokenService = TokenService.instance;
    final totalXp = widget.coreDataStore.player.totalXp;
    final knowledgeBalance = totalXp + creditsTotal;
    final dailyPlus = widget.progressService.snapshot.dailyXp;
    final currentLevelXp = widget.progressService.currentLevelXp(
      widget.coreDataStore.player.playerLevel,
    );
    final nextLevelXp = widget.progressService.nextLevelXp(
      widget.coreDataStore.player.playerLevel,
    );
    final remainingToNext = (nextLevelXp - totalXp).clamp(0, nextLevelXp);
    final levelProgress = nextLevelXp == currentLevelXp
        ? 1.0
        : ((totalXp - currentLevelXp) / (nextLevelXp - currentLevelXp))
            .clamp(0.0, 1.0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.progressService.justUsedSaver) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已使用連勝保護卡，連勝保住了！')),
        );
        widget.progressService.clearStreakNotices();
      } else if (widget.progressService.justFrozen) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('連勝冰封了 🧊 今天完成 5 題就能解凍！')),
        );
        widget.progressService.clearStreakNotices();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: null,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: LoomSpacing.screen),
            child: TokenChip(
              label: '知識幣 \$${tokenService.knowledgeToken}',
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
      floatingActionButton: kDebugMode
          ? FloatingActionButton(
              onPressed: () {
                TokenService.instance.addToken(5000);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('DEBUG: +5000 tokens added')),
                );
                setState(() {});
              },
              child: const Icon(Icons.attach_money),
            )
          : null,
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
        if (index == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ShopScreen(),
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
                  padding: EdgeInsets.only(
                    bottom: kBottomNavigationBarHeight +
                        MediaQuery.of(context).viewPadding.bottom +
                        LoomSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      StreakCard(
                        streakDays: streakDays,
                        prevStreakDays: prevStreakDays,
                        todayAnswered: todayAnswered,
                        dailyTarget: dailyTarget,
                        todayCompleted: todayCompleted,
                        yesterdayCompleted: yesterdayCompleted,
                        streakSavePending: streakSavePending,
                        canSaveStreak: canSaveStreak,
                        streakFrozen: widget.progressService.streakFrozen,
                        streakMissedYmd: widget.progressService.streakMissedYmd,
                      ),
                      const SizedBox(height: LoomSpacing.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text('今日知識幣', style: LoomTypography.secondary),
                              ),
                              Text(
                                '${tokenService.dailyTokenEarned}/10',
                                style: LoomTypography.secondary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value:
                                (tokenService.dailyTokenEarned / 10).clamp(0.0, 1.0),
                            minHeight: 4,
                            color: Theme.of(context).colorScheme.primary,
                            backgroundColor:
                                Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ],
                      ),
                      const SizedBox(height: LoomSpacing.md),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.38,
                        child: LoomCard(
                          background: LoomTheme.card(context),
                          borderColor: LoomTheme.border(context),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '智慧指數',
                                style: LoomTypography.sectionTitle.copyWith(
                                  color: LoomTheme.textSecondary(context),
                                ),
                              ),
                              const SizedBox(height: LoomSpacing.base),
                              SizedBox(
                                width: 120,
                                height: 120,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        knowledgeBalance.toString(),
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.visible,
                                        textAlign: TextAlign.center,
                                        style: LoomTypography.bigNumber.copyWith(
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                          fontSize: 72,
                                          fontWeight: FontWeight.w700,
                                          color: LoomTheme.accent(context),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: LoomSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: LoomTheme.accent(context).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  '今天 +$dailyPlus',
                                  style: LoomTypography.secondary.copyWith(
                                    color: LoomTheme.accent(context),
                                  ),
                                ),
                              ),
                              const SizedBox(height: LoomSpacing.sm),
                              Text(
                                '距離下一個里程碑還差 $remainingToNext',
                                textAlign: TextAlign.center,
                                style: LoomTypography.secondary.copyWith(
                                  color: LoomTheme.textSecondary(context),
                                ),
                              ),
                              const SizedBox(height: LoomSpacing.base),
                              SizedBox(
                                height: 4,
                                child: LinearProgressIndicator(
                                  value: levelProgress,
                                  color: LoomTheme.accent(context),
                                  backgroundColor: LoomTheme.border(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: LoomSpacing.md),
                      SizedBox(
                        height: LoomSizes.buttonHeight + 8,
                        child: LoomPrimaryButton(
                          label: '開始變聰明！',
                          onPressed: () => _startSubject(context, primarySubject),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              LoomColors.primaryStrong,
                              LoomTheme.accent(context),
                            ],
                          ),
                          shadowColor: LoomTheme.shadow(context).withOpacity(0.15),
                        ),
                      ),
                      const SizedBox(height: LoomSpacing.md),
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
        color: color ?? LoomTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: LoomTheme.shadow(context),
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
    final shopState = ShopStateService.instance;
    final extraSubjects = <Subject>[];
    if (shopState.isOwned('unlock_subject_pack_world_plus')) {
      extraSubjects.add(const Subject(subjectId: 'world', displayName: '世界＋'));
    }
    if (shopState.isOwned('unlock_subject_pack_science_plus')) {
      extraSubjects.add(const Subject(subjectId: 'science', displayName: '科學＋'));
    }
    if (shopState.isOwned('unlock_subject_pack_finance_plus')) {
      extraSubjects.add(const Subject(subjectId: 'money', displayName: '理財＋'));
    }
    final allSubjects = [...subjects, ...extraSubjects];
    return Scaffold(
      appBar: AppBar(title: const Text('試試你能不能撐過 5 題 ⚔️')),
      body: ListView(
        padding: const EdgeInsets.all(LoomSpacing.screen),
        children: [
          LoomSectionHeader(
            title: '選一個科目',
            subtitle: '想要變成專家？選你喜歡的科目吧！',
          ),
          const SizedBox(height: LoomSpacing.md),
          ...allSubjects.map((subject) {
            final displayTitle = subject.title == '金錢' ? '理財' : subject.title;
            final subtitle = switch (displayTitle.replaceAll('＋', '')) {
              '冷知識' => '變成朋友裡最聰明的那個。\n（隨時丟出一個沒人知道的答案 😏）',
              '世界' => '世界比想像中還要有趣。\n（地理、文化、奇聞一次補齊 🌍）',
              '歷史' => '古人其實沒那麼無聊。\n（事情怎麼變成現在這樣？📜）',
              '科學' => '原來日常都有科學在偷跑。\n（為什麼會這樣？現在就搞懂 ⚗️）',
              '理財' => '聰明的人，不讓錢亂跑。\n（少踩幾個坑，錢就會慢慢多起來 💰）',
              _ => '選一個科目，挑戰連續 5 題',
            };
            final isPlus = displayTitle.contains('＋');
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
                            Row(
                              children: [
                                Text(
                                  displayTitle,
                                  style: const TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.w600),
                                ),
                                if (isPlus) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '已解鎖',
                                    style: LoomTypography.secondary
                                        .copyWith(color: LoomColors.primary),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: LoomSpacing.base),
                            Text(
                              subtitle,
                              style: const TextStyle(fontSize: 14, height: 1.3)
                                  .copyWith(color: LoomColors.textSecondary),
                            ),
                            const SizedBox(height: LoomSpacing.base),
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
  bool _sessionBonus3Awarded = false;
  bool _sessionBonus5Awarded = false;
  bool _levelUpPulse = false;
  double _levelProgress = 0.0;
  int _progressAnimMs = 350;
  bool _levelUpMoment = false;
  bool _isJudging = false;
  bool _showFeedback = false;
  double _petBounceScale = 1.0;
  bool _lastIsCorrect = false;
  late final List<Question> _sessionQuestions;
  final Set<String> _recentQuestionIds = {};
  final Set<int> _disabledOptionIndexes = {};
  bool _hintUsed = false;

  // moment texts removed

  @override
  void initState() {
    super.initState();
    _sessionQuestions = List<Question>.from(widget.questions);
    _recentQuestionIds.addAll(_sessionQuestions.map((q) => q.id));
    _levelProgress = _currentLevelProgress();
  }

  double _currentLevelProgress() {
    final level = widget.coreDataStore.player.playerLevel;
    final current = widget.progressService.currentLevelXp(level);
    final next = widget.progressService.nextLevelXp(level);
    final snapshot = widget.progressService.snapshot;
    return ((snapshot.totalXp - current) / (next - current)).clamp(0.0, 1.0);
  }

  void _awardMilestoneTokens(int previousXp, int newXp) {
    if (newXp <= previousXp) return;
    final startLevel = LevelThresholds.levelForXp(previousXp);
    final endLevel = LevelThresholds.levelForXp(newXp);
    if (endLevel <= startLevel) return;
    final todayKey = widget.progressService.todayKey;
    for (var level = startLevel + 1; level <= endLevel; level++) {
      final threshold = LevelThresholds.thresholdForLevel(level);
      if (previousXp < threshold && newXp >= threshold) {
        TokenService.instance.addTokenWithCap(20, todayKey);
      }
    }
  }

  void _triggerMoment({required bool isCorrect, required bool leveledUp}) {}

  void _resetQuestionState() {
    _selected = null;
    _lastXp = 0;
    _dailyTargetJustCompleted = false;
    _streakJustHit = false;
    _levelUpPulse = false;
    _isJudging = false;
    _showFeedback = false;
    _petBounceScale = 1.0;
    _disabledOptionIndexes.clear();
    _hintUsed = false;
  }

  Future<Question> _fetchReplacementQuestion({String? avoidId}) async {
    Question? fallback;
    for (var i = 0; i < 10; i++) {
      final session = await widget.repository.getSession(
        subject: widget.subject.key,
        count: 1,
      );
      if (session.isEmpty) continue;
      final candidate = session.first;
      fallback ??= candidate;
      if (candidate.id == avoidId) continue;
      if (_recentQuestionIds.contains(candidate.id)) continue;
      return candidate;
    }
    return fallback ?? _sessionQuestions[_index];
  }

  Future<void> _useSkip() async {
    final inventory = InventoryService.instance;
    final remaining = inventory.count('util_skip_question');
    if (remaining <= 0) return;
    final confirmed = await _confirmUse(
      '消耗 1 張跳題券，直接跳到下一題。',
    );
    if (!confirmed) return;
    final consumed = await inventory.consume('util_skip_question');
    if (!consumed) return;
    if (_index + 1 < _sessionQuestions.length) {
      setState(() {
        _index += 1;
        _resetQuestionState();
      });
    } else {
      final nextQuestion = await _fetchReplacementQuestion(avoidId: _sessionQuestions[_index].id);
      setState(() {
        _sessionQuestions.add(nextQuestion);
        _recentQuestionIds.add(nextQuestion.id);
        _index += 1;
        _resetQuestionState();
      });
    }
    if (!mounted) return;
    final left = inventory.count('util_skip_question');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已跳過（剩餘 x$left）')),
    );
  }

  Future<void> _useReroll() async {
    final inventory = InventoryService.instance;
    final remaining = inventory.count('util_reroll_question');
    if (remaining <= 0) return;
    final confirmed = await _confirmUse(
      '消耗 1 張換題券，換一題新的。',
    );
    if (!confirmed) return;
    final consumed = await inventory.consume('util_reroll_question');
    if (!consumed) return;
    final replacement =
        await _fetchReplacementQuestion(avoidId: _sessionQuestions[_index].id);
    setState(() {
      _sessionQuestions[_index] = replacement;
      _recentQuestionIds.add(replacement.id);
      _resetQuestionState();
    });
    if (!mounted) return;
    final left = inventory.count('util_reroll_question');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已換題（剩餘 x$left）')),
    );
  }

  Future<void> _useHint() async {
    final inventory = InventoryService.instance;
    if (_selected != null || _hintUsed) return;
    final remaining = inventory.count('util_hint_reveal');
    if (remaining <= 0) return;
    final confirmed = await _confirmUse(
      '消耗 1 張提示券，排除兩個錯誤選項。',
    );
    if (!confirmed) return;
    final consumed = await inventory.consume('util_hint_reveal');
    if (!consumed) return;
    final question = _sessionQuestions[_index];
    // Question uses answerIndex as the correct option index.
    final correctIndex = question.answerIndex;
    final wrongIndexes = <int>[];
    for (var i = 0; i < question.options.length; i++) {
      if (i != correctIndex) {
        wrongIndexes.add(i);
      }
    }
    wrongIndexes.shuffle();
    final removeCount = question.options.length <= 3 ? 1 : 2;
    setState(() {
      _disabledOptionIndexes.addAll(wrongIndexes.take(removeCount));
      _hintUsed = true;
    });
    if (!mounted) return;
    final left = inventory.count('util_hint_reveal');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已提示（剩餘 x$left）')),
    );
  }

  Future<bool> _confirmUse(String body) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('使用道具？'),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('使用'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _handleCoreGrowth({required String subjectId, required bool isCorrect}) async {
    final previousStage = widget.coreDataStore.activePet.currentStage;
    final previousLevel = widget.coreDataStore.player.playerLevel;
    await widget.coreDataStore.recordAnswer(subjectId: subjectId, isCorrect: isCorrect);
    widget.progressService.setTotalXp(widget.coreDataStore.player.totalXp);
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
    final question = _sessionQuestions[_index];
    final inventory = InventoryService.instance;
    final skipCount = inventory.count('util_skip_question');
    final rerollCount = inventory.count('util_reroll_question');
    final hintCount = inventory.count('util_hint_reveal');
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subjectTitle),
        actions: [
          if (skipCount > 0)
            TextButton.icon(
              onPressed: _useSkip,
              icon: const Icon(Icons.skip_next, size: 16),
              label: const Text('跳過'),
            ),
          if (rerollCount > 0)
            TextButton.icon(
              onPressed: _useReroll,
              icon: const Icon(Icons.shuffle, size: 16),
              label: const Text('換一題'),
            ),
          if (hintCount > 0 && _selected == null && !_hintUsed)
            TextButton.icon(
              onPressed: _useHint,
              icon: const Icon(Icons.lightbulb_outline, size: 16),
              label: const Text('提示'),
            ),
          const SizedBox(width: 8),
        ],
      ),
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
                    Text('題目 ${_index + 1} / ${_sessionQuestions.length}',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: (_index + 1) / _sessionQuestions.length,
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
                      color: LoomTheme.accent(context),
                      backgroundColor: LoomTheme.accent(context).withOpacity(0.12),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  question.prompt,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  'ID: ${question.id}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: LoomTheme.textSecondary(context),
                      ),
                ),
                const SizedBox(height: 18),
                if (_selected != null && _showFeedback)
                  _FeedbackCard(
                    xp: _lastXp,
                    explanation: question.explanation,
                    isCorrect: question.isCorrect(_selected!),
                    levelUp: widget.progressService.snapshot.level > _lastLevel,
                    streakHit: _streakJustHit,
                    dailyHit: _dailyTargetJustCompleted,
                    isLast: _index + 1 >= _sessionQuestions.length,
                    levelUpPulse: _levelUpPulse,
                    onNext: () {
                      if (_index + 1 >= _sessionQuestions.length) {
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
                  final disabledByHint = _disabledOptionIndexes.contains(i);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AnswerOption(
                      label: option,
                      selected: selected,
                      enabled: _selected == null && !disabledByHint,
                      isLocked: _selected != null || disabledByHint,
                      isCorrectOption: question.isCorrect(i),
                      onTap: () async {
                        var isCorrect = question.isCorrect(i);
                        final tokenBefore = TokenService.instance.knowledgeToken;
                        final shopState = ShopStateService.instance;
                        final burstBefore = shopState.effectRemaining(
                          ShopStateService.xpBurstRemainingKey,
                        );
                        final focusBefore = shopState.effectRemaining(
                          ShopStateService.focusXpRemainingKey,
                        );
                        final baseXp = isCorrect ? 10 : 6;
                        final appliedMultiplier = burstBefore > 0
                            ? 1.5
                            : focusBefore > 0
                                ? 1.2
                                : 1.0;
                        if (!isCorrect) {
                          final inventory = InventoryService.instance;
                          if (inventory.isReady) {
                            final used = await inventory.consume('boost_mistake_shield');
                            if (used) {
                              isCorrect = true;
                              final remaining = inventory.count('boost_mistake_shield');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('失誤保護卡已使用（剩餘 x$remaining）'),
                                  ),
                                );
                              }
                            }
                          }
                        }
                        _lastLevel = widget.coreDataStore.player.playerLevel;
                        final result = widget.progressService.recordAnswer(
                          isCorrect: isCorrect,
                          difficulty: question.difficultyValue,
                        );
                        final prevXp = widget.coreDataStore.player.totalXp;
                        await _handleCoreGrowth(
                          subjectId: question.subject,
                          isCorrect: isCorrect,
                        );
                        final newXp = widget.coreDataStore.player.totalXp;
                        _awardMilestoneTokens(prevXp, newXp);
                        if (kDebugMode) {
                          final burstAfter = shopState.effectRemaining(
                            ShopStateService.xpBurstRemainingKey,
                          );
                          final focusAfter = shopState.effectRemaining(
                            ShopStateService.focusXpRemainingKey,
                          );
                          final finalXpWritten = newXp - prevXp;
                          final finalXpShown = result.gainedXp;
                          debugPrint(
                            '[XP_AUDIT] base=$baseXp mult=$appliedMultiplier '
                            'written=$finalXpWritten shown=$finalXpShown '
                            'burstLeft=$burstAfter focusLeft=$focusAfter',
                          );
                        }
                        final newLevel = widget.coreDataStore.player.playerLevel;
                        final leveledUp = newLevel > _lastLevel;
                        if (leveledUp) {
                          TokenService.instance.addToken(3);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('+3 知識幣（升級）')),
                          );
                          if (newLevel % 10 == 0) {
                            TokenService.instance.addToken(15);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('+15 知識幣（里程碑）')),
                            );
                          }
                        }
                        if (result.completedDailyTarget) {
                          final tokenAfterDaily =
                              TokenService.instance.knowledgeToken;
                          if (tokenAfterDaily - tokenBefore >= 5) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('+5 知識幣（今日完成）')),
                            );
                          }
                        }
                        if (result.completedDailyTarget && newLevel == 1) {
                          TokenService.instance.grantFirstDayBonus();
                        }
                        setState(() {
                          _selected = i;
                          _lastXp = result.gainedXp;
                          _sessionXp += result.gainedXp;
                          _dailyTargetJustCompleted = result.completedDailyTarget;
                          _isJudging = true;
                          _showFeedback = false;
                          _lastIsCorrect = isCorrect;
                          if (isCorrect) {
                            _correctStreak += 1;
                            _streakJustHit = _correctStreak == 3;
                            final todayKey = widget.progressService.todayKey;
                            TokenService.instance.addTokenFromAnswer(1);
                            final tokenAfterAnswer =
                                TokenService.instance.knowledgeToken;
                            if (tokenAfterAnswer > tokenBefore) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('+1 知識幣')),
                              );
                            }
                            if (_correctStreak == 3 && !_sessionBonus3Awarded) {
                              TokenService.instance.addTokenWithCap(2, todayKey);
                              _sessionBonus3Awarded = true;
                              TokenService.instance.awardGolden3(todayKey);
                            }
                            if (_correctStreak == 5 && !_sessionBonus5Awarded) {
                              TokenService.instance.addTokenWithCap(3, todayKey);
                              _sessionBonus5Awarded = true;
                            }
                          } else {
                            _correctStreak = 0;
                            _streakJustHit = false;
                          }
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
                        });

                        setState(() {
                          _isJudging = false;
                          _showFeedback = true;
                        });
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
                    color: Theme.of(context).shadowColor.withOpacity(0.8),
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
                          '智慧指數上漲$_sessionXp！',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: LoomTheme.textPrimary(context),
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
    final baseBg = LoomTheme.surface(context);
    final baseBorder = LoomTheme.border(context);
    final disabledHint = !enabled && !showCorrect && !showWrong;
    final bgColor = showCorrect
        ? LoomTheme.positive(context).withOpacity(0.12)
        : showWrong
            ? LoomTheme.negative(context).withOpacity(0.12)
            : disabledHint
                ? baseBg.withOpacity(0.6)
                : baseBg;
    final borderColor = showCorrect
        ? LoomTheme.positive(context)
        : showWrong
            ? LoomTheme.negative(context)
            : disabledHint
                ? baseBorder.withOpacity(0.6)
                : baseBorder;

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
            color: enabled ? LoomTheme.textPrimary(context) : LoomTheme.disabled(context),
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
    final bannerColor =
        isCorrect ? LoomTheme.positive(context) : LoomTheme.negative(context);
    final textColor = isCorrect
        ? Theme.of(context).colorScheme.onTertiary
        : Theme.of(context).colorScheme.onError;
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
              style: LoomTypography.sectionTitle.copyWith(color: textColor),
            ),
            const SizedBox(height: LoomSpacing.base),
            Text(
              isCorrect ? '繼續保持這個節奏' : '再試一次就會更穩',
              style: LoomTypography.body.copyWith(color: textColor),
            ),
            const SizedBox(height: LoomSpacing.base),
            Text(
              '本題 +$xp XP',
              style: LoomTypography.secondary.copyWith(color: textColor),
            ),
            if (levelUp) ...[
              const SizedBox(height: LoomSpacing.base),
              Text('升級完成', style: LoomTypography.body.copyWith(color: textColor)),
            ],
            if (streakHit) ...[
              const SizedBox(height: LoomSpacing.base),
              Text('連勝 x3', style: LoomTypography.body.copyWith(color: textColor)),
            ],
            if (dailyHit) ...[
              const SizedBox(height: LoomSpacing.base),
              Text('今日達標', style: LoomTypography.body.copyWith(color: textColor)),
            ],
            const SizedBox(height: LoomSpacing.sm),
            Text(explanation, style: LoomTypography.body.copyWith(color: textColor)),
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
