import 'package:shared_preferences/shared_preferences.dart';

class TokenService {
  TokenService._();

  static final TokenService instance = TokenService._();
  static const _tokenKey = 'loom_tokens';

  int knowledgeToken = 0;
  bool _mistakeShieldActive = false;
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    knowledgeToken = _prefs?.getInt(_tokenKey) ?? 0;
  }

  Future<void> _save() async {
    if (_prefs == null) return;
    await _prefs!.setInt(_tokenKey, knowledgeToken);
  }

  void addToken(int amount) {
    if (amount <= 0) return;
    knowledgeToken += amount;
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

  void activateMistakeShield() {
    _mistakeShieldActive = true;
  }

  bool consumeMistakeShield() {
    if (!_mistakeShieldActive) return false;
    _mistakeShieldActive = false;
    return true;
  }
}
