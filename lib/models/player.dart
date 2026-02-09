class Player {
  const Player({
    required this.playerId,
    required this.totalXp,
    required this.playerLevel,
  });

  final String playerId;
  final int totalXp;
  final int playerLevel;

  Player copyWith({
    String? playerId,
    int? totalXp,
    int? playerLevel,
  }) {
    return Player(
      playerId: playerId ?? this.playerId,
      totalXp: totalXp ?? this.totalXp,
      playerLevel: playerLevel ?? this.playerLevel,
    );
  }

  Map<String, dynamic> toJson() => {
        'player_id': playerId,
        'total_xp': totalXp,
        'player_level': playerLevel,
      };

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      playerId: json['player_id']?.toString() ?? 'player_1',
      totalXp: (json['total_xp'] as num?)?.toInt() ?? 0,
      playerLevel: (json['player_level'] as num?)?.toInt() ?? 1,
    );
  }
}
