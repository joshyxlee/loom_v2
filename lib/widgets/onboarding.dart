import 'package:flutter/material.dart';

import 'onboarding_pet_pulse.dart';

class OnboardingPage {
  const OnboardingPage({required this.title, required this.subtitle, this.showPet = false});
  final String title;
  final String subtitle;
  final bool showPet;
}

const onboardingPages = [
  OnboardingPage(
    title: '你每天都會遇到一堆問題。\n但老實說，\n你不是真的不懂。',
    subtitle: '只是有時候會被直覺騙一下。',
  ),
  OnboardingPage(
    title: '有些答案你其實「差一點就對了」。\n有些迷思，大家都信，但其實不太對。',
    subtitle: 'Loom 就是拿來處理這種狀況的。',
  ),
  OnboardingPage(
    title: '這不是刷題 App。\n是把「差點搞錯的地方」變成直覺。',
    subtitle: '',
  ),
  OnboardingPage(
    title: '每天幾題就好。\n答對、答錯、差一點，都算前進。',
    subtitle: '沒有壓力，也不用記規則。',
  ),
  OnboardingPage(
    title: '你玩的方式，\n會慢慢影響你的學習夥伴。',
    subtitle: '玩什麼多，它就長得比較像那一型。',
    showPet: true,
  ),
  OnboardingPage(
    title: '玩久了你會發現，\n有些問題真的不用想那麼久了。',
    subtitle: '那種感覺，很爽。',
  ),
  OnboardingPage(
    title: '好了，來玩一回合吧。',
    subtitle: '',
  ),
];

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _controller = PageController();
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: onboardingPages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, index) {
                  final page = onboardingPages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(page.title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge),
                        if (page.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(page.subtitle,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                        if (page.showPet) ...[
                          const SizedBox(height: 24),
                          OnboardingPetPulse(),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                onboardingPages.length,
                (i) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  decoration: BoxDecoration(
                    color: i == _index ? Colors.green : Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        if (_index == onboardingPages.length - 1) {
                          widget.onStart();
                        } else {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          );
                        }
                      },
                      child: Text(_index == onboardingPages.length - 1 ? '開始第一回合' : '下一步'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
