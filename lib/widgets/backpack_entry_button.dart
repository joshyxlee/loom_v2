import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_system.dart';

class BackpackEntryButton extends StatelessWidget {
  const BackpackEntryButton({
    super.key,
    required this.totalUsable,
    required this.onTap,
  });

  final int totalUsable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: LoomTheme.accent(context).withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          '背包🎒（$totalUsable）',
          style: LoomTypography.body.copyWith(
            fontWeight: FontWeight.w400,
            color: LoomTheme.textSecondary(context),
          ),
        ),
      ),
    );
  }
}
