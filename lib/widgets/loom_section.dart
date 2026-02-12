import 'package:flutter/material.dart';

import 'design_system.dart';

class LoomSectionHeader extends StatelessWidget {
  const LoomSectionHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: LoomTypography.screenTitle),
        if (subtitle != null) ...[
          const SizedBox(height: LoomSpacing.base),
          Text(
            subtitle!,
            style: LoomTypography.secondary.copyWith(
              color: LoomTheme.textSecondary(context),
            ),
          ),
        ],
      ],
    );
  }
}

class LoomProgressIndicator extends StatelessWidget {
  const LoomProgressIndicator({super.key, required this.activeCount});

  final int activeCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(7, (index) {
        final isActive = index < activeCount;
        return Container(
          width: LoomSizes.dotSize,
          height: LoomSizes.dotSize,
          margin: const EdgeInsets.only(right: LoomSpacing.base),
          decoration: BoxDecoration(
            color: isActive
                ? LoomTheme.accent(context)
                : LoomTheme.accent(context).withOpacity(0.4),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

class TokenChip extends StatelessWidget {
  const TokenChip({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: LoomTheme.accent(context).withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: LoomTheme.accent(context).withOpacity(0.6),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: LoomTypography.body.copyWith(
                fontWeight: FontWeight.w400,
                color: LoomTheme.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
