import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/token_service.dart';
import '../services/inventory_service.dart';
import '../services/shop_state_service.dart';
import '../shop/shop_catalog.dart';
import '../shop/shop_models.dart';
import '../widgets/design_system.dart';
import '../widgets/loom_card.dart';
import '../widgets/backpack_entry_button.dart';
import 'backpack_screen.dart';
import '../repositories/question_repository.dart';
import '../services/progress_service.dart';
import '../services/core_data_store.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({
    super.key,
    required this.repository,
    required this.progressService,
    required this.coreDataStore,
  });

  final QuestionRepository repository;
  final ProgressService progressService;
  final CoreDataStore coreDataStore;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int _tabIndex = 0;
  bool _limitedReady = false;
  Map<String, int> _limitedEnds = {};
  final _scrollController = ScrollController();
  final Map<String, GlobalKey> _itemKeys = {
    'boost_mistake_shield': GlobalKey(),
    'boost_focus_xp': GlobalKey(),
    'boost_double_token': GlobalKey(),
    'boost_xp_burst': GlobalKey(),
    'boost_streak_saver': GlobalKey(),
    'util_skip_question': GlobalKey(),
    'util_reroll_question': GlobalKey(),
    'util_hint_reveal': GlobalKey(),
    'cosmetic_theme_night': GlobalKey(),
    'cosmetic_theme_ocean': GlobalKey(),
    'cosmetic_theme_warm': GlobalKey(),
    'pack_ai': GlobalKey(),
    'pack_kpop': GlobalKey(),
    'pack_nba': GlobalKey(),
    'pack_business': GlobalKey(),
    'limited_bundle_starter': GlobalKey(),
    'limited_bundle_booster': GlobalKey(),
  };

  static const _limitedKey = 'loom_shop_limited_v1';

  @override
  void initState() {
    super.initState();
    _loadLimitedOffers();
  }

  Future<void> _loadLimitedOffers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_limitedKey);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (raw == null || raw.isEmpty) {
      final endsAt = now + const Duration(hours: 24).inMilliseconds;
      _limitedEnds = {
        'starterEndsAt': endsAt,
        'boosterEndsAt': endsAt,
      };
      await prefs.setString(_limitedKey, jsonEncode(_limitedEnds));
    } else {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _limitedEnds = decoded.map((key, value) {
            final parsed = value is int ? value : int.tryParse(value.toString()) ?? 0;
            return MapEntry(key.toString(), parsed);
          });
        }
      } catch (_) {
        _limitedEnds = {};
      }
      if (_limitedEnds.isEmpty) {
        final endsAt = now + const Duration(hours: 24).inMilliseconds;
        _limitedEnds = {
          'starterEndsAt': endsAt,
          'boosterEndsAt': endsAt,
        };
        await prefs.setString(_limitedKey, jsonEncode(_limitedEnds));
      }
    }
    if (mounted) {
      setState(() {
        _limitedReady = true;
      });
    }
  }

  bool _isLimitedActive(String bundleId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final endKey = bundleId == 'limited_bundle_starter' ? 'starterEndsAt' : 'boosterEndsAt';
    final endsAt = _limitedEnds[endKey] ?? 0;
    return now < endsAt;
  }

  Future<void> _handlePurchase(BuildContext context, ShopItem item) async {
    if (!item.isEnabled) return;
    final shopState = ShopStateService.instance;
    if ((item.kind == ShopItemKind.equipable || item.kind == ShopItemKind.owned) &&
        shopState.isOwned(item.id)) {
      return;
    }
    if (item.category == ShopCategory.limited && !_isLimitedActive(item.id)) {
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
    if (item.category == ShopCategory.limited) {
      await _purchaseBundle(item.id, item.priceTokens);
      return;
    }
    service.deductToken(item.priceTokens);
    if (item.kind == ShopItemKind.equipable || item.kind == ShopItemKind.owned) {
      await shopState.addOwned(item.id);
    } else {
      await InventoryService.instance.add(item.id, 1);
    }
    final message = item.category == ShopCategory.unlock
        ? '已解鎖：${item.titleZh}'
        : '已購買：${item.titleZh}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
        final isOwned =
            (item.kind == ShopItemKind.equipable || item.kind == ShopItemKind.owned) &&
                shopState.isOwned(item.id);
        final isEquipped = item.kind == ShopItemKind.equipable &&
            shopState.equippedFor('theme') == item.id;
        final isLimited = item.category == ShopCategory.limited;
        final limitedActive = isLimited ? _isLimitedActive(item.id) : false;
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
        if (isLimited) {
          statusText = limitedActive ? '今日限時' : '已結束';
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
        final actionLabel = isLimited
            ? (limitedActive ? '購買' : '已結束')
            : item.kind == ShopItemKind.equipable
                ? (isOwned ? (isEquipped ? '使用中' : '使用') : '購買')
                : item.kind == ShopItemKind.owned
                    ? (isOwned ? '已擁有' : '購買')
                    : item.isEnabled
                        ? '購買'
                        : '即將推出';
        final actionEnabled = isLimited
            ? limitedActive
            : item.kind == ShopItemKind.equipable
                ? !isEquipped
                : item.kind == ShopItemKind.owned
                    ? !isOwned
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
        } else if (item.id == 'cosmetic_theme_night' ||
            item.id == 'cosmetic_theme_ocean' ||
            item.id == 'cosmetic_theme_warm') {
          helperText = '永久擁有，可隨時切換';
        } else if (item.category == ShopCategory.unlock) {
          helperText = '解鎖後可在分科測驗中使用';
        } else if (item.category == ShopCategory.limited) {
          helperText = '購買後直接入庫';
        } else if (item.kind == ShopItemKind.consumable) {
          helperText = '購買後會先存起來';
        }
        final infoText = isLimited ? _bundleContentText(item.id) : null;
        Widget? titleIcon;
        if (item.category == ShopCategory.unlock) {
          final accent = _unlockAccent(item.id, context);
          titleIcon = Icon(
            isOwned ? Icons.check_circle : Icons.lock_outline,
            size: 16,
            color: isOwned ? accent : accent.withOpacity(0.6),
          );
        }
        return Padding(
          key: _itemKeys[item.id],
          padding: const EdgeInsets.only(bottom: LoomSpacing.sm),
          child: ShopItemCard(
            title: item.titleZh,
            description: item.subtitleZh,
            price: item.priceTokens,
            badgeCount: item.kind == ShopItemKind.consumable ? count : null,
            badgeText: badgeText,
            statusText: statusText,
            helperText: helperText,
            infoText: infoText,
            titleIcon: titleIcon,
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

  int _totalUsableItems(InventoryService inventory) {
    return inventory.count('boost_mistake_shield') +
        inventory.count('boost_focus_xp') +
        inventory.count('boost_double_token') +
        inventory.count('boost_xp_burst') +
        inventory.count('boost_streak_saver') +
        inventory.count('util_skip_question') +
        inventory.count('util_reroll_question') +
        inventory.count('util_hint_reveal');
  }

  String? _firstUsableItemId(InventoryService inventory) {
    final candidates = [
      'boost_mistake_shield',
      'boost_focus_xp',
      'boost_double_token',
      'boost_xp_burst',
      'boost_streak_saver',
      'util_skip_question',
      'util_reroll_question',
      'util_hint_reveal',
    ];
    for (final id in candidates) {
      if (inventory.count(id) > 0) return id;
    }
    return null;
  }

  String? _firstUsableItemLabel(InventoryService inventory) {
    final candidates = [
      'boost_mistake_shield',
      'boost_focus_xp',
      'boost_double_token',
      'boost_xp_burst',
      'util_skip_question',
      'util_reroll_question',
      'util_hint_reveal',
    ];
    for (final id in candidates) {
      if (inventory.count(id) > 0) {
        return switch (id) {
          'boost_mistake_shield' => '失誤保護卡',
          'boost_focus_xp' => '專注強化',
          'boost_double_token' => '雙倍獎勵',
          'boost_xp_burst' => '爆發加成',
          'util_skip_question' => '跳題券',
          'util_reroll_question' => '換題券',
          'util_hint_reveal' => '提示券',
          _ => null,
        };
      }
    }
    return null;
  }

  int _firstUsableItemCount(InventoryService inventory) {
    final candidates = [
      'boost_mistake_shield',
      'boost_focus_xp',
      'boost_double_token',
      'boost_xp_burst',
      'util_skip_question',
      'util_reroll_question',
      'util_hint_reveal',
    ];
    for (final id in candidates) {
      final count = inventory.count(id);
      if (count > 0) return count;
    }
    return 0;
  }

  void _jumpToRecommended(InventoryService inventory) {
    final recommendedId = _firstUsableItemId(inventory) ?? 'boost_mistake_shield';
    final category = buildShopCatalog()
        .firstWhere((item) => item.id == recommendedId)
        .category;
    final section = switch (category) {
      ShopCategory.boost => BackpackSection.boost,
      ShopCategory.utility => BackpackSection.utility,
      ShopCategory.cosmetic => BackpackSection.cosmetic,
      _ => BackpackSection.boost,
    };
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BackpackScreen(
          repository: widget.repository,
          progressService: widget.progressService,
          coreDataStore: widget.coreDataStore,
          entrySource: BackpackEntrySource.shop,
          focusSection: section,
          focusItemId: recommendedId,
        ),
      ),
    );
  }

  Color _unlockAccent(String itemId, BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (itemId) {
      case 'pack_ai':
        return scheme.primary;
      case 'pack_kpop':
        return scheme.tertiary;
      case 'pack_nba':
        return scheme.secondary;
      case 'pack_business':
        return scheme.primary.withOpacity(0.8);
      default:
        return scheme.primary;
    }
  }

  Map<String, int> _bundleContents(String bundleId) {
    switch (bundleId) {
      case 'limited_bundle_starter':
        return {
          'boost_mistake_shield': 2,
          'util_skip_question': 2,
          'boost_focus_xp': 1,
        };
      case 'limited_bundle_booster':
        return {
          'boost_mistake_shield': 3,
          'util_reroll_question': 3,
          'boost_xp_burst': 1,
          'boost_double_token': 1,
        };
      default:
        return {};
    }
  }

  String _bundleContentText(String bundleId) {
    final contents = _bundleContents(bundleId);
    if (contents.isEmpty) return '';
    final parts = <String>[];
    contents.forEach((key, value) {
      switch (key) {
        case 'boost_mistake_shield':
          parts.add('失誤保護卡×$value');
          break;
        case 'util_skip_question':
          parts.add('跳題券×$value');
          break;
        case 'boost_focus_xp':
          parts.add('專注強化×$value');
          break;
        case 'util_reroll_question':
          parts.add('換題券×$value');
          break;
        case 'boost_xp_burst':
          parts.add('爆發加成×$value');
          break;
        case 'boost_double_token':
          parts.add('雙倍獎勵×$value');
          break;
      }
    });
    return '內容物：${parts.join('、')}';
  }

  Future<void> _purchaseBundle(String bundleId, int price) async {
    final service = TokenService.instance;
    if (!service.canAfford(price)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('知識幣不足')),
      );
      return;
    }
    final contents = _bundleContents(bundleId);
    if (contents.isEmpty) return;
    final inventory = InventoryService.instance;
    final before = inventory.snapshot();
    final next = Map<String, int>.from(before);
    for (final entry in contents.entries) {
      next[entry.key] = (next[entry.key] ?? 0) + entry.value;
    }
    try {
      await inventory.setAll(next);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('購買失敗，請稍後再試')),
      );
      return;
    }
    service.deductToken(price);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已購買限時組合')),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final token = TokenService.instance.knowledgeToken;
    final inventory = InventoryService.instance;
    final shopState = ShopStateService.instance;
    if (!inventory.isReady || !shopState.isReady || !_limitedReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final focusRemaining =
        shopState.effectRemaining(ShopStateService.focusXpRemainingKey);
    final burstRemaining =
        shopState.effectRemaining(ShopStateService.xpBurstRemainingKey);
    final doubleRemaining =
        shopState.effectRemaining(ShopStateService.doubleTokenRemainingKey);
    final activeBuffText = focusRemaining > 0
        ? '專注 $focusRemaining'
        : burstRemaining > 0
            ? '爆發 $burstRemaining'
            : doubleRemaining > 0
                ? '雙倍 $doubleRemaining'
                : null;
    final activeBuffSubtitle = focusRemaining > 0
        ? '專注（剩 $focusRemaining/5）'
        : burstRemaining > 0
            ? '爆發（剩 $burstRemaining/3）'
            : doubleRemaining > 0
                ? '雙倍（剩 $doubleRemaining/3）'
                : null;
    final themeLabel = switch (shopState.equippedFor('theme')) {
      'cosmetic_theme_night' => '夜間',
      'cosmetic_theme_ocean' => '海洋',
      'cosmetic_theme_warm' => '暖陽',
      _ => '預設',
    };
    final subtitle = activeBuffSubtitle == null
        ? '加成中：無｜主題：$themeLabel'
        : '加成中：$activeBuffSubtitle｜主題：$themeLabel';

    return Scaffold(
      appBar: AppBar(
        title: const Text('商城'),
        actions: [
          BackpackEntryButton(
            totalUsable: _totalUsableItems(inventory),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BackpackScreen(
                    repository: widget.repository,
                    progressService: widget.progressService,
                    coreDataStore: widget.coreDataStore,
                    entrySource: BackpackEntrySource.shop,
                  ),
                ),
              );
            },
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
                if (activeBuffText != null)
                  _HudChip(
                    icon: Icons.flash_on,
                    label: activeBuffText,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BackpackScreen(
                            repository: widget.repository,
                            progressService: widget.progressService,
                            coreDataStore: widget.coreDataStore,
                            entrySource: BackpackEntrySource.shop,
                            focusSection: BackpackSection.boost,
                          ),
                        ),
                      );
                    },
                  ),
                if (activeBuffText != null) const SizedBox(width: LoomSpacing.base),
                _HudChip(
                  icon: Icons.inventory_2_outlined,
                  label:
                      '跳 x${inventory.count('util_skip_question')}  換 x${inventory.count('util_reroll_question')}  提 x${inventory.count('util_hint_reveal')}',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BackpackScreen(
                          repository: widget.repository,
                          progressService: widget.progressService,
                          coreDataStore: widget.coreDataStore,
                          entrySource: BackpackEntrySource.shop,
                          focusSection: BackpackSection.utility,
                        ),
                      ),
                    );
                  },
                ),
                const Spacer(),
                _TokenBadge(tokens: token),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: LoomTypography.secondary.copyWith(
                color: LoomTheme.textSecondary(context),
              ),
            ),
            const SizedBox(height: LoomSpacing.md),
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
            const SizedBox(height: LoomSpacing.sm),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TodayRecommendCard(
                      boostActive: focusRemaining > 0 || burstRemaining > 0 || doubleRemaining > 0,
                      boostLabel: focusRemaining > 0
                          ? '專注強化（剩餘 $focusRemaining/5）'
                          : burstRemaining > 0
                              ? '爆發加成（剩餘 $burstRemaining/3）'
                              : doubleRemaining > 0
                                  ? '雙倍獎勵（剩餘 $doubleRemaining/3）'
                                  : null,
                      usableItemLabel: _firstUsableItemLabel(inventory),
                      usableItemCount: _firstUsableItemCount(inventory),
                      onTapGo: () => _jumpToRecommended(inventory),
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

class _TodayRecommendCard extends StatelessWidget {
  const _TodayRecommendCard({
    required this.boostActive,
    required this.boostLabel,
    required this.usableItemLabel,
    required this.usableItemCount,
    required this.onTapGo,
  });

  final bool boostActive;
  final String? boostLabel;
  final String? usableItemLabel;
  final int usableItemCount;
  final VoidCallback onTapGo;

  @override
  Widget build(BuildContext context) {
    String content;
    String buttonLabel;
    if (boostActive && boostLabel != null) {
      content = '加成啟用中：$boostLabel';
      buttonLabel = '查看';
    } else if (usableItemLabel != null && usableItemCount > 0) {
      content = '你有可用道具：$usableItemLabel（持有 x$usableItemCount）';
      buttonLabel = '去使用';
    } else {
      content = '推薦：失誤保護卡 / 專注強化';
      buttonLabel = '去看看';
    }

    return LoomCard(
      background: LoomTheme.card(context),
      borderColor: LoomTheme.border(context),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('今日推薦', style: LoomTypography.sectionTitle),
                const SizedBox(height: 6),
                Text(
                  content,
                  style: LoomTypography.secondary.copyWith(
                    color: LoomTheme.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onTapGo, child: Text(buttonLabel)),
        ],
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
    final themeLabel = switch (themeId) {
      'cosmetic_theme_night' => '夜間（使用中）',
      'cosmetic_theme_ocean' => '海洋（使用中）',
      'cosmetic_theme_warm' => '暖陽（使用中）',
      _ => '預設',
    };
    return LoomCard(
      background: LoomTheme.card(context),
      borderColor: LoomTheme.border(context),
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
        color: LoomTheme.accent(context).withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          '知識幣 \$$tokens',
          style: LoomTypography.body.copyWith(
            fontWeight: FontWeight.w400,
            color: LoomTheme.textSecondary(context),
          ),
        ),
      ),
    );
  }
}

