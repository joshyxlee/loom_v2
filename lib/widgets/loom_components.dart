import 'dart:ui';

import 'package:flutter/material.dart';

import 'design_system.dart';

class LoomCard extends StatelessWidget {
  const LoomCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LoomSpacing.sm),
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
        child: Text(label, style: LoomTypography.body.copyWith(color: Colors.white)),
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
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: LoomColors.primary.withOpacity(0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LoomRadius.button),
          ),
        ),
        onPressed: onPressed,
        child: Text(label, style: LoomTypography.body.copyWith(color: LoomColors.primary)),
      ),
    );
  }
}

class LoomSectionHeader extends StatelessWidget {
  const LoomSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: LoomTypography.title),
              if (subtitle != null) ...[
                const SizedBox(height: LoomSpacing.xs),
                Text(subtitle!,
                    style: LoomTypography.caption.copyWith(color: LoomColors.mutedText)),
              ],
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class LoomPill extends StatelessWidget {
  const LoomPill({super.key, required this.label, required this.isActive});

  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LoomSpacing.sm,
        vertical: LoomSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isActive ? LoomColors.primary.withOpacity(0.12) : Colors.white,
        borderRadius: BorderRadius.circular(LoomRadius.pill),
        border: Border.all(color: LoomColors.divider),
      ),
      child: Text(
        label,
        style: LoomTypography.caption.copyWith(
          color: isActive ? LoomColors.primary : LoomColors.mutedText,
        ),
      ),
    );
  }
}

class LoomListRow extends StatelessWidget {
  const LoomListRow({
    super.key,
    required this.rank,
    required this.name,
    required this.score,
    this.isTop = false,
  });

  final int rank;
  final String name;
  final int score;
  final bool isTop;

  @override
  Widget build(BuildContext context) {
    final color = isTop ? LoomColors.primary : LoomColors.mutedText;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: LoomSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: LoomSpacing.md,
            child: Text(
              rank.toString(),
              style: LoomTypography.body.copyWith(color: color),
            ),
          ),
          const SizedBox(width: LoomSpacing.xs),
          Expanded(child: Text(name, style: LoomTypography.body)),
          Text(
            score.toString(),
            style: LoomTypography.body.copyWith(
              color: LoomColors.mutedText,
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class LoomProgressIndicator extends StatelessWidget {
  const LoomProgressIndicator({
    super.key,
    required this.activeIndex,
    required this.isActive,
  });

  final int activeIndex;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(7, (index) {
        final isToday = index == activeIndex;
        final fillColor = isToday && isActive
            ? LoomColors.warning
            : LoomColors.divider;
        return Container(
          width: LoomSizes.dotSize,
          height: LoomSizes.dotSize,
          margin: const EdgeInsets.only(right: LoomSpacing.xs),
          decoration: BoxDecoration(
            color: fillColor,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

class LoomActionCard extends StatelessWidget {
  const LoomActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(LoomRadius.card),
      onTap: onTap,
      child: LoomCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: LoomColors.primary),
            const SizedBox(height: LoomSpacing.xs),
            Text(title, style: LoomTypography.body),
            const SizedBox(height: LoomSpacing.xs),
            Text(subtitle,
                style: LoomTypography.micro.copyWith(color: LoomColors.mutedText)),
          ],
        ),
      ),
    );
  }
}

class LoomChallengeRow extends StatelessWidget {
  const LoomChallengeRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(LoomRadius.card),
      onTap: onTap,
      child: LoomCard(
        child: Row(
          children: [
            Icon(icon, color: LoomColors.primary),
            const SizedBox(width: LoomSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: LoomTypography.body),
                  const SizedBox(height: LoomSpacing.xs),
                  Text(subtitle,
                      style: LoomTypography.micro.copyWith(color: LoomColors.mutedText)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: LoomColors.mutedText),
          ],
        ),
      ),
    );
  }
}
