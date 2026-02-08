import 'package:flutter/material.dart';

class SessionSummaryCard extends StatelessWidget {
  const SessionSummaryCard({
    super.key,
    required this.subjectTitle,
    required this.totalQuestions,
    required this.totalXp,
    required this.dailyAnswered,
    required this.dailyTarget,
  });

  final String subjectTitle;
  final int totalQuestions;
  final int totalXp;
  final int dailyAnswered;
  final int dailyTarget;

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
              Text('科目：$subjectTitle'),
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
                onPressed: () => Navigator.pop(context),
                child: const Text('回到主選單'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
