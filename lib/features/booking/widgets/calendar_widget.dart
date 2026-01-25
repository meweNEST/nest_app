// VOLLSTÄNDIG ERSETZEN: lib/features/booking/widgets/calendar_widget.dart

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/app_theme.dart';
import '../models/booking_models.dart'; // WICHTIG: Der neue, zentrale Import

class CalendarWidget extends StatelessWidget {
  // DIE LOKALE ENUM-DEFINITION IST JETZT ENTFERNT.

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

  Color _getOccupancyColor(OccupancyStatus? status) {
    switch (status) {
      case OccupancyStatus.low:
      // 'empty' gibt es in unserem zentralen Enum nicht mehr, wir behandeln es wie 'low'
        return Colors.green.shade100;
      case OccupancyStatus.medium:
        return Colors.orange.shade100;
      case OccupancyStatus.high:
        return Colors.red.shade100;
      case OccupancyStatus.full:
        return Colors.red.shade100.withOpacity(0.5);
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
          color: Colors.blue.shade200,
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
              child: Center(child: Text(day.day.toString(), style: const TextStyle(color: Colors.black))),
            );
          }
          return null;
        },
        selectedBuilder: (context, day, focusedDay) {
          final status = occupancyMap[DateTime(day.year, day.month, day.day)];
          return Container(
            margin: const EdgeInsets.all(4.0),
            decoration: BoxDecoration(
              color: _getOccupancyColor(status).withOpacity(0.7),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.sageGreen, width: 2),
            ),
            child: Center(child: Text(day.day.toString(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
          );
        },
      ),
    );
  }
}
