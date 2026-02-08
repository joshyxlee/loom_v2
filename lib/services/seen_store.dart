import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SeenStore {
  static const _prefix = 'seen_ids_';
  static const _cap = 500;

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Set<String> load(String subject) {
    final raw = _prefs.getString('$_prefix$subject');
    if (raw == null || raw.isEmpty) return <String>{};
    try {
      final list = (json.decode(raw) as List).map((e) => e.toString()).toList();
      return list.toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> save(String subject, Iterable<String> ids) async {
    final current = _prefs.getString('$_prefix$subject');
    final list = <String>[];
    if (current != null && current.isNotEmpty) {
      try {
        final decoded = json.decode(current);
        if (decoded is List) {
          for (final e in decoded) {
            final s = e.toString();
            if (s.isNotEmpty) list.add(s);
          }
        }
      } catch (_) {}
    }

    for (final id in ids) {
      final s = id.trim();
      if (s.isNotEmpty) list.add(s);
    }

    final seen = <String>{};
    final compact = <String>[];
    for (final id in list.reversed) {
      if (seen.add(id)) compact.add(id);
      if (compact.length >= _cap) break;
    }
    final out = compact.reversed.toList();
    await _prefs.setString('$_prefix$subject', json.encode(out));
  }

  Future<void> reset(String subject) async {
    await _prefs.remove('$_prefix$subject');
  }
}
