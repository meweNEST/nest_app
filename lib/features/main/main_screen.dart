// VOLLSTÄNDIG ERSETZEN: lib/features/main/main_screen.dart

import 'package:flutter/material.dart';
import '../home/home_screen.dart'; // Wir brauchen die Imports für die späteren Tests
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

  // Die Liste der Widgets wird direkt hier deklariert.
  // Wir verwenden Dummys, um den Fehler zu finden.
  late final List<Widget> _widgetOptions;

  // Die Methode zum Wechseln des Tabs.
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // In: lib/features/main/main_screen.dart

  // In: lib/features/main/main_screen.dart

  // In: lib/features/main/main_screen.dart -> initState()

  // In: lib/features/main/main_screen.dart -> initState()

  // In: lib/features/main/main_screen.dart

  // In: lib/features/main/main_screen.dart -> initState()

  @override
  void initState() {
    super.initState();

    // WIR AKTIVIEREN JETZT ALLE ECHTEN SCREENS
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
        onTap: _onItemTapped, // Korrekt hier zugewiesen
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
