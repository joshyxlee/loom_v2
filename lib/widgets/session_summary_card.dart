import 'package:flutter/material.dart';

import '../models/subject.dart';
import '../repositories/question_repository.dart';
import '../services/progress_service.dart';
import '../main.dart';

class SessionSummaryCard extends StatelessWidget {
  const SessionSummaryCard({
    super.key,
    required this.subject,
    required this.totalQuestions,
    required this.dailyAnswered,
    required this.dailyTarget,
    required this.repository,
    required this.progressService,
  });

  final Subject subject;
  final int totalQuestions;
  final int dailyAnswered;
  final int dailyTarget;
  final QuestionRepository repository;
  final ProgressService progressService;

  @override
  Widget build(BuildContext context) {
    final remaining = (dailyTarget - dailyAnswered).clamp(0, dailyTarget);
    return Scaffold(
      appBar: AppBar(title: const Text('本回合完成')),
      body: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('你完成了一回合', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('科目：${subject.title}'),
              Text('題數：$totalQuestions 題'),
              const SizedBox(height: 8),
              Text('今天累積：$dailyAnswered / $dailyTarget'),
              if (remaining > 0)
                Text('再完成 $remaining 題就達標',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              if (remaining == 0)
                const Text('今日目標已達成 ✅', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final questions = await repository.getSession(
                    subject: subject.key,
                    count: 5,
                  );
                  if (!context.mounted) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuizScreen(
                        questions: questions,
                        progressService: progressService,
                        subjectTitle: subject.title,
                        subject: subject,
                        repository: repository,
                      ),
                    ),
                  );
                },
                child: const Text('再玩一回合'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                child: const Text('先到這裡'),
              ),
              const SizedBox(height: 6),
              const Text('明天回來繼續，會更快升級。',
                  style: TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }
}
