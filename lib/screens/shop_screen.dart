import 'package:flutter/material.dart';

import '../services/token_service.dart';
import '../services/inventory_service.dart';
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
    await InventoryService.instance.add(item.id, 1);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已購買：${item.titleZh}（+1）')),
    );
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = TokenService.instance.knowledgeToken;
    final inventory = InventoryService.instance;
    if (!inventory.isReady) {
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
                  label: '個性',
                  isActive: _tabIndex == 1,
                  onTap: () => setState(() => _tabIndex = 1),
                ),
                const SizedBox(width: LoomSpacing.base),
                _TabButton(
                  label: '解鎖',
                  isActive: _tabIndex == 2,
                  onTap: () => setState(() => _tabIndex = 2),
                ),
                const SizedBox(width: LoomSpacing.base),
                _TabButton(
                  label: '限時',
                  isActive: _tabIndex == 3,
                  onTap: () => setState(() => _tabIndex = 3),
                ),
              ],
            ),
            const SizedBox(height: LoomSpacing.md),
            ...buildShopCatalog().map((item) {
              final count = item.kind == ShopItemKind.consumable
                  ? inventory.count(item.id)
                  : 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: LoomSpacing.sm),
                child: ShopItemCard(
                  title: item.titleZh,
                  description: item.subtitleZh,
                  price: item.priceTokens,
                  badgeCount: item.kind == ShopItemKind.consumable ? count : null,
                  actionLabel: item.isEnabled ? '購買' : '即將推出',
                  actionEnabled: item.isEnabled,
                  onPurchase: () => _handlePurchase(context, item),
                ),
              );
            }),
          ],
        ),
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
    this.badgeCount,
  });

  final String title;
  final String description;
  final int price;
  final VoidCallback onPurchase;
  final String actionLabel;
  final bool actionEnabled;
  final int? badgeCount;

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
              const SizedBox(height: LoomSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('價格 \$$price', style: LoomTypography.body),
                  TextButton(
                    onPressed: actionEnabled ? onPurchase : null,
                    child: Text(actionLabel),
                  ),
                ],
              ),
            ],
          ),
          if (badgeCount != null)
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
                  '持有 x$badgeCount',
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
