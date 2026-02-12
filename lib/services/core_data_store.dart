import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/player.dart';
import '../models/subject.dart';
import '../models/active_pet.dart';
import '../models/pokedex_entry.dart';
import 'level_thresholds.dart';
import 'shop_state_service.dart';

class CoreDataStore {
  static const _playerKey = 'core_player';
  static const _subjectsKey = 'core_subjects';
  static const _creditsKey = 'core_subject_credits';
  static const _activePetKey = 'core_active_pet';
  static const _pokedexKey = 'core_pokedex';

  late SharedPreferences _prefs;

  late Player player;
  late List<Subject> subjects;
  late Map<String, int> creditsBySubject;
  late ActivePet activePet;
  late List<PokedexEntry> pokedexEntries;

  Future<void> init({required List<Subject> defaultSubjects}) async {
    _prefs = await SharedPreferences.getInstance();

    player = _loadPlayer() ?? _createDefaultPlayer();
    subjects = _loadSubjects() ?? List<Subject>.from(defaultSubjects);
    creditsBySubject = _loadCredits() ?? <String, int>{};
    activePet = _loadActivePet() ?? _createDefaultActivePet();
    pokedexEntries = _loadPokedex() ?? <PokedexEntry>[];

    _ensureCreditsForSubjects(subjects);

    await _savePlayer();
    await _saveSubjects();
    await _saveCredits();
    await _saveActivePet();
    await _savePokedex();
  }

  Future<void> recordAnswer({required String subjectId, required bool isCorrect}) async {
    _ensureCreditsForSubjects([Subject(subjectId: subjectId, displayName: '')]);

    var gainedXp = isCorrect ? 10 : 6;
    final shopState = ShopStateService.instance;
    if (shopState.isReady) {
      final remaining = shopState.effectRemaining(ShopStateService.focusXpRemainingKey);
      if (remaining > 0) {
        gainedXp = (gainedXp * 1.2).floor();
        shopState.setEffectRemaining(
          ShopStateService.focusXpRemainingKey,
          remaining - 1,
        );
      }
    }
    player = player.copyWith(
      totalXp: player.totalXp + gainedXp,
      playerLevel: LevelThresholds.levelForXp(player.totalXp + gainedXp),
    );

    final gainedCredit = isCorrect ? 10 : 3;
    creditsBySubject[subjectId] = (creditsBySubject[subjectId] ?? 0) + gainedCredit;

    final previousStage = activePet.currentStage;
    final nextStage = _stageForLevel(player.playerLevel);
    final nextBond = _bondForLevel(player.playerLevel);

    activePet = activePet.copyWith(
      currentStage: nextStage,
      currentBond: nextBond,
    );

    if (previousStage < 4 && nextStage >= 4) {
      pokedexEntries.add(_buildPokedexEntry(4));
    }

    await _savePlayer();
    await _saveCredits();
    await _saveActivePet();
    await _savePokedex();
  }

  void _ensureCreditsForSubjects(List<Subject> currentSubjects) {
    for (final subject in currentSubjects) {
      if (subject.subjectId.isEmpty) continue;
      creditsBySubject.putIfAbsent(subject.subjectId, () => 0);
    }
  }

  int _stageForLevel(int level) {
    if (level >= 40) return 4;
    if (level >= 20) return 3;
    if (level >= 10) return 2;
    if (level >= 5) return 1;
    return 0;
  }

  int _bondForLevel(int level) {
    if (level < 41) return 0;
    final bond = level - 40;
    return bond > 10 ? 10 : bond;
  }

  String _resolvePetType() {
    final total = creditsBySubject.values.fold<int>(0, (sum, v) => sum + v);
    if (total < 200) return 'balanced';
    final entries = creditsBySubject.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) return 'balanced';
    final top = entries.first;
    final ratio = total == 0 ? 0.0 : top.value / total;
    return ratio >= 0.4 ? 'major' : 'balanced';
  }

  List<CreditSnapshotItem> _creditSnapshotTop3() {
    final total = creditsBySubject.values.fold<int>(0, (sum, v) => sum + v);
    final entries = creditsBySubject.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(3).map((entry) {
      final ratio = total == 0 ? 0.0 : entry.value / total;
      return CreditSnapshotItem(subjectId: entry.key, ratio: ratio);
    }).toList();
  }

  PokedexEntry _buildPokedexEntry(int stage) {
    return PokedexEntry(
      entryId: '${DateTime.now().millisecondsSinceEpoch}_$stage',
      petStage: stage,
      petType: _resolvePetType(),
      creditSnapshotTop3: _creditSnapshotTop3(),
      bondLevelAtUnlock: activePet.currentBond,
      unlockedAt: DateTime.now(),
    );
  }

  Player _createDefaultPlayer() {
    return const Player(
      playerId: 'player_1',
      totalXp: 0,
      playerLevel: 1,
    );
  }

  ActivePet _createDefaultActivePet() {
    return ActivePet(
      petId: 'pet_1',
      currentStage: 0,
      currentBond: 0,
      createdAt: DateTime.now(),
    );
  }

  Player? _loadPlayer() {
    final raw = _prefs.getString(_playerKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final jsonMap = json.decode(raw);
      if (jsonMap is Map<String, dynamic>) return Player.fromJson(jsonMap);
      if (jsonMap is Map) return Player.fromJson(Map<String, dynamic>.from(jsonMap));
    } catch (_) {}
    return null;
  }

  List<Subject>? _loadSubjects() {
    final raw = _prefs.getString(_subjectsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final jsonList = json.decode(raw);
      if (jsonList is List) {
        return jsonList
            .whereType<Map>()
            .map((e) => Subject.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return null;
  }

  Map<String, int>? _loadCredits() {
    final raw = _prefs.getString(_creditsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final jsonMap = json.decode(raw);
      if (jsonMap is Map) {
        return jsonMap.map((key, value) => MapEntry(key.toString(), (value as num?)?.toInt() ?? 0));
      }
    } catch (_) {}
    return null;
  }

  ActivePet? _loadActivePet() {
    final raw = _prefs.getString(_activePetKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final jsonMap = json.decode(raw);
      if (jsonMap is Map<String, dynamic>) return ActivePet.fromJson(jsonMap);
      if (jsonMap is Map) return ActivePet.fromJson(Map<String, dynamic>.from(jsonMap));
    } catch (_) {}
    return null;
  }

  List<PokedexEntry>? _loadPokedex() {
    final raw = _prefs.getString(_pokedexKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final jsonList = json.decode(raw);
      if (jsonList is List) {
        return jsonList
            .whereType<Map>()
            .map((e) => PokedexEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return null;
  }

  Future<void> _savePlayer() async {
    await _prefs.setString(_playerKey, json.encode(player.toJson()));
  }

  Future<void> _saveSubjects() async {
    await _prefs.setString(_subjectsKey, json.encode(subjects.map((e) => e.toJson()).toList()));
  }

  Future<void> _saveCredits() async {
    await _prefs.setString(_creditsKey, json.encode(creditsBySubject));
  }

  Future<void> _saveActivePet() async {
    await _prefs.setString(_activePetKey, json.encode(activePet.toJson()));
  }

  Future<void> _savePokedex() async {
    await _prefs.setString(_pokedexKey, json.encode(pokedexEntries.map((e) => e.toJson()).toList()));
  }
}
