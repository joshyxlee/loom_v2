import 'package:flutter/material.dart';

class OnboardingPage {
  const OnboardingPage({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
}

const onboardingPages = [
  OnboardingPage(
    title: '每天 3 分鐘，把好奇變成習慣',
    subtitle: '不是考試，是每天替自己加一點知識厚度。',
  ),
  OnboardingPage(
    title: '你會有一個學習夥伴',
    subtitle: '你每天學的內容，會影響它變成什麼樣子。',
  ),
  OnboardingPage(
    title: '每次重要成長，都會被收藏',
    subtitle: '你的夥伴會留下不同樣子，成為你的收藏。',
  ),
];

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.onFinish});

  final VoidCallback onFinish;

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
                        const SizedBox(height: 12),
                        Text(page.subtitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium),
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
                  TextButton(
                    onPressed: widget.onFinish,
                    child: const Text('跳過'),
                  ),
                  const Spacer(),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        if (_index == onboardingPages.length - 1) {
                          widget.onFinish();
                        } else {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          );
                        }
                      },
                      child: Text(_index == onboardingPages.length - 1 ? '開始今日回合' : '下一步'),
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
