import 'package:shared_preferences/shared_preferences.dart';

class TokenService {
  TokenService._();

  static final TokenService instance = TokenService._();
  static const _tokenKey = 'loom_tokens';
  static const _earnedTodayKey = 'loom_tokens_earned_today';
  static const _earnedDateKey = 'loom_tokens_earned_date';
  static const _dailyBonusDateKey = 'loom_daily_token_bonus_date';
  static const _golden3DateKey = 'loom_golden3_bonus_date';

  static const _dailyCap = 30;

  int knowledgeToken = 0;
  int _earnedToday = 0;
  String? _earnedDate;
  bool _mistakeShieldActive = false;
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    knowledgeToken = _prefs?.getInt(_tokenKey) ?? 0;
    _earnedToday = _prefs?.getInt(_earnedTodayKey) ?? 0;
    _earnedDate = _prefs?.getString(_earnedDateKey);
  }

  Future<void> _save() async {
    if (_prefs == null) return;
    await _prefs!.setInt(_tokenKey, knowledgeToken);
    await _prefs!.setInt(_earnedTodayKey, _earnedToday);
    if (_earnedDate != null) {
      await _prefs!.setString(_earnedDateKey, _earnedDate!);
    }
  }

  void resetDailyEarnedIfNeeded(String todayKey) {
    if (_earnedDate != todayKey) {
      _earnedDate = todayKey;
      _earnedToday = 0;
      _save();
    }
  }

  void addTokenWithCap(int amount, String todayKey) {
    if (amount <= 0) return;
    resetDailyEarnedIfNeeded(todayKey);
    if (_earnedToday >= _dailyCap) return;
    final allowed = (_dailyCap - _earnedToday).clamp(0, amount);
    if (allowed == 0) return;
    knowledgeToken += allowed;
    _earnedToday += allowed;
    _save();
  }

  void deductToken(int amount) {
    if (amount <= 0) return;
    knowledgeToken = (knowledgeToken - amount).clamp(0, knowledgeToken);
    _save();
  }

  bool canAfford(int amount) {
    if (amount <= 0) return true;
    return knowledgeToken >= amount;
  }

  bool awardDailyCompletion(String todayKey) {
    resetDailyEarnedIfNeeded(todayKey);
    final last = _prefs?.getString(_dailyBonusDateKey);
    if (last == todayKey) return false;
    addTokenWithCap(8, todayKey);
    _prefs?.setString(_dailyBonusDateKey, todayKey);
    return true;
  }

  bool awardGolden3(String todayKey) {
    resetDailyEarnedIfNeeded(todayKey);
    final last = _prefs?.getString(_golden3DateKey);
    if (last == todayKey) return false;
    addTokenWithCap(5, todayKey);
    _prefs?.setString(_golden3DateKey, todayKey);
    return true;
  }

  void activateMistakeShield() {
    _mistakeShieldActive = true;
  }

  bool consumeMistakeShield() {
    if (!_mistakeShieldActive) return false;
    _mistakeShieldActive = false;
    return true;
  }
}
