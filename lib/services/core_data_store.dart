import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/player.dart';
import '../models/subject.dart';
import '../models/active_pet.dart';
import '../models/pokedex_entry.dart';

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

  void _ensureCreditsForSubjects(List<Subject> currentSubjects) {
    for (final subject in currentSubjects) {
      creditsBySubject.putIfAbsent(subject.subjectId, () => 0);
    }
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
