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
      id: 'boost_focus',
      titleZh: '專注強化',
      subtitleZh: '短時間內提升專注力的狀態加成。',
      category: ShopCategory.boost,
      priceTokens: 120,
      kind: ShopItemKind.consumable,
      isEnabled: false,
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
