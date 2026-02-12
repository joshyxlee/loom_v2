import 'package:flutter/material.dart';

import 'design_system.dart';

class LoomCard extends StatelessWidget {
  const LoomCard({
    super.key,
    required this.child,
    this.background,
    this.borderColor,
  });

  final Widget child;
  final Color? background;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LoomSizes.cardPadding),
      decoration: BoxDecoration(
        color: background ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(LoomRadius.card),
        boxShadow: LoomElevation.card,
        border:
            Border.all(color: borderColor ?? Theme.of(context).colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}
