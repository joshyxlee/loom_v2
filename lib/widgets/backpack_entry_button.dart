import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_system.dart';

class BackpackEntryButton extends StatefulWidget {
  const BackpackEntryButton({
    super.key,
    required this.totalUsable,
    required this.onTap,
  });

  final int totalUsable;
  final VoidCallback onTap;

  @override
  State<BackpackEntryButton> createState() => _BackpackEntryButtonState();
}

class _BackpackEntryButtonState extends State<BackpackEntryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _lastSeen = 0;

  @override
  void initState() {
    super.initState();
    _lastSeen = widget.totalUsable;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void didUpdateWidget(covariant BackpackEntryButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.totalUsable > _lastSeen) {
      HapticFeedback.lightImpact();
      _controller.forward(from: 0).then((_) => _controller.reverse());
    }
    _lastSeen = widget.totalUsable;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1 + 0.08 * _controller.value;
        final glowOpacity = 0.2 * _controller.value;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Transform.scale(
              scale: scale,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surfaceVariant.withOpacity(0.6),
                  border: Border.all(
                    color: scheme.outlineVariant.withOpacity(0.8),
                  ),
                  boxShadow: glowOpacity > 0
                      ? [
                          BoxShadow(
                            color: scheme.primary.withOpacity(glowOpacity),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: IconButton(
                  icon: const Icon(Icons.inventory_2_rounded, size: 22),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    widget.onTap();
                  },
                ),
              ),
            ),
            if (widget.totalUsable > 0)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.totalUsable}',
                    style: LoomTypography.secondary.copyWith(
                      color: scheme.onPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
