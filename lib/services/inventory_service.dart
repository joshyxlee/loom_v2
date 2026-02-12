import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class InventoryService {
  InventoryService._();

  static final InventoryService instance = InventoryService._();
  static const _inventoryKey = 'loom_shop_inventory_v1';

  SharedPreferences? _prefs;
  Map<String, int> _inventory = {};
  bool _ready = false;

  bool get isReady => _ready;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    _inventory = _loadInventory();
    _ready = true;
  }

  int count(String itemId) {
    return _inventory[itemId] ?? 0;
  }

  Future<void> add(String itemId, int qty) async {
    if (qty <= 0) return;
    final current = _inventory[itemId] ?? 0;
    _inventory[itemId] = current + qty;
    await _save();
  }

  Future<bool> consume(String itemId, {int qty = 1}) async {
    if (qty <= 0) return true;
    final current = _inventory[itemId] ?? 0;
    if (current < qty) return false;
    final next = current - qty;
    if (next == 0) {
      _inventory.remove(itemId);
    } else {
      _inventory[itemId] = next;
    }
    await _save();
    return true;
  }

  Map<String, int> _loadInventory() {
    final raw = _prefs?.getString(_inventoryKey);
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

  Future<void> _save() async {
    if (_prefs == null) return;
    final payload = jsonEncode(_inventory);
    await _prefs!.setString(_inventoryKey, payload);
  }
}
