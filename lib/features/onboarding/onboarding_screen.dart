// lib/features/onboarding/onboarding_screen.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const OnboardingScreen({super.key, required this.onFinished});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _pageIndex = 0;

  final List<Map<String, String>> _slides = [
    {
      'image': 'assets/images/onboarding_1.png',
      'title': 'Welcome to NEST!',
      'text':
      'NEST is a community built around the idea that it really does take a village to raise a child and a business (or career). At NEST, you’ll finally breathe a sigh of relief – you’ve found your people and your place.',
    },
    {
      'image': 'assets/images/onboarding_2.png',
      'title': 'Work Productively, Completely Guilt-Free',
      'text': 'Your child plays happily with trained childcare staff right next door.',
    },
    {
      'image': 'assets/images/onboarding_3.png',
      'title': 'Stay Close While Having All The Support You Need',
      'text': 'Pop in for a cuddle, a feed, or a quick check-in anytime.',
    },
    {
      'image': 'assets/images/onboarding_4.png',
      'title': 'Find Your Village',
      'text':
      'Goodbye isolation! Meet other parents who share your rhythm, struggles, goals and values.\nWork, chat, learn, breathe – together.',
    },
    {
      'image': 'assets/images/onboarding_5.png', // Your transparent image
      'title': 'Grow Together',
      'text':
      'Join us for classes and events tailored to you and your family! Or relax and connect in our Family Café that caters to big and small humans alike.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isLast = _pageIndex == _slides.length - 1;

    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      body: SafeArea(
        child: Column(
          children: [
            // SLIDES
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (index) => setState(() => _pageIndex = index),
                itemBuilder: (context, index) {
                  final slide = _slides[index];

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // IMAGE
                      Image.asset(
                        slide['image']!,
                        height: 260,
                        fit: BoxFit.contain,
                      ),

                      const SizedBox(height: 40),

                      // HEADLINE (SweetAndSalty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          slide['title']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'SweetAndSalty',
                            fontSize: 30,
                            color: AppTheme.darkText,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // TEXT (Charlevoix)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          slide['text']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'CharlevoixPro',
                            fontSize: 16,
                            height: 1.5,
                            color: AppTheme.darkText,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // NAVIGATION AREA
            Container(
              height: 110,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: isLast
                  ? Center(
                child: ElevatedButton(
                  onPressed: widget.onFinished,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.bookingButtonColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 32,
                    ),
                  ),
                  child: const Text(
                    'Get Started',
                    style: TextStyle(
                      fontFamily: 'CharlevoixPro',
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // SKIP BUTTON
                  TextButton(
                    onPressed: widget.onFinished,
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        fontFamily: 'CharlevoixPro',
                        fontSize: 16,
                        color: AppTheme.darkText,
                      ),
                    ),
                  ),

                  // DOTS
                  Row(
                    children: List.generate(
                      _slides.length,
                          (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _pageIndex == i ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _pageIndex == i
                              ? AppTheme.sageGreen
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  // NEXT ARROW
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () => _controller.nextPage(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
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
