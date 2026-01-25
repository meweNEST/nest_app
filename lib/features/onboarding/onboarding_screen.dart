// VOLLSTÄNDIG ERSETZEN: lib/features/onboarding/onboarding_screen.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  // NEU: Nimmt eine Funktion entgegen, die aufgerufen wird, wenn das Onboarding fertig ist.
  final VoidCallback onFinished;

  const OnboardingScreen({super.key, required this.onFinished});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _pageIndex = 0;

  final List<Map<String, String>> _slides = [
    {'image': 'assets/images/onboarding_1.png', 'title': 'Welcome', 'text': '...'},
    {'image': 'assets/images/onboarding_2.png', 'title': 'Book care', 'text': '...'},
    {'image': 'assets/images/onboarding_3.png', 'title': 'Manage', 'text': '...'},
    {'image': 'assets/images/onboarding_4.png', 'title': 'Connect', 'text': '...'},
    {'image': 'assets/images/onboarding_5.png', 'title': 'Safe care', 'text': '...'},
  ];

  @override
  Widget build(BuildContext context) {
    final isLast = _pageIndex == _slides.length - 1;

    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (index) => setState(() => _pageIndex = index),
                itemBuilder: (context, index) {
                  // ... (Der Inhalt des PageView.builder bleibt gleich)
                  final slide = _slides[index];
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(slide['image']!, height: 280),
                      const SizedBox(height: 40),
                      Text(slide['title']!, style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(slide['text']!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)),
                      ),
                    ],
                  );
                },
              ),
            ),
            Container(
              height: 100,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: isLast
                  ? Center(
                child: ElevatedButton(
                  // RUFT JETZT DIE onFinished FUNKTION AUF
                  onPressed: widget.onFinished,
                  child: const Text('Get Started'),
                ),
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(onPressed: widget.onFinished, child: const Text('Skip')),
                  // ... (Dots)
                  Row(
                    children: List.generate(_slides.length, (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8, width: _pageIndex == i ? 24 : 8,
                      decoration: BoxDecoration(color: _pageIndex == i ? AppTheme.sageGreen : Colors.grey.shade300, borderRadius: BorderRadius.circular(12)),
                    ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () => _controller.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut),
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
