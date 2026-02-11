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
          Text(subtitle!,
              style: LoomTypography.secondary.copyWith(color: LoomColors.textSecondary)),
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
            color: isActive ? LoomColors.primary : LoomColors.divider,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}
