// VOLLSTÄNDIG ERSETZEN: lib/features/main/main_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/nest_button.dart';

// ⚠️ Adjust if your login screen file lives elsewhere
import '../auth/login_screen.dart';

import '../home/home_screen.dart';
import '../schedule/schedule_screen.dart';
import '../membership/membership_screen.dart';
import '../cafe/cafe_screen.dart';
import '../profile/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();

    _widgetOptions = [
      HomeScreen(
        onNavigateToSchedule: () => _onItemTapped(1),
        onNavigateToMembership: () => _onItemTapped(4),
      ),
      const ScheduleScreen(),
      const CafeScreen(),
      const ProfileScreen(),
      const MembershipScreen(),
    ];
  }

  void _onItemTapped(int index) {
    final user = Supabase.instance.client.auth.currentUser;
    final isGuest = user == null;

    // ✅ Guest trying to open Schedule -> show popup with ONLY "Back to login"
    if (index == 1 && isGuest) {
      _showGuestSchedulePopup().then((goToLogin) {
        if (!mounted) return;

        if (goToLogin == true) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
          );
        }
        // If dismissed -> stay on current tab (do nothing)
      });
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  Future<bool?> _showGuestSchedulePopup() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please login to book',
                style: TextStyle(
                  fontFamily: 'SweetAndSalty',
                  fontSize: 22,
                  color: AppTheme.darkText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'To book a workspace, please login or create an account.',
                style: TextStyle(
                  fontFamily: 'CharlevoixPro',
                  fontSize: 14,
                  color: AppTheme.secondaryText,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: NestPrimaryButton(
                  text: 'Back to login',
                  backgroundColor: AppTheme.bookingButtonColor,
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), label: 'Schedule'),
          BottomNavigationBarItem(icon: Icon(Icons.coffee_outlined), label: 'Café'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.star_outline), label: 'Membership'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
