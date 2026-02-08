import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/booking_models.dart';
import '../widgets/calendar_widget.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime selectedDate = DateTime.now();
  final Map<DateTime, OccupancyStatus> occupancyMap = {};
  late final DateTime firstAvailableDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(
        title: const Text("Book a Space"),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Choose your date",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkText,
              ),
            ),
            const SizedBox(height: 16),
            CalendarWidget(
              selectedDate: selectedDate,
              onDateSelected: (date) {
                setState(() => selectedDate = date);
              },
              occupancyMap: occupancyMap,
              firstAvailableDate: firstAvailableDate,
              isDayEnabled: (date) => date
                  .isAfter(DateTime.now().subtract(const Duration(days: 1))),
            ),
            const SizedBox(height: 40),
            const Center(
              child: Text(
                "Workspace selection kommt als Nächstes 🚀",
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
