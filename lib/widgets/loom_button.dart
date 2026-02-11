import 'package:flutter/material.dart';

import 'design_system.dart';

class LoomPrimaryButton extends StatelessWidget {
  const LoomPrimaryButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: LoomSizes.buttonHeight,
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        child: Text(label, style: LoomTypography.body.copyWith(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class LoomSecondaryButton extends StatelessWidget {
  const LoomSecondaryButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: LoomSizes.buttonHeight,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        child: Text(label, style: LoomTypography.body.copyWith(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class LoomTileButton extends StatelessWidget {
  const LoomTileButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: LoomSizes.buttonHeight,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        child: Text(label, style: LoomTypography.body),
      ),
    );
  }
}
