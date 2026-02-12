import 'package:flutter/material.dart';

import 'design_system.dart';

class LoomPrimaryButton extends StatelessWidget {
  const LoomPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.gradient,
    this.shadowColor,
  });

  final String label;
  final VoidCallback onPressed;
  final Gradient? gradient;
  final Color? shadowColor;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LoomSizes.buttonRadius),
        ),
        elevation: 0.8,
        shadowColor: shadowColor ?? LoomTheme.shadow(context),
        backgroundColor: gradient == null ? null : Colors.transparent,
        textStyle: LoomTypography.body.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );

    if (gradient == null) {
      return SizedBox(
        height: LoomSizes.buttonHeight,
        width: double.infinity,
        child: button,
      );
    }

    return SizedBox(
      height: LoomSizes.buttonHeight,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(LoomSizes.buttonRadius),
          boxShadow: [
            BoxShadow(
              color: shadowColor ?? LoomTheme.shadow(context),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: button,
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