class _HudChip extends StatelessWidget {
  const _HudChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: LoomTheme.card(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: LoomTheme.border(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: LoomTheme.accent(context)),
            const SizedBox(width: 4),
            Text(label, style: LoomTypography.secondary),
          ],
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
          color: isActive
              ? LoomTheme.accent(context).withOpacity(0.12)
              : LoomTheme.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: LoomTheme.border(context)),
        ),
        child: Text(
          label,
          style: LoomTypography.body.copyWith(
            fontWeight: FontWeight.w600,
            color: isActive ? LoomTheme.accent(context) : LoomTheme.textSecondary(context),
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
    this.infoText,
    this.titleIcon,
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
  final String? infoText;
  final Widget? titleIcon;

  @override
  Widget build(BuildContext context) {
    return LoomCard(
      background: LoomTheme.card(context),
      borderColor: LoomTheme.border(context),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (titleIcon != null) ...[
                    titleIcon!,
                    const SizedBox(width: 6),
                  ],
                  Text(title, style: LoomTypography.sectionTitle),
                ],
              ),
              const SizedBox(height: LoomSpacing.base),
              Text(description,
                  style: LoomTypography.body.copyWith(color: LoomTheme.textSecondary(context))),
              if (infoText != null) ...[
                const SizedBox(height: LoomSpacing.base),
                Text(
                  infoText!,
                  style: LoomTypography.secondary.copyWith(
                    color: LoomTheme.textSecondary(context),
                  ),
                ),
              ],
              if (statusText != null) ...[
                const SizedBox(height: LoomSpacing.sm),
                Text(
                  statusText!,
                  style: LoomTypography.body.copyWith(color: LoomTheme.accent(context)),
                ),
              ],
              if (helperText != null) ...[
                const SizedBox(height: LoomSpacing.sm),
                Text(
                  helperText!,
                  style: LoomTypography.secondary.copyWith(
                    color: LoomTheme.textSecondary(context),
                  ),
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
                  color: badgeText == '使用中'
                      ? LoomTheme.badgeBgActive(context)
                      : LoomTheme.badgeBgNeutral(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeText ?? '持有 x$badgeCount',
                  style: LoomTypography.body.copyWith(
                    fontSize: 12,
                    color: LoomTheme.textSecondary(context),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
