import 'package:flutter/material.dart';

import 'design_system.dart';
import 'loom_card.dart';

class StreakCard extends StatelessWidget {
  const StreakCard({
    super.key,
    required this.streakDays,
    required this.prevStreakDays,
    required this.todayAnswered,
    required this.dailyTarget,
    required this.todayCompleted,
    required this.yesterdayCompleted,
    required this.streakSavePending,
    required this.canSaveStreak,
  });

  final int streakDays;
  final int prevStreakDays;
  final int todayAnswered;
  final int dailyTarget;
  final bool todayCompleted;
  final bool yesterdayCompleted;
  final bool streakSavePending;
  final bool canSaveStreak;

  @override
  Widget build(BuildContext context) {
    final broken = streakDays == 0 &&
        (streakSavePending || (!yesterdayCompleted && prevStreakDays > 0));
    final showSaveHint = broken && streakSavePending && canSaveStreak;

    final status = broken
        ? '已中斷'
        : '連續 $streakDays 天';
    final statusIcon = broken ? Icons.ac_unit : Icons.local_fire_department;

    final headline = broken
        ? (showSaveHint ? '昨天差一點，還能用知識幣保住 🔥' : '昨天沒完成，火熄了 🧊')
        : (todayCompleted ? '今天達標 ✅ 火焰續命' : '今天完成 $todayAnswered/$dailyTarget 題，火會繼續燒');

    final activeCount = broken
        ? (prevStreakDays > 0 ? prevStreakDays.clamp(1, 7) : 3)
        : (streakDays + (todayCompleted ? 1 : 0)).clamp(0, 7);

    return LoomCard(
      background: LoomTheme.card(context),
      borderColor: LoomTheme.border(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '每日五題，讓知識的火焰傳遞下去！',
                  style: LoomTypography.secondary.copyWith(
                    color: LoomTheme.textSecondary(context),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: LoomTheme.accent(context).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Text(
                      status,
                      style: LoomTypography.secondary.copyWith(
                        color: LoomTheme.accent(context),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      statusIcon,
                      size: 19,
                      color: LoomTheme.accent(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: LoomSpacing.base),
          Text(
            headline,
            style: LoomTypography.secondary.copyWith(
              color: LoomTheme.textSecondary(context),
            ),
          ),
          const SizedBox(height: LoomSpacing.sm),
          SizedBox(
            height: 28,
            child: Row(
              children: List.generate(7, (index) {
                final isActive = index < activeCount;
                final decoration = BoxDecoration(
                  color: isActive
                      ? LoomTheme.accent(context).withOpacity(0.3)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: isActive
                      ? null
                      : Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                );
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: decoration,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
