import 'shop_models.dart';

const mistakeShieldItemId = 'boost_mistake_shield';

List<ShopItem> buildShopCatalog() {
  return const [
    ShopItem(
      id: mistakeShieldItemId,
      titleZh: '失誤保護卡',
      subtitleZh: '第一次答錯不扣分，保住這一回合。',
      category: ShopCategory.boost,
      priceTokens: 150,
      kind: ShopItemKind.consumable,
      isEnabled: true,
      effect: ShopEffect.mistakeShield,
    ),
    ShopItem(
      id: 'boost_focus_xp',
      titleZh: '專注強化',
      subtitleZh: '+20% XP（接下來 5 題）',
      category: ShopCategory.boost,
      priceTokens: 120,
      kind: ShopItemKind.consumable,
      isEnabled: true,
      effect: ShopEffect.focusXp,
    ),
    ShopItem(
      id: 'boost_double_token',
      titleZh: '雙倍獎勵',
      subtitleZh: '接下來 3 次答對，知識幣×2',
      category: ShopCategory.boost,
      priceTokens: 180,
      kind: ShopItemKind.consumable,
      isEnabled: true,
      effect: ShopEffect.doubleToken,
    ),
    ShopItem(
      id: 'cosmetic_custom',
      titleZh: '自訂外觀',
      subtitleZh: '為你的成長旅程加上一點個性。',
      category: ShopCategory.cosmetic,
      priceTokens: 200,
      kind: ShopItemKind.owned,
      isEnabled: false,
    ),
  ];
}
