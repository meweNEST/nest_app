// VOLLSTÄNDIG ERSETZEN: lib/features/schedule/schedule_screen.dart

import 'dart:collection';
import 'package:flutter/material.dart';

// Korrigierte Imports, die jetzt auf die zentrale Model-Datei verweisen
import '../../core/theme/app_theme.dart';
import '../booking/models/booking_models.dart'; // WICHTIG: Neuer Import
import '../booking/widgets/calendar_widget.dart';
import '../booking/widgets/meeting_room_selection_sheet.dart';
import '../booking/widgets/add_extras_bottom_sheet.dart';


class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  // Die lokalen Definitionen von UserBooking und UserMembership sind jetzt GELÖSCHT
  // ... (Der Rest der Datei bleibt exakt so, wie du ihn hattest)

  final DateTime firstAvailableDate = DateTime(2026, 3, 16);
  late DateTime selectedDate;
  String? selectedTimeSlot;
  String? selectedPreference;

  final UserMembership _currentUserMembership = UserMembership.regular;
  final List<UserBooking> _userBookings = [];

  final List<String> timeSlots = ['9-12', '12-15', '15-18', 'Full Day'];
  final List<String> preferences = ['Quiet Zone', 'Social Area'];

  final List<Map<String, dynamic>> _dummyWorkspaces = [
    {'id': '1', 'name': 'Sunny Corner Desk ☀️', 'type': 'desk', 'capacity': 1, 'subline': 'Work while your child plays nearby.', 'benefits': ['High-speed Wi-Fi', 'Ergonomic chair', 'Natural light'], 'tags': ['social']},
    {'id': '2', 'name': 'Quiet Focus Pod 🎧', 'type': 'desk', 'capacity': 1, 'subline': 'Sound-proofed for concentration.', 'benefits': ['Noise-cancelling', 'Adjustable desk', 'Privacy screen'], 'tags': ['quiet']},
    {'id': '3', 'name': 'Meeting Room 🤝', 'type': 'meeting', 'capacity': 4, 'subline': 'Collaborate in a professional setting.', 'benefits': ['Whiteboard', 'Comfortable seating', 'Video conferencing'], 'tags': ['social', 'quiet']},
  ];

  late Map<DateTime, OccupancyStatus> _occupancyMap;

  @override
  void initState() {
    super.initState();
    selectedDate = firstAvailableDate;
    _recalculateAndSetOccupancy();
  }

  bool _isWeekend(DateTime day) => day.weekday == 6 || day.weekday == 7;

  bool _isHolidayInHamburg2026(DateTime day) {
    final holidays = [DateTime(2026, 1, 1), DateTime(2026, 4, 3), DateTime(2026, 4, 6), DateTime(2026, 5, 1), DateTime(2026, 5, 14), DateTime(2026, 5, 25), DateTime(2026, 10, 3), DateTime(2026, 10, 31), DateTime(2026, 12, 25)];
    return holidays.any((h) => h.year == day.year && h.month == day.month && h.day == day.day);
  }

  bool isDayEnabled(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    if (normalizedDay.isBefore(firstAvailableDate)) return false;
    if (_isWeekend(day)) return false;
    if (_isHolidayInHamburg2026(day)) return false;
    return true;
  }

  void _recalculateAndSetOccupancy() {
    const int totalCapacityPerDay = 24;
    final Map<DateTime, int> bookingCounts = HashMap();
    for (final booking in _userBookings) {
      final dayOnly = DateTime(booking.day.year, booking.day.month, booking.day.day);
      bookingCounts[dayOnly] = (bookingCounts[dayOnly] ?? 0) + 1;
    }
    final Map<DateTime, OccupancyStatus> newOccupancyMap = HashMap();
    final endDate = DateTime(2026, 12, 31);
    for (var day = firstAvailableDate; day.isBefore(endDate); day = day.add(const Duration(days: 1))) {
      final dayOnly = DateTime(day.year, day.month, day.day);
      if (!isDayEnabled(dayOnly)) {
        newOccupancyMap[dayOnly] = OccupancyStatus.notAvailable;
        continue;
      }
      final count = bookingCounts[dayOnly] ?? 0;
      final occupancyPercent = count / totalCapacityPerDay;
      if (count >= totalCapacityPerDay) {
        newOccupancyMap[dayOnly] = OccupancyStatus.full;
      } else if (occupancyPercent > 0.8) {
        newOccupancyMap[dayOnly] = OccupancyStatus.high;
      } else if (occupancyPercent > 0.2) {
        newOccupancyMap[dayOnly] = OccupancyStatus.medium;
      } else {
        newOccupancyMap[dayOnly] = OccupancyStatus.low;
      }
    }
    setState(() {
      _occupancyMap = newOccupancyMap;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(elevation: 0, toolbarHeight: 0, backgroundColor: AppTheme.white),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Image.asset('assets/images/nest_logo.png', height: 100)),
              const SizedBox(height: 16),
              const Center(child: Text('Find your perfect spot!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.darkText))),
              const Center(child: Text('Book a workspace that fits your needs', style: TextStyle(fontSize: 14, color: AppTheme.secondaryText))),
              const SizedBox(height: 24),
              const Text("Choose your date", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
              const SizedBox(height: 16),
              CalendarWidget(
                selectedDate: selectedDate,
                onDateSelected: (date) => setState(() => selectedDate = date),
                occupancyMap: _occupancyMap,
                firstAvailableDate: firstAvailableDate,
                isDayEnabled: isDayEnabled,
              ),
              const SizedBox(height: 40),
              const Text("Select Time Slot", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
              const SizedBox(height: 16),
              _buildFilterChips(timeSlots, selectedTimeSlot, (val) => setState(() => selectedTimeSlot = val)),
              const SizedBox(height: 40),
              const Text("Preferences", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
              const SizedBox(height: 16),
              _buildFilterChips(preferences, selectedPreference, (val) => setState(() => selectedPreference = val)),
              const SizedBox(height: 40),
              const Text("Available Workspaces", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
              const SizedBox(height: 16),
              _buildWorkspaceList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(List<String> items, String? selectedItem, Function(String?) onSelected) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: items.map((item) {
        final isSelected = item == selectedItem;
        return ChoiceChip(
          label: Text(item),
          selected: isSelected,
          selectedColor: AppTheme.sageGreen,
          backgroundColor: AppTheme.creamBackground,
          labelStyle: TextStyle(color: isSelected ? Colors.white : AppTheme.darkText, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
          side: const BorderSide(color: AppTheme.sageGreen),
          onSelected: (selected) => onSelected(selected ? item : null),
        );
      }).toList(),
    );
  }

  Widget _buildWorkspaceList() {
    if (selectedTimeSlot == null) {
      return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text("Please select a time slot.", textAlign: TextAlign.center)));
    }
    List<Map<String, dynamic>> filteredWorkspaces = _dummyWorkspaces;
    if (selectedPreference != null) {
      final tag = selectedPreference == 'Quiet Zone' ? 'quiet' : 'social';
      filteredWorkspaces = _dummyWorkspaces.where((ws) => (ws['tags'] as List<String>).contains(tag)).toList();
    }
    return Column(
      children: filteredWorkspaces.map((workspace) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))]),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(workspace['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
                      const SizedBox(height: 4),
                      Text(workspace['subline'], style: const TextStyle(fontSize: 14, color: AppTheme.secondaryText)),
                      const SizedBox(height: 8),
                      ...(workspace['benefits'] as List<String>).take(3).map((b) => Padding(padding: const EdgeInsets.only(bottom: 2.0), child: Row(children: [const Text('• '), Expanded(child: Text(b))]))).toList(),
                    ],
                  ),
                ),
                SizedBox(
                  width: 180,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => _handleWorkspaceSelection(workspace),
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(AppTheme.bookingButtonColor),
                      shape: MaterialStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                    ),
                    child: const Text('Select Workspace'),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _handleWorkspaceSelection(Map<String, dynamic> workspace) async {
    final isBooked = _userBookings.any((b) => b.day.isAtSameMomentAs(selectedDate) && (b.timeSlot == selectedTimeSlot || b.timeSlot == 'Full Day' || selectedTimeSlot == 'Full Day'));
    if (isBooked) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Overlapping booking exists."), backgroundColor: Colors.red));
      return;
    }
    Map<String, dynamic>? details = workspace;
    if (workspace['type'] == 'meeting') {
      final selection = await showModalBottomSheet<MeetingBookingType>(context: context, builder: (ctx) => MeetingRoomSelectionSheet(currentUserMembership: _currentUserMembership));
      if (selection == null) return;
      details = selection == MeetingBookingType.private
          ? {'name': 'Private Room', 'subline': '...', 'benefits': <String>['Absolute privacy', 'Large screen']}
          : {'name': 'Shared Desk', 'subline': '...', 'benefits': <String>['Whiteboard', 'Comfortable seating']};
    }
    final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => AddExtrasBottomSheet(
          workspaceName: details!['name'],
          workspaceSubline: details['subline'],
          workspaceBenefits: (details['benefits'] as List).map((item) => item as String).toList(),
        ));
    if (confirmed == true && mounted) {
      setState(() {
        _userBookings.add(UserBooking(selectedDate, selectedTimeSlot!));
        _recalculateAndSetOccupancy();
      });
      showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Booking Confirmed!'), content: Text('${details!['name']} is booked.'), actions: [TextButton(child: const Text('OK'), onPressed: () => Navigator.of(ctx).pop())]));
    }
  }
}
