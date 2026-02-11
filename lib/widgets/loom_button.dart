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
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LoomSizes.buttonRadius),
          ),
          elevation: 0.8,
          shadowColor: Colors.black.withOpacity(0.08),
          textStyle: LoomTypography.body.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
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
