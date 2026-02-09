class LevelThresholds {
  static const Map<int, int> _anchors = {
    1: 0,
    2: 60,
    3: 140,
    4: 240,
    5: 360,
    6: 520,
    7: 720,
    8: 960,
    9: 1240,
    10: 1560,
    12: 2200,
    15: 3400,
    20: 6000,
    30: 12000,
    40: 20000,
    50: 30000,
  };

  static int thresholdForLevel(int level) {
    if (level <= 1) return 0;
    if (_anchors.containsKey(level)) return _anchors[level]!;
    final levels = _anchors.keys.toList()..sort();
    int lowerLevel = levels.first;
    int upperLevel = levels.last;
    for (var i = 0; i < levels.length - 1; i++) {
      final a = levels[i];
      final b = levels[i + 1];
      if (level > a && level < b) {
        lowerLevel = a;
        upperLevel = b;
        break;
      }
    }
    final lowerXp = _anchors[lowerLevel] ?? 0;
    final upperXp = _anchors[upperLevel] ?? lowerXp;
    final ratio = (level - lowerLevel) / (upperLevel - lowerLevel);
    final xp = lowerXp + (upperXp - lowerXp) * ratio;
    return xp.round();
  }

  static int levelForXp(int xp, {int maxLevel = 50}) {
    for (var level = 1; level <= maxLevel; level++) {
      if (xp < thresholdForLevel(level)) return level;
    }
    return maxLevel;
  }
}
