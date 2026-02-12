import 'package:shared_preferences/shared_preferences.dart';

import 'shop_state_service.dart';

class TokenService {
  TokenService._();

  static final TokenService instance = TokenService._();
  static const _tokenKey = 'loom_tokens';
  static const _earnedTodayKey = 'loom_tokens_earned_today';
  static const _earnedDateKey = 'loom_tokens_earned_date';
  static const _dailyBonusDateKey = 'loom_daily_token_bonus_date';
  static const _golden3DateKey = 'loom_golden3_bonus_date';
  static const _dailyTokenKey = 'loom_daily_token_v1';
  static const _firstDayBonusKey = 'loom_first_day_bonus_given_v1';

  static const _dailyCap = 30;
  static const _dailyTokenCap = 10;

  int knowledgeToken = 0;
  int _earnedToday = 0;
  int _dailyTokenEarned = 0;
  String? _earnedDate;
  bool _mistakeShieldActive = false;
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    knowledgeToken = _prefs?.getInt(_tokenKey) ?? 0;
    _earnedToday = _prefs?.getInt(_earnedTodayKey) ?? 0;
    _dailyTokenEarned = _prefs?.getInt(_dailyTokenKey) ?? 0;
    _earnedDate = _prefs?.getString(_earnedDateKey);
  }

  Future<void> _save() async {
    if (_prefs == null) return;
    await _prefs!.setInt(_tokenKey, knowledgeToken);
    await _prefs!.setInt(_earnedTodayKey, _earnedToday);
    await _prefs!.setInt(_dailyTokenKey, _dailyTokenEarned);
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

  void resetDailyToken() {
    _dailyTokenEarned = 0;
    _prefs?.setInt(_dailyTokenKey, _dailyTokenEarned);
  }

  void addToken(int amount) {
    if (amount <= 0) return;
    knowledgeToken += amount;
    _save();
  }

  void addTokenFromAnswer(int amount) {
    if (amount <= 0) return;
    if (_dailyTokenEarned >= _dailyTokenCap) return;
    var finalAmount = amount;
    final shopState = ShopStateService.instance;
    if (shopState.isReady) {
      final remaining =
          shopState.effectRemaining(ShopStateService.doubleTokenRemainingKey);
      if (remaining > 0) {
        finalAmount = amount * 2;
        shopState.setEffectRemaining(
          ShopStateService.doubleTokenRemainingKey,
          remaining - 1,
        );
      }
    }
    final allowed = (_dailyTokenCap - _dailyTokenEarned).clamp(0, finalAmount);
    if (allowed == 0) return;
    knowledgeToken += allowed;
    _dailyTokenEarned += allowed;
    _save();
  }

  bool grantFirstDayBonus() {
    final given = _prefs?.getBool(_firstDayBonusKey) ?? false;
    if (given) return false;
    addToken(20);
    _prefs?.setBool(_firstDayBonusKey, true);
    return true;
  }

  void addTokenWithCap(int amount, String todayKey, {String source = 'generic'}) {
    if (amount <= 0) return;
    resetDailyEarnedIfNeeded(todayKey);
    var finalAmount = amount;
    if (source == 'answer_correct') {
      final shopState = ShopStateService.instance;
      if (shopState.isReady) {
        final remaining = shopState.effectRemaining(ShopStateService.doubleTokenRemainingKey);
        if (remaining > 0) {
          finalAmount = amount * 2;
          shopState.setEffectRemaining(ShopStateService.doubleTokenRemainingKey, remaining - 1);
        }
      }
    }
    if (_earnedToday >= _dailyCap) return;
    final allowed = (_dailyCap - _earnedToday).clamp(0, finalAmount);
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
