class TokenService {
  TokenService._();

  static final TokenService instance = TokenService._();

  int knowledgeToken = 0;
  bool _mistakeShieldActive = false;

  void addToken(int amount) {
    if (amount <= 0) return;
    knowledgeToken += amount;
  }

  void deductToken(int amount) {
    if (amount <= 0) return;
    knowledgeToken = (knowledgeToken - amount).clamp(0, knowledgeToken);
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
