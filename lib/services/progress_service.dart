import 'dart:math';

class ProgressSnapshot {
  const ProgressSnapshot({
    required this.totalXp,
    required this.level,
    required this.dailyAnswered,
    required this.dailyTarget,
    required this.streakDays,
    required this.dailyBonusMultiplier,
    required this.lastActiveDate,
  });

  final int totalXp;
  final int level;
  final int dailyAnswered;
  final int dailyTarget;
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
  int _streakDays = 0;
  double _dailyBonusMultiplier = 1.0;
  DateTime? _lastActiveDate;

  ProgressSnapshot get snapshot => ProgressSnapshot(
        totalXp: _totalXp,
        level: _levelForXp(_totalXp),
        dailyAnswered: _dailyAnswered,
        dailyTarget: dailyTarget,
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
    if (continuedStreak) {
      _streakDays += 1;
      _dailyBonusMultiplier = min(2.0, 1.0 + _streakDays * 0.05);
    } else {
      _streakDays = 0;
      _dailyBonusMultiplier = 1.0;
    }
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
    final baseXp = _baseXpForDifficulty(difficulty);
    final correctXp = isCorrect ? baseXp * 3 : baseXp;
    final bonus = (correctXp * (_dailyBonusMultiplier - 1)).round();
    final gained = correctXp + bonus;
    _totalXp += gained;
    _dailyAnswered += 1;
    _lastActiveDate = DateTime.now();
    final completedDailyTarget = _dailyAnswered == dailyTarget;
    return AnswerResult(gainedXp: gained, completedDailyTarget: completedDailyTarget);
  }

  int _baseXpForDifficulty(int difficulty) {
    switch (difficulty) {
      case 5:
        return 50;
      case 4:
        return 40;
      case 3:
        return 30;
      case 2:
        return 20;
      case 1:
      default:
        return 10;
    }
  }

  int _levelForXp(int xp) {
    for (var level = 1; level <= maxLevel; level++) {
      if (xp < _xpThreshold(level)) return level;
    }
    return maxLevel;
  }

  int _xpThreshold(int level) {
    // Non-linear growth: fast early, slower later.
    // level 1 -> 0 xp, level 50 ~ 50k xp
    final curve = pow(level, 2.1).toDouble();
    return (curve * 40).round();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
