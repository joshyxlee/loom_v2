import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShopStateService {
  ShopStateService._();

  static final ShopStateService instance = ShopStateService._();

  static const focusXpRemainingKey = 'focus_xp_remaining_questions';
  static const xpBurstRemainingKey = 'xp_burst_remaining_questions';
  static const doubleTokenRemainingKey = 'double_token_remaining_correct';

  static const _effectsKey = 'loom_shop_effects_v1';
  static const _ownedKey = 'loom_shop_owned_v1';
  static const _equippedKey = 'loom_shop_equipped_v1';

  SharedPreferences? _prefs;
  Map<String, int> _effects = {};
  Set<String> _owned = {};
  Map<String, String> _equipped = {};
  bool _ready = false;
  final ValueNotifier<String?> themeNotifier = ValueNotifier<String?>(null);

  bool get isReady => _ready;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    _effects = _loadEffects();
    _owned = _loadOwned();
    _equipped = _loadEquipped();
    themeNotifier.value = _equipped['theme'];
    _ready = true;
  }

  int effectRemaining(String key) => _effects[key] ?? 0;

  Future<void> setEffectRemaining(String key, int value) async {
    if (value <= 0) {
      _effects.remove(key);
    } else {
      _effects[key] = value;
    }
    await _saveEffects();
  }

  bool isOwned(String itemId) => _owned.contains(itemId);

  Future<void> addOwned(String itemId) async {
    _owned.add(itemId);
    await _saveOwned();
  }

  String? equippedFor(String slot) => _equipped[slot];

  Future<void> equip(String slot, String itemId) async {
    _equipped[slot] = itemId;
    if (slot == 'theme') {
      themeNotifier.value = itemId;
    }
    await _saveEquipped();
  }

  Map<String, int> _loadEffects() {
    final raw = _prefs?.getString(_effectsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map((key, value) {
        final qty = value is int ? value : int.tryParse(value.toString()) ?? 0;
        return MapEntry(key.toString(), qty);
      })..removeWhere((key, value) => value <= 0);
    } catch (_) {
      return {};
    }
  }

  Set<String> _loadOwned() {
    final raw = _prefs?.getString(_ownedKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return {};
      return decoded.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  Map<String, String> _loadEquipped() {
    final raw = _prefs?.getString(_equippedKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map((key, value) => MapEntry(key.toString(), value.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveEffects() async {
    if (_prefs == null) return;
    await _prefs!.setString(_effectsKey, jsonEncode(_effects));
  }

  Future<void> _saveOwned() async {
    if (_prefs == null) return;
    await _prefs!.setString(_ownedKey, jsonEncode(_owned.toList()));
  }

  Future<void> _saveEquipped() async {
    if (_prefs == null) return;
    await _prefs!.setString(_equippedKey, jsonEncode(_equipped));
  }
}
