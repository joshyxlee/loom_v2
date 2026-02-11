import 'package:flutter/material.dart';

import 'design_system.dart';

class LoomCard extends StatelessWidget {
  const LoomCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LoomSizes.cardPadding),
      decoration: BoxDecoration(
        color: LoomColors.surface,
        borderRadius: BorderRadius.circular(LoomRadius.card),
        boxShadow: LoomElevation.card,
        border: Border.all(color: LoomColors.divider),
      ),
      child: child,
    );
  }
}
