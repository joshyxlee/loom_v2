import 'dart:math';

class ProgressSnapshot {
  const ProgressSnapshot({
    required this.totalXp,
    required this.level,
    required this.dailyAnswered,
    required this.dailyTarget,
    required this.streakDays,
    required this.dailyBonusMultiplier,
  });

  final int totalXp;
  final int level;
  final int dailyAnswered;
  final int dailyTarget;
  final int streakDays;
  final double dailyBonusMultiplier;
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

  ProgressSnapshot get snapshot => ProgressSnapshot(
        totalXp: _totalXp,
        level: _levelForXp(_totalXp),
        dailyAnswered: _dailyAnswered,
        dailyTarget: dailyTarget,
        streakDays: _streakDays,
        dailyBonusMultiplier: _dailyBonusMultiplier,
      );

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

  int recordAnswer({required bool isCorrect, required int difficulty}) {
    final baseXp = _baseXpForDifficulty(difficulty);
    final correctXp = isCorrect ? baseXp * 3 : baseXp;
    final bonus = (correctXp * (_dailyBonusMultiplier - 1)).round();
    final gained = correctXp + bonus;
    _totalXp += gained;
    _dailyAnswered += 1;
    return gained;
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
}
