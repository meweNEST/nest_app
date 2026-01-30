import 'package:flutter/material.dart';
import 'package:nest_app/core/theme/app_theme.dart';
import 'package:nest_app/widgets/nest_button.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback? onNavigateToSchedule;
  final VoidCallback? onNavigateToMembership;

  const HomeScreen({
    super.key,
    this.onNavigateToSchedule,
    this.onNavigateToMembership,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // LOGO
              Center(
                child: Image.asset(
                  'assets/images/nest_logo.png',
                  height: 100,
                ),
              ),

              const SizedBox(height: 16),

              // HEADLINE
              const Center(
                child: Text(
                  'Welcome back, Ella! 👋',
                  style: TextStyle(
                    fontFamily: 'SweetAndSalty',
                    fontSize: 28,
                    color: AppTheme.darkText,
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // SUBLINE
              const Center(
                child: Text(
                  'Ready to be productive today?',
                  style: TextStyle(
                    fontFamily: 'CharlevoixPro',
                    fontSize: 16,
                    color: AppTheme.secondaryText,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 32),

              // QUICK ACTIONS TITLE
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontFamily: 'CharlevoixPro',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText,
                ),
              ),

              const SizedBox(height: 12),

              // QUICK ACTIONS BUTTONS
              Row(
                children: [
                  Expanded(
                    child: NestPrimaryButton(
                      text: 'BOOK DESK',
                      onPressed: () => onNavigateToSchedule?.call(),
                      backgroundColor: AppTheme.bookingButtonColor,
                      textColor: AppTheme.bookingButtonTextColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NestPrimaryButton(
                      text: 'ORDER COFFEE',
                      onPressed: () {},
                      backgroundColor: Color(0xFFFFBD59),
                      textColor: Colors.black87,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // UPCOMING EVENT CARD
              _buildInfoCard(
                icon: Icons.celebration_outlined,
                title: 'Upcoming Event',
                content: 'Grand opening event - 16 March 2026',
                subcontent: 'Don\'t forget to register and join the party!',
                backgroundColor: AppTheme.bookingButtonHoverColor,
                hasBorder: false,
              ),

              const SizedBox(height: 16),

              // OPENING HOURS CARD
              _buildInfoCard(
                icon: Icons.access_time_filled_rounded,
                title: 'Opening Hours',
                content: 'Mon - Fri: 8:00 AM - 6:00 PM',
                subcontent: 'Sat - Sun & Holidays: Closed',
                backgroundColor: Colors.white,
                hasBorder: true,
              ),

              const SizedBox(height: 16),

              // MEMBERSHIP CTA BOX
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.bookingButtonHoverColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Ready to Make Work & Family Actually Fit Together?',
                      style: TextStyle(
                        fontFamily: 'CharlevoixPro',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'We open in March 2026!\nOur first location is coming to Hamburg-Uhlenhorst soon. Spots are limited to keep groups small & personal. Join the waitlist now – no commitment, and get a special early-bird discount if you become a member.',
                      style: TextStyle(
                        fontFamily: 'CharlevoixPro',
                        fontSize: 14,
                        height: 1.5,
                        color: AppTheme.darkText,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              NestPrimaryButton(
                text: 'Choose your membership',
                onPressed: () => onNavigateToMembership?.call(),
                backgroundColor: Color(0xFFFF5757),
              ),

              const SizedBox(height: 32),

              // FOUNDERS SECTION
              Container(
                margin: const EdgeInsets.only(bottom: 32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Color(0xFFF87CC8),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Meet NEST – CoWork & Play',
                      style: TextStyle(
                        fontFamily: 'SweetAndSalty',
                        fontSize: 28,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'Your coworking and community space in Hamburg Uhlenhorst, designed for parents with babies & toddlers (0–5).',
                      style: TextStyle(
                        fontFamily: 'CharlevoixPro',
                        fontSize: 16,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 24),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/images/delia and melissa.jpeg',
                        fit: BoxFit.cover,
                      ),
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'Founded by two moms while literally working from playground benches... NEST was built to solve the problem parents actually live.',
                      style: TextStyle(
                        fontFamily: 'CharlevoixPro',
                        fontSize: 14,
                        color: Colors.white,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      '✨ A quiet workspace\n'
                          '✨ Montessori-inspired childcare\n'
                          '✨ A supportive community\n'
                          '✨ A family café & classes\n',
                      style: TextStyle(
                        fontFamily: 'CharlevoixPro',
                        fontSize: 14,
                        color: Colors.white,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.left,
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'Here, you can work with focus and stay close to your child — so everyone thrives.',
                      style: TextStyle(
                        fontFamily: 'CharlevoixPro',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // INFO CARD
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required String subcontent,
    required Color backgroundColor,
    bool hasBorder = false,
  }) {
    final Color textColor = hasBorder ? AppTheme.darkText : Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: hasBorder ? Border.all(color: Colors.grey.shade300) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: textColor, size: 20),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'CharlevoixPro',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            content,
            style: TextStyle(
              fontFamily: 'CharlevoixPro',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            subcontent,
            style: TextStyle(
              fontFamily: 'CharlevoixPro',
              fontSize: 14,
              color: textColor.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}
