class TreeStage {
  const TreeStage({
    required this.level,
    required this.name,
  });

  final int level;
  final String name;
}

class TreeGrowth {
  static const stages = [
    TreeStage(level: 1, name: '種子'),
    TreeStage(level: 5, name: '發芽'),
    TreeStage(level: 10, name: '幼苗'),
    TreeStage(level: 18, name: '小樹'),
    TreeStage(level: 28, name: '成樹'),
    TreeStage(level: 40, name: '大樹'),
    TreeStage(level: 50, name: '蒼天大樹'),
  ];

  static TreeStage stageForLevel(int level) {
    TreeStage current = stages.first;
    for (final stage in stages) {
      if (level >= stage.level) current = stage;
    }
    return current;
  }
}
