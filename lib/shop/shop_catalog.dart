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
      id: 'util_skip_question',
      titleZh: '跳題券',
      subtitleZh: '跳過這題，不扣分、不計次',
      category: ShopCategory.utility,
      priceTokens: 80,
      kind: ShopItemKind.consumable,
      isEnabled: true,
    ),
    ShopItem(
      id: 'util_reroll_question',
      titleZh: '換題券',
      subtitleZh: '換一題新的（不計次）',
      category: ShopCategory.utility,
      priceTokens: 60,
      kind: ShopItemKind.consumable,
      isEnabled: true,
    ),
    ShopItem(
      id: 'cosmetic_theme_night',
      titleZh: '夜間主題',
      subtitleZh: '更舒服的暗色介面',
      category: ShopCategory.cosmetic,
      priceTokens: 200,
      kind: ShopItemKind.equipable,
      isEnabled: true,
    ),
  ];
}
