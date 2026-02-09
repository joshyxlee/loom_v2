import '../models/subject.dart';

final List<Subject> defaultSubjects = [
  Subject(subjectId: 'funFacts', displayName: '冷知識'),
  Subject(subjectId: 'world', displayName: '世界'),
  Subject(subjectId: 'history', displayName: '歷史'),
  Subject(subjectId: 'science', displayName: '科學'),
  Subject(subjectId: 'money', displayName: '金錢'),
];

List<Subject> subjects = List<Subject>.from(defaultSubjects);

void setSubjects(List<Subject> next) {
  subjects = List<Subject>.from(next);
}
