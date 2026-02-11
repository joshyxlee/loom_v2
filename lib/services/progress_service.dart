import 'level_thresholds.dart';

class ProgressSnapshot {
  const ProgressSnapshot({
    required this.totalXp,
    required this.level,
    required this.dailyAnswered,
    required this.dailyTarget,
    required this.dailyXp,
    required this.streakDays,
    required this.dailyBonusMultiplier,
    required this.lastActiveDate,
  });

  final int totalXp;
  final int level;
  final int dailyAnswered;
  final int dailyTarget;
  final int dailyXp;
  final int streakDays;
  final double dailyBonusMultiplier;
  final DateTime? lastActiveDate;
}

class AnswerResult {
  const AnswerResult({
    required this.gainedXp,
    required this.completedDailyTarget,
  });

  final int gainedXp;
  final bool completedDailyTarget;
}

class ProgressService {
  ProgressService({
    this.dailyTarget = 10,
    this.maxLevel = 50,
  });

  final int dailyTarget;
  final int maxLevel;

  int _totalXp = 0;
  int _dailyAnswered = 0;
  int _dailyXp = 0;
  int _streakDays = 0;
  double _dailyBonusMultiplier = 1.0;
  DateTime? _lastActiveDate;

  ProgressSnapshot get snapshot => ProgressSnapshot(
        totalXp: _totalXp,
        level: _levelForXp(_totalXp),
        dailyAnswered: _dailyAnswered,
        dailyTarget: dailyTarget,
        dailyXp: _dailyXp,
        streakDays: _streakDays,
        dailyBonusMultiplier: _dailyBonusMultiplier,
        lastActiveDate: _lastActiveDate,
      );

  int currentLevelXp(int level) {
    if (level <= 1) return 0;
    return _xpThreshold(level - 1);
  }

  int nextLevelXp(int level) {
    return _xpThreshold(level);
  }

  void resetDailyProgress({required bool continuedStreak}) {
    _dailyAnswered = 0;
    _dailyXp = 0;
    _streakDays = 0;
    _dailyBonusMultiplier = 1.0;
  }

  void resetAll() {
    _totalXp = 0;
    _dailyAnswered = 0;
    _dailyXp = 0;
    _streakDays = 0;
    _dailyBonusMultiplier = 1.0;
    _lastActiveDate = null;
  }

  void ensureDailyState() {
    final now = DateTime.now();
    if (_lastActiveDate == null) {
      _lastActiveDate = now;
      return;
    }
    if (_isSameDay(_lastActiveDate!, now)) return;

    final completed = _dailyAnswered >= dailyTarget;
    resetDailyProgress(continuedStreak: completed);
    _lastActiveDate = now;
  }

  AnswerResult recordAnswer({required bool isCorrect, required int difficulty}) {
    ensureDailyState();
    final gained = isCorrect ? 10 : 6;
    _dailyAnswered += 1;
    _dailyXp += gained;
    _lastActiveDate = DateTime.now();
    final completedDailyTarget = _dailyAnswered == dailyTarget;
    return AnswerResult(gainedXp: gained, completedDailyTarget: completedDailyTarget);
  }

  void setTotalXp(int totalXp) {
    _totalXp = totalXp;
  }

  int _levelForXp(int xp) {
    return LevelThresholds.levelForXp(xp, maxLevel: maxLevel);
  }

  int _xpThreshold(int level) {
    return LevelThresholds.thresholdForLevel(level);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
