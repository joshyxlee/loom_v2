enum ShopCategory { boost, utility, cosmetic }

enum ShopItemKind { consumable, owned, equipable }

enum ShopEffect { mistakeShield }

class ShopItem {
  const ShopItem({
    required this.id,
    required this.titleZh,
    required this.subtitleZh,
    required this.category,
    required this.priceTokens,
    required this.kind,
    required this.isEnabled,
    this.effect,
  });

  final String id;
  final String titleZh;
  final String subtitleZh;
  final ShopCategory category;
  final int priceTokens;
  final ShopItemKind kind;
  final bool isEnabled;
  final ShopEffect? effect;
}
