class PokedexEntry {
  const PokedexEntry({
    required this.entryId,
    required this.petStage,
    required this.petType,
    required this.creditSnapshotTop3,
    required this.bondLevelAtUnlock,
    required this.unlockedAt,
  });

  final String entryId;
  final int petStage;
  final String petType;
  final List<CreditSnapshotItem> creditSnapshotTop3;
  final int bondLevelAtUnlock;
  final DateTime unlockedAt;

  Map<String, dynamic> toJson() => {
        'entry_id': entryId,
        'pet_stage': petStage,
        'pet_type': petType,
        'credit_snapshot_top3': creditSnapshotTop3.map((e) => e.toJson()).toList(),
        'bond_level_at_unlock': bondLevelAtUnlock,
        'unlocked_at': unlockedAt.toIso8601String(),
      };

  factory PokedexEntry.fromJson(Map<String, dynamic> json) {
    final list = json['credit_snapshot_top3'];
    final items = <CreditSnapshotItem>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          items.add(CreditSnapshotItem.fromJson(item));
        } else if (item is Map) {
          items.add(CreditSnapshotItem.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    final unlockedRaw = json['unlocked_at']?.toString();
    return PokedexEntry(
      entryId: json['entry_id']?.toString() ?? '',
      petStage: (json['pet_stage'] as num?)?.toInt() ?? 0,
      petType: json['pet_type']?.toString() ?? '',
      creditSnapshotTop3: items,
      bondLevelAtUnlock: (json['bond_level_at_unlock'] as num?)?.toInt() ?? 0,
      unlockedAt: unlockedRaw != null ? DateTime.tryParse(unlockedRaw) ?? DateTime.now() : DateTime.now(),
    );
  }
}

class CreditSnapshotItem {
  const CreditSnapshotItem({
    required this.subjectId,
    required this.ratio,
  });

  final String subjectId;
  final double ratio;

  Map<String, dynamic> toJson() => {
        'subject_id': subjectId,
        'ratio': ratio,
      };

  factory CreditSnapshotItem.fromJson(Map<String, dynamic> json) {
    return CreditSnapshotItem(
      subjectId: json['subject_id']?.toString() ?? '',
      ratio: (json['ratio'] as num?)?.toDouble() ?? 0,
    );
  }
}
