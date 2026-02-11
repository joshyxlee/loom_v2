import 'package:flutter/material.dart';

import '../services/token_service.dart';
import '../widgets/design_system.dart';
import '../widgets/loom_card.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int _tabIndex = 0;

  void _handlePurchase(BuildContext context, int price, {bool activateShield = false}) {
    final service = TokenService.instance;
    if (!service.canAfford(price)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('知識幣不足')),
      );
      return;
    }
    service.deductToken(price);
    if (activateShield) {
      service.activateMistakeShield();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('購買成功')),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final token = TokenService.instance.knowledgeToken;
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
            ShopItemCard(
              title: '失誤保護卡',
              description: '第一次答錯不扣分，保住這一回合。',
              price: 150,
              onPurchase: () => _handlePurchase(context, 150, activateShield: true),
            ),
            const SizedBox(height: LoomSpacing.sm),
            ShopItemCard(
              title: '專注強化',
              description: '短時間內提升專注力的狀態加成。',
              price: 120,
              onPurchase: () => _handlePurchase(context, 120),
            ),
            const SizedBox(height: LoomSpacing.sm),
            ShopItemCard(
              title: '自訂外觀',
              description: '為你的成長旅程加上一點個性。',
              price: 200,
              onPurchase: () => _handlePurchase(context, 200),
            ),
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
  });

  final String title;
  final String description;
  final int price;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    return LoomCard(
      child: Column(
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
                onPressed: onPurchase,
                child: const Text('購買'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
