import 'package:flutter/material.dart';

import '../data/subjects.dart';
import '../models/question.dart';
import '../models/subject.dart';
import '../repositories/question_repository.dart';
import '../services/core_data_store.dart';
import '../services/inventory_service.dart';
import '../services/progress_service.dart';
import '../services/shop_state_service.dart';
import '../shop/shop_catalog.dart';
import '../shop/shop_models.dart';
import '../widgets/design_system.dart';
import '../widgets/loom_card.dart';
import '../widgets/loom_section.dart';
import 'package:loom_v2/main.dart' show QuizScreen, AdvancedChallengeScreen;

enum BackpackSection { boost, utility, cosmetic }

class BackpackScreen extends StatefulWidget {
  const BackpackScreen({
    super.key,
    required this.repository,
    required this.progressService,
    required this.coreDataStore,
    this.focusSection,
    this.focusItemId,
  });

  final String? focusItemId;

  final QuestionRepository repository;
  final ProgressService progressService;
  final CoreDataStore coreDataStore;
  final BackpackSection? focusSection;

  @override
  State<BackpackScreen> createState() => _BackpackScreenState();
}

class _BackpackScreenState extends State<BackpackScreen> {
  final _scrollController = ScrollController();
  final _boostKey = GlobalKey();
  final _utilityKey = GlobalKey();
  final _cosmeticKey = GlobalKey();
  final Map<String, GlobalKey> _itemKeys = {
    'boost_mistake_shield': GlobalKey(),
    'boost_focus_xp': GlobalKey(),
    'boost_double_token': GlobalKey(),
    'boost_xp_burst': GlobalKey(),
    'boost_streak_saver': GlobalKey(),
    'util_skip_question': GlobalKey(),
    'util_hint_reveal': GlobalKey(),
    'util_reroll_question': GlobalKey(),
    'cosmetic_theme_night': GlobalKey(),
    'cosmetic_theme_ocean': GlobalKey(),
    'cosmetic_theme_warm': GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final focusKey = widget.focusItemId != null
          ? _itemKeys[widget.focusItemId!]
          : null;
      if (focusKey?.currentContext != null) {
        Scrollable.ensureVisible(
          focusKey!.currentContext!,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
        return;
      }
      final targetKey = switch (widget.focusSection) {
        BackpackSection.boost => _boostKey,
        BackpackSection.utility => _utilityKey,
        BackpackSection.cosmetic => _cosmeticKey,
        _ => null,
      };
      if (targetKey?.currentContext != null) {
        Scrollable.ensureVisible(
          targetKey!.currentContext!,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startSubject(Subject subject) async {
    final questions = await widget.repository.getSession(
      subject: subject.key,
      count: 5,
    );
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          questions: questions,
          progressService: widget.progressService,
          coreDataStore: widget.coreDataStore,
          subjectTitle: subject.title,
          subject: subject,
          repository: widget.repository,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final inventory = InventoryService.instance;
    final shopState = ShopStateService.instance;
    final items = buildShopCatalog();

    return Scaffold(
      appBar: AppBar(title: const Text('背包')),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(LoomSpacing.screen),
        children: [
          LoomCard(
            background: LoomTheme.card(context),
            borderColor: LoomTheme.border(context),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: LoomTheme.accent(context)),
                const SizedBox(width: LoomSpacing.base),
                Expanded(
                  child: Text(
                    '提示：回合中到右上角使用 跳題/換題/提示',
                    style: LoomTypography.secondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: LoomSpacing.md),
          LoomSectionHeader(
            title: '目前主題：${_themeLabel(shopState.equippedFor('theme'))}',
          ),
          const SizedBox(height: LoomSpacing.sm),
          _SectionBlock(
            key: _boostKey,
            title: '強化',
            subtitle: '一次只能啟用一種加成',
            children: items
                .where((item) => item.category == ShopCategory.boost)
                .map(
                  (item) => _KeyedItem(
                    key: _itemKeys[item.id],
                    child: _BoostItemCard(item: item, inventory: inventory),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: LoomSpacing.md),
          _SectionBlock(
            key: _utilityKey,
            title: '實用',
            subtitle: '回合中右上角可用',
            children: items
                .where((item) => item.category == ShopCategory.utility)
                .map(
                  (item) => _KeyedItem(
                    key: _itemKeys[item.id],
                    child: _UtilityItemCard(item: item, inventory: inventory),
                  ),
                )
                .toList(),
            footer: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _openChallengePicker(),
                child: const Text('進入回合測試'),
              ),
            ),
          ),
          const SizedBox(height: LoomSpacing.md),
          _SectionBlock(
            key: _cosmeticKey,
            title: '個性',
            subtitle: null,
            children: items
                .where((item) => item.category == ShopCategory.cosmetic)
                .map(
                  (item) => _KeyedItem(
                    key: _itemKeys[item.id],
                    child: _ThemeItemCard(item: item),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  void _openChallengePicker() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdvancedChallengeScreen(
          subjects: subjects,
          onStartSubject: (subject) => _startSubject(subject),
        ),
      ),
    );
  }

  String _themeLabel(String? themeId) {
    return switch (themeId) {
      'cosmetic_theme_night' => '夜間（使用中）',
      'cosmetic_theme_ocean' => '海洋（使用中）',
      'cosmetic_theme_warm' => '暖陽（使用中）',
      _ => '預設',
    };
  }
}

class _KeyedItem extends StatelessWidget {
  const _KeyedItem({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LoomSectionHeader(title: title, subtitle: subtitle),
        const SizedBox(height: LoomSpacing.sm),
        ...children,
        if (footer != null) ...[
          const SizedBox(height: LoomSpacing.sm),
          footer!,
        ],
      ],
    );
  }
}

class _BoostItemCard extends StatelessWidget {
  const _BoostItemCard({required this.item, required this.inventory});

  final ShopItem item;
  final InventoryService inventory;

  @override
  Widget build(BuildContext context) {
    final shopState = ShopStateService.instance;
    final count = inventory.count(item.id);
    final focusRemaining =
        shopState.effectRemaining(ShopStateService.focusXpRemainingKey);
    final burstRemaining =
        shopState.effectRemaining(ShopStateService.xpBurstRemainingKey);
    final doubleRemaining =
        shopState.effectRemaining(ShopStateService.doubleTokenRemainingKey);
    final activeText = item.id == 'boost_xp_burst' && burstRemaining > 0
        ? '啟用中：剩餘 $burstRemaining/3'
        : item.effect == ShopEffect.focusXp && focusRemaining > 0
            ? '啟用中：剩餘 $focusRemaining/5'
            : item.effect == ShopEffect.doubleToken && doubleRemaining > 0
                ? '啟用中：剩餘 $doubleRemaining/3'
                : null;

    final canUse = item.effect == ShopEffect.focusXp
        ? count > 0 && focusRemaining == 0
        : item.effect == ShopEffect.doubleToken
            ? count > 0 && doubleRemaining == 0
            : item.id == 'boost_xp_burst'
                ? count > 0 && burstRemaining == 0
                : false;

    return Padding(
      padding: const EdgeInsets.only(bottom: LoomSpacing.sm),
      child: LoomCard(
        background: LoomTheme.card(context),
        borderColor: LoomTheme.border(context),
        child: Row(
          children: [
            Icon(Icons.flash_on, size: 18, color: LoomTheme.accent(context)),
            const SizedBox(width: LoomSpacing.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.titleZh, style: LoomTypography.body),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitleZh,
                    style: LoomTypography.secondary.copyWith(
                      color: LoomTheme.textSecondary(context),
                    ),
                  ),
                  if (activeText != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      activeText,
                      style: LoomTypography.secondary.copyWith(
                        color: LoomTheme.accent(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: LoomSpacing.base),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _CountBadge(count: count),
                const SizedBox(height: 4),
                if (activeText != null)
                  TextButton(onPressed: null, child: const Text('啟用中'))
                else if (canUse)
                  TextButton(
                    onPressed: () async {
                      if (item.id == 'boost_xp_burst' && focusRemaining > 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已啟用專注強化，結束後再使用')),
                        );
                        return;
                      }
                      final consumed = await inventory.consume(item.id);
                      if (!consumed) return;
                      if (item.effect == ShopEffect.focusXp) {
                        await shopState.setEffectRemaining(
                            ShopStateService.focusXpRemainingKey, 5);
                      }
                      if (item.effect == ShopEffect.doubleToken) {
                        await shopState.setEffectRemaining(
                            ShopStateService.doubleTokenRemainingKey, 3);
                      }
                      if (item.id == 'boost_xp_burst') {
                        await shopState.setEffectRemaining(
                            ShopStateService.xpBurstRemainingKey, 3);
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已啟用：${item.titleZh}')),
                      );
                    },
                    child: const Text('使用'),
                  )
                else
                  TextButton(onPressed: null, child: const Text('使用')),
                if (count == 0)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('去商城'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UtilityItemCard extends StatelessWidget {
  const _UtilityItemCard({required this.item, required this.inventory});

  final ShopItem item;
  final InventoryService inventory;

  @override
  Widget build(BuildContext context) {
    final count = inventory.count(item.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: LoomSpacing.sm),
      child: LoomCard(
        background: LoomTheme.card(context),
        borderColor: LoomTheme.border(context),
        child: Row(
          children: [
            Icon(Icons.handyman_outlined, size: 18, color: LoomTheme.accent(context)),
            const SizedBox(width: LoomSpacing.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.titleZh, style: LoomTypography.body),
                  const SizedBox(height: 2),
                  Text(
                    '回合中右上角可用',
                    style: LoomTypography.secondary.copyWith(
                      color: LoomTheme.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: LoomSpacing.base),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _CountBadge(count: count),
                if (count == 0)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('去商城'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: LoomTheme.card(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: LoomTheme.border(context)),
      ),
      child: Text('x$count', style: LoomTypography.secondary),
    );
  }
}

class _ThemeItemCard extends StatelessWidget {
  const _ThemeItemCard({required this.item});

  final ShopItem item;

  @override
  Widget build(BuildContext context) {
    final shopState = ShopStateService.instance;
    final isOwned = shopState.isOwned(item.id);
    final isEquipped = shopState.equippedFor('theme') == item.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: LoomSpacing.sm),
      child: LoomCard(
        background: LoomTheme.card(context),
        borderColor: LoomTheme.border(context),
        child: Row(
          children: [
            Icon(Icons.palette_outlined, size: 18, color: LoomTheme.accent(context)),
            const SizedBox(width: LoomSpacing.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.titleZh, style: LoomTypography.body),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitleZh,
                    style: LoomTypography.secondary.copyWith(
                      color: LoomTheme.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: LoomSpacing.base),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(isOwned ? '已擁有' : '未擁有', style: LoomTypography.secondary),
                TextButton(
                  onPressed: !isOwned
                      ? null
                      : isEquipped
                          ? null
                          : () async {
                              await shopState.equip('theme', item.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('已使用：${item.titleZh}')),
                              );
                            },
                  child: Text(isEquipped ? '使用中' : '使用'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
