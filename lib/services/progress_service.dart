import 'package:shared_preferences/shared_preferences.dart';

import 'level_thresholds.dart';
import 'token_service.dart';
import 'shop_state_service.dart';

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
    this.dailyTarget = 5,
    this.maxLevel = 50,
  });

  static const _streakKey = 'loom_streak_days';
  static const _lastActiveKey = 'loom_last_active_date';
  static const _yesterdayCompletedKey = 'loom_yesterday_completed';
  static const _todayCompletedKey = 'loom_today_completed';
  static const _streakSavePendingKey = 'loom_streak_save_pending';
  static const _prevStreakKey = 'loom_prev_streak_days';

  final int dailyTarget;
  final int maxLevel;

  int _totalXp = 0;
  int _dailyAnswered = 0;
  int _dailyXp = 0;
  int _streakDays = 0;
  bool _todayCompleted = false;
  bool _yesterdayCompleted = false;
  bool _streakSavePending = false;
  int _prevStreakDays = 0;
  double _dailyBonusMultiplier = 1.0;
  DateTime? _lastActiveDate;
  SharedPreferences? _prefs;

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

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    _streakDays = _prefs?.getInt(_streakKey) ?? 0;
    _prevStreakDays = _prefs?.getInt(_prevStreakKey) ?? 0;
    _todayCompleted = _prefs?.getBool(_todayCompletedKey) ?? false;
    _yesterdayCompleted = _prefs?.getBool(_yesterdayCompletedKey) ?? false;
    _streakSavePending = _prefs?.getBool(_streakSavePendingKey) ?? false;
    final lastRaw = _prefs?.getString(_lastActiveKey);
    if (lastRaw != null && lastRaw.isNotEmpty) {
      _lastActiveDate = DateTime.tryParse(lastRaw);
    }
  }

  bool get streakSavePending => _streakSavePending;
  bool get todayCompleted => _todayCompleted;
  bool get yesterdayCompleted => _yesterdayCompleted;
  int get prevStreakDays => _prevStreakDays;
  String get todayKey => _dayKey(DateTime.now());

  void clearStreakSavePending() {
    _streakSavePending = false;
    _saveStreakState();
  }

  void resetStreak() {
    _prevStreakDays = _streakDays;
    _streakDays = 0;
    _streakSavePending = false;
    _saveStreakState();
  }

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
    _dailyBonusMultiplier = 1.0;
  }

  void resetAll() {
    _totalXp = 0;
    _dailyAnswered = 0;
    _dailyXp = 0;
    _streakDays = 0;
    _prevStreakDays = 0;
    _todayCompleted = false;
    _yesterdayCompleted = false;
    _streakSavePending = false;
    _dailyBonusMultiplier = 1.0;
    _lastActiveDate = null;
    _saveStreakState();
  }

  void ensureDailyState() {
    final now = DateTime.now();
    final todayKey = _dayKey(now);
    if (_lastActiveDate == null) {
      _lastActiveDate = now;
      _saveStreakState(lastActiveOverride: todayKey);
      return;
    }
    if (_isSameDay(_lastActiveDate!, now)) return;

    final lastKey = _dayKey(_lastActiveDate!);
    final gapDays = _daysBetween(lastKey, todayKey);

    TokenService.instance.resetDailyEarnedIfNeeded(todayKey);
    if (!_yesterdayCompleted && _streakDays > 0) {
      _streakSavePending = true;
      _prevStreakDays = _streakDays;
    } else if (gapDays == 1 && _yesterdayCompleted) {
      _streakDays = _streakDays <= 0 ? 1 : _streakDays + 1;
      _prevStreakDays = _streakDays;
    } else if (gapDays > 1) {
      _prevStreakDays = _streakDays;
      _streakDays = 0;
    }

    _yesterdayCompleted = _todayCompleted;
    _todayCompleted = false;
    resetDailyProgress(continuedStreak: _yesterdayCompleted);
    _lastActiveDate = now;
    _saveStreakState(lastActiveOverride: todayKey);
  }

  AnswerResult recordAnswer({required bool isCorrect, required int difficulty}) {
    ensureDailyState();
    var gained = isCorrect ? 10 : 6;
    final shopState = ShopStateService.instance;
    if (shopState.isReady) {
      final remaining = shopState.effectRemaining(ShopStateService.focusXpRemainingKey);
      if (remaining > 0) {
        gained = (gained * 1.2).floor();
      }
    }
    _dailyAnswered += 1;
    _dailyXp += gained;
    _lastActiveDate = DateTime.now();
    final completedDailyTarget = _dailyAnswered == dailyTarget;
    if (completedDailyTarget && !_todayCompleted) {
      _todayCompleted = true;
      TokenService.instance.awardDailyCompletion(todayKey);
      _saveStreakState();
    }
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

  String _dayKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}'
        '-${date.month.toString().padLeft(2, '0')}'
        '-${date.day.toString().padLeft(2, '0')}';
  }

  int _daysBetween(String from, String to) {
    final fromDate = DateTime.tryParse(from) ?? DateTime.now();
    final toDate = DateTime.tryParse(to) ?? DateTime.now();
    return toDate.difference(fromDate).inDays;
  }

  void _saveStreakState({String? lastActiveOverride}) {
    if (_prefs == null) return;
    _prefs!.setInt(_streakKey, _streakDays);
    _prefs!.setBool(_todayCompletedKey, _todayCompleted);
    _prefs!.setBool(_yesterdayCompletedKey, _yesterdayCompleted);
    _prefs!.setBool(_streakSavePendingKey, _streakSavePending);
    _prefs!.setInt(_prevStreakKey, _prevStreakDays);
    final lastKey = lastActiveOverride ?? (_lastActiveDate != null ? _dayKey(_lastActiveDate!) : null);
    if (lastKey != null) {
      _prefs!.setString(_lastActiveKey, lastKey);
    }
  }
}
