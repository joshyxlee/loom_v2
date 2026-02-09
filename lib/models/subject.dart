class Subject {
  const Subject({
    required this.subjectId,
    required this.displayName,
    this.icon,
    this.theme,
  });

  final String subjectId;
  final String displayName;
  final String? icon;
  final String? theme;

  String get key => subjectId;
  String get title => displayName;

  Map<String, dynamic> toJson() => {
        'subject_id': subjectId,
        'display_name': displayName,
        'icon': icon,
        'theme': theme,
      };

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      subjectId: json['subject_id']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      icon: json['icon']?.toString(),
      theme: json['theme']?.toString(),
    );
  }
}
