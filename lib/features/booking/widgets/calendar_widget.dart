// VOLLSTÄNDIG ERSETZEN: lib/features/booking/widgets/calendar_widget.dart

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/app_theme.dart';
import '../models/booking_models.dart';

class CalendarWidget extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;
  final Map<DateTime, OccupancyStatus> occupancyMap;
  final DateTime firstAvailableDate;
  final bool Function(DateTime) isDayEnabled;

  const CalendarWidget({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    required this.occupancyMap,
    required this.firstAvailableDate,
    required this.isDayEnabled,
  });

  // ✅ NEW: Your exact colors
  static const Color _dayGreen = Color(0xFFB2E5D1); // 0–50%
  static const Color _dayOrange = Color(0xFFFFBD59); // 50–99%
  static const Color _dayRed = Color(0xFFFF5757); // 100%

  Color _getOccupancyColor(OccupancyStatus? status) {
    switch (status) {
      case OccupancyStatus.low:
        return _dayGreen;

    // We treat both as "busy" (50–99%) to be safe,
    // even if 'high' is not used by your current logic.
      case OccupancyStatus.medium:
      case OccupancyStatus.high:
        return _dayOrange;

      case OccupancyStatus.full:
        return _dayRed;

      default:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TableCalendar(
      locale: 'en_US',
      firstDay: firstAvailableDate,
      lastDay: DateTime(2026, 12, 31),
      focusedDay: selectedDate,
      calendarFormat: CalendarFormat.month,
      availableCalendarFormats: const {CalendarFormat.month: 'Month'},
      selectedDayPredicate: (day) => isSameDay(selectedDate, day),
      onDaySelected: (selectedDay, focusedDay) {
        if (isDayEnabled(selectedDay)) {
          onDateSelected(selectedDay);
        }
      },
      enabledDayPredicate: isDayEnabled,
      headerStyle: const HeaderStyle(
        titleCentered: true,
        formatButtonVisible: false,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      calendarStyle: CalendarStyle(
        todayDecoration: const BoxDecoration(color: Colors.transparent, shape: BoxShape.circle),
        todayTextStyle: const TextStyle(color: Colors.black),
        selectedDecoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.sageGreen, width: 2),
        ),
        selectedTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        disabledTextStyle: TextStyle(color: Colors.grey.shade400),
        outsideTextStyle: const TextStyle(color: Colors.transparent),
      ),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) {
          final status = occupancyMap[DateTime(day.year, day.month, day.day)];
          if (status != null && status != OccupancyStatus.notAvailable) {
            return Container(
              margin: const EdgeInsets.all(4.0),
              decoration: BoxDecoration(
                color: _getOccupancyColor(status),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  day.day.toString(),
                  style: const TextStyle(color: Colors.black),
                ),
              ),
            );
          }
          return null;
        },
        selectedBuilder: (context, day, focusedDay) {
          final status = occupancyMap[DateTime(day.year, day.month, day.day)];
          final baseColor = _getOccupancyColor(status);

          return Container(
            margin: const EdgeInsets.all(4.0),
            decoration: BoxDecoration(
              color: baseColor == Colors.transparent ? Colors.blueAccent.withOpacity(0.12) : baseColor.withOpacity(0.75),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.sageGreen, width: 2),
            ),
            child: Center(
              child: Text(
                day.day.toString(),
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
      ),
    );
  }
}
