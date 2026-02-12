import 'package:flutter/material.dart';

import '../services/token_service.dart';
import '../services/inventory_service.dart';
import '../services/shop_state_service.dart';
import '../shop/shop_catalog.dart';
import '../shop/shop_models.dart';
import '../widgets/design_system.dart';
import '../widgets/loom_card.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int _tabIndex = 0;

  Future<void> _handlePurchase(BuildContext context, ShopItem item) async {
    if (!item.isEnabled) return;
    final shopState = ShopStateService.instance;
    if (item.kind == ShopItemKind.equipable && shopState.isOwned(item.id)) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認購買？'),
        content: Text('將花費 ${item.priceTokens} 知識幣購買「${item.titleZh}」。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('購買'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final service = TokenService.instance;
    if (!service.canAfford(item.priceTokens)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('知識幣不足')),
      );
      return;
    }
    service.deductToken(item.priceTokens);
    if (item.kind == ShopItemKind.equipable) {
      await shopState.addOwned(item.id);
    } else {
      await InventoryService.instance.add(item.id, 1);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已購買：${item.titleZh}')),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleUse(BuildContext context, ShopItem item) async {
    final inventory = InventoryService.instance;
    final shopState = ShopStateService.instance;
    if (item.kind == ShopItemKind.equipable) {
      await shopState.equip('theme', item.id);
      if (mounted) {
        setState(() {});
      }
      return;
    }
    final count = inventory.count(item.id);
    if (count <= 0) return;
    if (item.effect == ShopEffect.focusXp &&
        shopState.effectRemaining(ShopStateService.focusXpRemainingKey) > 0) {
      return;
    }
    if (item.effect == ShopEffect.doubleToken &&
        shopState.effectRemaining(ShopStateService.doubleTokenRemainingKey) > 0) {
      return;
    }
    if (item.id == 'boost_xp_burst') {
      final focusActive =
          shopState.effectRemaining(ShopStateService.focusXpRemainingKey) > 0;
      if (focusActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已啟用專注強化，結束後再使用')),
        );
        return;
      }
      final burstActive =
          shopState.effectRemaining(ShopStateService.xpBurstRemainingKey) > 0;
      if (burstActive) {
        return;
      }
    }
    final consumed = await inventory.consume(item.id);
    if (!consumed) return;
    if (item.effect == ShopEffect.focusXp) {
      await shopState.setEffectRemaining(ShopStateService.focusXpRemainingKey, 5);
    }
    if (item.effect == ShopEffect.doubleToken) {
      await shopState.setEffectRemaining(ShopStateService.doubleTokenRemainingKey, 3);
    }
    if (item.id == 'boost_xp_burst') {
      await shopState.setEffectRemaining(ShopStateService.xpBurstRemainingKey, 3);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已啟用：${item.titleZh}')),
    );
    setState(() {});
  }

  List<Widget> _buildSection(String title, ShopCategory category) {
    final inventory = InventoryService.instance;
    final shopState = ShopStateService.instance;
    final items = buildShopCatalog().where((item) => item.category == category).toList();
    if (items.isEmpty) {
      return [
        Text(title, style: LoomTypography.sectionTitle),
        const SizedBox(height: LoomSpacing.sm),
        Text('此分類暫無商品', style: LoomTypography.body),
      ];
    }
    return [
      Text(title, style: LoomTypography.sectionTitle),
      const SizedBox(height: LoomSpacing.sm),
      ...items.map((item) {
        final count = item.kind == ShopItemKind.consumable
            ? inventory.count(item.id)
            : 0;
        final focusRemaining =
            shopState.effectRemaining(ShopStateService.focusXpRemainingKey);
        final burstRemaining =
            shopState.effectRemaining(ShopStateService.xpBurstRemainingKey);
        final doubleRemaining =
            shopState.effectRemaining(ShopStateService.doubleTokenRemainingKey);
        final isOwned = item.kind == ShopItemKind.equipable && shopState.isOwned(item.id);
        final isEquipped =
            item.kind == ShopItemKind.equipable && shopState.equippedFor('theme') == item.id;
        String? statusText;
        if (item.id == 'boost_xp_burst' && burstRemaining > 0) {
          statusText = '啟用中：剩餘 $burstRemaining/3';
        }
        if (item.effect == ShopEffect.focusXp && focusRemaining > 0) {
          statusText = '啟用中：剩餘 $focusRemaining/5';
        }
        if (item.effect == ShopEffect.doubleToken && doubleRemaining > 0) {
          statusText = '啟用中：剩餘 $doubleRemaining/3';
        }
        String? badgeText;
        if (isEquipped) {
          badgeText = '使用中';
        } else if (isOwned) {
          badgeText = '已擁有';
        }
        final canUse = item.effect == ShopEffect.focusXp
            ? count > 0 && focusRemaining == 0
            : item.effect == ShopEffect.doubleToken
                ? count > 0 && doubleRemaining == 0
                : item.id == 'boost_xp_burst'
                    ? count > 0 && burstRemaining == 0
                    : item.kind == ShopItemKind.equipable
                        ? isOwned && !isEquipped
                        : false;
        final showUse = item.effect == ShopEffect.focusXp ||
            item.effect == ShopEffect.doubleToken ||
            item.id == 'boost_xp_burst' ||
            item.kind == ShopItemKind.equipable;
        final actionLabel = item.kind == ShopItemKind.equipable
            ? (isOwned ? (isEquipped ? '使用中' : '使用') : '購買')
            : item.isEnabled
                ? '購買'
                : '即將推出';
        final actionEnabled = item.kind == ShopItemKind.equipable
            ? !isEquipped
            : item.isEnabled;
        final secondaryActionLabel =
            item.kind == ShopItemKind.equipable ? '' : (showUse ? '使用' : '');
        final actionHandler = item.kind == ShopItemKind.equipable && isOwned && !isEquipped
            ? () => _handleUse(context, item)
            : () => _handlePurchase(context, item);
        String? helperText;
        if (item.effect == ShopEffect.focusXp || item.effect == ShopEffect.doubleToken) {
          helperText = '啟用後會自動倒數';
        } else if (item.id == 'boost_xp_burst') {
          helperText = '啟用後會自動倒數';
        } else if (item.id == 'util_skip_question' || item.id == 'util_reroll_question') {
          helperText = '不計次、不扣分';
        } else if (item.id == 'util_hint_reveal') {
          helperText = '排除錯誤選項';
        } else if (item.id == 'cosmetic_theme_night') {
          helperText = '永久擁有，可隨時切換';
        } else if (item.kind == ShopItemKind.consumable) {
          helperText = '購買後會先存起來';
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: LoomSpacing.sm),
          child: ShopItemCard(
            title: item.titleZh,
            description: item.subtitleZh,
            price: item.priceTokens,
            badgeCount: item.kind == ShopItemKind.consumable ? count : null,
            badgeText: badgeText,
            statusText: statusText,
            helperText: helperText,
            actionLabel: actionLabel,
            actionEnabled: actionEnabled,
            secondaryActionLabel: secondaryActionLabel,
            secondaryActionEnabled: item.kind == ShopItemKind.equipable ? false : canUse,
            onPurchase: actionHandler,
            onSecondaryAction: () => _handleUse(context, item),
          ),
        );
      }),
    ];
  }

  ShopCategory _selectedCategory() {
    switch (_tabIndex) {
      case 0:
        return ShopCategory.boost;
      case 1:
        return ShopCategory.utility;
      case 2:
        return ShopCategory.cosmetic;
      case 3:
        return ShopCategory.unlock;
      case 4:
        return ShopCategory.limited;
      default:
        return ShopCategory.boost;
    }
  }

  String _selectedCategoryLabel() {
    switch (_tabIndex) {
      case 0:
        return '強化';
      case 1:
        return '實用';
      case 2:
        return '個性';
      case 3:
        return '解鎖';
      case 4:
        return '限時';
      default:
        return '強化';
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = TokenService.instance.knowledgeToken;
    final inventory = InventoryService.instance;
    final shopState = ShopStateService.instance;
    if (!inventory.isReady || !shopState.isReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('商城'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: LoomSpacing.screen),
            child: _TokenBadge(tokens: token),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(LoomSpacing.screen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _TabButton(
                  label: '強化',
                  isActive: _tabIndex == 0,
                  onTap: () => setState(() => _tabIndex = 0),
                ),
                const SizedBox(width: LoomSpacing.base),
                _TabButton(
                  label: '實用',
                  isActive: _tabIndex == 1,
                  onTap: () => setState(() => _tabIndex = 1),
                ),
                const SizedBox(width: LoomSpacing.base),
                _TabButton(
                  label: '個性',
                  isActive: _tabIndex == 2,
                  onTap: () => setState(() => _tabIndex = 2),
                ),
                const SizedBox(width: LoomSpacing.base),
                _TabButton(
                  label: '解鎖',
                  isActive: _tabIndex == 3,
                  onTap: () => setState(() => _tabIndex = 3),
                ),
                const SizedBox(width: LoomSpacing.base),
                _TabButton(
                  label: '限時',
                  isActive: _tabIndex == 4,
                  onTap: () => setState(() => _tabIndex = 4),
                ),
              ],
            ),
            const SizedBox(height: LoomSpacing.md),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MyItemsCard(
                      focusRemaining: shopState.effectRemaining(
                        ShopStateService.focusXpRemainingKey,
                      ),
                      doubleRemaining: shopState.effectRemaining(
                        ShopStateService.doubleTokenRemainingKey,
                      ),
                      shieldCount: inventory.count('boost_mistake_shield'),
                      skipCount: inventory.count('util_skip_question'),
                      rerollCount: inventory.count('util_reroll_question'),
                      themeId: shopState.equippedFor('theme'),
                    ),
                    const SizedBox(height: LoomSpacing.md),
                    ..._buildSection(
                      _selectedCategoryLabel(),
                      _selectedCategory(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyItemsCard extends StatelessWidget {
  const _MyItemsCard({
    required this.focusRemaining,
    required this.doubleRemaining,
    required this.shieldCount,
    required this.skipCount,
    required this.rerollCount,
    required this.themeId,
  });

  final int focusRemaining;
  final int doubleRemaining;
  final int shieldCount;
  final int skipCount;
  final int rerollCount;
  final String? themeId;

  @override
  Widget build(BuildContext context) {
    final hasActive = focusRemaining > 0 || doubleRemaining > 0;
    final themeLabel = themeId == 'cosmetic_theme_night' ? '夜間（使用中）' : '預設';
    return LoomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('我的道具', style: LoomTypography.sectionTitle),
          const SizedBox(height: LoomSpacing.base),
          if (hasActive) ...[
            if (focusRemaining > 0)
              Text('專注強化：剩餘 $focusRemaining/5 題', style: LoomTypography.body),
            if (doubleRemaining > 0)
              Text('雙倍獎勵：剩餘 $doubleRemaining/3 次答對', style: LoomTypography.body),
          ] else
            Text('目前沒有啟用中的加成', style: LoomTypography.body),
          const SizedBox(height: LoomSpacing.base),
          Text(
            '失誤保護卡 x$shieldCount · 跳題券 x$skipCount · 換題券 x$rerollCount',
            style: LoomTypography.body,
          ),
          const SizedBox(height: LoomSpacing.base),
          Text('主題：$themeLabel', style: LoomTypography.body),
        ],
      ),
    );
  }
}

class _TokenBadge extends StatelessWidget {
  const _TokenBadge({required this.tokens});

  final int tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: LoomColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          '知識幣 \$$tokens',
          style: LoomTypography.body.copyWith(
            fontWeight: FontWeight.w400,
            color: LoomColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? LoomColors.primary.withOpacity(0.12) : LoomColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: LoomColors.divider),
        ),
        child: Text(
          label,
          style: LoomTypography.body.copyWith(
            fontWeight: FontWeight.w600,
            color: isActive ? LoomColors.primary : LoomColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class ShopItemCard extends StatelessWidget {
  const ShopItemCard({
    super.key,
    required this.title,
    required this.description,
    required this.price,
    required this.onPurchase,
    required this.actionLabel,
    required this.actionEnabled,
    required this.secondaryActionLabel,
    required this.secondaryActionEnabled,
    required this.onSecondaryAction,
    this.badgeCount,
    this.badgeText,
    this.statusText,
    this.helperText,
  });

  final String title;
  final String description;
  final int price;
  final VoidCallback onPurchase;
  final String actionLabel;
  final bool actionEnabled;
  final String secondaryActionLabel;
  final bool secondaryActionEnabled;
  final VoidCallback onSecondaryAction;
  final int? badgeCount;
  final String? badgeText;
  final String? statusText;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return LoomCard(
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: LoomTypography.sectionTitle),
              const SizedBox(height: LoomSpacing.base),
              Text(description,
                  style: LoomTypography.body.copyWith(color: LoomColors.textSecondary)),
              if (statusText != null) ...[
                const SizedBox(height: LoomSpacing.sm),
                Text(
                  statusText!,
                  style: LoomTypography.body.copyWith(color: LoomColors.primary),
                ),
              ],
              if (helperText != null) ...[
                const SizedBox(height: LoomSpacing.sm),
                Text(
                  helperText!,
                  style: LoomTypography.secondary.copyWith(color: LoomColors.textSecondary),
                ),
              ],
              const SizedBox(height: LoomSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('價格 \$$price', style: LoomTypography.body),
                  Row(
                    children: [
                      if (secondaryActionLabel.isNotEmpty)
                        TextButton(
                          onPressed: secondaryActionEnabled ? onSecondaryAction : null,
                          child: Text(secondaryActionLabel),
                        ),
                      TextButton(
                        onPressed: actionEnabled ? onPurchase : null,
                        child: Text(actionLabel),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          if (badgeCount != null || badgeText != null)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: LoomColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeText ?? '持有 x$badgeCount',
                  style: LoomTypography.body.copyWith(
                    fontSize: 12,
                    color: LoomColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
