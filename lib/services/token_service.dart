class TokenService {
  TokenService._();

  static final TokenService instance = TokenService._();

  int knowledgeToken = 0;

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
}
