import 'package:flutter/material.dart';
import 'package:nest_app/core/theme/app_theme.dart';
// ScheduleScreen ist nicht mehr direkt notwendig, da die Navigation über den MainScreen geht

class HomeScreen extends StatelessWidget {
  // Callback-Funktion, um dem MainScreen zu sagen, den Tab zu wechseln
  final VoidCallback? onNavigateToSchedule;
  final VoidCallback? onNavigateToMembership;


  const HomeScreen({super.key, this.onNavigateToSchedule, this.onNavigateToMembership});

  @override
  Widget build(BuildContext context) {
    const Color membershipButtonColor = Color.fromRGBO(255, 87, 87, 1); // Farbe von "Choose your membership"
    const Color orderCoffeeBackgroundColor = Color.fromRGBO(255, 189, 89, 1); // Farbe von "Order Coffee"
    const Color orderCoffeeHoverColor = Color.fromRGBO(255, 87, 87, 1); // Hover-Farbe von "Order Coffee"

    // Das ist die Farbe für den Hover-Effekt des Book-Buttons vom ScheduleScreen
    final Color bookButtonHoverColor = AppTheme.bookingButtonHoverColor;

    // Für den Beispielinhalt: Später würde dies von der Datenquelle kommen
    const bool hasUpcomingBooking = false; // Setzen Sie dies auf false, um das Event zu sehen

    // Einheitlicher Button-Style für abgerundete Ecken
    final ButtonStyle roundedButtonStyle = ButtonStyle(
      padding: MaterialStateProperty.all(const EdgeInsets.symmetric(vertical: 16, horizontal: 20)),
      shape: MaterialStateProperty.all(const StadiumBorder()),
      foregroundColor: MaterialStateProperty.all(Colors.white), // Standard-Textfarbe
    );

    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // Standardmäßig linksbündig
            children: [
              const SizedBox(height: 24),
              // Logo, Headline und Subline zentriert
              Center(
                child: Image.asset(
                  'assets/images/nest_logo.png',
                  height: 100,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(
                    height: 100,
                    child: Text('Logo not found'),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Center( // Zentriert
                child: Text(
                  'Welcome back, Ella! 👋', // Aktualisierter Text
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 4),
              const Center( // Zentriert
                child: Text(
                  'Ready to be productive today?', // Aktualisierter Text
                  style: TextStyle(fontSize: 16, color: AppTheme.secondaryText),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),

              // --- Quick Actions Section ---
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkText),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        onNavigateToSchedule?.call(); // Navigation zum Schedule-Tab
                      },
                      style: roundedButtonStyle.copyWith(
                        backgroundColor: MaterialStateProperty.all(AppTheme.bookingButtonColor), // Pink Farbe
                        foregroundColor: MaterialStateProperty.all(AppTheme.bookingButtonTextColor),
                        overlayColor: MaterialStateProperty.all(bookButtonHoverColor), // Hover-Farbe
                      ),
                      child: const Text('BOOK DESK'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Implement "Order Coffee" logic
                      },
                      style: roundedButtonStyle.copyWith(
                        backgroundColor: MaterialStateProperty.all(orderCoffeeBackgroundColor),
                        foregroundColor: MaterialStateProperty.all(AppTheme.darkText),
                        overlayColor: MaterialStateProperty.all(orderCoffeeHoverColor), // Hover-Farbe
                      ),
                      child: const Text('ORDER COFFEE'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- Conditional Upcoming Booking/Event Card ---
              if (hasUpcomingBooking)
                _buildInfoCard(
                  icon: Icons.calendar_today,
                  title: 'Upcoming Booking',
                  content: 'Quiet Desk - Tomorrow, 9:00 AM',
                  subcontent: 'Don\'t forget to check in for your next booking',
                  backgroundColor: AppTheme.bookingButtonColor, // Pink Farbe
                )
              else
                _buildInfoCard(
                  icon: Icons.celebration_outlined,
                  title: 'Upcoming Event',
                  content: 'Grand opening event - 16 March 2026',
                  subcontent: 'Don\'t forget to register and join the party!',
                  backgroundColor: AppTheme.bookingButtonHoverColor, // Hoverfarbe des Book-Buttons
                  hasBorder: false, // Hat keine Border, da es eine Hintergrundfarbe hat
                ),
              const SizedBox(height: 16),

              // --- Opening Hours Card ---
              _buildInfoCard(
                icon: Icons.access_time_filled_rounded,
                title: 'Opening Hours',
                content: 'Mon - Fri: 8:00 AM - 6:00 PM',
                subcontent: 'Sat - Sun & Holidays: Closed',
                backgroundColor: Colors.white,
                hasBorder: true,
              ),
              const SizedBox(height: 16),

              // --- Membership/Waitlist Card ---
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: AppTheme.bookingButtonHoverColor, // Hintergrundfarbe angepasst
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ready to Make Work & Family Actually Fit Together?',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'We open in March 2026!\nOur first location is coming to Hamburg-Uhlenhorst soon. Spots are limited to keep groups small & personal. Join the waitlist now – no commitment, and get a special early-bird discount if you become a member.',
                      style: TextStyle(fontSize: 14, color: AppTheme.darkText, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    // Button "Choose your membership"
                    SizedBox( // Wrapped in SizedBox to give it full width
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          onNavigateToMembership?.call(); // Navigation zum Membership-Screen
                        },
                        style: roundedButtonStyle.copyWith(
                          backgroundColor: MaterialStateProperty.all(membershipButtonColor),
                          foregroundColor: MaterialStateProperty.all(Colors.white),
                          padding: MaterialStateProperty.all(const EdgeInsets.symmetric(vertical: 16, horizontal: 24)), // Padding für Text im Button
                        ),
                        child: const Text('Choose your membership'), // Text geändert
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32), // Spacer am Ende
            ],
          ),
        ),
      ),
    );
  }

  // A generic helper widget for the info cards
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required String subcontent,
    required Color backgroundColor,
    bool hasBorder = false,
  }) {
    // Farbe des Textes wird automatisch angepasst, je nach Hintergrundhelligkeit
    final Color textColor = hasBorder ? AppTheme.darkText : Colors.white;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16.0),
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
                style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 4),
          Text(
            subcontent,
            style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.9)),
          ),
        ],
      ),
    );
  }
}
