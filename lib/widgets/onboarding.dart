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
    title: '你在養一棵會長大的樹',
    subtitle: '每一題都是養分，樹會替你記得你的成長。',
  ),
  OnboardingPage(
    title: '今天走一小步，明天就輕鬆很多',
    subtitle: '每天一回合，累積的不是分數，是底氣。',
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
                  FilledButton(
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
