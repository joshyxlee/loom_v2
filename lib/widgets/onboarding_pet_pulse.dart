import 'package:flutter/material.dart';

class OnboardingPetPulse extends StatefulWidget {
  const OnboardingPetPulse({super.key});

  @override
  State<OnboardingPetPulse> createState() => _OnboardingPetPulseState();
}

class _OnboardingPetPulseState extends State<OnboardingPetPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: const Icon(Icons.pets, size: 64, color: Color(0xFF3CC77A)),
    );
  }
}
