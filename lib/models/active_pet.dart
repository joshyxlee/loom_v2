class ActivePet {
  const ActivePet({
    required this.petId,
    required this.currentStage,
    required this.currentBond,
    required this.createdAt,
  });

  final String petId;
  final int currentStage;
  final int currentBond;
  final DateTime createdAt;

  ActivePet copyWith({
    String? petId,
    int? currentStage,
    int? currentBond,
    DateTime? createdAt,
  }) {
    return ActivePet(
      petId: petId ?? this.petId,
      currentStage: currentStage ?? this.currentStage,
      currentBond: currentBond ?? this.currentBond,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'pet_id': petId,
        'current_stage': currentStage,
        'current_bond': currentBond,
        'created_at': createdAt.toIso8601String(),
      };

  factory ActivePet.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['created_at']?.toString();
    return ActivePet(
      petId: json['pet_id']?.toString() ?? 'pet_1',
      currentStage: (json['current_stage'] as num?)?.toInt() ?? 0,
      currentBond: (json['current_bond'] as num?)?.toInt() ?? 0,
      createdAt: createdAtRaw != null ? DateTime.tryParse(createdAtRaw) ?? DateTime.now() : DateTime.now(),
    );
  }
}
